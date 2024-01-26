// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseTest} from "../BaseTest.sol";
import {RegistryLib} from "src/lib/RegistryLib.sol";
import {BytesLib} from "solidity-bytes-utils/BytesLib.sol";
import {CastLib} from "src/lib/CastLib.sol";
import {RegistryLib} from "src/lib/RegistryLib.sol";
import {IDecompressor} from "src/interfaces/IDecompressor.sol";
import {DecompressionLib} from "src/lib/DecompressionLib.sol";
import {console2} from "forge-std/console2.sol";

contract DecompressionLibTest is BaseTest {
    using RegistryLib for RegistryLib.RegistryStore;
    using BytesLib for bytes;
    using CastLib for uint256;

    RegistryLib.RegistryStore registry;
    Decompressor decompressor;

    function setUp() public override {
        super.setUp();

        registry.initialize();
        decompressor = new Decompressor();
    }

    function testCompression(uint256 _idSizeBytes, uint256 _lengthSizeBytes) external {
        vm.assume(_idSizeBytes > 1 && _idSizeBytes < 32);
        vm.assume(_lengthSizeBytes > 0 && _lengthSizeBytes < 32);

        // encoded even number
        uint256 number = uint256(bytes32(abi.encodePacked(keccak256("testCompression")))) / 2 * 2;
        uint256 numberCompressed = number / 2;

        bytes memory data = abi.encode(number);

        // Test Register and Compress
        bytes memory compressed = this.helper_compress(data, decompressor, _idSizeBytes, _lengthSizeBytes);
        assertEq(
            compressed.slice(0, _idSizeBytes),
            uint256(DecompressionLib.RESERVED_IDS.REGISTER_DECOMPRESSOR_AND_DECOMPRESS).toBytesNPacked(_idSizeBytes)
        );
        assertEq(compressed.slice(_idSizeBytes, 20), abi.encodePacked(address(decompressor)));
        assertEq(
            compressed.slice(_idSizeBytes + 20, _lengthSizeBytes),
            abi.encodePacked(uint256(data.length).toBytesNPacked(_lengthSizeBytes))
        );
        assertEq(compressed.slice(_idSizeBytes + 20 + _lengthSizeBytes, data.length), abi.encode(numberCompressed));
        assertEq(compressed.length, _idSizeBytes + 20 + _lengthSizeBytes + data.length);

        // Test Decompression
        assertEq(this.helper_decompress(compressed, _idSizeBytes, _lengthSizeBytes), abi.encode(number));

        // Test Pre Registered Address compression
        compressed = this.helper_compress(data, decompressor, _idSizeBytes, _lengthSizeBytes);
        assertTrue(registry.addrToId[address(decompressor)] >= RegistryLib.FIRST_ID);
        assertEq(
            compressed.slice(0, _idSizeBytes),
            uint256(registry.addrToId[address(decompressor)]).toBytesNPacked(_idSizeBytes)
        );
        assertEq(
            compressed.slice(_idSizeBytes, _lengthSizeBytes),
            abi.encodePacked(uint256(data.length).toBytesNPacked(_lengthSizeBytes))
        );
        assertEq(compressed.slice(_idSizeBytes + _lengthSizeBytes, data.length), abi.encode(numberCompressed));
        assertEq(compressed.length, _idSizeBytes + _lengthSizeBytes + data.length);

        // Test Decompression
        assertEq(this.helper_decompress(compressed, _idSizeBytes, _lengthSizeBytes), abi.encode(number));
    }

    function testShouldNotRegisterSameAddressTwice(uint256 _idSizeBytes, uint256 _lengthSizeBytes) external {
        vm.assume(_idSizeBytes > 1 && _idSizeBytes < 32);
        vm.assume(_lengthSizeBytes > 0 && _lengthSizeBytes < 32);

        // encoded even number
        uint256 number = uint256(bytes32(abi.encodePacked(keccak256("testCompression")))) / 2 * 2;
        uint256 numberCompressed = number / 2;

        bytes memory data = abi.encode(number);

        // Test Register and Compress
        bytes memory compressed = this.helper_compress(data, decompressor, _idSizeBytes, _lengthSizeBytes);
        assertEq(
            compressed.slice(0, _idSizeBytes),
            uint256(DecompressionLib.RESERVED_IDS.REGISTER_DECOMPRESSOR_AND_DECOMPRESS).toBytesNPacked(_idSizeBytes)
        );
        assertEq(compressed.slice(_idSizeBytes, 20), abi.encodePacked(address(decompressor)));
        assertEq(
            compressed.slice(_idSizeBytes + 20, _lengthSizeBytes),
            abi.encodePacked(uint256(data.length).toBytesNPacked(_lengthSizeBytes))
        );
        assertEq(compressed.slice(_idSizeBytes + 20 + _lengthSizeBytes, data.length), abi.encode(numberCompressed));
        assertEq(compressed.length, _idSizeBytes + 20 + _lengthSizeBytes + data.length);

        // Test Decompression
        assertEq(this.helper_decompress(compressed, _idSizeBytes, _lengthSizeBytes), abi.encode(number));
        uint256 id = registry.addrToId[address(decompressor)];
        uint256 nextId = registry.nextId;

        // Test Decompression
        assertEq(this.helper_decompress(compressed, _idSizeBytes, _lengthSizeBytes), abi.encode(number));
        assertEq(registry.addrToId[address(decompressor)], id);
        assertEq(registry.nextId, nextId);
    }

    function testPassthrough(uint256 _idSizeBytes, uint256 _lengthSizeBytes, bytes calldata _data) external {
        vm.assume(_idSizeBytes > 1 && _idSizeBytes < 32);
        vm.assume(_lengthSizeBytes > 0 && _lengthSizeBytes < 32);

        // Passthrough Compression
        bytes memory compressed = this.helper_compress(_data, IDecompressor(address(0)), _idSizeBytes, _lengthSizeBytes);
        assertEq(
            compressed.slice(0, _idSizeBytes),
            uint256(DecompressionLib.RESERVED_IDS.DO_NOT_DECOMPRESS).toBytesNPacked(_idSizeBytes)
        );
        assertEq(
            compressed.slice(_idSizeBytes, _lengthSizeBytes),
            abi.encodePacked(uint256(_data.length).toBytesNPacked(_lengthSizeBytes))
        );
        assertEq(compressed.slice(_idSizeBytes + _lengthSizeBytes, _data.length), _data);
        assertEq(compressed.length, _idSizeBytes + _lengthSizeBytes + _data.length);

        // Test Decompression
        assertEq(this.helper_decompress(compressed, _idSizeBytes, _lengthSizeBytes), _data);
    }

    function testShouldRevertIfInvalidDecompressorIdIsSent(uint256 _decompressorId) external {
        vm.assume(_decompressorId > 1 && _decompressorId < RegistryLib.FIRST_ID);

        bytes memory compressed = _decompressorId.toBytesNPacked(2);
        vm.expectRevert(abi.encodeWithSelector(DecompressionLib.InvalidDecompressorId.selector, _decompressorId));
        this.helper_decompress(compressed, 2, 2);
    }

    function testShouldRevertInDecompressionCaseIfDecompressorIsNotRegistered(
        uint256 _idSizeBytes,
        uint256 _lengthSizeBytes
    ) external {
        vm.assume(_idSizeBytes > 1 && _idSizeBytes < 32);
        vm.assume(_lengthSizeBytes > 0 && _lengthSizeBytes < 32);

        // encoded even number
        uint256 number = uint256(bytes32(abi.encodePacked(keccak256("testCompression")))) / 2 * 2;

        bytes memory data = abi.encode(number);

        // Register Decompressor
        bytes memory compressed = this.helper_compress(data, decompressor, _idSizeBytes, _lengthSizeBytes);
        assertEq(this.helper_decompress(compressed, _idSizeBytes, _lengthSizeBytes), abi.encode(number));

        // Get Compressed Data with pre-registered compressor
        compressed = this.helper_compress(data, decompressor, _idSizeBytes, _lengthSizeBytes);

        // De-Register Decompressor
        uint256 decompressorId = registry.addrToId[address(decompressor)];
        registry.idToAddr[decompressorId] = address(0);

        // Decompression
        vm.expectRevert(abi.encodeWithSelector(RegistryLib.IdNotRegistered.selector, decompressorId));
        this.helper_decompress(compressed, _idSizeBytes, _lengthSizeBytes);
    }

    function helper_compress(
        bytes calldata _data,
        IDecompressor _decompressor,
        uint256 _decompressorIdSizeBytes,
        uint256 _lengthSizeBytes
    ) external returns (bytes memory) {
        return DecompressionLib.compress(_data, registry, _decompressor, _decompressorIdSizeBytes, _lengthSizeBytes);
    }

    function helper_decompress(bytes calldata _data, uint256 _decompressorIdSizeBytes, uint256 _lengthSizeBytes)
        external
        returns (bytes memory data)
    {
        (data,) = DecompressionLib.decompress(_data, registry, _decompressorIdSizeBytes, _lengthSizeBytes);
    }
}

contract Decompressor is IDecompressor {
    function decompress(bytes calldata _compressedData) external pure returns (bytes memory data) {
        uint256 value = abi.decode(_compressedData, (uint256));
        return abi.encode(value * 2);
    }

    function compress(bytes calldata _data) external pure returns (bytes memory compressedData) {
        uint256 value = abi.decode(_data, (uint256));
        return abi.encode(value / 2);
    }
}
