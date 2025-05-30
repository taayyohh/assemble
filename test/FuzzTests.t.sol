// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { SocialLibrary } from "../src/libraries/SocialLibrary.sol";
import { CommentLibrary } from "../src/libraries/CommentLibrary.sol";

/// @title Comprehensive Fuzz Tests for Assemble Protocol
/// @notice Property-based testing with random inputs to ensure protocol robustness
contract FuzzTests is Test {
    Assemble public assemble;

    address public feeTo = makeAddr("feeTo");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // Constants for bounded fuzzing
    uint256 constant MAX_CAPACITY = 100_000;
    uint256 constant MAX_PRICE = 10 ether;
    uint256 constant MAX_QUANTITY = 50; // Matches MAX_TICKET_QUANTITY
    uint256 constant MAX_TIERS = 10;
    uint256 constant MAX_SPLITS = 20; // Matches MAX_PAYMENT_SPLITS

    function setUp() public {
        assemble = new Assemble(feeTo);
        
        // Fund test accounts
        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        vm.deal(charlie, 1000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        EVENT CREATION FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_CreateEventWithRandomParams(
        uint256 startTimeOffset,
        uint256 duration,
        uint256 capacity,
        uint256 tierPrice,
        uint256 tierSupply
    ) public {
        // Bound inputs to reasonable ranges
        startTimeOffset = bound(startTimeOffset, 1 hours, 365 days);
        duration = bound(duration, 1 hours, 30 days);
        capacity = bound(capacity, 1, MAX_CAPACITY);
        tierPrice = bound(tierPrice, 0, MAX_PRICE);
        tierSupply = bound(tierSupply, 1, capacity);

        uint256 startTime = block.timestamp + startTimeOffset;
        uint256 endTime = startTime + duration;

        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Fuzz Test Event",
            description: "Testing with random parameters",
            imageUri: "ipfs://fuzz-test",
            startTime: startTime,
            endTime: endTime,
            capacity: capacity,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Fuzz Tier",
            price: tierPrice,
            maxSupply: tierSupply,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: startTime,
            transferrable: true
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit(alice, 10_000, "organizer");

        vm.prank(alice);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        // Verify event was created correctly
        (uint128 basePrice, uint64 storedStartTime, uint32 storedCapacity,,,) = assemble.events(eventId);
        
        assertEq(basePrice, tierPrice);
        assertEq(storedStartTime, startTime);
        assertEq(storedCapacity, capacity);
        assertEq(assemble.eventOrganizers(eventId), alice);
    }

    function testFuzz_PaymentSplitsAlwaysTotal100Percent(
        uint256 split1,
        uint256 split2,
        uint256 split3
    ) public {
        // Ensure splits total exactly 10,000 basis points (100%)
        split1 = bound(split1, 1, 9998);
        split2 = bound(split2, 1, 10000 - split1 - 1);
        split3 = 10000 - split1 - split2;

        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Split Test",
            description: "Testing payment splits",
            imageUri: "ipfs://split-test",
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

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](3);
        splits[0] = Assemble.PaymentSplit(alice, split1, "recipient1");
        splits[1] = Assemble.PaymentSplit(bob, split2, "recipient2");
        splits[2] = Assemble.PaymentSplit(charlie, split3, "recipient3");

        vm.prank(alice);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        // Verify splits were stored correctly
        Assemble.PaymentSplit[] memory storedSplits = assemble.getPaymentSplits(eventId);
        
        uint256 totalBps = 0;
        for (uint i = 0; i < storedSplits.length; i++) {
            totalBps += storedSplits[i].basisPoints;
        }
        
        assertEq(totalBps, 10_000, "Payment splits must total 100%");
    }

    /*//////////////////////////////////////////////////////////////
                        TICKET PURCHASING FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_PurchaseTicketsWithRandomQuantity(
        uint256 quantity,
        uint256 tierPrice,
        uint256 paymentAmount
    ) public {
        quantity = bound(quantity, 1, MAX_QUANTITY);
        tierPrice = bound(tierPrice, 0.001 ether, 1 ether);
        
        uint256 eventId = _createFuzzEvent(tierPrice, 100);
        
        uint256 totalCost = assemble.calculatePrice(eventId, 0, quantity);
        paymentAmount = bound(paymentAmount, totalCost, totalCost + 1 ether);

        vm.deal(bob, paymentAmount);
        vm.prank(bob);
        assemble.purchaseTickets{value: paymentAmount}(eventId, 0, quantity);

        // Verify tickets were minted correctly
        uint256 tokenId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);
        assertGt(assemble.balanceOf(bob, tokenId), 0, "User should have tickets");

        // Verify tier sold count updated
        (, , , uint256 sold, , ,) = assemble.ticketTiers(eventId, 0);
        assertEq(sold, quantity, "Sold count should match quantity purchased");
    }

    function testFuzz_TicketPriceCalculation(
        uint256 basePrice,
        uint256 quantity
    ) public {
        basePrice = bound(basePrice, 0, 10 ether);
        quantity = bound(quantity, 1, MAX_QUANTITY);

        uint256 eventId = _createFuzzEvent(basePrice, 100);
        
        uint256 calculatedPrice = assemble.calculatePrice(eventId, 0, quantity);
        uint256 expectedPrice = basePrice * quantity;

        // Handle free tickets
        if (basePrice == 0) {
            assertEq(calculatedPrice, 0, "Free tickets should have zero price");
        } else {
            assertEq(calculatedPrice, expectedPrice, "Price should be base price * quantity");
        }
    }

    /*//////////////////////////////////////////////////////////////
                        SOCIAL GRAPH FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_FriendSystemIntegrity(
        address[] memory friends
    ) public {
        vm.assume(friends.length <= 50); // Reasonable limit for gas
        
        // Filter out invalid addresses and duplicates
        address[] memory validFriends = new address[](friends.length);
        uint256 validCount = 0;
        
        for (uint i = 0; i < friends.length; i++) {
            if (friends[i] != address(0) && friends[i] != alice) {
                // Check for duplicates
                bool isDuplicate = false;
                for (uint j = 0; j < validCount; j++) {
                    if (validFriends[j] == friends[i]) {
                        isDuplicate = true;
                        break;
                    }
                }
                
                if (!isDuplicate) {
                    validFriends[validCount] = friends[i];
                    validCount++;
                }
            }
        }

        // Add friends
        for (uint i = 0; i < validCount; i++) {
            if (!assemble.isFriend(alice, validFriends[i])) {
                vm.prank(alice);
                assemble.addFriend(validFriends[i]);
            }
        }

        // Verify friend count
        address[] memory aliceFriends = assemble.getFriends(alice);
        assertEq(aliceFriends.length, validCount, "Friend count mismatch");

        // Test removal
        if (validCount > 0) {
            vm.prank(alice);
            assemble.removeFriend(validFriends[0]);
            
            address[] memory aliceFriendsAfter = assemble.getFriends(alice);
            assertEq(aliceFriendsAfter.length, validCount - 1, "Friend should be removed");
            assertFalse(assemble.isFriend(alice, validFriends[0]), "Friendship should be false");
        }
    }

    /*//////////////////////////////////////////////////////////////
                        REFUND SYSTEM FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_RefundIntegrity(
        uint256 ticketQuantity,
        uint256 tipAmount
    ) public {
        ticketQuantity = bound(ticketQuantity, 1, 10);
        tipAmount = bound(tipAmount, 0.01 ether, 1 ether);

        uint256 eventId = _createFuzzEvent(0.1 ether, 100);
        
        uint256 ticketCost = assemble.calculatePrice(eventId, 0, ticketQuantity);
        
        // Purchase tickets
        vm.deal(bob, ticketCost + tipAmount);
        vm.prank(bob);
        assemble.purchaseTickets{value: ticketCost}(eventId, 0, ticketQuantity);

        // Send tip
        vm.prank(bob);
        assemble.tipEvent{value: tipAmount}(eventId);

        // Record balances before cancellation
        uint256 bobBalanceBeforeCancel = bob.balance;

        // Cancel event
        vm.prank(alice);
        assemble.cancelEvent(eventId);

        // Check refund amounts
        (uint256 ticketRefund, uint256 tipRefundAmount) = assemble.getRefundAmounts(eventId, bob);
        
        assertEq(ticketRefund, ticketCost, "Ticket refund should equal ticket cost");
        assertEq(tipRefundAmount, tipAmount, "Tip refund should equal tip amount");

        // Claim refunds
        vm.prank(bob);
        assemble.claimTicketRefund(eventId);
        
        vm.prank(bob);
        assemble.claimTipRefund(eventId);

        // Verify refunds received
        uint256 expectedBalance = bobBalanceBeforeCancel + ticketCost + tipAmount;
        assertEq(bob.balance, expectedBalance, "User should receive full refund");
    }

    /*//////////////////////////////////////////////////////////////
                        COMMENT SYSTEM FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_CommentSystem(
        string memory content,
        uint256 likeCount
    ) public {
        vm.assume(bytes(content).length > 0 && bytes(content).length <= 1000);
        likeCount = bound(likeCount, 1, 100);

        uint256 eventId = _createFuzzEvent(0.1 ether, 100);

        // Post comment
        vm.prank(alice);
        assemble.postComment(eventId, content, 0);

        uint256 commentId = 1; // First comment

        // Create multiple users to like the comment
        for (uint i = 0; i < likeCount; i++) {
            address liker = address(uint160(1000 + i));
            vm.prank(liker);
            assemble.likeComment(commentId);
        }

        // Verify comment data
        CommentLibrary.Comment memory comment = assemble.getComment(commentId);
        assertEq(comment.likes, likeCount, "Like count should match");
        assertEq(comment.content, content, "Content should match");
        assertEq(comment.author, alice, "Author should be Alice");
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_MaximumValues() public {
        // Test with maximum allowed values
        uint256 eventId = _createFuzzEvent(type(uint128).max, type(uint32).max);
        
        // Should not revert with max values - check by getting event data
        (,uint64 startTime,,,,) = assemble.events(eventId);
        assertTrue(startTime > 0, "Event should be created with max values");
    }

    function testFuzz_ProtocolFeeCalculation(
        uint256 amount,
        uint256 feeBps
    ) public {
        amount = bound(amount, 1, 100 ether);
        feeBps = bound(feeBps, 0, 1000); // 0-10% max protocol fee

        // Set protocol fee
        vm.prank(feeTo);
        assemble.setProtocolFee(feeBps);

        uint256 eventId = _createFuzzEvent(0.1 ether, 100);

        vm.deal(bob, amount);
        vm.prank(bob);
        assemble.tipEvent{value: amount}(eventId);

        uint256 expectedFee = (amount * feeBps) / 10_000;
        uint256 actualFee = assemble.pendingWithdrawals(feeTo);

        assertEq(actualFee, expectedFee, "Protocol fee calculation incorrect");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createFuzzEvent(uint256 price, uint256 capacity) internal returns (uint256 eventId) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Fuzz Event",
            description: "Event for fuzz testing",
            imageUri: "ipfs://fuzz",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: capacity,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Fuzz Tier",
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