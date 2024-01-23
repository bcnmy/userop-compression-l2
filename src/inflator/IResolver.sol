// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IResolver {
    function registeredId() external view returns (bytes32);

    function resolve(bytes calldata _data) external view returns (bytes memory data);
}
