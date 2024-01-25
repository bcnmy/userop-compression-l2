// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseTest} from "./BaseTest.sol";
import {RegistryLib} from "src/lib/RegistryLib.sol";

contract RegistryLibTest is BaseTest {
    using RegistryLib for RegistryLib.RegistryStore;

    RegistryLib.RegistryStore store;

    function setUp() public override {
        super.setUp();
        store.initialize();
    }

    function testShouldRegisterAddress(uint256 _keySizeBytes) external {
        vm.assume(_keySizeBytes >= 2);
        vm.assume(_keySizeBytes < 32);

        vm.expectEmit();
        emit RegistryLib.Registered(RegistryLib.FIRST_ID, alice.addr, store.registryId());
        uint256 id = store.checkAndRegister(alice.addr, _keySizeBytes);
        assertEq(id, RegistryLib.FIRST_ID);

        assertEq(alice.addr, store.checkAndGet(id));
        assertEq(id, store.addrToId[alice.addr]);
    }

    function testShouldRevertIfCheckAndGetIsCalledWithUnregisteredId(uint256 _id) external {
        vm.expectRevert(abi.encodeWithSelector(RegistryLib.IdNotRegistered.selector, _id));
        store.checkAndGet(_id);
    }

    function testShouldRevertIfInvalidKeySizeIsProvided() external {
        vm.expectRevert(abi.encodeWithSelector(RegistryLib.InvalidKeySizeBytes.selector, 1));
        store.checkAndRegister(alice.addr, 1);

        vm.expectRevert(abi.encodeWithSelector(RegistryLib.InvalidKeySizeBytes.selector, 32));
        store.checkAndRegister(alice.addr, 32);
    }

    function testShouldRevertIfZeroAddressIsProvided() external {
        vm.expectRevert(abi.encodeWithSelector(RegistryLib.ZeroAddressCannotBeRegistered.selector));
        store.checkAndRegister(address(0), 2);
    }

    function testShouldRevertIfKeySpaceIsExhaused() external {
        store.nextId = 2 ** (8 * 2);

        vm.expectRevert(abi.encodeWithSelector(RegistryLib.NoMoreSpaceForNewDecompressors.selector));
        store.checkAndRegister(alice.addr, 2);
    }

    function shouldSkipRegistrationIfAlreadyRegistered() external {
        uint256 id = store.checkAndRegister(alice.addr, 2);

        emit RegistryLib.AlreadyRegistered(id, alice.addr, store.registryId());
        assertEq(store.checkAndRegister(alice.addr, 2), id);
    }
}
