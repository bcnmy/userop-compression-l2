// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseTest} from "../BaseTest.sol";
import {CalldataReadLib} from "src/lib/CalldataReadLib.sol";

contract CalldataReadLibTest is BaseTest {
    using CalldataReadLib for bytes;

    function setUp() public override {
        super.setUp();
    }

    function testRead() public {
        address a = address(this);
        this.helper_testRead(abi.encodePacked(a), a);
    }

    function helper_testRead(bytes calldata _data, address _a) external {
        assertEq(_data.read(2), uint256(uint160(_a)) >> 144);
    }

    function testShouldNotReadMoreThan32Bytes() public {
        address a = address(this);
        this.helper_testRead(abi.encodePacked(a), a);
    }

    function helper_testShouldNotReadMoreThan32Bytes(bytes calldata _data, address) external {
        vm.expectRevert(abi.encodeWithSelector(CalldataReadLib.CannotReadMoreThan32Bytes.selector, 33));
        _data.read(33);
    }

    function testShouldNotReadMoreThanTotalLength() public {
        address a = address(this);
        this.helper_testRead(abi.encodePacked(a), a);
    }

    function helper_testShouldNotReadMoreThanTotalLength(bytes calldata _data, address) external {
        vm.expectRevert(abi.encodeWithSelector(CalldataReadLib.CannotReadOutsideOfSlice.selector, 21));
        _data.read(21);
    }
}
