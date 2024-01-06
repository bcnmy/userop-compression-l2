// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AddressRegistry} from "./AddressRegistry.sol";
import {EPMiddleware} from "./EPMiddleware.sol";
import {IPerpsV2MarketDelayedIntent} from "./rage-trade/IPerpsV2MarkedDelayerIntent.sol";

contract RageTradeSubmitDelayedOrderCalldataResolver {
    bytes32 public registeredId;

    constructor(AddressRegistry _dappSmartContractRegistry) {
        registeredId = _dappSmartContractRegistry.register(address(this));
    }

    function resolve(bytes calldata _data) internal view returns (bytes memory userOpCalldata) {}
}
