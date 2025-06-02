// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { SocialLibrary } from "../src/libraries/SocialLibrary.sol";
import { CommentLibrary } from "../src/libraries/CommentLibrary.sol";
import { PaymentLibrary } from "../src/libraries/PaymentLibrary.sol";

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
    )
        public
    {
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
            description: "Event for fuzz testing",
            imageUri: "QmFuzzTestImage",
            startTime: startTime,
            endTime: endTime,
            capacity: capacity,
            latitude: 404052000, // NYC: 40.4052 * 1e7
            longitude: -739979000, // NYC: -73.9979 * 1e7
            venueName: "Fuzz Test Venue",
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
        splits[0] = Assemble.PaymentSplit(alice, 10_000);

        vm.prank(alice);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        // Verify event was created correctly
        (uint128 basePrice, uint128 locationData, uint64 storedStartTime, uint32 storedCapacity, uint64 venueHash, uint16 tierCount,,,,,) = assemble.events(eventId);

        assertEq(basePrice, tierPrice);
        assertEq(storedStartTime, startTime);
        assertEq(storedCapacity, capacity);
        assertEq(assemble.eventOrganizers(eventId), alice);
    }

    function testFuzz_PaymentSplitsAlwaysTotal100Percent(uint256 split1, uint256 split2, uint256 split3) public {
        // Ensure splits total exactly 10,000 basis points (100%)
        split1 = bound(split1, 1, 9998);
        split2 = bound(split2, 1, 10_000 - split1 - 1);
        split3 = 10_000 - split1 - split2;

        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Split Test",
            description: "Testing payment splits",
            imageUri: "ipfs://split-test",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 100,
            latitude: 404052000, // NYC: 40.4052 * 1e7
            longitude: -739979000, // NYC: -73.9979 * 1e7
            venueName: "Split Test Venue",
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
        splits[0] = Assemble.PaymentSplit(alice, split1);
        splits[1] = Assemble.PaymentSplit(bob, split2);
        splits[2] = Assemble.PaymentSplit(charlie, split3);

        vm.prank(alice);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        // Verify splits were stored correctly
        Assemble.PaymentSplit[] memory storedSplits = assemble.getPaymentSplits(eventId);

        uint256 totalBps = 0;
        for (uint256 i = 0; i < storedSplits.length; i++) {
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
    )
        public
    {
        quantity = bound(quantity, 1, MAX_QUANTITY);
        tierPrice = bound(tierPrice, 0.001 ether, 1 ether);

        uint256 eventId = _createFuzzEvent(tierPrice, 100);

        uint256 totalCost = assemble.calculatePrice(eventId, 0, quantity);
        paymentAmount = bound(paymentAmount, totalCost, totalCost + 1 ether);

        vm.deal(bob, paymentAmount);
        vm.prank(bob);
        assemble.purchaseTickets{ value: paymentAmount }(eventId, 0, quantity);

        // Verify tickets were minted correctly
        uint256 tokenId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);
        assertGt(assemble.balanceOf(bob, tokenId), 0, "User should have tickets");

        // Verify tier sold count updated
        (,,, uint256 sold,,,) = assemble.ticketTiers(eventId, 0);
        assertEq(sold, quantity, "Sold count should match quantity purchased");
    }

    function testFuzz_TicketPriceCalculation(uint256 basePrice, uint256 quantity) public {
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

    function testFuzz_FriendSystemIntegrity(address[] memory friends) public {
        vm.assume(friends.length <= 50); // Reasonable limit for gas

        // Filter out invalid addresses and duplicates
        address[] memory validFriends = new address[](friends.length);
        uint256 validCount = 0;

        for (uint256 i = 0; i < friends.length; i++) {
            if (friends[i] != address(0) && friends[i] != alice) {
                // Check for duplicates
                bool isDuplicate = false;
                for (uint256 j = 0; j < validCount; j++) {
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
        for (uint256 i = 0; i < validCount; i++) {
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

    function testFuzz_RefundIntegrity(uint256 ticketQuantity, uint256 tipAmount) public {
        ticketQuantity = bound(ticketQuantity, 1, 10);
        tipAmount = bound(tipAmount, 0.01 ether, 1 ether);

        uint256 eventId = _createFuzzEvent(0.1 ether, 100);

        uint256 ticketCost = assemble.calculatePrice(eventId, 0, ticketQuantity);

        // Purchase tickets
        vm.deal(bob, ticketCost + tipAmount);
        vm.prank(bob);
        assemble.purchaseTickets{ value: ticketCost }(eventId, 0, ticketQuantity);

        // Send tip
        vm.prank(bob);
        assemble.tipEvent{ value: tipAmount }(eventId);

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

    function testFuzz_CommentSystem(string memory content, uint256 likeCount) public {
        vm.assume(bytes(content).length > 0 && bytes(content).length <= 1000);
        likeCount = bound(likeCount, 1, 100);

        uint256 eventId = _createFuzzEvent(0.1 ether, 100);

        // Post comment
        vm.prank(alice);
        assemble.postComment(eventId, content, 0);

        uint256 commentId = 1; // First comment

        // Create multiple users to like the comment
        for (uint256 i = 0; i < likeCount; i++) {
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
        (,, uint64 startTime,,,,,,,,) = assemble.events(eventId);
        assertTrue(startTime > 0, "Event should be created with max values");
    }

    function testFuzz_ProtocolFeeCalculation(uint256 amount, uint256 feeBps) public {
        amount = bound(amount, 1, 100 ether);
        feeBps = bound(feeBps, 0, 1000); // 0-10% max protocol fee

        // Set protocol fee
        vm.prank(feeTo);
        assemble.setProtocolFee(feeBps);

        uint256 eventId = _createFuzzEvent(0.1 ether, 100);

        vm.deal(bob, amount);
        vm.prank(bob);
        assemble.tipEvent{ value: amount }(eventId);

        uint256 expectedFee = (amount * feeBps) / 10_000;
        uint256 actualFee = assemble.pendingWithdrawals(feeTo);

        assertEq(actualFee, expectedFee, "Protocol fee calculation incorrect");
    }

    /*//////////////////////////////////////////////////////////////
                        PLATFORM FEE FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_PlatformFeeTicketPurchase(uint256 ticketPrice, uint256 quantity, uint256 platformFeeBps) public {
        ticketPrice = bound(ticketPrice, 0.001 ether, 1 ether);
        quantity = bound(quantity, 1, 10);
        platformFeeBps = bound(platformFeeBps, 0, 500); // 0-5% max platform fee

        uint256 eventId = _createFuzzEvent(ticketPrice, 100);
        address platform = makeAddr("fuzzPlatform");

        uint256 totalCost = ticketPrice * quantity;
        vm.deal(bob, totalCost + 1 ether);

        vm.prank(bob);
        assemble.purchaseTickets{ value: totalCost }(eventId, 0, quantity, platform, platformFeeBps);

        // Calculate expected platform fee
        uint256 expectedPlatformFee = (totalCost * platformFeeBps) / 10_000;
        assertEq(assemble.pendingWithdrawals(platform), expectedPlatformFee, "Platform fee calculation incorrect");
        assertEq(assemble.totalReferralFees(platform), expectedPlatformFee, "Referral fee tracking incorrect");

        // Verify platform can claim fees
        if (expectedPlatformFee > 0) {
            vm.prank(platform);
            assemble.claimFunds();
            assertEq(platform.balance, expectedPlatformFee, "Platform should receive correct fee amount");
        }
    }

    function testFuzz_PlatformFeeTipping(uint256 tipAmount, uint256 platformFeeBps) public {
        tipAmount = bound(tipAmount, 0.01 ether, 10 ether);
        platformFeeBps = bound(platformFeeBps, 0, 500); // 0-5% max platform fee

        uint256 eventId = _createFuzzEvent(0.1 ether, 100);
        address platform = makeAddr("tipPlatform");

        vm.deal(charlie, tipAmount + 1 ether);

        vm.prank(charlie);
        assemble.tipEvent{ value: tipAmount }(eventId, platform, platformFeeBps);

        // Calculate expected platform fee
        uint256 expectedPlatformFee = (tipAmount * platformFeeBps) / 10_000;
        assertEq(assemble.pendingWithdrawals(platform), expectedPlatformFee, "Platform fee from tip incorrect");
        assertEq(assemble.totalReferralFees(platform), expectedPlatformFee, "Referral fee from tip tracking incorrect");
    }

    function testFuzz_PlatformFeeValidation(uint256 platformFeeBps, bool useZeroReferrer) public {
        platformFeeBps = bound(platformFeeBps, 501, 10_000); // Above max platform fee
        uint256 eventId = _createFuzzEvent(0.1 ether, 100);

        vm.deal(bob, 1 ether);

        address referrer = useZeroReferrer ? address(0) : makeAddr("referrer");

        // Should revert with fee too high
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("PlatformHigh()"));
        assemble.purchaseTickets{value: 0.1 ether}(eventId, 0, 1, referrer, 501);
    }

    function testFuzz_PlatformFeeEdgeCases(address referrer, uint256 platformFeeBps) public {
        vm.assume(referrer != address(0));
        platformFeeBps = bound(platformFeeBps, 1, 500); // Valid range with non-zero fee

        uint256 eventId = _createFuzzEvent(0.1 ether, 100);
        vm.deal(referrer, 1 ether);

        // Test self-referral prevention
        vm.prank(referrer);
        vm.expectRevert(abi.encodeWithSignature("BadRef()"));
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1, referrer, platformFeeBps);

        // Test zero address with non-zero fee
        vm.prank(referrer);
        vm.expectRevert(abi.encodeWithSignature("BadRef()"));
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1, address(0), platformFeeBps);
    }

    function testFuzz_MultiplePlatformInteractions(
        uint256 platform1Fee,
        uint256 platform2Fee,
        uint256 numTransactions
    )
        public
    {
        platform1Fee = bound(platform1Fee, 50, 250); // 0.5-2.5%
        platform2Fee = bound(platform2Fee, 100, 300); // 1-3%
        numTransactions = bound(numTransactions, 1, 5);

        uint256 eventId = _createFuzzEvent(0.1 ether, 100);
        address platform1 = makeAddr("platform1");
        address platform2 = makeAddr("platform2");

        uint256 expectedPlatform1Total = 0;
        uint256 expectedPlatform2Total = 0;

        for (uint256 i = 0; i < numTransactions;) {
            address buyer = address(uint160(1000 + i));
            vm.deal(buyer, 1 ether);

            // Alternate between platforms
            if (i % 2 == 0) {
                vm.prank(buyer);
                assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1, platform1, platform1Fee);
                expectedPlatform1Total += (0.1 ether * platform1Fee) / 10_000;
            } else {
                vm.prank(buyer);
                assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1, platform2, platform2Fee);
                expectedPlatform2Total += (0.1 ether * platform2Fee) / 10_000;
            }

            unchecked {
                ++i;
            }
        }

        // Verify total fees for each platform
        assertEq(assemble.totalReferralFees(platform1), expectedPlatform1Total, "Platform 1 total fees incorrect");
        assertEq(assemble.totalReferralFees(platform2), expectedPlatform2Total, "Platform 2 total fees incorrect");
        assertEq(
            assemble.pendingWithdrawals(platform1), expectedPlatform1Total, "Platform 1 pending withdrawal incorrect"
        );
        assertEq(
            assemble.pendingWithdrawals(platform2), expectedPlatform2Total, "Platform 2 pending withdrawal incorrect"
        );
    }

    function testFuzz_PlatformFeeWithProtocolFee(
        uint256 amount,
        uint256 platformFeeBps,
        uint256 protocolFeeBps
    )
        public
    {
        amount = bound(amount, 0.01 ether, 5 ether);
        platformFeeBps = bound(platformFeeBps, 0, 500); // 0-5%
        protocolFeeBps = bound(protocolFeeBps, 0, 1000); // 0-10%

        // Set protocol fee
        vm.prank(feeTo);
        assemble.setProtocolFee(protocolFeeBps);

        uint256 eventId = _createFuzzEvent(amount, 100);
        address platform = makeAddr("platformFee");

        vm.deal(bob, amount + 1 ether);

        vm.prank(bob);
        assemble.tipEvent{ value: amount }(eventId, platform, platformFeeBps);

        // Calculate expected fees in correct order
        uint256 expectedPlatformFee = (amount * platformFeeBps) / 10_000;
        uint256 remainingAfterPlatform = amount - expectedPlatformFee;
        uint256 expectedProtocolFee = (remainingAfterPlatform * protocolFeeBps) / 10_000;

        assertEq(assemble.pendingWithdrawals(platform), expectedPlatformFee, "Platform fee incorrect");
        assertEq(assemble.pendingWithdrawals(feeTo), expectedProtocolFee, "Protocol fee incorrect");

        // Verify total fees don't exceed original amount
        uint256 totalFees = expectedPlatformFee + expectedProtocolFee;
        assertTrue(totalFees <= amount, "Total fees exceed original amount");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createFuzzEvent(uint256 price, uint256 capacity) internal returns (uint256 eventId) {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 endTime = startTime + 1 days;
        
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Another Fuzz Event",
            description: "Second fuzz event",
            imageUri: "QmFuzzTestImage2",
            startTime: startTime,
            endTime: endTime,
            capacity: capacity,
            latitude: 377826000, // SF: 37.7826 * 1e7
            longitude: -1224241000, // SF: -122.4241 * 1e7
            venueName: "Another Fuzz Venue",
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
        splits[0] = Assemble.PaymentSplit(alice, 10_000);

        vm.prank(alice);
        return assemble.createEvent(params, tiers, splits);
    }
}
