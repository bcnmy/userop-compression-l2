// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IInflator {
    function inflate(bytes calldata _compressedData) external returns (bytes memory _data);

    function deflate(bytes calldata _data) external view returns (bytes memory _compressedData);
}
