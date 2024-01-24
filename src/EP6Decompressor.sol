// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IDecompressor} from "./interfaces/IDecompressor.sol";
import {IEntryPoint, UserOperation, IStakeManager} from "account-abstraction/interfaces/IEntrypoint.sol";
import {BytesLib} from "solidity-bytes-utils/BytesLib.sol";
import {IEP6Decompressor} from "./interfaces/IEP6Decompressor.sol";
import {RegistryLib} from "./lib/RegistryLib.sol";
import {DecompressionLib} from "./lib/DecompressionLib.sol";
import {SenderLib} from "./lib/SenderLib.sol";
import {CastLib} from "./lib/CastLib.sol";

// TODO: Custom Errors

contract EP6Decompressor is IEP6Decompressor {
    using RegistryLib for RegistryLib.RegistryStore;
    using CastLib for uint256;
    using BytesLib for bytes;

    // userOp.sender
    // Theoretical maximum of 4B unique senders
    uint256 public constant SENDER_REPRESENTATION_SIZE_BYTES = 4;

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
    // TODO: Multiplier from constructor
    // The verification gas limit can be approximated as the next greatest multiple of 5,000
    // Since SA/paymaster do not pay for unused gas (as of EPv0.6), this is a safe approximation.
    // Assuming a maximum of 1M gas, we can bound it to 1 byte instead of the usual 32.
    uint256 constant VERIFICATION_GAS_LIMIT_REPRESENTATION_SIZE_BYTES = 1;
    uint256 constant VERIFICATION_GAS_LIMIT_MULTIPLIER = 5000;

    // TODO: userOp.callGasLimit
    // TODO: Multiplier from constructor
    // The call gas limit can be approximated as the next greatest multiple of 50,000
    uint256 constant CALL_GAS_LIMIT_REPRESENTATION_SIZE_BYTES = 1;
    uint256 constant CALL_GAS_LIMIT_MULTIPLIER = 50000;

    // userOp.maxPriorityFeePerGas
    // The following guarantees a maximum of ~4300 gwei
    // TODO: Multiplier from constructor
    uint256 constant MAX_PRIORITY_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES = 4;
    uint256 constant MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER = 0.000001 gwei;

    // userOp.maxFeePerGas
    // The following guarantees a maximum of ~43k gwei
    // TODO: Multiplier from constructor
    uint256 constant MAX_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES = 4;
    uint256 constant MAX_FEE_PER_GAS_MULTIPLIER = 0.00001 gwei;

    // userOp.initCode
    uint256 constant INITCODE_DECOMPRESSOR_ID_REPRESENTATION_SIZE_BYTES = 2;
    uint256 constant INITICODE_LENGTH_REPRESENTATION_SIZE_BYTES = 2;

    // userOp.paymasterAndData
    uint256 constant PMD_DECOMPRESSOR_ID_REPRESENTATION_SIZE_BYTES = 2;
    uint256 constant PMD_LENGTH_REPRESENTATION_SIZE_BYTES = 2;

    // userOp.calldata
    uint256 constant CALLDATA_DECOMPRESSOR_ID_REPRESENTATION_SIZE_BYTES = 2;
    uint256 constant CALLDATA_LENGTH_REPRESENTATION_SIZE_BYTES = 2;

    // userOp.signature
    uint256 constant SIGNATURE_DECOMPRESSOR_ID_REPRESENTATION_SIZE_BYTES = 2;
    uint256 constant SIGNATURE_LENGTH_REPRESENTATION_SIZE_BYTES = 2;

    // Bundling
    // Support a max bundle length of 256
    uint256 constant BUNDLE_LENGTH_REPRESENTATION_SIZE_BYTES = 1;

    IEntryPoint public immutable entryPointV6;
    RegistryLib.RegistryStore public senderRegistry;
    RegistryLib.RegistryStore public paymasterDecompressorRegistry;
    RegistryLib.RegistryStore public signatureDecompressorRegistry;
    RegistryLib.RegistryStore public calldataDecompressorRegistry;
    RegistryLib.RegistryStore public initCodeDecompressorRegistry;

    constructor(IEntryPoint _entryPointV6) {
        entryPointV6 = _entryPointV6;
        senderRegistry.initialize();
        paymasterDecompressorRegistry.initialize();
        signatureDecompressorRegistry.initialize();
        calldataDecompressorRegistry.initialize();
        initCodeDecompressorRegistry.initialize();
    }

    /**
     * Inflation and Defalation
     */

    // sender
    function _decompressSender(bytes calldata _slice) internal returns (address sender, bytes calldata nextSlice) {
        (sender, nextSlice) = SenderLib.decompress(_slice, senderRegistry, SENDER_REPRESENTATION_SIZE_BYTES);
    }

    function _compressSender(address _sender) internal view returns (bytes memory compressedSender) {
        compressedSender = SenderLib.compress(senderRegistry, _sender, SENDER_REPRESENTATION_SIZE_BYTES);
    }

    // nonce
    function _decompressNonce(bytes calldata _slice, address _sender)
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

    function _compressNonce(uint256 _nonce) internal pure returns (bytes memory compressedNonce) {
        compressedNonce = abi.encodePacked(uint192(_nonce >> 64));
    }

    // preVerificationGas
    function _decompressPreVerificationGas(bytes calldata _slice)
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

    function _compressPreVerificationGas(uint256 _preVerificationGas)
        internal
        pure
        returns (bytes memory compressedPreVerificationGas)
    {
        compressedPreVerificationGas =
            _preVerificationGas.toBytesNPacked(PRE_VERIFICATION_GAS_REPRESENTATION_SIZE_BYTES);
    }

    // verificationGasLimit
    function _decompressVerificationGasLimit(bytes calldata _slice)
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

    function _compressVerificationGasLimit(uint256 _verificationGasLimit)
        internal
        pure
        returns (bytes memory compressedVerificationGasLimit)
    {
        uint256 multiplier;
        if (_verificationGasLimit % VERIFICATION_GAS_LIMIT_MULTIPLIER == 0) {
            multiplier = _verificationGasLimit / VERIFICATION_GAS_LIMIT_MULTIPLIER;
        } else {
            multiplier = (_verificationGasLimit / VERIFICATION_GAS_LIMIT_MULTIPLIER) + 1;
        }
        return multiplier.toBytesNPacked(VERIFICATION_GAS_LIMIT_REPRESENTATION_SIZE_BYTES);
    }

    // callGasLimit
    function _decompressCallGasLimit(bytes calldata _slice)
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

    function _compressCallGasLimit(uint256 _callGasLimit) internal pure returns (bytes memory compressedCallGasLimit) {
        uint256 multiplier;
        if (_callGasLimit % CALL_GAS_LIMIT_MULTIPLIER == 0) {
            multiplier = _callGasLimit / CALL_GAS_LIMIT_MULTIPLIER;
        } else {
            multiplier = (_callGasLimit / CALL_GAS_LIMIT_MULTIPLIER) + 1;
        }
        return multiplier.toBytesNPacked(CALL_GAS_LIMIT_REPRESENTATION_SIZE_BYTES);
    }

    // maxPriorityFeePerGas
    function _decompressMaxPriorityFeePerGas(bytes calldata _slice)
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

    function _compressMaxPriorityFeePerGas(uint256 _maxPriorityFeePerGas)
        internal
        pure
        returns (bytes memory compressedMaxPriorityFeePerGas)
    {
        uint256 multiplier;
        if (_maxPriorityFeePerGas % MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER == 0) {
            multiplier = _maxPriorityFeePerGas / MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER;
        } else {
            multiplier = (_maxPriorityFeePerGas / MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER) + 1;
        }
        return multiplier.toBytesNPacked(MAX_PRIORITY_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES);
    }

    // maxFeePerGas
    function _decompressMaxFeePerGas(bytes calldata _slice)
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

    function _compressMaxFeePerGas(uint256 _maxFeePerGas) internal pure returns (bytes memory compressedMaxFeePerGas) {
        uint256 multiplier;
        if (_maxFeePerGas % MAX_FEE_PER_GAS_MULTIPLIER == 0) {
            multiplier = _maxFeePerGas / MAX_FEE_PER_GAS_MULTIPLIER;
        } else {
            multiplier = (_maxFeePerGas / MAX_FEE_PER_GAS_MULTIPLIER) + 1;
        }
        return multiplier.toBytesNPacked(MAX_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES);
    }

    // initCode
    function _decompressInitcode(bytes calldata _slice)
        internal
        returns (bytes memory initCode, bytes calldata nextSlice)
    {
        (initCode, nextSlice) = DecompressionLib.decompress(
            _slice,
            initCodeDecompressorRegistry,
            INITCODE_DECOMPRESSOR_ID_REPRESENTATION_SIZE_BYTES,
            INITICODE_LENGTH_REPRESENTATION_SIZE_BYTES
        );
    }

    function _compressInitcode(bytes calldata _initCode, IDecompressor _initCodeDecompressor)
        internal
        view
        returns (bytes memory compressedInitcode)
    {
        compressedInitcode = DecompressionLib.compress(
            _initCode,
            initCodeDecompressorRegistry,
            _initCodeDecompressor,
            INITCODE_DECOMPRESSOR_ID_REPRESENTATION_SIZE_BYTES,
            INITICODE_LENGTH_REPRESENTATION_SIZE_BYTES
        );
    }

    // Calldata
    function _decompressCalldata(bytes calldata _slice)
        internal
        returns (bytes memory callData, bytes calldata nextSlice)
    {
        (callData, nextSlice) = DecompressionLib.decompress(
            _slice,
            calldataDecompressorRegistry,
            CALLDATA_DECOMPRESSOR_ID_REPRESENTATION_SIZE_BYTES,
            CALLDATA_LENGTH_REPRESENTATION_SIZE_BYTES
        );
    }

    function _compressCalldata(bytes calldata _calldata, IDecompressor _calldataDecompressor)
        internal
        view
        returns (bytes memory compressedCalldata)
    {
        compressedCalldata = DecompressionLib.compress(
            _calldata,
            calldataDecompressorRegistry,
            _calldataDecompressor,
            CALLDATA_DECOMPRESSOR_ID_REPRESENTATION_SIZE_BYTES,
            CALLDATA_LENGTH_REPRESENTATION_SIZE_BYTES
        );
    }

    // PaymasterAndData
    function _decompressPaymasterAndData(bytes calldata _slice)
        internal
        returns (bytes memory paymasterAndData, bytes calldata nextSlice)
    {
        (paymasterAndData, nextSlice) = DecompressionLib.decompress(
            _slice,
            paymasterDecompressorRegistry,
            PMD_DECOMPRESSOR_ID_REPRESENTATION_SIZE_BYTES,
            PMD_LENGTH_REPRESENTATION_SIZE_BYTES
        );
    }

    function _compressPaymasterAndData(bytes calldata _paymasterAndData, IDecompressor _paymasterAndDataDecompressor)
        internal
        view
        returns (bytes memory compressedPaymasterAndData)
    {
        compressedPaymasterAndData = DecompressionLib.compress(
            _paymasterAndData,
            paymasterDecompressorRegistry,
            _paymasterAndDataDecompressor,
            PMD_DECOMPRESSOR_ID_REPRESENTATION_SIZE_BYTES,
            PMD_LENGTH_REPRESENTATION_SIZE_BYTES
        );
    }

    // Signature
    function _decompressSignature(bytes calldata _slice)
        internal
        returns (bytes memory signature, bytes calldata nextSlice)
    {
        (signature, nextSlice) = DecompressionLib.decompress(
            _slice,
            signatureDecompressorRegistry,
            SIGNATURE_DECOMPRESSOR_ID_REPRESENTATION_SIZE_BYTES,
            SIGNATURE_LENGTH_REPRESENTATION_SIZE_BYTES
        );
    }

    function _compressSignature(bytes calldata _signature, IDecompressor _signatureDecompressor)
        internal
        view
        returns (bytes memory compressedSignature)
    {
        compressedSignature = DecompressionLib.compress(
            _signature,
            signatureDecompressorRegistry,
            _signatureDecompressor,
            SIGNATURE_DECOMPRESSOR_ID_REPRESENTATION_SIZE_BYTES,
            SIGNATURE_LENGTH_REPRESENTATION_SIZE_BYTES
        );
    }

    // Use fallback so that selector is not used
    /// @inheritdoc IEP6Decompressor
    fallback() external {
        entryPointV6.handleOps(decompressOps(msg.data), payable(msg.sender));
    }

    /**
     * Decompressor Management
     */
    /// @inheritdoc IEP6Decompressor
    function senderId(address _sender) external view override returns (uint256) {
        return senderRegistry.addrToId[_sender];
    }

    /// @inheritdoc IEP6Decompressor
    function paymasterInfaltorId(IDecompressor _inflator) external view override returns (uint256) {
        return paymasterDecompressorRegistry.addrToId[address(_inflator)];
    }

    /// @inheritdoc IEP6Decompressor
    function signatureDecompressorId(IDecompressor _inflator) external view override returns (uint256) {
        return signatureDecompressorRegistry.addrToId[address(_inflator)];
    }

    /// @inheritdoc IEP6Decompressor
    function initCodeDecompressorId(IDecompressor _inflator) external view override returns (uint256) {
        return initCodeDecompressorRegistry.addrToId[address(_inflator)];
    }

    /// @inheritdoc IEP6Decompressor
    function callDataDecompressorId(IDecompressor _inflator) external view override returns (uint256) {
        return calldataDecompressorRegistry.addrToId[address(_inflator)];
    }

    /**
     * EntryPoint wrappers
     */

    /// @inheritdoc IEP6Decompressor
    function simulateHandleCompressedOp(bytes calldata _compressdOp, address _target, bytes calldata _targetCallData)
        external
    {
        (UserOperation memory decompressedOp,) = _decompressOp(_compressdOp);
        try entryPointV6.simulateHandleOp(decompressedOp, _target, _targetCallData) {}
        catch (bytes memory revertData) {
            (
                uint256 preOpGas,
                uint256 paid,
                uint48 validAfter,
                uint48 validUntil,
                bool targetSuccess,
                bytes memory targetResult
            ) = abi.decode(revertData.slice(4, revertData.length - 4), (uint256, uint256, uint48, uint48, bool, bytes));
            revert ExecutionResultWithUserOperation(
                preOpGas, paid, validAfter, validUntil, targetSuccess, targetResult, decompressedOp
            );
        }

        revert SimulateHandleOpDidNotRevert();
    }

    /// @inheritdoc IEP6Decompressor
    function simulateValidationCompressedOp(bytes calldata _compressdOp) external {
        (UserOperation memory decompressedOp,) = _decompressOp(_compressdOp);
        try entryPointV6.simulateValidation(decompressedOp) {}
        catch (bytes memory revertData) {
            (
                IEntryPoint.ReturnInfo memory returnInfo,
                IStakeManager.StakeInfo memory senderInfo,
                IStakeManager.StakeInfo memory factoryInfo,
                IStakeManager.StakeInfo memory paymasterInfo
            ) = abi.decode(
                revertData.slice(4, revertData.length - 4),
                (IEntryPoint.ReturnInfo, IStakeManager.StakeInfo, IStakeManager.StakeInfo, IStakeManager.StakeInfo)
            );
            revert ValidationResultWithUserOperation(returnInfo, senderInfo, factoryInfo, paymasterInfo, decompressedOp);
        }

        revert SimulateValidationDidNotRevert();
    }

    /**
     * Bundler Utilities
     */
    function _decompressOp(bytes calldata _compressdOp)
        internal
        returns (UserOperation memory op, bytes calldata next)
    {
        next = _compressdOp;
        (op.sender, next) = _decompressSender(next);
        (op.nonce, next) = _decompressNonce(next, op.sender);
        (op.callGasLimit, next) = _decompressCallGasLimit(next);
        (op.verificationGasLimit, next) = _decompressVerificationGasLimit(next);
        (op.preVerificationGas, next) = _decompressPreVerificationGas(next);
        (op.maxFeePerGas, next) = _decompressMaxFeePerGas(next);
        (op.maxPriorityFeePerGas, next) = _decompressMaxPriorityFeePerGas(next);
        (op.initCode, next) = _decompressInitcode(next);
        (op.callData, next) = _decompressCalldata(next);
        (op.paymasterAndData, next) = _decompressPaymasterAndData(next);
        (op.signature, next) = _decompressSignature(next);
    }

    /// @inheritdoc IEP6Decompressor
    function decompressOps(bytes calldata _compressdOps) public returns (UserOperation[] memory ops) {
        bytes calldata next = _compressdOps;

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
            (ops[i], next) = _decompressOp(next);
        }
    }

    function _compressOp(UserOperation calldata _op, DecompressionOptions calldata _option)
        internal
        view
        returns (bytes memory compressedOp)
    {
        compressedOp = abi.encodePacked(
            _compressSender(_op.sender),
            _compressNonce(_op.nonce),
            _compressCallGasLimit(_op.callGasLimit),
            _compressVerificationGasLimit(_op.verificationGasLimit),
            _compressPreVerificationGas(_op.preVerificationGas),
            _compressMaxFeePerGas(_op.maxFeePerGas),
            _compressMaxPriorityFeePerGas(_op.maxPriorityFeePerGas),
            _compressInitcode(_op.initCode, _option.initCodeDecompressor),
            _compressCalldata(_op.callData, _option.callDataDecompressor),
            _compressPaymasterAndData(_op.paymasterAndData, _option.paymasterAndDataDecompressor),
            _compressSignature(_op.signature, _option.signatureDecompressor)
        );
    }

    /// @inheritdoc IEP6Decompressor
    function compressOps(UserOperation[] calldata _ops, DecompressionOptions[] calldata _options)
        external
        view
        override
        returns (bytes memory compressedOps)
    {
        // todo: length validation
        compressedOps = abi.encodePacked(uint256(_ops.length).toBytesNPacked(BUNDLE_LENGTH_REPRESENTATION_SIZE_BYTES));
        for (uint256 i = 0; i < _ops.length; ++i) {
            compressedOps = abi.encode(compressedOps, _compressOp(_ops[i], _options[i]));
        }
    }
}
