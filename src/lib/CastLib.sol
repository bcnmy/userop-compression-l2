// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

library CastLib {
    // To be used strictly off-chain
    function toBytesNPacked(uint256 _x, uint256 _n) internal pure returns (bytes memory b) {
        if (_n == 1) {
            return abi.encodePacked(uint8(_x));
        } else if (_n == 2) {
            return abi.encodePacked(uint16(_x));
        } else if (_n == 3) {
            return abi.encodePacked(uint24(_x));
        } else if (_n == 4) {
            return abi.encodePacked(uint32(_x));
        } else if (_n == 5) {
            return abi.encodePacked(uint40(_x));
        } else if (_n == 6) {
            return abi.encodePacked(uint48(_x));
        } else if (_n == 7) {
            return abi.encodePacked(uint56(_x));
        } else if (_n == 8) {
            return abi.encodePacked(uint64(_x));
        } else if (_n == 9) {
            return abi.encodePacked(uint72(_x));
        } else if (_n == 10) {
            return abi.encodePacked(uint80(_x));
        } else if (_n == 11) {
            return abi.encodePacked(uint88(_x));
        } else if (_n == 12) {
            return abi.encodePacked(uint96(_x));
        } else if (_n == 13) {
            return abi.encodePacked(uint104(_x));
        } else if (_n == 14) {
            return abi.encodePacked(uint112(_x));
        } else if (_n == 15) {
            return abi.encodePacked(uint120(_x));
        } else if (_n == 16) {
            return abi.encodePacked(uint128(_x));
        } else if (_n == 17) {
            return abi.encodePacked(uint136(_x));
        } else if (_n == 18) {
            return abi.encodePacked(uint144(_x));
        } else if (_n == 19) {
            return abi.encodePacked(uint152(_x));
        } else if (_n == 20) {
            return abi.encodePacked(uint160(_x));
        } else if (_n == 21) {
            return abi.encodePacked(uint168(_x));
        } else if (_n == 22) {
            return abi.encodePacked(uint176(_x));
        } else if (_n == 23) {
            return abi.encodePacked(uint184(_x));
        } else if (_n == 24) {
            return abi.encodePacked(uint192(_x));
        } else if (_n == 25) {
            return abi.encodePacked(uint200(_x));
        } else if (_n == 26) {
            return abi.encodePacked(uint208(_x));
        } else if (_n == 27) {
            return abi.encodePacked(uint216(_x));
        } else if (_n == 28) {
            return abi.encodePacked(uint224(_x));
        } else if (_n == 29) {
            return abi.encodePacked(uint232(_x));
        } else if (_n == 30) {
            return abi.encodePacked(uint240(_x));
        } else if (_n == 31) {
            return abi.encodePacked(uint248(_x));
        } else if (_n == 32) {
            return abi.encodePacked(uint256(_x));
        } else {
            revert("CastLib: invalid n");
        }
    }
}
