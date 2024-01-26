// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseTest} from "../BaseTest.sol";
import {CastLib} from "src/lib/CastLib.sol";

contract CalldataReadLibTest is BaseTest {
    using CastLib for uint256;

    function setUp() public override {
        super.setUp();
    }

    function testEncoding() public {
        uint256 value = uint256(bytes32(keccak256(abi.encodePacked("hello world"))));

        for (uint256 i = 1; i <= 32; ++i) {
            unchecked {
                assertEq(uint256(bytes32(value.toBytesNPacked(i))), (value & ((1 << (i * 8)) - 1)) << ((32 - i) * 8));
            }
            assertEq(value.toBytesNPacked(i).length, i);
        }
    }

    function testShouldRevertIfLengthIsGreaterThan32(uint256 n) public {
        vm.assume(n > 32);
        vm.expectRevert(abi.encodeWithSelector(CastLib.CastLibInvalidSize.selector, n));
        uint256(bytes32(keccak256(abi.encodePacked("hello world")))).toBytesNPacked(n);
    }

    function testShouldRevertIfLengthIs0() public {
        vm.expectRevert(abi.encodeWithSelector(CastLib.CastLibInvalidSize.selector, 0));
        uint256(bytes32(keccak256(abi.encodePacked("hello world")))).toBytesNPacked(0);
    }
}
