// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IInflator} from "./IInflator.sol";
import {IEntryPoint, UserOperation} from "account-abstraction/interfaces/IEntrypoint.sol";

interface IEP6CompressionMiddleware {
    /* Inflation Utilities */
    struct InflationOptions {
        IInflator paymasterAndDataInflator;
        IInflator signatureInflator;
        IInflator initCodeInflator;
        IInflator callDataInflator;
    }

    /* Registry Management */
    function senderId(address _sender) external view returns (uint256);
    function paymasterInfaltorId(IInflator _inflator) external view returns (uint256);
    function signatureInflatorId(IInflator _inflator) external view returns (uint256);
    function initCodeInflatorId(IInflator _inflator) external view returns (uint256);
    function callDataInflatorId(IInflator _inflator) external view returns (uint256);

    /* Bundler Utilities */
    function simulateHandleDeflatedOp(bytes calldata _deflatedOp, address _target, bytes calldata _targetCallData)
        external
        returns (UserOperation memory inflatedOp);

    function simulateValidationDeflatedOp(bytes calldata _deflatedOp)
        external
        returns (UserOperation memory inflatedOp);

    function inflateOps(bytes calldata _deflatedOps) external returns (UserOperation[] memory op);

    function deflateOps(UserOperation[] calldata _ops, InflationOptions[] calldata _options)
        external
        view
        returns (bytes memory _deflatedOp);

    /* Deflated Op Execution - handleDeflatedOps */
    fallback(bytes calldata _deflatedOps) external returns (bytes memory);
}
