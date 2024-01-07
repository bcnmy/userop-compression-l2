// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IEntryPoint, UserOperation} from "account-abstraction/interfaces/IEntrypoint.sol";
import {AddressRegistry} from "./AddressRegistry.sol";
import {IResolver} from "./resolver/IResolver.sol";

contract EPMiddleware {
    IEntryPoint public ep;
    AddressRegistry public smartAccountRegistry = new AddressRegistry();
    AddressRegistry public paymasterRegistry = new AddressRegistry();
    AddressRegistry public signatureRegistry = new AddressRegistry();
    AddressRegistry public dappSmartContractRegistry = new AddressRegistry();

    constructor(IEntryPoint _ep) {
        ep = _ep;
    }

    // Based on the fact the max no. of active addresses on Ethereum Mainnet = 1.5M
    // log2(1.5M) / 8 = 2.56
    uint256 constant SENDER_REPRESENTATION_PRECISION_BYTES = 3;
    uint256 constant SENDER_LOAD_OFFSET = 0;

    function _resolveSender() internal view returns (address) {
        bytes32 senderIdentifier;
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(SENDER_REPRESENTATION_PRECISION_BYTES, 8))
            senderIdentifier := shr(bitsToDiscard, calldataload(SENDER_LOAD_OFFSET))
        }
        return smartAccountRegistry.registry(senderIdentifier);
    }

    // We can fetch the next valid for the given key based on the SA address and the key itself.
    // Therefore we do not need to pass the 64 bit value in the calldata.
    uint256 constant NONCE_REPRESENTATION_PRECISION_BYTES = 24;
    uint256 constant NONCE_LOAD_OFFSET = 3;

    function _resolveNonce() internal view returns (uint256) {
        address sender = _resolveSender();
        uint192 key;
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(NONCE_REPRESENTATION_PRECISION_BYTES, 8))
            key := shr(bitsToDiscard, calldataload(NONCE_LOAD_OFFSET))
        }
        return ep.getNonce(sender, key) | (key << 64);
    }

    // By definition, the pre-verification gas cannot be computed on-chain.
    // Also, the SA/paymaster will always pay the FULL pre-verification gas.
    // therefore, it has to be supplied as it is.
    // We can assume an upper bound of 50M to bound it to 26 bytes instead of the usual 32.
    uint256 constant PRE_VERIFICATION_GAS_REPRESENTATION_PRECISION_BYTES = 26;
    uint256 constant PRE_VERIFICATION_GAS_LOAD_OFFSET = 27;

    function _resolvePreVerificationGas() internal pure returns (uint256 preVerificationGas) {
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(PRE_VERIFICATION_GAS_REPRESENTATION_PRECISION_BYTES, 8))
            preVerificationGas := shr(bitsToDiscard, calldataload(PRE_VERIFICATION_GAS_LOAD_OFFSET))
        }
        return preVerificationGas;
    }

    // The verification gas limit can be approximated as the next greatest multiple of 5,000
    // Since SA/paymaster do not pay for unused gas (as of EPv0.6), this is a safe approximation.
    // Assuming a maximum of 1M gas, we can bound it to 1 byte instead of the usual 32.
    uint256 constant VERIFICATION_GAS_LIMIT_REPRESENTATION_PRECISION_BYTES = 1;
    uint256 constant VERIFICATION_GAS_LIMIT_LOAD_OFFSET = 53;
    uint256 constant VERIFICATION_GAS_LIMIT_MULTIPLIER = 5000;

    function _resolveVerificationGasLimit() internal pure returns (uint256 verificationGasLimit) {
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(VERIFICATION_GAS_LIMIT_REPRESENTATION_PRECISION_BYTES, 8))
            verificationGasLimit := shr(bitsToDiscard, calldataload(VERIFICATION_GAS_LIMIT_LOAD_OFFSET))
            verificationGasLimit := mul(verificationGasLimit, VERIFICATION_GAS_LIMIT_MULTIPLIER)
        }
    }

    // A similar approach can be used for the call gas limit.
    uint256 constant CALL_GAS_LIMIT_REPRESENTATION_PRECISION_BYTES = 1;
    uint256 constant CALL_GAS_LIMIT_LOAD_OFFSET = 54;
    uint256 constant CALL_GAS_LIMIT_MULTIPLIER = 50000;

    function _resolveCallGasLimit() internal pure returns (uint256 callGasLimit) {
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(CALL_GAS_LIMIT_REPRESENTATION_PRECISION_BYTES, 8))
            callGasLimit := shr(bitsToDiscard, calldataload(CALL_GAS_LIMIT_LOAD_OFFSET))
            callGasLimit := mul(callGasLimit, CALL_GAS_LIMIT_MULTIPLIER)
        }
    }

    // Assume multiplier of 0.01 gwei. With a upper limit of 500 gwei, we can bound it to 2 bytes.
    uint256 constant MAX_PRIORITY_FEE_PER_GAS_REPRESENTATION_PRECISION_BYTES = 3;
    uint256 constant MAX_PRIORITY_FEE_PER_GAS_LOAD_OFFSET = 55;
    uint256 constant MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER = 0.000001 gwei;

    function _resolveMaxPriorityFeePerGas() internal pure returns (uint256 maxPriorityFeePerGas) {
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(MAX_PRIORITY_FEE_PER_GAS_REPRESENTATION_PRECISION_BYTES, 8))
            maxPriorityFeePerGas := shr(bitsToDiscard, calldataload(MAX_PRIORITY_FEE_PER_GAS_LOAD_OFFSET))
            maxPriorityFeePerGas := mul(maxPriorityFeePerGas, MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER)
        }
    }

    // Similar for max fee per gas
    uint256 constant MAX_FEE_PER_GAS_REPRESENTATION_PRECISION_BYTES = 3;
    uint256 constant MAX_FEE_PER_GAS_LOAD_OFFSET = 58;
    uint256 constant MAX_FEE_PER_GAS_MULTIPLIER = 0.0001 gwei;

    function _resolveMaxFeePerGas() internal pure returns (uint256 maxFeePerGas) {
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(MAX_FEE_PER_GAS_REPRESENTATION_PRECISION_BYTES, 8))
            maxFeePerGas := shr(bitsToDiscard, calldataload(MAX_FEE_PER_GAS_LOAD_OFFSET))
            maxFeePerGas := mul(maxFeePerGas, MAX_FEE_PER_GAS_MULTIPLIER)
        }
    }

    // Leaving empty for now
    uint256 constant INITCODE_LOAD_OFFSET = 61;

    function _resolveInitcode() internal pure returns (bytes memory initcode, uint256 callDataStartOffset) {
        return (hex"", INITCODE_LOAD_OFFSET);
    }

    // The variable length byte arrays (callData, paymasterAndData, signature) are encoded as:
    // <2 bytes - resolverId><2 bytes - length><length bytes - compressed data>
    // concatenated, each for the respective variable length byte array.
    uint256 constant CALLDATA_SIZE_REPRESENTATION_PRECISION_BYTES = 2;
    uint256 constant DAPP_RESOLVER_ID_REPRESENTATION_PRECISION_BYTES = 2;

    function _resolveCalldata(uint256 _callDataStartOffset)
        internal
        view
        returns (bytes memory callData, uint256 paymasterAndDataStartOffset)
    {
        bytes32 resolverId;
        bytes calldata compressedCalldata;
        assembly ("memory-safe") {
            let offset := _callDataStartOffset

            // The first 2 bytes of the calldata represent the resolverId
            let bitsToDiscard := sub(256, mul(DAPP_RESOLVER_ID_REPRESENTATION_PRECISION_BYTES, 8))
            resolverId := shr(bitsToDiscard, calldataload(offset))

            // The next 2 bytes represent the length of the compressed calldata
            offset := add(offset, DAPP_RESOLVER_ID_REPRESENTATION_PRECISION_BYTES)
            bitsToDiscard := sub(256, mul(CALLDATA_SIZE_REPRESENTATION_PRECISION_BYTES, 8))
            let callDataLength := shr(bitsToDiscard, calldataload(offset))

            // The next `callDataLength` bytes represent the compressed calldata
            offset := add(offset, CALLDATA_SIZE_REPRESENTATION_PRECISION_BYTES)
            compressedCalldata.offset := offset
            compressedCalldata.length := callDataLength

            // The next bytes represent the paymasterAndData
            paymasterAndDataStartOffset := add(offset, callDataLength)
        }

        callData = IResolver(dappSmartContractRegistry.registry(resolverId)).resolve(compressedCalldata);
    }

    uint256 constant PND_SIZE_REPRESENTATION_PRECISION_BYTES = 2;
    uint256 constant PND_RESOLVER_ID_REPRESENTATION_PRECISION_BYTES = 2;

    function _resolvePaymasterAndData(uint256 _paymasterAndDataStartOffset)
        internal
        view
        returns (bytes memory paymasterAndData, uint256 signatureStartOffset)
    {
        bytes32 resolverId;
        bytes calldata compressedPaymasterAndData;
        assembly ("memory-safe") {
            let offset := _paymasterAndDataStartOffset

            // The first 2 bytes of the calldata represent the resolverId
            let bitsToDiscard := sub(256, mul(PND_RESOLVER_ID_REPRESENTATION_PRECISION_BYTES, 8))
            resolverId := shr(bitsToDiscard, calldataload(offset))

            // The next 2 bytes represent the length of the compressed paymasterAndData
            offset := add(offset, PND_RESOLVER_ID_REPRESENTATION_PRECISION_BYTES)
            bitsToDiscard := sub(256, mul(PND_SIZE_REPRESENTATION_PRECISION_BYTES, 8))
            let pndLength := shr(bitsToDiscard, calldataload(offset))

            // The next `pndLength` bytes represent the compressed calldata
            offset := add(offset, PND_SIZE_REPRESENTATION_PRECISION_BYTES)
            compressedPaymasterAndData.offset := offset
            compressedPaymasterAndData.length := pndLength

            // The next bytes represent the signature
            signatureStartOffset := add(offset, pndLength)
        }

        paymasterAndData = IResolver(paymasterRegistry.registry(resolverId)).resolve(compressedPaymasterAndData);
    }

    uint256 constant SIG_SIZE_REPRESENTATION_PRECISION_BYTES = 2;
    uint256 constant SIG_RESOLVER_ID_REPRESENTATION_PRECISION_BYTES = 2;

    function _resolveSignature(uint256 _signatureStartOffset) internal view returns (bytes memory signature) {
        bytes32 resolverId;
        bytes calldata compressedSignature;
        assembly ("memory-safe") {
            let offset := _signatureStartOffset

            // The first 2 bytes of the calldata represent the resolverId
            let bitsToDiscard := sub(256, mul(SIG_RESOLVER_ID_REPRESENTATION_PRECISION_BYTES, 8))
            resolverId := shr(bitsToDiscard, calldataload(offset))

            // The next 2 bytes represent the length of the compressed paymasterAndData
            offset := add(offset, SIG_RESOLVER_ID_REPRESENTATION_PRECISION_BYTES)
            bitsToDiscard := sub(256, mul(SIG_SIZE_REPRESENTATION_PRECISION_BYTES, 8))
            let pndLength := shr(bitsToDiscard, calldataload(offset))

            // The next `pndLength` bytes represent the compressed calldata
            offset := add(offset, SIG_SIZE_REPRESENTATION_PRECISION_BYTES)
            compressedSignature.offset := offset
            compressedSignature.length := pndLength
        }

        signature = IResolver(signatureRegistry.registry(resolverId)).resolve(compressedSignature);
    }

    // Use fallback so that selector is not used
    fallback() external {
        // Rebuild the UserOperation struct from the calldata
        UserOperation[] memory operations = new UserOperation[](1);
        (bytes memory initCode, uint256 callDataStartOffset) = _resolveInitcode();
        (bytes memory callData, uint256 paymasterAndDataStartOffset) = _resolveCalldata(callDataStartOffset);
        (bytes memory paymasterAndData, uint256 signatureStartOffset) =
            _resolvePaymasterAndData(paymasterAndDataStartOffset);
        bytes memory signature = _resolveSignature(signatureStartOffset);
        operations[0] = UserOperation({
            sender: _resolveSender(),
            nonce: _resolveNonce(),
            callGasLimit: _resolveCallGasLimit(),
            verificationGasLimit: _resolveVerificationGasLimit(),
            preVerificationGas: _resolvePreVerificationGas(),
            maxFeePerGas: _resolveMaxFeePerGas(),
            maxPriorityFeePerGas: _resolveMaxPriorityFeePerGas(),
            initCode: initCode,
            callData: callData,
            paymasterAndData: paymasterAndData,
            signature: signature
        });

        ep.handleOps(operations, payable(msg.sender));
    }
}
