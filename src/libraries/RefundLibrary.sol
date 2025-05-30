// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Refund Management Library
/// @notice Library for handling event cancellations and refunds
library RefundLibrary {
    /// @notice Refund claim deadline (90 days after cancellation)
    uint256 internal constant REFUND_CLAIM_DEADLINE = 90 days;

    event RefundClaimed(uint256 indexed eventId, address indexed user, uint256 amount, string refundType);
    event UnclaimedRefundsRecovered(uint256 indexed eventId, uint256 amount, uint256 userCount);

    /// @notice Process ticket refund claim
    function claimTicketRefund(
        mapping(uint256 => bool) storage eventCancelled,
        mapping(uint256 => uint256) storage eventCancellationTime,
        mapping(uint256 => mapping(address => uint256)) storage userTicketPayments,
        uint256 eventId,
        address user
    )
        internal
    {
        require(eventCancelled[eventId], "Event not cancelled");
        require(block.timestamp <= eventCancellationTime[eventId] + REFUND_CLAIM_DEADLINE, "Refund deadline expired");

        uint256 refundAmount = userTicketPayments[eventId][user];
        require(refundAmount > 0, "No refund available");

        // Clear payment tracking to prevent re-claiming
        userTicketPayments[eventId][user] = 0;

        // Transfer refund
        (bool success,) = payable(user).call{ value: refundAmount }("");
        require(success, "Refund transfer failed");

        emit RefundClaimed(eventId, user, refundAmount, "ticket");
    }

    /// @notice Process tip refund claim
    function claimTipRefund(
        mapping(uint256 => bool) storage eventCancelled,
        mapping(uint256 => uint256) storage eventCancellationTime,
        mapping(uint256 => mapping(address => uint256)) storage userTipPayments,
        uint256 eventId,
        address user
    )
        internal
    {
        require(eventCancelled[eventId], "Event not cancelled");
        require(block.timestamp <= eventCancellationTime[eventId] + REFUND_CLAIM_DEADLINE, "Refund deadline expired");

        uint256 refundAmount = userTipPayments[eventId][user];
        require(refundAmount > 0, "No refund available");

        // Clear payment tracking to prevent re-claiming
        userTipPayments[eventId][user] = 0;

        // Transfer refund
        (bool success,) = payable(user).call{ value: refundAmount }("");
        require(success, "Refund transfer failed");

        emit RefundClaimed(eventId, user, refundAmount, "tip");
    }

    /// @notice Recover unclaimed refunds for protocol treasury
    function recoverUnclaimedRefunds(
        mapping(uint256 => bool) storage eventCancelled,
        mapping(uint256 => uint256) storage eventCancellationTime,
        mapping(uint256 => mapping(address => uint256)) storage userTicketPayments,
        mapping(uint256 => mapping(address => uint256)) storage userTipPayments,
        mapping(address => uint256) storage pendingWithdrawals,
        uint256 eventId,
        address[] calldata users,
        address feeTo
    )
        internal
    {
        require(eventCancelled[eventId], "Event not cancelled");
        require(block.timestamp > eventCancellationTime[eventId] + REFUND_CLAIM_DEADLINE, "Refund deadline not expired");

        uint256 totalRecovered = 0;

        for (uint256 i = 0; i < users.length; i++) {
            uint256 ticketRefund = userTicketPayments[eventId][users[i]];
            uint256 tipRefund = userTipPayments[eventId][users[i]];

            if (ticketRefund > 0) {
                userTicketPayments[eventId][users[i]] = 0;
                totalRecovered += ticketRefund;
            }

            if (tipRefund > 0) {
                userTipPayments[eventId][users[i]] = 0;
                totalRecovered += tipRefund;
            }
        }

        if (totalRecovered > 0) {
            pendingWithdrawals[feeTo] += totalRecovered;
            emit UnclaimedRefundsRecovered(eventId, totalRecovered, users.length);
        }
    }
}
