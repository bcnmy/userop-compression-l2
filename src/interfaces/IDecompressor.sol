// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IDecompressor
 * @author @ankurdubey521
 * @dev Implements use-case specfic compression and decompression logic.
 */
interface IDecompressor {
    /**
     * @dev Decompress the compressed data.
     * @param _compressedData the compressed data
     * @return data the decompressed data
     */
    function decompress(bytes calldata _compressedData) external returns (bytes memory data);

    /**
     * @dev Compress the decompressed data.
     * @param _data the decompressed data
     * @return compressedData the compressed data
     */
    function compress(bytes calldata _data) external view returns (bytes memory compressedData);
}
