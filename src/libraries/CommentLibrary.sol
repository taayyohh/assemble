// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Comment Library
/// @notice Library for handling comment system functionality
/// @author taayyohh
library CommentLibrary {
    /// @notice Comment data structure (optimized - removed isDeleted field)
    struct Comment {
        address author; // Comment author
        uint256 timestamp; // When comment was posted
        string content; // Comment text content
        uint256 parentId; // Parent comment ID for replies (0 for top-level)
    }

    // Library functions removed - comment posting inlined in main contract for optimization
}
