// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RegistryLib} from "./RegistryLib.sol";
import {IDecompressor} from "../interfaces/IDecompressor.sol";
import {CastLib} from "./CastLib.sol";
import {console2} from "forge-std/console2.sol";

library DecompressionLib {
    using RegistryLib for RegistryLib.RegistryStore;
    using CastLib for uint256;

    // Reserved IDs (upto 0x00FF)
    enum RESERVED_IDS {
        DO_NOT_DECOMPRESS, // 0x0000
        REGISTER_DECOMPRESSOR_AND_DECOMPRESS // 0x0001
    }

    function decompress(
        bytes calldata _slice,
        RegistryLib.RegistryStore storage _registry,
        uint256 _decompressorIdSizeBytes,
        uint256 _arrayLenSizeBytes
    ) internal returns (bytes memory decompressedData, bytes calldata nextSlice) {
        /*
         * Layout
         * Offset (in bytes)        | Length (in bytes)         | Contents
         * 0x0                      | _decompressorIdSizeBytes  | The Decompressor ID / Reserved ID
         * _decompressorIdSizeBytes | ??                        | Rest of the data
         */

        nextSlice = _slice;

        // Extract the decompressor id
        bytes32 decompressorId;
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(_decompressorIdSizeBytes, 8))
            decompressorId := shr(bitsToDiscard, calldataload(nextSlice.offset))

            nextSlice.offset := add(nextSlice.offset, _decompressorIdSizeBytes)
            nextSlice.length := sub(nextSlice.length, _decompressorIdSizeBytes)
        }

        if (decompressorId == bytes32(uint256(RESERVED_IDS.DO_NOT_DECOMPRESS))) {
            (decompressedData, nextSlice) = handleDoNotDecompressCase(nextSlice, _arrayLenSizeBytes);
        } else if (decompressorId == bytes32(uint256(RESERVED_IDS.REGISTER_DECOMPRESSOR_AND_DECOMPRESS))) {
            (decompressedData, nextSlice) = handleRegisterDecompressorAndDecompressCase(
                nextSlice, _registry, _decompressorIdSizeBytes, _arrayLenSizeBytes
            );
        } else if (uint256(decompressorId) >= RegistryLib.FIRST_ID) {
            (decompressedData, nextSlice) =
                handleDecompressCase(nextSlice, _registry, uint256(decompressorId), _arrayLenSizeBytes);
        } else {
            revert("compressionLib: invalid decompressor id");
        }
    }

    function handleDoNotDecompressCase(bytes calldata _slice, uint256 _arrayLenSizeBytes)
        internal
        pure
        returns (bytes memory decompressedData, bytes calldata nextSlice)
    {
        /*
         * Layout
         * Offset (in bytes)    | Length (in bytes)     | Contents
         * 0x0                  | _arraryLenSizeBytes   | Length of the Array of un-compressed data
         *  _arraryLenSizeBytes | len                   | un-compressed data
         */

        nextSlice = _slice;

        // Extract the array length
        uint256 arrayLen;
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(_arrayLenSizeBytes, 8))
            arrayLen := shr(bitsToDiscard, calldataload(nextSlice.offset))

            nextSlice.offset := add(nextSlice.offset, _arrayLenSizeBytes)
            nextSlice.length := sub(nextSlice.length, _arrayLenSizeBytes)
        }

        // Copy the array
        decompressedData = nextSlice[:arrayLen];
        assembly ("memory-safe") {
            nextSlice.offset := add(nextSlice.offset, arrayLen)
            nextSlice.length := sub(nextSlice.length, arrayLen)
        }
    }

    function handleRegisterDecompressorAndDecompressCase(
        bytes calldata _slice,
        RegistryLib.RegistryStore storage _registry,
        uint256 _decompressorIdSizeBytes,
        uint256 _arrayLenSizeBytes
    ) internal returns (bytes memory decompressedData, bytes calldata nextSlice) {
        /*
         * Layout
         * Offset (in bytes)          | Length (in bytes)     | Contents
         * 0x0                        | 20                    | Decompressor Address
         * 0x14                       | _arraryLenSizeBytes   | Length of the Array of compressed data
         * 0x14 + _arraryLenSizeBytes | len                   | compressed data
         */

        nextSlice = _slice;

        // Extract the decompressor address
        address decompressorAddr;
        assembly ("memory-safe") {
            decompressorAddr := shr(96, calldataload(nextSlice.offset))

            nextSlice.offset := add(nextSlice.offset, 20)
            nextSlice.length := sub(nextSlice.length, 20)
        }

        // Extract the array length
        uint256 arrayLen;
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(_arrayLenSizeBytes, 8))
            arrayLen := shr(bitsToDiscard, calldataload(nextSlice.offset))

            nextSlice.offset := add(nextSlice.offset, _arrayLenSizeBytes)
            nextSlice.length := sub(nextSlice.length, _arrayLenSizeBytes)
        }

        // Register the decompressor
        _registry.checkAndRegister(decompressorAddr, _decompressorIdSizeBytes);

        // Copy the array
        bytes memory compressedData = nextSlice[:arrayLen];
        assembly ("memory-safe") {
            nextSlice.offset := add(nextSlice.offset, arrayLen)
            nextSlice.length := sub(nextSlice.length, arrayLen)
        }

        // Decompress the data
        try IDecompressor(decompressorAddr).decompress(compressedData) returns (bytes memory _decompressdData) {
            decompressedData = _decompressdData;
        } catch Error(string memory reason) {
            revert(string.concat("compressionLib: decompressor failed to decompress: ", reason));
        } catch {
            revert("compressionLib: decompressor failed to decompress");
        }
    }

    function handleDecompressCase(
        bytes calldata _slice,
        RegistryLib.RegistryStore storage _registry,
        uint256 _decompressorId,
        uint256 _arrayLenSizeBytes
    ) internal returns (bytes memory decompressedData, bytes calldata nextSlice) {
        /*
         * Layout
         * Offset (in bytes)         | Length (in bytes)         | Contents
         * 0x0                       | _arraryLenSizeBytes       | Length of the Array of compressed data
         *  _arraryLenSizeBytes      | len                       | compressed data
         */

        nextSlice = _slice;

        IDecompressor decompressor = IDecompressor(_registry.checkAndGet(_decompressorId));
        if (address(decompressor) == address(0)) {
            revert("compressionLib: decompressor not registered");
        }

        // Extract the array length
        uint256 arrayLen;
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(_arrayLenSizeBytes, 8))
            arrayLen := shr(bitsToDiscard, calldataload(nextSlice.offset))

            nextSlice.offset := add(nextSlice.offset, _arrayLenSizeBytes)
            nextSlice.length := sub(nextSlice.length, _arrayLenSizeBytes)
        }

        // Copy the array
        bytes memory compressedData = nextSlice[:arrayLen];
        assembly ("memory-safe") {
            nextSlice.offset := add(nextSlice.offset, arrayLen)
            nextSlice.length := sub(nextSlice.length, arrayLen)
        }

        // Decompress the data
        try decompressor.decompress(compressedData) returns (bytes memory _decompressdData) {
            decompressedData = _decompressdData;
        } catch Error(string memory reason) {
            revert(string.concat("compressionLib: decompressor failed to decompress: ", reason));
        } catch {
            revert("compressionLib: decompressor failed to decompress");
        }
    }

    function compress(
        bytes calldata _data,
        RegistryLib.RegistryStore storage _registry,
        IDecompressor _decompressor,
        uint256 _decompressorIdSizeBytes,
        uint256 _lengthSizeBytes
    ) internal view returns (bytes memory) {
        // Do not decompress
        if (address(_decompressor) == address(0)) {
            return abi.encodePacked(
                uint256(RESERVED_IDS.DO_NOT_DECOMPRESS).toBytesNPacked(_decompressorIdSizeBytes),
                _data.length.toBytesNPacked(_lengthSizeBytes),
                _data
            );
        }

        bytes memory compressedData = _decompressor.compress(_data);

        uint256 decompressorId = _registry.addrToId[address(_decompressor)];
        // Register and decompress
        if (decompressorId == 0) {
            return abi.encodePacked(
                uint256(RESERVED_IDS.REGISTER_DECOMPRESSOR_AND_DECOMPRESS).toBytesNPacked(_decompressorIdSizeBytes),
                address(_decompressor),
                compressedData.length.toBytesNPacked(_lengthSizeBytes),
                compressedData
            );
        } else {
            // Normal Decompress Case
            return abi.encodePacked(
                decompressorId.toBytesNPacked(_decompressorIdSizeBytes),
                compressedData.length.toBytesNPacked(_lengthSizeBytes),
                compressedData
            );
        }
    }
}
