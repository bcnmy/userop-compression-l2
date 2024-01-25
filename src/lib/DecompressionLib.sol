// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RegistryLib} from "./RegistryLib.sol";
import {IDecompressor} from "../interfaces/IDecompressor.sol";
import {CastLib} from "./CastLib.sol";
import {CalldataReadLib} from "./CalldataReadLib.sol";

library DecompressionLib {
    using RegistryLib for RegistryLib.RegistryStore;
    using CastLib for uint256;
    using CalldataReadLib for bytes;

    error InvalidDecompressorId(uint256 decompressorId);
    error DecompressorFailedToDecompressWithReason(IDecompressor decompressor, bytes reason);
    error DecompressorFailedToCompressWithReason(IDecompressor decompressor, bytes reason);

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
        uint256 decompressorId = nextSlice.read(_decompressorIdSizeBytes);
        nextSlice = nextSlice[_decompressorIdSizeBytes:];

        if (decompressorId == uint256(RESERVED_IDS.DO_NOT_DECOMPRESS)) {
            (decompressedData, nextSlice) = handleDoNotDecompressCase(nextSlice, _arrayLenSizeBytes);
        } else if (decompressorId == uint256(RESERVED_IDS.REGISTER_DECOMPRESSOR_AND_DECOMPRESS)) {
            (decompressedData, nextSlice) = handleRegisterDecompressorAndDecompressCase(
                nextSlice, _registry, _decompressorIdSizeBytes, _arrayLenSizeBytes
            );
        } else if (decompressorId >= RegistryLib.FIRST_ID) {
            (decompressedData, nextSlice) =
                handleDecompressCase(nextSlice, _registry, decompressorId, _arrayLenSizeBytes);
        } else {
            revert InvalidDecompressorId(decompressorId);
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
        uint256 arrayLen = nextSlice.read(_arrayLenSizeBytes);
        nextSlice = nextSlice[_arrayLenSizeBytes:];

        // Copy the array
        decompressedData = nextSlice[:arrayLen];
        nextSlice = nextSlice[arrayLen:];
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
        address decompressorAddr = address(uint160(nextSlice.read(20)));
        nextSlice = nextSlice[20:];

        // Extract the array length
        uint256 arrayLen = nextSlice.read(_arrayLenSizeBytes);
        nextSlice = nextSlice[_arrayLenSizeBytes:];

        // Register the decompressor
        _registry.checkAndRegister(decompressorAddr, _decompressorIdSizeBytes);

        // Copy the array
        bytes memory compressedData = nextSlice[:arrayLen];
        nextSlice = nextSlice[arrayLen:];

        // Decompress the data
        try IDecompressor(decompressorAddr).decompress(compressedData) returns (bytes memory _decompressdData) {
            decompressedData = _decompressdData;
        } catch Error(string memory reason) {
            revert DecompressorFailedToDecompressWithReason(IDecompressor(decompressorAddr), abi.encode(reason));
        } catch (bytes memory reason) {
            revert DecompressorFailedToDecompressWithReason(IDecompressor(decompressorAddr), reason);
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

        // Extract the array length
        uint256 arrayLen = nextSlice.read(_arrayLenSizeBytes);
        nextSlice = nextSlice[_arrayLenSizeBytes:];

        // Copy the array
        bytes memory compressedData = nextSlice[:arrayLen];
        nextSlice = nextSlice[arrayLen:];

        // Decompress the data
        try decompressor.decompress(compressedData) returns (bytes memory _decompressdData) {
            decompressedData = _decompressdData;
        } catch Error(string memory reason) {
            revert DecompressorFailedToDecompressWithReason(decompressor, abi.encode(reason));
        } catch (bytes memory reason) {
            revert DecompressorFailedToDecompressWithReason(decompressor, reason);
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

        bytes memory compressedData;
        try _decompressor.compress(_data) returns (bytes memory _compressedData) {
            compressedData = _compressedData;
        } catch Error(string memory reason) {
            revert DecompressorFailedToCompressWithReason(_decompressor, abi.encode(reason));
        } catch (bytes memory reason) {
            revert DecompressorFailedToCompressWithReason(_decompressor, reason);
        }

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
