// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseTest} from "../BaseTest.sol";
import {RegistryLib} from "src/lib/RegistryLib.sol";
import {SenderLib} from "src/lib/SenderLib.sol";
import {BytesLib} from "solidity-bytes-utils/BytesLib.sol";
import {CastLib} from "src/lib/CastLib.sol";

contract SenderLibTest is BaseTest {
    using RegistryLib for RegistryLib.RegistryStore;
    using BytesLib for bytes;
    using CastLib for uint256;

    RegistryLib.RegistryStore registry;

    function setUp() public override {
        super.setUp();

        registry.initialize();
    }

    function testCompression(uint256 _idSizeBytes) external {
        vm.assume(_idSizeBytes > 1 && _idSizeBytes < 32);

        // Test Register and Compress
        bytes memory compressed = SenderLib.compress(registry, alice.addr, _idSizeBytes);
        assertEq(
            compressed.slice(0, _idSizeBytes),
            uint256(SenderLib.RESERVED_IDS.REGISTER_SENDER).toBytesNPacked(_idSizeBytes)
        );
        assertEq(compressed.slice(_idSizeBytes, 20), abi.encodePacked(alice.addr));
        assertEq(compressed.length, _idSizeBytes + 20);

        // Test Decompression
        assertEq(this.helper_testDecompresss(compressed, _idSizeBytes), alice.addr);

        // Test Pre Registered Address compression
        compressed = SenderLib.compress(registry, alice.addr, _idSizeBytes);
        assertTrue(registry.addrToId[alice.addr] >= RegistryLib.FIRST_ID);
        assertEq(compressed.slice(0, _idSizeBytes), uint256(registry.addrToId[alice.addr]).toBytesNPacked(_idSizeBytes));
        assertEq(compressed.length, _idSizeBytes);

        // Test Decompression
        assertEq(this.helper_testDecompresss(compressed, _idSizeBytes), alice.addr);
    }

    function testShouldNotReRegisterSameAddressTwice(uint256 _idSizeBytes) external {
        vm.assume(_idSizeBytes > 1 && _idSizeBytes < 32);

        // Test Register and Compress
        bytes memory compressed = SenderLib.compress(registry, alice.addr, _idSizeBytes);
        assertEq(
            compressed.slice(0, _idSizeBytes),
            uint256(SenderLib.RESERVED_IDS.REGISTER_SENDER).toBytesNPacked(_idSizeBytes)
        );
        assertEq(compressed.slice(_idSizeBytes, 20), abi.encodePacked(alice.addr));
        assertEq(compressed.length, _idSizeBytes + 20);

        // Test Decompression
        assertEq(this.helper_testDecompresss(compressed, _idSizeBytes), alice.addr);
        uint256 id = registry.addrToId[alice.addr];
        uint256 nextId = registry.nextId;

        // Test Decompression
        assertEq(this.helper_testDecompresss(compressed, _idSizeBytes), alice.addr);
        assertEq(registry.addrToId[alice.addr], id);
        assertEq(registry.nextId, nextId);
    }

    function helper_testDecompresss(bytes calldata _compressed, uint256 _idSizeBytes)
        external
        returns (address sender)
    {
        (sender,) = SenderLib.decompress(_compressed, registry, _idSizeBytes);
    }

    function testShouldRevertIfInvalidSenderIdIsSent(uint256 _senderId) external {
        vm.assume(_senderId > 0 && _senderId < RegistryLib.FIRST_ID);

        bytes memory compressed = _senderId.toBytesNPacked(2);
        vm.expectRevert(abi.encodeWithSelector(SenderLib.InvalidSenderId.selector, _senderId));
        this.helper_testDecompresss(compressed, 2);
    }

    function testShoudlRevertInCompressionCaseIfSenderIdIsNotRegistered() external {
        bytes memory compressed = uint256(RegistryLib.FIRST_ID).toBytesNPacked(2);
        vm.expectRevert(abi.encodeWithSelector(RegistryLib.IdNotRegistered.selector, RegistryLib.FIRST_ID));
        this.helper_testDecompresss(compressed, 2);
    }
}
