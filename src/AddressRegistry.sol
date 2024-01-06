// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract AddressRegistry {
    uint256 nextId = 0;

    mapping(bytes32 id => address) public registry;

    function register(address addr) public returns (bytes32 id) {
        id = bytes32(nextId++);
        registry[id] = addr;
    }
}
