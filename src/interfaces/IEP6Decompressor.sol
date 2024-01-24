// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IDecompressor} from "./IDecompressor.sol";
import {IEntryPoint, UserOperation} from "account-abstraction/interfaces/IEntrypoint.sol";

/**
 * @title EP6Decompressor
 * @author @ankurdubey521
 * @dev The contract acts as a middleware between the EntryPoint and the bundler.
 */
interface IEP6Decompressor {
    /**
     * @dev Return value of simulateHandleCompressedOp
     * @param preOpGas gas used before the operation
     * @param paid amount paid for the operation
     * @param validAfter validAfter time-range
     * @param validUntil validUntil time-range
     * @param targetSuccess true if the target operation succeeded
     * @param targetResult result of the target operation
     * @param userOp the de-compressed user operation
     */
    error ExecutionResultWithUserOperation(
        uint256 preOpGas,
        uint256 paid,
        uint48 validAfter,
        uint48 validUntil,
        bool targetSuccess,
        bytes targetResult,
        UserOperation userOp
    );

    /**
     * @dev Successful result from simulateValidationCompressedOp.
     * @param returnInfo gas and time-range returned values
     * @param senderInfo stake information about the sender
     * @param factoryInfo stake information about the factory (if any)
     * @param paymasterInfo stake information about the paymaster (if any)
     * @param userOp the de-compressed user operation
     */
    error ValidationResultWithUserOperation(
        IEntryPoint.ReturnInfo returnInfo,
        IEntryPoint.StakeInfo senderInfo,
        IEntryPoint.StakeInfo factoryInfo,
        IEntryPoint.StakeInfo paymasterInfo,
        UserOperation userOp
    );

    /**
     * @dev Given a sender address, return the sender id if registered.
     * @param _sender the sender address
     * @return the sender id, or 0 if not registered
     */
    function senderId(address _sender) external view returns (uint256);

    /**
     * @dev Given a paymaster decompressor address, return the paymaster decompressor id if registered.
     * @param _decompressor the paymaster decompressor address
     * @return the paymaster decompressor id, or 0 if not registered
     */
    function paymasterInfaltorId(IDecompressor _decompressor) external view returns (uint256);

    /**
     * @dev Given a signature decompressor address, return the signature decompressor id if registered.
     * @param _decompressor the signature decompressor address
     * @return the signature decompressor id, or 0 if not registered
     */
    function signatureDecompressorId(IDecompressor _decompressor) external view returns (uint256);

    /**
     * @dev Given a init code decompressor address, return the init code decompressor id if registered.
     * @param _decompressor the init code decompressor address
     * @return the init code decompressor id, or 0 if not registered
     */
    function initCodeDecompressorId(IDecompressor _decompressor) external view returns (uint256);

    /**
     * @dev Given a call data decompressor address, return the call data decompressor id if registered.
     * @param _decompressor the call data decompressor address
     * @return the call data decompressor id, or 0 if not registered
     */
    function callDataDecompressorId(IDecompressor _decompressor) external view returns (uint256);

    /**
     * @dev De-compresses the compressed user operation, then calls the EntryPoint's simulateHandleOp with the de-compressed
     *      user operation and other expected parameters. Then reverts with the EntryPoint's revert data along with the
     *      de-compressed user operation (refer to the ExecutionResultWithUserOperation error).
     * @param _compressedOp the compressed user operation
     * @param _target the target address
     * @param _targetCallData the target call data
     * @custom:revertswith ExecutionResultWithUserOperation
     */
    function simulateHandleCompressedOp(bytes calldata _compressedOp, address _target, bytes calldata _targetCallData)
        external;

    /**
     * @dev De-compresses the compressed user operation, then calls the EntryPoint's simulateValidation with the de-compressed
     *      user operation and other expected parameters. Then reverts with the EntryPoint's revert data along with the de-compressed
     *      user operation (refer to the ValidationResultWithUserOperation error).
     * @param _compressedOp the compressed user operation
     * @custom:revertswith ValidationResultWithUserOperation
     */
    function simulateValidationCompressedOp(bytes calldata _compressedOp) external;

    /**
     * @dev Given a bundle of compressed user operations, de-compresses each user operation and returns the de-compressed user operations.
     * @param _compressedOps the compressed user operations
     * @return ops the de-compressed user operations
     */
    function decompressOps(bytes calldata _compressedOps) external returns (UserOperation[] memory ops);

    /**
     * @param paymasterAndDataDecompressor the paymaster and data decompressor. If address(0), then compression is skipped
     *        and paymasterAndData is included as it is in the compressed UserOperation.
     * @param signatureDecompressor the signature decompressor. If address(0), then compression is skipped
     *        and signature is included as it is in the compressed UserOperation.
     * @param initCodeDecompressor the init code decompressor. If address(0), then compression is skipped
     *        and initCode is included as it is in the compressed UserOperation.
     * @param callDataDecompressor the call data decompressor. If address(0), then compression is skipped
     *        and callData is included as it is in the compressed UserOperation.
     */
    struct DecompressionOptions {
        IDecompressor paymasterAndDataDecompressor;
        IDecompressor signatureDecompressor;
        IDecompressor initCodeDecompressor;
        IDecompressor callDataDecompressor;
    }

    /**
     * @dev Given a bundle of user operations and inflation options, compresses each user operation and returns the compressed user operations.
     * @param _ops the user operations
     * @param _options the inflation options. Refer to the DecompressionOptions struct above.
     * @return compressedOp the compressed user operations
     */
    function compressOps(UserOperation[] calldata _ops, DecompressionOptions[] calldata _options)
        external
        view
        returns (bytes memory compressedOp);

    /**
     * @dev Forwards a bundle of compressed UserOperations to the EntryPoint's handleOps function
     *      after de-compressing each user operation.
     *      Sets the msg.sender as the beneficiary of the fees in the handleOps call.
     * @notice We use a fallback function here to avoid the need to pass a function selector for the handleOps function,
     *        saving 4 bytes per compressed bundle.
     * @custom:msgdata the compressed user operations bundle
     */
    fallback() external;
}
