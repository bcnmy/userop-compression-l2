// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RegistryLib} from "./RegistryLib.sol";

library SenderLib {
    using RegistryLib for RegistryLib.RegistryStore;

    // Reserved IDs (upto 0x0000FF)
    enum RESERVED_IDS {
        REGISTER_SENDER // 0x000000
    }

    function inflate(
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
        uint256 senderId;
        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(_senderRepresentationSizeBytes, 8))
            senderId := shr(bitsToDiscard, calldataload(nextSlice.offset))
            nextSlice.offset := add(nextSlice.offset, _senderRepresentationSizeBytes)
        }

        if (senderId == uint256(RESERVED_IDS.REGISTER_SENDER)) {
            (sender, nextSlice) = handleRegisterSenderCase(_slice, _registry, _senderRepresentationSizeBytes);
        } else if (senderId >= RegistryLib.FIRST_ID) {
            sender = handleDeflationCase(senderId, _registry);
        } else {
            revert("DeflationLib: invalid sender id");
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
        assembly ("memory-safe") {
            sender := shr(96, calldataload(nextSlice.offset))
            nextSlice.offset := add(nextSlice.offset, 20)
        }

        // Register the sender
        _registry.checkAndRegister(sender, _senderIdSizeBytes);
    }

    function handleDeflationCase(uint256 _senderId, RegistryLib.RegistryStore storage _registry)
        internal
        view
        returns (address sender)
    {
        sender = _registry.checkAndGet(_senderId);
    }
}
