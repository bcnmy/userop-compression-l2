// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/StdCheats.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenBalanceMappingSlotScraper is StdCheats, Script {
    struct TokenScrapeItem {
        IERC20 token;
        string rpcUrl;
    }

    TokenScrapeItem[] public tokenScrapeItems;

    address public alice = makeAddr("alice");

    constructor() {
        // Add more tokens here
        tokenScrapeItems.push(
            TokenScrapeItem({
                token: IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270),
                rpcUrl: "https://polygon-rpc.com"
            })
        );
    }

    function run() external {
        for (uint256 i = 0; i < tokenScrapeItems.length; i++) {
            _findBalanceMappingSlot(tokenScrapeItems[i]);
        }
    }

    function _findBalanceMappingSlot(TokenScrapeItem storage item) internal {
        // Fork the blockchain on which the token is deployed
        vm.createSelectFork(item.rpcUrl);

        // Override the ERC20 balance to a non-zero value
        uint256 balanceOverride = 1000 ether;
        deal(address(item.token), alice, balanceOverride);

        // The general idea is to do a balanceOf call, and record which storage slots were
        // accessed by using the record() cheats.
        // Once we get a list of slots, we do a brute force search to find the slot that
        // matches the balance slot of the user.
        vm.record();
        uint256 balance = item.token.balanceOf(alice);
        if (balance != balanceOverride) {
            console.log("Failed to override balance");
            return;
        }
        (bytes32[] memory reads,) = vm.accesses(address(item.token));

        for (uint256 j = 0; j < reads.length; ++j) {
            // reads[j] is the storage slot that was accessed
            bytes32 slotValue = vm.load(address(item.token), reads[j]);
            if (uint256(slotValue) != balance) {
                // If the value in the slot is not the balance, then it's not the balance slot
                continue;
            }

            // For each base slot in [0, 49], we check if the calculated slot matches the balance slot
            for (uint256 k = 0; k < 50; ++k) {
                if (keccak256(abi.encode(alice, k)) == reads[j]) {
                    console.log(
                        "Slot for balance mapping for token %s on chainId %s: %s", address(item.token), block.chainid, k
                    );
                    return;
                }
            }
        }

        console.log("Failed to find balance slot for token %s", address(item.token));
    }
}
