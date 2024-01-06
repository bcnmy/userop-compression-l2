// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IPerpsV2MarketDelayedIntent {
    function submitCloseOffchainDelayedOrderWithTracking(uint256 desiredFillPrice, bytes32 trackingCode) external;

    function submitCloseDelayedOrderWithTracking(
        uint256 desiredTimeDelta,
        uint256 desiredFillPrice,
        bytes32 trackingCode
    ) external;

    function submitDelayedOrder(int256 sizeDelta, uint256 desiredTimeDelta, uint256 desiredFillPrice) external;

    function submitDelayedOrderWithTracking(
        int256 sizeDelta,
        uint256 desiredTimeDelta,
        uint256 desiredFillPrice,
        bytes32 trackingCode
    ) external;

    function submitOffchainDelayedOrder(int256 sizeDelta, uint256 desiredFillPrice) external;

    function submitOffchainDelayedOrderWithTracking(int256 sizeDelta, uint256 desiredFillPrice, bytes32 trackingCode)
        external;
}
