// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RegistryLib} from "./RegistryLib.sol";
import {CastLib} from "./CastLib.sol";
import {CalldataReadLib} from "./CalldataReadLib.sol";

library SenderLib {
    using RegistryLib for RegistryLib.RegistryStore;
    using CastLib for uint256;
    using CalldataReadLib for bytes;

    error InvalidSenderId(uint256 senderId);

    // Reserved IDs (upto 0x00FF)
    enum RESERVED_IDS {
        REGISTER_SENDER // 0x0000
    }

    function decompress(
        bytes calldata _slice,
        RegistryLib.RegistryStore storage _registry,
        uint256 _senderRepresentationSizeBytes
    ) internal returns (address sender, bytes calldata nextSlice) {
        /*
         * Layout
         * Offset (in bytes)              | Length (in bytes)              | Contents
         * 0x0                            | _senderRepresentationSizeBytes | The Sender ID / Reserved ID
         * _senderRepresentationSizeBytes | ??                             | Rest of the data
         */

        nextSlice = _slice;

        // Extract the sender id
        uint256 senderId = nextSlice.read(_senderRepresentationSizeBytes);
        nextSlice = nextSlice[_senderRepresentationSizeBytes:];

        if (senderId == uint256(RESERVED_IDS.REGISTER_SENDER)) {
            (sender, nextSlice) = handleRegisterSenderCase(nextSlice, _registry, _senderRepresentationSizeBytes);
        } else if (senderId >= RegistryLib.FIRST_ID) {
            sender = handleCompressionCase(senderId, _registry);
        } else {
            revert InvalidSenderId(senderId);
        }
    }

    function handleRegisterSenderCase(
        bytes calldata _slice,
        RegistryLib.RegistryStore storage _registry,
        uint256 _senderIdSizeBytes
    ) internal returns (address sender, bytes calldata nextSlice) {
        /*
         * Layout
         * Offset (in bytes)       | Length (in bytes) | Contents
         * 0x0                     | 20                | Sender Address
         */

        nextSlice = _slice;

        // Extract the sender address
        sender = address(uint160(nextSlice.read(20)));
        nextSlice = nextSlice[20:];

        // Register the sender
        _registry.checkAndRegister(sender, _senderIdSizeBytes);
    }

    function handleCompressionCase(uint256 _senderId, RegistryLib.RegistryStore storage _registry)
        internal
        view
        returns (address sender)
    {
        sender = _registry.checkAndGet(_senderId);
    }

    function compress(RegistryLib.RegistryStore storage _registry, address _sender, uint256 _senderIdSizeBytes)
        internal
        view
        returns (bytes memory compressedSender)
    {
        uint256 senderId = _registry.addrToId[_sender];
        if (senderId == 0) {
            return abi.encodePacked(uint256(RESERVED_IDS.REGISTER_SENDER).toBytesNPacked(_senderIdSizeBytes), _sender);
        } else {
            return abi.encodePacked(senderId.toBytesNPacked(_senderIdSizeBytes));
        }
    }
}
