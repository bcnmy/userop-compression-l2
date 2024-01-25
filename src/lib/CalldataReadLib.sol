// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

library CalldataReadLib {
    error CannotReadMoreThan32Bytes(uint256 bytesToRead);
    error CannotReadOutsideOfSlice(uint256 sliceLength, uint256 bytesToRead);

    function read(bytes calldata _slice, uint256 _bytesToRead) internal pure returns (uint256 value) {
        if (_bytesToRead > 32) {
            revert CannotReadMoreThan32Bytes(_bytesToRead);
        }
        if (_slice.length < _bytesToRead) {
            revert CannotReadOutsideOfSlice(_slice.length, _bytesToRead);
        }

        assembly ("memory-safe") {
            let bitsToDiscard := sub(256, mul(_bytesToRead, 8))
            value := shr(bitsToDiscard, calldataload(_slice.offset))
        }
    }
}
