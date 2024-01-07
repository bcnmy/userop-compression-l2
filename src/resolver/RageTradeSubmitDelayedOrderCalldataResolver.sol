// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AddressRegistry} from "../AddressRegistry.sol";
import {IPerpsV2MarketDelayedIntent} from "../rage-trade/IPerpsV2MarkedDelayerIntent.sol";
import {ISmartAccount} from "../smart-account/ISmartAccount.sol";
import {IResolver} from "./IResolver.sol";

contract RageTradeSubmitDelayedOrderCalldataResolver is IResolver {
    bytes32 public registeredId;
    IPerpsV2MarketDelayedIntent public perpsV2MarketDelayedIntent =
        IPerpsV2MarketDelayedIntent(0x0EA09D97b4084d859328ec4bF8eBCF9ecCA26F1D);

    constructor(AddressRegistry _dappSmartContractRegistry) {
        registeredId = _dappSmartContractRegistry.register(address(this));
    }

    function resolve(bytes calldata _data) external view override returns (bytes memory userOpCalldata) {
        address[] memory dest = new address[](1);
        dest[0] = address(perpsV2MarketDelayedIntent);

        uint256[] memory value = new uint256[](1);

        bytes[] memory func = new bytes[](1);
        func[0] = _data;

        userOpCalldata = abi.encodeCall(ISmartAccount.executeBatch_y6U, (dest, value, func));
    }
}
