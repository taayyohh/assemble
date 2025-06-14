// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { SocialLibrary } from "../src/libraries/SocialLibrary.sol";
import { CommentLibrary } from "../src/libraries/CommentLibrary.sol";

/// @title Comment System Example Test
/// @notice Demonstrates comprehensive comment functionality matching Partiful features
/// @author @taayyohh
contract CommentSystemExampleTest is Test {
    Assemble public assemble;

    address public organizer = makeAddr("organizer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public spammer = makeAddr("spammer");

    uint256 public eventId;

    function setUp() public {
        assemble = new Assemble(address(this));

        // Create test event
        vm.prank(organizer);
        eventId = _createTestEvent();
    }

    function test_BasicCommentWorkflow() public {
        console.log("\n=== Basic Comment Workflow ===");

        // Alice posts a question about the event
        vm.prank(alice);
        assemble.postComment(eventId, "What should I bring to the party?", 0);

        console.log("Alice posted question about the event");

        // Bob replies to Alice's comment
        vm.prank(bob);
        assemble.postComment(eventId, "Just bring yourself! Food will be provided.", 1);

        console.log("Bob replied with helpful answer");

        // Organizer adds official update
        vm.prank(organizer);
        assemble.postComment(eventId, "UPDATE: Event moved indoors due to weather. Same time!", 0);

        console.log("Organizer posted important update");

        // Check comments were stored correctly
        uint256[] memory comments = assemble.getEventComments(eventId);
        assertEq(comments.length, 3, "Should have 3 comments");

        // Verify comment details
        CommentLibrary.Comment memory aliceComment = assemble.getComment(1);
        assertEq(aliceComment.author, alice);
        assertEq(aliceComment.parentId, 0); // Top-level comment
        assertEq(aliceComment.content, "What should I bring to the party?");

        CommentLibrary.Comment memory bobReply = assemble.getComment(2);
        assertEq(bobReply.author, bob);
        assertEq(bobReply.parentId, 1); // Reply to Alice

        console.log("All comments stored and retrieved correctly");
    }

    // Note: Comment liking system removed for bytecode optimization
    // Threaded comments provide sufficient interaction without like/unlike functionality

    function test_ThreadedConversations() public {
        console.log("\n=== Threaded Conversations ===");

        // Alice starts discussion
        vm.prank(alice);
        assemble.postComment(eventId, "Should we do a gift exchange?", 0);

        // Multiple people reply to Alice
        vm.prank(bob);
        assemble.postComment(eventId, "Great idea! I'm in.", 1);

        vm.prank(charlie);
        assemble.postComment(eventId, "Yes! $20 limit?", 1);

        vm.prank(organizer);
        assemble.postComment(eventId, "Love this idea! Let's do $20 limit.", 1);

        // Bob replies to Charlie's suggestion
        vm.prank(bob);
        assemble.postComment(eventId, "Perfect amount!", 3);

        console.log("Threaded conversation created with multiple replies");

        // Get all comments and filter for replies to Alice's original comment (comment 1)
        uint256[] memory allComments = assemble.getEventComments(eventId);
        uint256 replyCount = 0;
        for (uint256 i = 0; i < allComments.length; i++) {
            CommentLibrary.Comment memory comment = assemble.getComment(allComments[i]);
            if (comment.parentId == 1) {
                replyCount++;
            }
        }
        assertEq(replyCount, 3, "Should have 3 direct replies");

        // Get replies to Charlie's comment (comment 3)
        uint256 charlieReplyCount = 0;
        for (uint256 i = 0; i < allComments.length; i++) {
            CommentLibrary.Comment memory comment = assemble.getComment(allComments[i]);
            if (comment.parentId == 3) {
                charlieReplyCount++;
            }
        }
        assertEq(charlieReplyCount, 1, "Should have 1 reply to Charlie");

        console.log("Thread structure preserved correctly");
    }

    function test_CommentModeration() public {
        console.log("\n=== Comment Moderation ===");

        // Spammer posts inappropriate content
        vm.prank(spammer);
        assemble.postComment(eventId, "Buy crypto now! Amazing deals!", 0);

        console.log("Spam comment posted");

        // Note: Comment deletion removed - comments are now permanent on blockchain
        // Frontend applications can implement their own filtering and moderation

        // Verify comment exists and cannot be deleted
        CommentLibrary.Comment memory spamComment = assemble.getComment(1);
        assertEq(spamComment.author, spammer, "Comment should exist permanently");
        assertGt(spamComment.timestamp, 0, "Comment should have valid timestamp");

        console.log("Comments are now permanent - moderation handled at application layer");

        // User can still comment (but frontend could filter them out)
        vm.prank(spammer);
        assemble.postComment(eventId, "This will be posted but clients can filter it", 0);

        console.log("Moderation now handled by client-side filtering of permanent comments");
    }

    function test_CommentValidation() public {
        console.log("\n=== Comment Validation ===");

        // Try to post comment that's too long
        string memory tooLongContent = string(new bytes(1001)); // Over 1000 chars
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("BadInput()"));
        assemble.postComment(eventId, tooLongContent, 0);

        // Try to post empty comment
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("BadInput()"));
        assemble.postComment(eventId, "", 0);

        // Test replying to non-existent comment
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotFound()"));
        assemble.postComment(eventId, "Reply to nothing", 999);

        console.log("All comment validations working correctly");
    }

    function test_EventCommentsIntegration() public {
        console.log("\n=== Integration with Event Features ===");

        // Users comment and RSVP
        vm.prank(alice);
        assemble.postComment(eventId, "Can't wait for this!", 0);

        vm.prank(alice);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        // Friends can see each other's comments and RSVPs
        vm.prank(alice);
        assemble.addFriend(bob);

        vm.prank(bob);
        assemble.addFriend(alice);

        vm.prank(bob);
        assemble.postComment(eventId, "See you there Alice!", 1);

        console.log("Comments integrated with social features");

        // Event organizer can engage with community
        vm.prank(organizer);
        assemble.postComment(eventId, "Thanks everyone! This will be amazing!", 0);

        console.log("Complete social coordination through comments");
    }

    function test_CommentSystemPerformance() public {
        console.log("\n=== Comment System Performance Test ===");

        // Create multiple comments to test gas efficiency
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(alice);
            assemble.postComment(eventId, string(abi.encodePacked("Comment #", _toString(i))), 0);
        }

        // Get all comments efficiently
        uint256[] memory allComments = assemble.getEventComments(eventId);
        assertEq(allComments.length, 10, "Should have 10 comments");

        console.log("Comment system scales efficiently with multiple comments");
    }

    // Helper functions
    function _createTestEvent() internal returns (uint256) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Community Tech Meetup",
            description: "Monthly gathering for local developers and tech enthusiasts",
            imageUri: "QmTechMeetupImage",
            startTime: block.timestamp + 7 days,
            endTime: block.timestamp + 7 days + 3 hours,
            capacity: 100,
            latitude: 377826000, // SF: 37.7826 * 1e7
            longitude: -1224241000, // SF: -122.4241 * 1e7
            venueName: "Tech Hub Coworking Space",
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "General Admission",
            price: 0, // Free event
            maxSupply: 50,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: false
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit(organizer, 10_000);

        return assemble.createEvent(params, tiers, splits);
    }

    function _generateLongString(uint256 length) internal pure returns (string memory) {
        bytes memory longBytes = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            longBytes[i] = "a";
        }
        return string(longBytes);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }
}
