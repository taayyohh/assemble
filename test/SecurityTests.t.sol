// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { SocialLibrary } from "../src/libraries/SocialLibrary.sol";

/// @title Security Tests for Assemble Protocol
/// @notice Tests for potential security vulnerabilities and attack vectors
contract SecurityTests is Test {
    Assemble public assemble;

    address public feeTo = makeAddr("feeTo");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public attacker = makeAddr("attacker");
    address public victim = makeAddr("victim");

    function setUp() public {
        assemble = new Assemble(feeTo);

        // Fund accounts
        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        vm.deal(attacker, 1000 ether);
        vm.deal(victim, 1000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        ECONOMIC ATTACK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CannotDrainProtocolFunds() public {
        uint256 eventId = _createEvent(0.1 ether, 100);

        // Users purchase tickets, creating protocol revenue
        uint256 price = assemble.calculatePrice(eventId, 0, 5);
        vm.deal(victim, price);
        vm.prank(victim);
        assemble.purchaseTickets{ value: price }(eventId, 0, 5);

        // Attacker tries to claim protocol funds
        uint256 protocolFunds = assemble.pendingWithdrawals(feeTo);
        assertGt(protocolFunds, 0, "Protocol should have funds");

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotFound()"));
        assemble.claimFunds(); // Should fail - attacker has no pending funds

        // Only feeTo can claim protocol funds
        uint256 feeToBalanceBefore = feeTo.balance;
        vm.prank(feeTo);
        assemble.claimFunds();

        assertEq(feeTo.balance, feeToBalanceBefore + protocolFunds);
        assertEq(assemble.pendingWithdrawals(feeTo), 0);
    }

    function test_CannotManipulateRefundAmounts() public {
        uint256 eventId = _createEvent(0.1 ether, 100);

        // Victim purchases tickets
        uint256 price = assemble.calculatePrice(eventId, 0, 2);
        vm.deal(victim, price);
        vm.prank(victim);
        assemble.purchaseTickets{ value: price }(eventId, 0, 2);

        // Event gets cancelled
        vm.prank(bob); // Not organizer
        vm.expectRevert(abi.encodeWithSignature("NotAuth()"));
        assemble.cancelEvent(eventId);

        // Actually cancel the event with organizer
        vm.prank(alice);
        assemble.cancelEvent(eventId);

        // Check victim's refund amount
        uint256 victimRefund = assemble.userTicketPayments(eventId, victim);
        assertEq(victimRefund, price);

        // Attacker cannot claim victim's refund
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotFound()"));
        assemble.claimTicketRefund(eventId);

        // Victim can claim their own refund
        uint256 victimBalanceBefore = victim.balance;
        vm.prank(victim);
        assemble.claimTicketRefund(eventId);

        assertEq(victim.balance, victimBalanceBefore + price);

        (,, uint64 startTime, uint32 capacity, uint64 venueHash, uint16 tierCount, uint8 visibility, uint8 status,,,) = assemble.events(eventId);
        assertTrue(status == 1); // 1 = CANCELLED
    }

    function test_CannotBypassTicketLimits() public {
        // Create event with limited capacity
        uint256 eventId = _createEvent(0.01 ether, 10); // Only 10 tickets

        // Purchase up to capacity
        for (uint256 i = 0; i < 10; i++) {
            address buyer = makeAddr(string(abi.encodePacked("buyer", vm.toString(i))));
            uint256 buyerPrice = assemble.calculatePrice(eventId, 0, 1);
            vm.deal(buyer, buyerPrice);
            vm.prank(buyer);
            assemble.purchaseTickets{ value: buyerPrice }(eventId, 0, 1);
        }

        // Attacker tries to purchase more tickets
        uint256 price = assemble.calculatePrice(eventId, 0, 1);
        vm.deal(attacker, price);
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("BadPayment()"));
        assemble.purchaseTickets{ value: price }(eventId, 0, 1);
    }

    function test_CannotExceedMaxTicketQuantity() public {
        uint256 eventId = _createEvent(0.01 ether, 1000);
        uint256 maxQuantity = assemble.MAX_TICKET_QUANTITY(); // 50

        // Try to purchase more than max in single transaction
        uint256 price = assemble.calculatePrice(eventId, 0, maxQuantity + 1);
        vm.deal(attacker, price);
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("BadPayment()"));
        assemble.purchaseTickets{ value: price }(eventId, 0, maxQuantity + 1);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OnlyOrganizerCanCancelEvent() public {
        uint256 eventId = _createEvent(0.1 ether, 100);

        // Non-organizer cannot cancel
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuth()"));
        assemble.cancelEvent(eventId);

        // Organizer can cancel
        vm.prank(alice);
        assemble.cancelEvent(eventId);

        (,, uint64 startTime, uint32 capacity, uint64 venueHash, uint16 tierCount, uint8 visibility, uint8 status,,,) = assemble.events(eventId);
        assertTrue(status == 1); // 1 = CANCELLED
    }

    function test_OnlyFeeToCanUpdateProtocolSettings() public {
        // Non-feeTo cannot update settings
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuth()"));
        assemble.setProtocolFee(100);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuth()"));
        assemble.setFeeTo(attacker);

        // feeTo can update settings
        vm.prank(feeTo);
        assemble.setProtocolFee(100);
        assertEq(assemble.protocolFeeBps(), 100);

        address newFeeTo = makeAddr("newFeeTo");
        vm.prank(feeTo);
        assemble.setFeeTo(newFeeTo);
        assertEq(assemble.feeTo(), newFeeTo);
    }

    function test_CannotSetExcessiveProtocolFee() public {
        uint256 maxFee = assemble.MAX_PROTOCOL_FEE(); // 1000 bps = 10%

        vm.prank(feeTo);
        vm.expectRevert(abi.encodeWithSignature("BadPayment()"));
        assemble.setProtocolFee(maxFee + 1);

        // Max fee should work
        vm.prank(feeTo);
        assemble.setProtocolFee(maxFee);
        assertEq(assemble.protocolFeeBps(), maxFee);
    }

    /*//////////////////////////////////////////////////////////////
                        PAYMENT MANIPULATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CannotPayLessThanRequired() public {
        uint256 eventId = _createEvent(0.1 ether, 100);
        uint256 requiredPrice = assemble.calculatePrice(eventId, 0, 1);

        // Try to pay less than required
        vm.deal(attacker, requiredPrice - 1 wei);
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("BadPayment()"));
        assemble.purchaseTickets{ value: requiredPrice - 1 wei }(eventId, 0, 1);
    }

    function test_ExcessPaymentIsRefunded() public {
        uint256 eventId = _createEvent(0.1 ether, 100);
        uint256 requiredPrice = assemble.calculatePrice(eventId, 0, 1);
        uint256 excessPayment = requiredPrice + 1 ether;

        vm.deal(attacker, excessPayment);
        uint256 attackerBalanceBefore = attacker.balance;

        vm.prank(attacker);
        assemble.purchaseTickets{ value: excessPayment }(eventId, 0, 1);

        // Should get refund for excess
        uint256 attackerBalanceAfter = attacker.balance;
        assertEq(attackerBalanceAfter, attackerBalanceBefore - requiredPrice);
    }

    /*//////////////////////////////////////////////////////////////
                        REENTRANCY ATTACK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ReentrancyProtectionOnCriticalFunctions() public {
        uint256 eventId = _createEvent(0.1 ether, 100);

        // Purchase ticket to have funds to claim
        uint256 price = assemble.calculatePrice(eventId, 0, 1);
        vm.deal(alice, price);
        vm.prank(alice);
        assemble.purchaseTickets{ value: price }(eventId, 0, 1);

        // Cancel event to enable refunds
        vm.prank(alice);
        assemble.cancelEvent(eventId);

        // Normal refund claim should work
        vm.prank(alice);
        assemble.claimTicketRefund(eventId);

        // Try to claim again (should fail - already claimed)
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotFound()"));
        assemble.claimTicketRefund(eventId);
    }

    /*//////////////////////////////////////////////////////////////
                        FRONT-RUNNING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CannotFrontRunTicketPurchases() public {
        uint256 eventId = _createEvent(0.1 ether, 1); // Only 1 ticket available

        // Two users try to buy the same ticket simultaneously
        uint256 price = assemble.calculatePrice(eventId, 0, 1);

        vm.deal(victim, price);
        vm.deal(attacker, price);

        // First purchase succeeds
        vm.prank(victim);
        assemble.purchaseTickets{ value: price }(eventId, 0, 1);

        // Second purchase fails (no more capacity)
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("BadPayment()"));
        assemble.purchaseTickets{ value: price }(eventId, 0, 1);
    }

    /*//////////////////////////////////////////////////////////////
                        SOULBOUND TOKEN SECURITY
    //////////////////////////////////////////////////////////////*/

    function test_SoulboundTokensCannotBeStolen() public {
        uint256 eventId = _createEvent(0.1 ether, 100);

        // Fast forward to event time and check in
        vm.warp(block.timestamp + 1 days);
        vm.prank(victim);
        assemble.checkIn(eventId);

        uint256 badgeId = assemble.generateTokenId(Assemble.TokenType.ATTENDANCE_BADGE, eventId, 0, 0);
        assertEq(assemble.balanceOf(victim, badgeId), 1);

        // Attacker cannot transfer victim's soulbound token
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuth()"));
        assemble.transfer(victim, attacker, badgeId, 1);

        // Even with approval, soulbound tokens cannot be transferred
        vm.prank(victim);
        assemble.approve(attacker, badgeId, 1);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("SocialError()"));
        assemble.transfer(victim, attacker, badgeId, 1);

        // Victim still has their badge
        assertEq(assemble.balanceOf(victim, badgeId), 1);
        assertEq(assemble.balanceOf(attacker, badgeId), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        SOCIAL GRAPH MANIPULATION
    //////////////////////////////////////////////////////////////*/

    function test_CannotManipulateFriendsList() public {
        // Victim adds legitimate friend
        vm.prank(victim);
        assemble.addFriend(bob);
        assertTrue(assemble.isFriend(victim, bob));

        // Attacker cannot add themselves to victim's friend list
        vm.prank(attacker);
        assemble.addFriend(victim); // This adds victim to attacker's list, not the reverse

        assertFalse(assemble.isFriend(victim, attacker));
        assertTrue(assemble.isFriend(attacker, victim));

        // Attacker cannot remove victim's friends
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("SocialError()"));
        assemble.removeFriend(bob); // Attacker is not friends with bob
    }

    function test_CannotSpamComments() public {
        uint256 eventId = _createEvent(0.1 ether, 100);

        // Post legitimate comment
        vm.prank(victim);
        assemble.postComment(eventId, "Great event!", 0);

        // Try to post overly long comment
        string memory spamContent = string(new bytes(1001)); // Over 1000 char limit
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("BadInput()"));
        assemble.postComment(eventId, spamContent, 0);

        // Try to post empty comment
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("BadInput()"));
        assemble.postComment(eventId, "", 0);
    }

    /*//////////////////////////////////////////////////////////////
                        INPUT VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CannotCreateEventWithInvalidSplits() public {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Invalid Splits Event",
            description: "Testing invalid payment splits",
            imageUri: "ipfs://invalid",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 100,
            latitude: 377826000, // SF: 37.7826 * 1e7
            longitude: -1224241000, // SF: -122.4241 * 1e7
            venueName: "Security Test Venue 2",
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

        // Splits that don't total 100%
        Assemble.PaymentSplit[] memory invalidSplits = new Assemble.PaymentSplit[](2);
        invalidSplits[0] = Assemble.PaymentSplit(alice, 6000); // 60%
        invalidSplits[1] = Assemble.PaymentSplit(bob, 3000); // 30% - total 90%

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("BadPayment()"));
        assemble.createEvent(params, tiers, invalidSplits);

        // Splits with zero recipient
        Assemble.PaymentSplit[] memory zeroSplits = new Assemble.PaymentSplit[](1);
        zeroSplits[0] = Assemble.PaymentSplit(address(0), 10_000);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("BadInput()"));
        assemble.createEvent(params, tiers, zeroSplits);
    }

    function test_CannotCreateEventWithInvalidTiming() public {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Invalid Timing Event",
            description: "Testing invalid event timing",
            imageUri: "ipfs://invalid-timing",
            startTime: block.timestamp - 1, // In the past (just 1 second ago to avoid underflow)
            endTime: block.timestamp + 1 days,
            capacity: 100,
            latitude: 422390000, // Boston: 42.2390 * 1e7
            longitude: -711040000, // Boston: -71.1040 * 1e7
            venueName: "Security Test Venue 3",
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

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit(alice, 10_000);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("BadTiming()"));
        assemble.createEvent(params, tiers, splits);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createEvent(uint256 price, uint256 capacity) internal returns (uint256 eventId) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Security Test Event 1",
            description: "Testing security vulnerabilities",
            imageUri: "QmSecurityTestImage1",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: capacity,
            latitude: 404052000, // NYC: 40.4052 * 1e7
            longitude: -739979000, // NYC: -73.9979 * 1e7
            venueName: "Security Test Venue 1",
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Security Tier",
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
