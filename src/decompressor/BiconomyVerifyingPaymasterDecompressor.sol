// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AddressRegistry} from "./AddressRegistry.sol";
import {ISmartAccount} from "../smart-account/ISmartAccount.sol";
import {IDecompressor} from "../interfaces/IDecompressor.sol";

contract BiconomyVerifyingPaymasterDecompressor is IDecompressor {
    address paymaster = 0x00000f79B7FaF42EEBAdbA19aCc07cD08Af44789;
    AddressRegistry public paymasterIdRegistry = new AddressRegistry();

    /**
     * Normally, the pnd for Verifying Paymaster is:
     *    abi.encodePacked(
     *       paymasterAddress,
     *       abi.encode(
     *          address paymasterId,
     *          uint48 validUntil,
     *          uint48 validAfter,
     *          bytes memory signature
     *       )
     *     )
     *     To compress, we:
     *     1. Hardcode the paymaster address in this Decompressor
     *     2. Replace 20 byte paymasterId with 2 byte id for (65536 unique paymasterIds)
     *     3. Encode signature as it is, but without the initial offset introduced by abi.encode.
     *         Instead encode it as <2 bytes - length><signature>
     */
    uint256 constant PID_REPRESENTATION_PRECISION_BYTES = 2;
    uint256 constant SIGNATURE_LENGTH_BYTES = 2;

    function decompress(bytes calldata _data) external view override returns (bytes memory paymasterAndData) {
        bytes32 paymasterIdId;
        uint48 validUntil;
        uint48 validAfter;
        bytes calldata signature;

        assembly ("memory-safe") {
            let offset := _data.offset

            // Extract paymasterIdId
            let bitsToDiscard := sub(256, mul(PID_REPRESENTATION_PRECISION_BYTES, 8))
            paymasterIdId := shr(bitsToDiscard, calldataload(offset))
            offset := add(offset, PID_REPRESENTATION_PRECISION_BYTES)

            // Extract validUntil
            bitsToDiscard := sub(256, 48)
            validUntil := shr(bitsToDiscard, calldataload(offset))
            offset := add(offset, div(48, 8))

            // Extract validAfter
            bitsToDiscard := sub(256, 48)
            validAfter := shr(bitsToDiscard, calldataload(offset))
            offset := add(offset, div(48, 8))

            // Extract signature
            bitsToDiscard := sub(256, mul(SIGNATURE_LENGTH_BYTES, 8))
            let length := shr(bitsToDiscard, calldataload(offset))

            // Set signature
            signature.offset := add(offset, SIGNATURE_LENGTH_BYTES)
            signature.length := length
        }

        address paymasterId = paymasterIdRegistry.registry(paymasterIdId);
        paymasterAndData = abi.encodePacked(paymaster, abi.encode(paymasterId, validUntil, validAfter, signature));
    }

    function compress(bytes calldata _data) external view override returns (bytes memory) {
        bytes calldata pmData = _data[20:];
        (address paymasterId, uint48 validUntil, uint48 validAfter, bytes memory signature) =
            abi.decode(pmData, (address, uint48, uint48, bytes));

        bytes32 paymasterIdId = paymasterIdRegistry.reverseRegistry(paymasterId);
        if (paymasterIdId == bytes32(0)) {
            revert("BiconomyVerifyingPaymasterDecompressor: paymasterId not registered");
        }
        return abi.encodePacked(
            uint16(uint256(paymasterIdId)), validUntil, validAfter, uint16(signature.length), signature
        );
    }
}
