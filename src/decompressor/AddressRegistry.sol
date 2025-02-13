// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract AddressRegistry {
    uint256 nextId = 1;

    mapping(bytes32 id => address) public registry;
    mapping(address => bytes32) public reverseRegistry;

    function register(address addr) public returns (bytes32 id) {
        id = bytes32(nextId++);
        registry[id] = addr;
        reverseRegistry[addr] = id;
    }
}
