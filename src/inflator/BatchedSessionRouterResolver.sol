// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AddressRegistry} from "./AddressRegistry.sol";
import {ISmartAccount} from "../smart-account/ISmartAccount.sol";
import {IInflator} from "../interfaces/IInflator.sol";
import "forge-std/console2.sol";

struct SessionData {
    uint48 validUntil;
    uint48 validAfter;
    address sessionValidationModule;
    bytes sessionKeyData;
    bytes32[] merkleProof;
    bytes callSpecificData;
}

/**
 * DISCLAIMER: This is a PoC - not gas optimised
 */
contract BatchedSessionRouterResolver is IInflator {
    address sessionKeyManager = 0x000002FbFfedd9B33F4E7156F2DE8D48945E7489;
    address batchedSessionRouter = 0x00000D09967410f8C76752A104c9848b57ebba55;
    AddressRegistry public svmRegistry = new AddressRegistry();

    /**
     * Normally, the user op signature for batched session router is:
     * abi.encode(
     *     bytes moduleSignature,
     *     address batchedSessionRouter
     *  )
     *
     *  where moduleSignature is
     *  abi.encode(
     *     address sessionKeyManager,
     *     SessionData[] sessionDatas,
     *     bytes sessionKeySignature
     *  )
     *
     *  where SessionData is
     *  struct SessionData {
     *     uint48 validUntil;
     *     uint48 validAfter;
     *     address sessionValidationModule;
     *     bytes sessionKeyData;
     *     bytes32[] merkleProof;
     *     bytes callSpecificData;
     * }
     *
     *  There are a series of improvements that can be done here:
     *  1. Hardcode the batchedSessionRouter address in this resolver
     *  2. Hardcode the sessionKeyManager address in this resolver
     *  3. replace 20 byte sessionValidationModule with 2 byte id for (65536 unique sessionValidationModules)
     *
     *  Note: A lot of other stuff can be done like caching merkle proofs, packing data more efficiently etc.
     *  However, much of that is already taken care of in Session Keys V2 therefore I will not repeat the effort here in this PoC.
     *  This means that there will be significant scope of improvement here in the future.
     */

    function inflate(bytes calldata _data) external view override returns (bytes memory signature) {
        // _data:
        // <2 bytes - len(encoded(SessionDatas))> <len bytes - encoded(SessionDatas)> <remaining - encoded(sessionKeySignature)>
        // yeah ik session key signature can itself be better packed.
        // cut me some slack :P it's just a poc

        bytes calldata encodedSessionDatasArray;
        bytes calldata sessionKeySignature;
        assembly ("memory-safe") {
            let offset := _data.offset

            // Extract encodedSessionDatas
            let bitsToDiscard := sub(256, mul(2, 8))
            let encodedSessionDatasLen := shr(bitsToDiscard, calldataload(offset))
            offset := add(offset, 2)

            encodedSessionDatasArray.offset := offset
            encodedSessionDatasArray.length := encodedSessionDatasLen

            // Extract sessionKeySignature
            offset := add(offset, encodedSessionDatasLen)
            sessionKeySignature.offset := offset
            sessionKeySignature.length := sub(sub(_data.length, 2), encodedSessionDatasLen)
        }

        // rehydrate sessionDatas
        bytes[] calldata sessionDatasArray;
        assembly ("memory-safe") {
            let dataPointer := add(encodedSessionDatasArray.offset, calldataload(encodedSessionDatasArray.offset))
            sessionDatasArray.offset := add(dataPointer, 0x20)
            sessionDatasArray.length := calldataload(dataPointer)
        }
        SessionData[] memory sessionDatas = new SessionData[](sessionDatasArray.length);
        for (uint256 i = 0; i < sessionDatasArray.length; i++) {
            uint48 validUntil;
            uint48 validAfter;
            bytes32 svmId;
            bytes calldata sessionKeyData;
            bytes calldata encodeMerkleProofs;
            bytes calldata callSpecificData;

            bytes calldata sessionDataCompressed = sessionDatasArray[i];

            assembly ("memory-safe") {
                let offset := sessionDataCompressed.offset

                let bitsToDiscard := sub(256, 48)
                validUntil := shr(bitsToDiscard, calldataload(offset))
                offset := add(offset, div(48, 8))

                bitsToDiscard := sub(256, 48)
                validAfter := shr(bitsToDiscard, calldataload(offset))
                offset := add(offset, div(48, 8))

                bitsToDiscard := sub(256, mul(2, 8))
                svmId := shr(bitsToDiscard, mload(offset))
                offset := add(offset, 2)

                // extract dynamic length sessionKeyData
                bitsToDiscard := sub(256, mul(2, 8))
                sessionKeyData.length := shr(bitsToDiscard, calldataload(offset))
                sessionKeyData.offset := add(offset, 2)
                offset := add(offset, add(2, sessionKeyData.length))

                // extract dynamic length merkleProof
                bitsToDiscard := sub(256, mul(2, 8))
                encodeMerkleProofs.length := shr(bitsToDiscard, calldataload(offset))
                encodeMerkleProofs.offset := add(offset, 2)
                offset := add(offset, add(2, encodeMerkleProofs.length))

                // extract dynamic length callSpecificData
                bitsToDiscard := sub(256, mul(2, 8))
                callSpecificData.length := shr(bitsToDiscard, calldataload(offset))
                callSpecificData.offset := add(offset, 2)
            }

            address svm = svmRegistry.registry(svmId);
            bytes32[] memory merkleProof = abi.decode(encodeMerkleProofs, (bytes32[]));

            sessionDatas[i] = SessionData({
                validUntil: validUntil,
                validAfter: validAfter,
                sessionValidationModule: svm,
                sessionKeyData: sessionKeyData,
                merkleProof: merkleProof,
                callSpecificData: callSpecificData
            });
        }

        signature = abi.encode(abi.encode(sessionKeyManager, sessionDatas, sessionKeySignature), batchedSessionRouter);
    }

    function deflate(bytes calldata _data) external view returns (bytes memory compressedData) {
        (bytes memory moduleSignature,) = abi.decode(_data, (bytes, address));
        (, SessionData[] memory sessionDatas, bytes memory sessionKeySignature) =
            abi.decode(moduleSignature, (address, SessionData[], bytes));

        bytes memory compressedSessionDatas;

        for (uint256 i = 0; i < sessionDatas.length; i++) {
            SessionData memory sessionData = sessionDatas[i];
            bytes2 svmId = bytes2(svmRegistry.reverseRegistry(sessionData.sessionValidationModule));
            if (svmId == bytes2(0)) {
                revert("BatchedSessionRouterResolver: sessionValidationModule not registered");
            }
            compressedSessionDatas = abi.encodePacked(
                compressedSessionDatas,
                abi.encodePacked(
                    sessionData.validUntil,
                    sessionData.validAfter,
                    svmId,
                    abi.encode(
                        sessionData.sessionKeyData, abi.encode(sessionData.merkleProof), sessionData.callSpecificData
                    )
                )
            );
        }

        compressedData =
            abi.encodePacked(uint16(compressedSessionDatas.length), compressedSessionDatas, sessionKeySignature);
    }
}
