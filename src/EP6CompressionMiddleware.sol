// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IInflator} from "./interfaces/IInflator.sol";
import {IEntryPoint, UserOperation} from "account-abstraction/interfaces/IEntrypoint.sol";
import {IEP6CompressionMiddleware} from "./interfaces/IEP6CompressionMiddleware.sol";
import {RegistryLib} from "./lib/RegistryLib.sol";
import {InflationLib} from "./lib/InflationLib.sol";
import {SenderLib} from "./lib/SenderLib.sol";

contract EP6CompressionMiddleware is IEP6CompressionMiddleware {
    using RegistryLib for RegistryLib.RegistryStore;

    // userOp.sender
    // Based on the fact the max no. of active addresses on Ethereum Mainnet = 1.5M
    // log2(1.5M) / 8 = 2.56
    uint256 public constant SENDER_REPRESENTATION_SIZE_BYTES = 3;

    // userOp.nonce
    // We can fetch the next valid for the given key based on the SA address and the key itself.
    // Therefore we do not need to pass the 64 bit 'value' in the calldata.
    uint256 public constant NONCE_REPRESENTATION_SIZE_BYTES = 24;

    // userOp.preVerificationGas
    // By definition, the pre-verification gas cannot be computed on-chain.
    // Also, the SA/paymaster will always pay the FULL pre-verification gas.
    // therefore, it has to be supplied as it is.
    // We can assume an upper bound of 10B to bound it to 5 bytes instead of the usual 32.
    uint256 constant PRE_VERIFICATION_GAS_REPRESENTATION_SIZE_BYTES = 5;

    // TODO: userOp.verificationGasLimit
    // The verification gas limit can be approximated as the next greatest multiple of 5,000
    // Since SA/paymaster do not pay for unused gas (as of EPv0.6), this is a safe approximation.
    // Assuming a maximum of 1M gas, we can bound it to 1 byte instead of the usual 32.
    uint256 constant VERIFICATION_GAS_LIMIT_REPRESENTATION_SIZE_BYTES = 1;
    uint256 constant VERIFICATION_GAS_LIMIT_MULTIPLIER = 5000;

    // TODO: userOp.callGasLimit
    // The call gas limit can be approximated as the next greatest multiple of 50,000
    uint256 constant CALL_GAS_LIMIT_REPRESENTATION_SIZE_BYTES = 1;
    uint256 constant CALL_GAS_LIMIT_MULTIPLIER = 50000;

    // userOp.maxPriorityFeePerGas
    // The following guarantees a maximum of ~4300 gwei
    uint256 constant MAX_PRIORITY_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES = 4;
    uint256 constant MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER = 0.000001 gwei;

    // userOp.maxFeePerGas
    // The following guarantees a maximum of ~43k gwei
    uint256 constant MAX_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES = 4;
    uint256 constant MAX_FEE_PER_GAS_MULTIPLIER = 0.00001 gwei;

    // userOp.initCode
    uint256 constant INITCODE_INFLATOR_ID_REPRESENTATION_SIZE_BYTES = 2;
    uint256 constant INITICODE_LENGTH_REPRESENTATION_SIZE_BYTES = 2;

    // userOp.paymasterAndData
    uint256 constant PMD_INFLATOR_ID_REPRESENTATION_SIZE_BYTES = 2;
    uint256 constant PMD_LENGTH_REPRESENTATION_SIZE_BYTES = 2;

    // userOp.calldata
    uint256 constant CALLDATA_INFLATOR_ID_REPRESENTATION_SIZE_BYTES = 2;
    uint256 constant CALLDATA_LENGTH_REPRESENTATION_SIZE_BYTES = 2;

    // userOp.signature
    uint256 constant SIGNATURE_INFLATOR_ID_REPRESENTATION_SIZE_BYTES = 2;
    uint256 constant SIGNATURE_LENGTH_REPRESENTATION_SIZE_BYTES = 2;

    // Bundling
    // Support a max bundle length of 256
    uint256 constant BUNDLE_LENGTH_REPRESENTATION_SIZE_BYTES = 1;

    IEntryPoint public immutable entryPointV6;
    RegistryLib.RegistryStore public senderRegistry;
    RegistryLib.RegistryStore public paymasterInflatorRegistry;
    RegistryLib.RegistryStore public signatureInflatorRegistry;
    RegistryLib.RegistryStore public calldataInflatorRegistry;
    RegistryLib.RegistryStore public initCodeInflatorRegistry;

    constructor(IEntryPoint _entryPointV6) {
        entryPointV6 = _entryPointV6;
        senderRegistry.initialize();
        paymasterInflatorRegistry.initialize();
        signatureInflatorRegistry.initialize();
        calldataInflatorRegistry.initialize();
        initCodeInflatorRegistry.initialize();
    }

    /**
     * Inflation and Defalation
     */

    // TODO: dynamic
    function _inflateSender(bytes calldata _slice) internal view returns (address sender, bytes calldata nextSlice) {
        (sender, nextSlice) = SenderLib.inflate(_slice, senderRegistry, SENDER_REPRESENTATION_SIZE_BYTES);
    }

    function _inflateNonce(bytes calldata _slice, address _sender)
        internal
        view
        returns (uint256 nonce, bytes calldata nextSlice)
    {
        uint192 key;
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(NONCE_REPRESENTATION_SIZE_BYTES, 8))
            key := shr(bitsToDiscard, calldataload(_slice.offset))
            nextSlice.offset := add(_slice.offset, NONCE_REPRESENTATION_SIZE_BYTES)
        }
        nonce = entryPointV6.getNonce(_sender, key) | (key << 64);
    }

    function _inflatePreVerificationGas(bytes calldata _slice)
        internal
        pure
        returns (uint256 preVerificationGas, bytes calldata nextSlice)
    {
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(PRE_VERIFICATION_GAS_REPRESENTATION_SIZE_BYTES, 8))
            preVerificationGas := shr(bitsToDiscard, calldataload(_slice.offset))
            nextSlice.offset := add(_slice.offset, PRE_VERIFICATION_GAS_REPRESENTATION_SIZE_BYTES)
        }
    }

    function _inflateVerificationGasLimit(bytes calldata _slice)
        internal
        pure
        returns (uint256 verificationGasLimit, bytes calldata nextSlice)
    {
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(VERIFICATION_GAS_LIMIT_REPRESENTATION_SIZE_BYTES, 8))
            verificationGasLimit := shr(bitsToDiscard, calldataload(_slice.offset))
            verificationGasLimit := mul(verificationGasLimit, VERIFICATION_GAS_LIMIT_MULTIPLIER)
            nextSlice.offset := add(_slice.offset, VERIFICATION_GAS_LIMIT_REPRESENTATION_SIZE_BYTES)
        }
    }

    function _inflateCallGasLimit(bytes calldata _slice)
        internal
        pure
        returns (uint256 callGasLimit, bytes calldata nextSlice)
    {
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(CALL_GAS_LIMIT_REPRESENTATION_SIZE_BYTES, 8))
            callGasLimit := shr(bitsToDiscard, calldataload(_slice.offset))
            callGasLimit := mul(callGasLimit, CALL_GAS_LIMIT_MULTIPLIER)
            nextSlice.offset := add(_slice.offset, CALL_GAS_LIMIT_REPRESENTATION_SIZE_BYTES)
        }
    }

    function _inflateMaxPriorityFeePerGas(bytes calldata _slice)
        internal
        pure
        returns (uint256 maxPriorityFeePerGas, bytes calldata nextSlice)
    {
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(MAX_PRIORITY_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES, 8))
            maxPriorityFeePerGas := shr(bitsToDiscard, calldataload(_slice.offset))
            maxPriorityFeePerGas := mul(maxPriorityFeePerGas, MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER)
            nextSlice.offset := add(_slice.offset, MAX_PRIORITY_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES)
        }
    }

    function _inflateMaxFeePerGas(bytes calldata _slice)
        internal
        pure
        returns (uint256 maxFeePerGas, bytes calldata nextSlice)
    {
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(MAX_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES, 8))
            maxFeePerGas := shr(bitsToDiscard, calldataload(_slice.offset))
            maxFeePerGas := mul(maxFeePerGas, MAX_FEE_PER_GAS_MULTIPLIER)
            nextSlice.offset := add(_slice.offset, MAX_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES)
        }
    }

    function _inflateInitcode(bytes calldata _slice)
        internal
        pure
        returns (bytes memory initCode, bytes calldata nextSlice)
    {
        (initCode, nextSlice) = InflationLib.inflate(
            _slice,
            initCodeInflatorRegistry,
            INITCODE_INFLATOR_ID_REPRESENTATION_SIZE_BYTES,
            INITICODE_LENGTH_REPRESENTATION_SIZE_BYTES
        );
    }

    function _inflateCalldata(bytes calldata _slice)
        internal
        view
        returns (bytes memory callData, bytes calldata nextSlice)
    {
        (callData, nextSlice) = InflationLib.inflate(
            _slice,
            calldataInflatorRegistry,
            CALLDATA_INFLATOR_ID_REPRESENTATION_SIZE_BYTES,
            CALLDATA_LENGTH_REPRESENTATION_SIZE_BYTES
        );
    }

    function _inflatePaymasterAndData(bytes calldata _slice)
        internal
        view
        returns (bytes memory paymasterAndData, bytes calldata nextSlice)
    {
        (paymasterAndData, nextSlice) = InflationLib.inflate(
            _slice,
            paymasterInflatorRegistry,
            PMD_INFLATOR_ID_REPRESENTATION_SIZE_BYTES,
            PMD_LENGTH_REPRESENTATION_SIZE_BYTES
        );
    }

    function _inflateSignature(bytes calldata _slice)
        internal
        view
        returns (bytes memory signature, bytes calldata nextSlice)
    {
        (signature, nextSlice) = InflationLib.inflate(
            _slice,
            signatureInflatorRegistry,
            SIGNATURE_INFLATOR_ID_REPRESENTATION_SIZE_BYTES,
            SIGNATURE_LENGTH_REPRESENTATION_SIZE_BYTES
        );
    }

    // Use fallback so that selector is not used
    fallback(bytes calldata) external returns (bytes memory) {
        entryPointV6.handleOps(inflateOps(msg.data), payable(msg.sender));
    }

    /**
     * Inflator Management
     */
    function senderId(address _sender) external view override returns (uint256) {
        return senderRegistry.addrToId[_sender];
    }

    function paymasterInfaltorId(IInflator _inflator) external view override returns (uint256) {
        return paymasterInflatorRegistry.addrToId[address(_inflator)];
    }

    function signatureInflatorId(IInflator _inflator) external view override returns (uint256) {
        return signatureInflatorRegistry.addrToId[address(_inflator)];
    }

    function initCodeInflatorId(IInflator _inflator) external view override returns (uint256) {
        return initCodeInflatorRegistry.addrToId[address(_inflator)];
    }

    function callDataInflatorId(IInflator _inflator) external view override returns (uint256) {
        return calldataInflatorRegistry.addrToId[address(_inflator)];
    }

    /**
     * EntryPoint wrappers
     */

    /**
     * Bundler Utilities
     */
    function _inflateOp(bytes calldata _deflatedOp) internal returns (UserOperation memory op, bytes calldata next) {
        next = _deflatedOp;
        (op.sender, next) = _inflateSender(next);
        (op.nonce, next) = _inflateNonce(next, op.sender);
        (op.callGasLimit, next) = _inflateCallGasLimit(next);
        (op.verificationGasLimit, next) = _inflateVerificationGasLimit(next);
        (op.preVerificationGas, next) = _inflatePreVerificationGas(next);
        (op.maxFeePerGas, next) = _inflateMaxFeePerGas(next);
        (op.maxPriorityFeePerGas, next) = _inflateMaxPriorityFeePerGas(next);
        (op.initCode, next) = _inflateInitcode(next);
        (op.callData, next) = _inflateCalldata(next);
        (op.paymasterAndData, next) = _inflatePaymasterAndData(next);
        (op.signature, next) = _inflateSignature(next);
    }

    function inflateOps(bytes calldata _deflatedOps) public returns (UserOperation[] memory ops) {
        bytes calldata next = _deflatedOps;

        // Extract the bundle length
        uint256 bundleLength;
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(BUNDLE_LENGTH_REPRESENTATION_SIZE_BYTES, 8))
            bundleLength := shr(bitsToDiscard, calldataload(next.offset))
            next.offset := add(next.offset, BUNDLE_LENGTH_REPRESENTATION_SIZE_BYTES)
        }

        // Re-Build the bundle
        ops = new UserOperation[](bundleLength);

        for (uint256 i = 0; i < bundleLength; ++i) {
            (ops[i], next) = _inflateOp(next);
        }
    }
}
