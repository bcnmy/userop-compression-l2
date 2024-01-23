// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RegistryLib} from "./RegistryLib.sol";
import {IInflator} from "../interfaces/IInflator.sol";
import {CastLib} from "./CastLib.sol";

library InflationLib {
    using RegistryLib for RegistryLib.RegistryStore;
    using CastLib for uint256;

    // Reserved IDs (upto 0x0000FF)
    enum RESERVED_IDS {
        DO_NOT_INFLATE, // 0x000000
        REGISTER_INFLATOR_AND_INFLATE // 0x000001
    }

    function inflate(
        bytes calldata _slice,
        RegistryLib.RegistryStore storage _registry,
        uint256 _inflatorIdSizeBytes,
        uint256 _arrayLenSizeBytes
    ) internal returns (bytes memory inflatedData, bytes calldata nextSlice) {
        /*
         * Layout
         * Offset (in bytes)    | Length (in bytes)     | Contents
         * 0x0                  | _inflatorIdSizeBytes  | The Inflator ID / Reserved ID
         * _inflatorIdSizeBytes | ??                    | Rest of the data
         */

        nextSlice = _slice;

        // Extract the inflator id
        bytes32 inflatorId;
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(_inflatorIdSizeBytes, 8))
            inflatorId := shr(bitsToDiscard, calldataload(nextSlice.offset))
            nextSlice.offset := add(nextSlice.offset, _inflatorIdSizeBytes)
        }

        if (inflatorId == bytes32(uint256(RESERVED_IDS.DO_NOT_INFLATE))) {
            (inflatedData, nextSlice) = handleDoNotInflateCase(_slice, _arrayLenSizeBytes);
        } else if (inflatorId == bytes32(uint256(RESERVED_IDS.REGISTER_INFLATOR_AND_INFLATE))) {
            (inflatedData, nextSlice) =
                handleRegisterInflatorAndDecompressCase(_slice, _registry, _inflatorIdSizeBytes, _arrayLenSizeBytes);
        } else if (uint256(inflatorId) >= RegistryLib.FIRST_ID) {
            (inflatedData, nextSlice) =
                handleDecompressCase(_slice, _registry, _inflatorIdSizeBytes, _arrayLenSizeBytes);
        } else {
            revert("DeflationLib: invalid inflator id");
        }
    }

    function handleDoNotInflateCase(bytes calldata _slice, uint256 _arrayLenSizeBytes)
        internal
        pure
        returns (bytes memory inflatedData, bytes calldata nextSlice)
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
        }

        // Copy the array
        inflatedData = new bytes(arrayLen);
        assembly ("memory-safe") {
            calldatacopy(inflatedData, nextSlice.offset, arrayLen)
            nextSlice.offset := add(nextSlice.offset, arrayLen)
        }
    }

    function handleRegisterInflatorAndDecompressCase(
        bytes calldata _slice,
        RegistryLib.RegistryStore storage _registry,
        uint256 _inflatorIdSizeBytes,
        uint256 _arrayLenSizeBytes
    ) internal returns (bytes memory inflatedData, bytes calldata nextSlice) {
        /*
         * Layout
         * Offset (in bytes)          | Length (in bytes)     | Contents
         * 0x0                        | 20                    | Inflator Address
         * 0x14                       | _arraryLenSizeBytes   | Length of the Array of compressed data
         * 0x14 + _arraryLenSizeBytes | len                   | compressed data
         */

        nextSlice = _slice;

        // Extract the inflator address
        address inflatorAddr;
        assembly ("memory-safe") {
            inflatorAddr := shr(96, calldataload(nextSlice.offset))
            nextSlice.offset := add(nextSlice.offset, 20)
        }

        // Extract the array length
        uint256 arrayLen;
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(_arrayLenSizeBytes, 8))
            arrayLen := shr(bitsToDiscard, calldataload(nextSlice.offset))
            nextSlice.offset := add(nextSlice.offset, _arrayLenSizeBytes)
        }

        // Register the inflator
        _registry.checkAndRegister(inflatorAddr, _inflatorIdSizeBytes);

        // Copy the array
        bytes memory compressedData = new bytes(arrayLen);
        assembly ("memory-safe") {
            calldatacopy(compressedData, nextSlice.offset, arrayLen)
            nextSlice.offset := add(nextSlice.offset, arrayLen)
        }

        // Decompress the data
        try IInflator(inflatorAddr).inflate(compressedData) returns (bytes memory _inflatedData) {
            inflatedData = _inflatedData;
        } catch Error(string memory reason) {
            revert(string.concat("DeflationLib: inflator failed to inflate: ", reason));
        } catch {
            revert("DeflationLib: inflator failed to inflate");
        }
    }

    function handleDecompressCase(
        bytes calldata _slice,
        RegistryLib.RegistryStore storage _registry,
        uint256 _inflatorIdSizeBytes,
        uint256 _arrayLenSizeBytes
    ) internal returns (bytes memory inflatedData, bytes calldata nextSlice) {
        /*
         * Layout
         * Offset (in bytes)                          | Length (in bytes)     | Contents
         * 0x0                                        | _inflatorIdSizeBytes  | Inflator ID
         * _inflatorIdSizeBytes                       | _arraryLenSizeBytes   | Length of the Array of compressed data
         * _inflatorIdSizeBytes + _arraryLenSizeBytes | len                   | compressed data
         */

        nextSlice = _slice;
        uint256 inflatorId;

        // Extract the inflator id
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(_inflatorIdSizeBytes, 8))
            inflatorId := shr(bitsToDiscard, calldataload(nextSlice.offset))
            nextSlice.offset := add(nextSlice.offset, _inflatorIdSizeBytes)
        }

        // Get the inflator
        IInflator inflator = IInflator(_registry.checkAndGet(inflatorId));
        if (address(inflator) == address(0)) {
            revert("DeflationLib: inflator not registered");
        }

        // Extract the array length
        uint256 arrayLen;
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(_arrayLenSizeBytes, 8))
            arrayLen := shr(bitsToDiscard, calldataload(nextSlice.offset))
            nextSlice.offset := add(nextSlice.offset, _arrayLenSizeBytes)
        }

        // Copy the array
        bytes memory compressedData = new bytes(arrayLen);
        assembly ("memory-safe") {
            calldatacopy(compressedData, nextSlice.offset, arrayLen)
            nextSlice.offset := add(nextSlice.offset, arrayLen)
        }

        // Decompress the data
        try inflator.inflate(compressedData) returns (bytes memory _inflatedData) {
            inflatedData = _inflatedData;
        } catch Error(string memory reason) {
            revert(string.concat("DeflationLib: inflator failed to inflate: ", reason));
        } catch {
            revert("DeflationLib: inflator failed to inflate");
        }
    }

    function deflate(
        bytes calldata _data,
        RegistryLib.RegistryStore storage _registry,
        IInflator _inflator,
        uint256 _inflatorIdSizeBytes,
        uint256 _lengthSizeBytes
    ) internal view returns (bytes memory) {
        // Do not inflate
        if (address(_inflator) == address(0)) {
            return abi.encodePacked(
                uint256(RESERVED_IDS.DO_NOT_INFLATE).toBytesNPacked(_inflatorIdSizeBytes),
                _data.length.toBytesNPacked(_lengthSizeBytes),
                _data
            );
        }

        bytes memory deflatedData = _inflator.deflate(_data);

        uint256 inflatorId = _registry.addrToId[address(_inflator)];
        // Register and inflate
        if (inflatorId == 0) {
            return abi.encodePacked(
                uint256(RESERVED_IDS.REGISTER_INFLATOR_AND_INFLATE).toBytesNPacked(_inflatorIdSizeBytes),
                address(_inflator),
                deflatedData.length.toBytesNPacked(_lengthSizeBytes),
                deflatedData
            );
        }
        // Normal Inflate Case
        else {
            return abi.encodePacked(
                inflatorId.toBytesNPacked(_inflatorIdSizeBytes),
                deflatedData.length.toBytesNPacked(_lengthSizeBytes),
                deflatedData
            );
        }
    }
}
