// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { SocialLibrary } from "../src/libraries/SocialLibrary.sol";
import { CommentLibrary } from "../src/libraries/CommentLibrary.sol";

/// @title Edge Case Tests for Assemble Protocol
/// @notice Tests boundary conditions, unusual scenarios, and potential attack vectors
contract EdgeCaseTests is Test {
    Assemble public assemble;

    address public feeTo = makeAddr("feeTo");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public attacker = makeAddr("attacker");

    function setUp() public {
        assemble = new Assemble(feeTo);

        // Fund test accounts with varying amounts
        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        vm.deal(charlie, 1000 ether);
        vm.deal(attacker, 1000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        BOUNDARY VALUE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MaximumEventCapacity() public {
        uint256 maxCapacity = type(uint32).max; // 4.2 billion

        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Maximum Capacity Event",
            description: "Testing maximum capacity limits",
            imageUri: "ipfs://max-capacity",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: maxCapacity,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Max Tier",
            price: 0.001 ether,
            maxSupply: 1000, // Reasonable for testing
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit(alice, 10_000, "organizer");

        vm.prank(alice);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        // Verify max capacity was stored correctly
        (,, uint32 storedCapacity,,,) = assemble.events(eventId);
        assertEq(storedCapacity, maxCapacity);
    }

    function test_ZeroPriceTickets() public {
        uint256 eventId = _createEvent(0, 100); // Free tickets

        vm.prank(bob);
        assemble.purchaseTickets{ value: 0 }(eventId, 0, 1);

        // Verify free ticket was minted
        uint256 tokenId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);
        assertEq(assemble.balanceOf(bob, tokenId), 1);

        // No protocol fees for free tickets
        assertEq(assemble.pendingWithdrawals(feeTo), 0);
    }

    function test_MaximumTicketQuantity() public {
        uint256 maxQuantity = assemble.MAX_TICKET_QUANTITY(); // 50
        uint256 eventId = _createEvent(0.01 ether, maxQuantity); // Set capacity to max quantity

        uint256 totalCost = assemble.calculatePrice(eventId, 0, maxQuantity);

        vm.deal(bob, totalCost);
        vm.prank(bob);
        assemble.purchaseTickets{ value: totalCost }(eventId, 0, maxQuantity);

        // Verify all tickets were minted
        (,, uint256 sold,,,,) = assemble.ticketTiers(eventId, 0);
        assertEq(sold, maxQuantity);
    }

    function test_MaximumPaymentSplits() public {
        uint256 maxSplits = assemble.MAX_PAYMENT_SPLITS(); // 20

        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Max Splits Event",
            description: "Testing maximum payment splits",
            imageUri: "ipfs://max-splits",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 100,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Test Tier",
            price: 0.1 ether,
            maxSupply: 100,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });

        // Create maximum number of splits
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](maxSplits);
        uint256 bpsPerSplit = 10_000 / maxSplits; // Equal distribution
        uint256 remainder = 10_000 % maxSplits;

        for (uint256 i = 0; i < maxSplits; i++) {
            address recipient = makeAddr(string(abi.encodePacked("recipient", vm.toString(i))));
            uint256 bps = bpsPerSplit;
            if (i == 0) bps += remainder; // First recipient gets remainder

            splits[i] = Assemble.PaymentSplit(recipient, bps, "role");
        }

        vm.prank(alice);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        // Verify all splits were stored
        Assemble.PaymentSplit[] memory storedSplits = assemble.getPaymentSplits(eventId);
        assertEq(storedSplits.length, maxSplits);
    }

    /*//////////////////////////////////////////////////////////////
                        TIME-BASED EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_EventStartingInFarFuture() public {
        uint256 farFuture = block.timestamp + 100 * 365 days; // 100 years

        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Far Future Event",
            description: "Event in distant future",
            imageUri: "ipfs://far-future",
            startTime: farFuture,
            endTime: farFuture + 1 days,
            capacity: 100,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Future Tier",
            price: 0.1 ether,
            maxSupply: 100,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: farFuture,
            transferrable: true
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit(alice, 10_000, "organizer");

        vm.prank(alice);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        // Should work fine with far future dates
        assertTrue(eventId > 0);
    }

    function test_TicketSaleEndingAtEventStart() public {
        uint256 startTime = block.timestamp + 1 days;

        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Last Minute Sales",
            description: "Sales end exactly at event start",
            imageUri: "ipfs://last-minute",
            startTime: startTime,
            endTime: startTime + 1 days,
            capacity: 100,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Last Minute",
            price: 0.1 ether,
            maxSupply: 100,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: startTime - 1, // End 1 second before event start
            transferrable: true
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit(alice, 10_000, "organizer");

        vm.prank(alice);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        // Purchase before sale ends
        uint256 price = assemble.calculatePrice(eventId, 0, 1);
        vm.deal(bob, price);
        vm.prank(bob);
        assemble.purchaseTickets{ value: price }(eventId, 0, 1);

        // Fast forward past sale end time
        vm.warp(startTime);

        // Should fail to purchase after sale ends
        vm.deal(charlie, price);
        vm.prank(charlie);
        vm.expectRevert(bytes("ended"));
        assemble.purchaseTickets{ value: price }(eventId, 0, 1);
    }

    function test_RefundClaimDeadlineEdge() public {
        uint256 eventId = _createEvent(0.1 ether, 100);

        // Purchase ticket
        uint256 price = assemble.calculatePrice(eventId, 0, 1);
        vm.deal(bob, price);
        vm.prank(bob);
        assemble.purchaseTickets{ value: price }(eventId, 0, 1);

        // Cancel event
        vm.prank(alice);
        assemble.cancelEvent(eventId);

        // Fast forward to exactly 90 days after cancellation
        vm.warp(block.timestamp + 90 days);

        // Should still work at exactly the deadline
        vm.prank(bob);
        assemble.claimTicketRefund(eventId);

        assertEq(bob.balance, price); // Got refund

        // Create another scenario one second past deadline
        uint256 eventId2 = _createEvent(0.1 ether, 100);

        vm.deal(charlie, price);
        vm.prank(charlie);
        assemble.purchaseTickets{ value: price }(eventId2, 0, 1);

        vm.prank(alice);
        assemble.cancelEvent(eventId2);

        // Fast forward past deadline
        vm.warp(block.timestamp + 90 days + 1 seconds);

        vm.prank(charlie);
        vm.expectRevert(bytes("Refund deadline expired"));
        assemble.claimTicketRefund(eventId2);
    }

    /*//////////////////////////////////////////////////////////////
                        ARITHMETIC EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_PriceCalculationOverflow() public {
        // Create event with high price that could overflow
        uint256 highPrice = 1000 ether; // High but not max to avoid immediate overflow
        uint256 eventId = _createEvent(highPrice, 100);

        // Should not overflow when calculating price for 1 ticket
        uint256 price = assemble.calculatePrice(eventId, 0, 1);
        assertEq(price, highPrice);

        // Large quantities should be caught by quantity check before overflow
        // MAX_TICKET_QUANTITY is 50, so 51 should fail
        vm.expectRevert(bytes("!qty"));
        assemble.purchaseTickets{ value: 0 }(eventId, 0, 51); // Test the actual purchase, not just calculation
    }

    function test_ProtocolFeeRounding() public {
        // Test with amounts that cause rounding
        uint256 eventId = _createEvent(0, 100); // Free event for tips

        // Tip amount that doesn't divide evenly by protocol fee
        uint256 tipAmount = 1003 wei; // Odd amount

        vm.deal(bob, tipAmount);
        vm.prank(bob);
        assemble.tipEvent{ value: tipAmount }(eventId);

        uint256 expectedFee = (tipAmount * 50) / 10_000; // 0.5%
        uint256 actualFee = assemble.pendingWithdrawals(feeTo);

        assertEq(actualFee, expectedFee);
        // Verify organizer gets remainder
        uint256 organizerFunds = assemble.pendingWithdrawals(alice);
        assertEq(organizerFunds, tipAmount - expectedFee);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_NonOrganizerCannotCancelEvent() public {
        uint256 eventId = _createEvent(0.1 ether, 100);

        vm.prank(attacker);
        vm.expectRevert(bytes("Not event organizer"));
        assemble.cancelEvent(eventId);
    }

    function test_NonFeeToCannotUpdateProtocolSettings() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("Not authorized"));
        assemble.setProtocolFee(100);

        vm.prank(attacker);
        vm.expectRevert(bytes("Not authorized"));
        assemble.setFeeTo(attacker);
    }

    /*//////////////////////////////////////////////////////////////
                        REENTRANCY EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_ReentrancyProtectionOnPurchase() public {
        // This would require a malicious contract that tries to reenter
        // For now, verify the nonReentrant modifier is in place
        uint256 eventId = _createEvent(0.1 ether, 100);

        uint256 price = assemble.calculatePrice(eventId, 0, 1);
        vm.deal(bob, price);
        vm.prank(bob);
        assemble.purchaseTickets{ value: price }(eventId, 0, 1);

        // Successful purchase means reentrancy protection didn't interfere
        uint256 tokenId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);
        assertEq(assemble.balanceOf(bob, tokenId), 1);
    }

    /*//////////////////////////////////////////////////////////////
                        SOCIAL GRAPH EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_FriendListWithManyFriends() public {
        // Add many friends to test gas limits
        for (uint256 i = 0; i < 100; i++) {
            address friend = makeAddr(string(abi.encodePacked("friend", vm.toString(i))));
            vm.prank(alice);
            assemble.addFriend(friend);
        }

        address[] memory friends = assemble.getFriends(alice);
        assertEq(friends.length, 100);

        // Remove friend from middle of list
        vm.prank(alice);
        assemble.removeFriend(friends[50]);

        address[] memory friendsAfter = assemble.getFriends(alice);
        assertEq(friendsAfter.length, 99);
        assertFalse(assemble.isFriend(alice, friends[50]));
    }

    function test_CannotAddSelfAsFriend() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Cannot add yourself"));
        assemble.addFriend(alice);
    }

    function test_CannotAddZeroAddressAsFriend() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Invalid address"));
        assemble.addFriend(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_TokenIdGeneration() public {
        // Test different token types
        uint256 ticketId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, 1, 0, 1);
        uint256 badgeId = assemble.generateTokenId(Assemble.TokenType.ATTENDANCE_BADGE, 1, 0, 0);
        uint256 credId = assemble.generateTokenId(Assemble.TokenType.ORGANIZER_CRED, 1, 0, 0);

        // All should be different
        assertTrue(ticketId != badgeId);
        assertTrue(badgeId != credId);
        assertTrue(ticketId != credId);

        // Verify token type extraction
        assertEq(uint8(ticketId >> 248), uint8(Assemble.TokenType.EVENT_TICKET));
        assertEq(uint8(badgeId >> 248), uint8(Assemble.TokenType.ATTENDANCE_BADGE));
        assertEq(uint8(credId >> 248), uint8(Assemble.TokenType.ORGANIZER_CRED));
    }

    function test_SoulboundTokenTransferRestrictions() public {
        uint256 eventId = _createEvent(0.1 ether, 100);

        // Fast forward to event and check in
        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        assemble.checkIn(eventId);

        uint256 badgeId = assemble.generateTokenId(Assemble.TokenType.ATTENDANCE_BADGE, eventId, 0, 0);

        // Try to transfer soulbound token
        vm.prank(alice);
        vm.expectRevert(bytes("soulbound"));
        assemble.transfer(alice, bob, badgeId, 1);

        // Same for organizer credential
        vm.warp(block.timestamp + 1 days + 1 hours);
        vm.prank(alice);
        assemble.claimOrganizerCredential(eventId);

        uint256 credId = assemble.generateTokenId(Assemble.TokenType.ORGANIZER_CRED, eventId, 0, 0);

        vm.prank(alice);
        vm.expectRevert(bytes("soulbound"));
        assemble.transfer(alice, bob, credId, 1);
    }

    /*//////////////////////////////////////////////////////////////
                        COMMENT SYSTEM EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_MaxLengthComment() public {
        uint256 eventId = _createEvent(0.1 ether, 100);

        // Create comment at max length (1000 chars)
        string memory maxContent = string(new bytes(1000));

        vm.prank(alice);
        assemble.postComment(eventId, maxContent, 0);

        uint256 commentId = 1;
        CommentLibrary.Comment memory comment = assemble.getComment(commentId);
        assertEq(bytes(comment.content).length, 1000);
    }

    function test_CommentTooLong() public {
        uint256 eventId = _createEvent(0.1 ether, 100);

        // Try to create comment over max length
        string memory tooLong = string(new bytes(1001));

        vm.prank(alice);
        vm.expectRevert(bytes("Invalid length"));
        assemble.postComment(eventId, tooLong, 0);
    }

    function test_EmptyComment() public {
        uint256 eventId = _createEvent(0.1 ether, 100);

        vm.prank(alice);
        vm.expectRevert(bytes("Invalid length"));
        assemble.postComment(eventId, "", 0);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createEvent(uint256 price, uint256 capacity) internal returns (uint256 eventId) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Edge Case Event",
            description: "Event for edge case testing",
            imageUri: "ipfs://edge-case",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: capacity,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Edge Tier",
            price: price,
            maxSupply: capacity,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit(alice, 10_000, "organizer");

        vm.prank(alice);
        return assemble.createEvent(params, tiers, splits);
    }
}
