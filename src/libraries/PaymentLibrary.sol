// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PaymentLibrary
/// @notice Optimized payment processing for ERC20 tokens
/// @dev Extracts complex payment logic from main contract to reduce bytecode size
library PaymentLibrary {
    /// @notice Error for unsupported tokens
    error UnsupportedToken();
    
    /// @notice Error for transfer failures
    error TransferFail();
    
    /// @notice Error for platform fee too high
    error PlatformHigh();
    
    /// @notice Error for bad referrer
    error BadRef();

    /// @notice Ultra-efficient ERC20 transfer with inline assembly calls
    /// @param token ERC20 token address
    /// @param from Source address (user or contract)
    /// @param to Destination address 
    /// @param amount Amount to transfer
    function transferERC20(address token, address from, address to, uint256 amount) external {
        if (amount == 0) return;
        
        bytes4 selector;
        bytes memory callData;
        
        if (from == address(this)) {
            // Transfer from contract (withdrawals) - use transfer()
            selector = 0xa9059cbb;
            callData = abi.encodeWithSelector(selector, to, amount);
        } else {
            // Transfer from user (payments) - use transferFrom()
            selector = 0x23b872dd;
            callData = abi.encodeWithSelector(selector, from, to, amount);
        }
        
        (bool success, bytes memory data) = token.call(callData);
        
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFail();
        }
    }

    /// @notice Calculate fees for any payment
    /// @param amount Total payment amount
    /// @param protocolFeeBps Protocol fee in basis points
    /// @param platformFeeBps Platform fee in basis points
    /// @return protocolFee Fee for protocol
    /// @return platformFee Fee for platform
    /// @return netAmount Amount after fees
    function calculateFees(
        uint256 amount,
        uint256 protocolFeeBps,
        uint256 platformFeeBps
    ) external pure returns (uint256 protocolFee, uint256 platformFee, uint256 netAmount) {
        // Platform fee first
        platformFee = (amount * platformFeeBps) / 10_000;
        
        // Protocol fee on remainder
        uint256 remainingAmount = amount - platformFee;
        protocolFee = (remainingAmount * protocolFeeBps) / 10_000;
        
        // Net amount after all fees
        netAmount = remainingAmount - protocolFee;
    }

    /// @notice Validate platform fee parameters
    /// @param referrer Platform referrer address
    /// @param platformFeeBps Platform fee basis points
    /// @param maxPlatformFee Maximum allowed platform fee
    function validatePlatformFee(
        address referrer,
        uint256 platformFeeBps,
        uint256 maxPlatformFee,
        address msgSender
    ) external pure {
        if (platformFeeBps > maxPlatformFee) revert PlatformHigh();
        if (platformFeeBps > 0 && referrer == address(0)) revert BadRef();
        if (referrer == msgSender) revert BadRef();
    }

    /// @notice Process ERC20 purchase logic (extracted from main contract)
    /// @param token ERC20 token address
    /// @param amount Total purchase amount
    /// @param from Buyer address
    /// @param protocolFeeBps Protocol fee basis points
    /// @param platformFeeBps Platform fee basis points
    /// @param feeTo Protocol fee recipient
    /// @param referrer Platform fee recipient (can be address(0))
    /// @return netAmount Amount for event splits after fees
    function processERC20Purchase(
        address token,
        uint256 amount,
        address from,
        uint256 protocolFeeBps,
        uint256 platformFeeBps,
        address feeTo,
        address referrer
    ) external returns (uint256 netAmount) {
        // Calculate fees inline (avoid function call)
        uint256 platformFee = (amount * platformFeeBps) / 10_000;
        uint256 remainingAmount = amount - platformFee;
        uint256 protocolFee = (remainingAmount * protocolFeeBps) / 10_000;
        netAmount = remainingAmount - protocolFee;
        
        // Single transfer from user to contract
        if (amount == 0) return 0;
        
        bytes memory callData = abi.encodeWithSelector(0x23b872dd, from, address(this), amount);
        (bool success, bytes memory data) = token.call(callData);
        
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFail();
        }
        
        return netAmount;
    }

    /// @notice Distribute ERC20 funds to recipients via pending withdrawals
    /// @param token ERC20 token address
    /// @param amount Amount to distribute
    /// @param recipients Array of payment split recipients
    /// @param basisPoints Array of basis points for each recipient
    /// @param pendingERC20Withdrawals Pending withdrawal mapping
    function distributeERC20Funds(
        address token,
        uint256 amount,
        address[] calldata recipients,
        uint256[] calldata basisPoints,
        mapping(address => mapping(address => uint256)) storage pendingERC20Withdrawals
    ) external {
        uint256 length = recipients.length;
        for (uint256 i = 0; i < length;) {
            uint256 payment = (amount * basisPoints[i]) / 10_000;
            pendingERC20Withdrawals[token][recipients[i]] += payment;
            unchecked { ++i; }
        }
    }
} 