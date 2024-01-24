// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {console2} from "forge-std/console2.sol";

library RegistryLib {
    uint256 constant FIRST_ID = 0x0100;

    event Registered(uint256 indexed id, address indexed addr, uint256 indexed registryId);

    struct RegistryStore {
        mapping(uint256 => address) idToAddr;
        mapping(address => uint256) addrToId;
        uint256 nextId;
    }

    function initialize(RegistryStore storage _self) internal {
        _self.nextId = FIRST_ID;
    }

    function checkAndRegister(RegistryStore storage _self, address _addr, uint256 _keySizeBytes)
        internal
        returns (uint256 id)
    {
        if (2 ** (8 * _keySizeBytes) == _self.nextId) {
            revert("Registry: no more space for new decompressors");
        }

        if (_addr == address(0)) {
            revert("Registry: cannot register zero address");
        }

        if (_self.idToAddr[_self.nextId] != address(0)) {
            revert("Registry: id already registered");
        }

        id = _self.nextId++;
        _self.idToAddr[id] = _addr;
        _self.addrToId[_addr] = id;

        emit Registered(id, _addr, registryId(_self));
    }

    function checkAndGet(RegistryStore storage _self, uint256 _id) internal view returns (address addr) {
        addr = _self.idToAddr[_id];
        require(addr != address(0), "Registry: id not registered");
    }

    function registryId(RegistryStore storage _self) internal pure returns (uint256 id) {
        assembly ("memory-safe") {
            id := _self.slot
        }
    }
}
