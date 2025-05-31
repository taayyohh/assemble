// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Comment Library
/// @notice Library for handling comment system functionality
/// @author taayyohh
library CommentLibrary {
    /// @notice Comment data structure
    struct Comment {
        address author; // Comment author
        uint256 timestamp; // When comment was posted
        string content; // Comment text content
        uint256 parentId; // Parent comment ID for replies (0 for top-level)
        bool isDeleted; // Soft delete flag
        uint256 likes; // Number of likes
    }

    /// @notice Post a comment on an event
    /// @param comments Storage mapping of comments
    /// @param eventComments Storage mapping of event comments
    /// @param bannedUsers Storage mapping of banned users
    /// @param nextCommentId Next comment ID counter
    /// @param eventId Event to comment on
    /// @param content Comment text content
    /// @param parentId Parent comment ID for replies (0 for top-level)
    /// @param author Comment author
    /// @return commentId The ID of the created comment
    function postComment(
        mapping(uint256 => Comment) storage comments,
        mapping(uint256 => uint256[]) storage eventComments,
        mapping(address => bool) storage bannedUsers,
        uint256 nextCommentId,
        uint256 eventId,
        string calldata content,
        uint256 parentId,
        address author
    )
        external
        returns (uint256 commentId)
    {
        require(!bannedUsers[author], "Banned");
        require(bytes(content).length > 0 && bytes(content).length <= 1000, "Invalid length");

        // Validate parent comment if replying
        if (parentId > 0) {
            require(comments[parentId].timestamp > 0, "Parent not found");
            require(!comments[parentId].isDeleted, "Parent deleted");

            // Verify parent belongs to this event
            uint256[] memory eventCommentIds = eventComments[eventId];
            bool parentFound = false;
            for (uint256 i = 0; i < eventCommentIds.length; i++) {
                if (eventCommentIds[i] == parentId) {
                    parentFound = true;
                    break;
                }
            }
            require(parentFound, "Parent not in event");
        }

        commentId = nextCommentId;

        comments[commentId] = Comment({
            author: author,
            timestamp: block.timestamp,
            content: content,
            parentId: parentId,
            isDeleted: false,
            likes: 0
        });

        eventComments[eventId].push(commentId);

        return commentId;
    }

    /// @notice Like a comment
    /// @param comments Storage mapping of comments
    /// @param commentLikes Storage mapping of comment likes
    /// @param commentId Comment to like
    /// @param user User liking the comment
    function likeComment(
        mapping(uint256 => Comment) storage comments,
        mapping(uint256 => mapping(address => bool)) storage commentLikes,
        uint256 commentId,
        address user
    )
        external
    {
        require(comments[commentId].timestamp > 0, "Not found");
        require(!comments[commentId].isDeleted, "Deleted");
        require(!commentLikes[commentId][user], "Already liked");

        commentLikes[commentId][user] = true;
        comments[commentId].likes++;
    }

    /// @notice Unlike a comment
    /// @param comments Storage mapping of comments
    /// @param commentLikes Storage mapping of comment likes
    /// @param commentId Comment to unlike
    /// @param user User unliking the comment
    function unlikeComment(
        mapping(uint256 => Comment) storage comments,
        mapping(uint256 => mapping(address => bool)) storage commentLikes,
        uint256 commentId,
        address user
    )
        external
    {
        require(comments[commentId].timestamp > 0, "Not found");
        require(commentLikes[commentId][user], "Not liked");

        commentLikes[commentId][user] = false;
        comments[commentId].likes--;
    }

    /// @notice Delete a comment (soft delete)
    /// @param comments Storage mapping of comments
    /// @param eventComments Storage mapping of event comments
    /// @param eventOrganizers Storage mapping of event organizers
    /// @param feeTo Protocol admin address
    /// @param nextEventId Next event ID for searching
    /// @param commentId Comment to delete
    /// @param caller Address requesting deletion
    function deleteComment(
        mapping(uint256 => Comment) storage comments,
        mapping(uint256 => uint256[]) storage eventComments,
        mapping(uint256 => address) storage eventOrganizers,
        address feeTo,
        uint256 nextEventId,
        uint256 commentId,
        address caller
    )
        external
    {
        require(comments[commentId].timestamp > 0, "Not found");
        require(!comments[commentId].isDeleted, "Already deleted");

        // Find which event this comment belongs to
        uint256 targetEventId = 0;
        for (uint256 eventId = 1; eventId < nextEventId; eventId++) {
            uint256[] memory eventCommentIds = eventComments[eventId];
            for (uint256 i = 0; i < eventCommentIds.length; i++) {
                if (eventCommentIds[i] == commentId) {
                    targetEventId = eventId;
                    break;
                }
            }
            if (targetEventId > 0) break;
        }

        require(targetEventId > 0, "Event not found");

        // Check permissions
        require(
            comments[commentId].author == caller || eventOrganizers[targetEventId] == caller || caller == feeTo,
            "Not authorized"
        );

        comments[commentId].isDeleted = true;
    }

    /// @notice Get replies to a comment
    /// @param comments Storage mapping of comments
    /// @param eventComments Storage mapping of event comments
    /// @param parentId Parent comment ID
    /// @param eventId Event ID to search within
    /// @return replyIds Array of reply comment IDs
    function getCommentReplies(
        mapping(uint256 => Comment) storage comments,
        mapping(uint256 => uint256[]) storage eventComments,
        uint256 parentId,
        uint256 eventId
    )
        external
        view
        returns (uint256[] memory replyIds)
    {
        uint256[] memory eventCommentIds = eventComments[eventId];

        // Count replies first
        uint256 replyCount = 0;
        for (uint256 i = 0; i < eventCommentIds.length; i++) {
            if (comments[eventCommentIds[i]].parentId == parentId) {
                replyCount++;
            }
        }

        // Build result array
        replyIds = new uint256[](replyCount);
        uint256 index = 0;
        for (uint256 i = 0; i < eventCommentIds.length; i++) {
            if (comments[eventCommentIds[i]].parentId == parentId) {
                replyIds[index] = eventCommentIds[i];
                index++;
            }
        }
    }
}
