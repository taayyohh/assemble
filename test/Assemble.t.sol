// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { SocialLibrary } from "../src/libraries/SocialLibrary.sol";

contract AssembleTest is Test {
    Assemble public assemble;

    address public feeTo = makeAddr("feeTo");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        assemble = new Assemble(feeTo);
    }

    function test_Initialize() public {
        assertEq(assemble.feeTo(), feeTo);
        assertEq(assemble.protocolFeeBps(), 50);
        assertEq(assemble.nextEventId(), 1);
    }

    function test_CreateEvent() public {
        // Create event parameters
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Test Event",
            description: "A test event for validation",
            imageUri: "ipfs://test-image",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 100,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        // Create ticket tiers
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](2);
        tiers[0] = Assemble.TicketTier({
            name: "Early Bird",
            price: 0.1 ether,
            maxSupply: 50,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });
        tiers[1] = Assemble.TicketTier({
            name: "General",
            price: 0.2 ether,
            maxSupply: 50,
            sold: 0,
            startSaleTime: block.timestamp + 1 hours,
            endSaleTime: block.timestamp + 2 days,
            transferrable: true
        });

        // Create payment splits
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](2);
        splits[0] = Assemble.PaymentSplit({
            recipient: alice,
            basisPoints: 7000, // 70%
            role: "organizer"
        });
        splits[1] = Assemble.PaymentSplit({
            recipient: bob,
            basisPoints: 3000, // 30%
            role: "venue"
        });

        // Create event as alice
        vm.prank(alice);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        // Verify event was created
        assertEq(eventId, 1);
        assertEq(assemble.nextEventId(), 2);
        assertEq(assemble.eventOrganizers(eventId), alice);

        // Check event data
        (uint128 basePrice, uint64 startTime, uint32 capacity, uint16 venueId, uint8 visibility, uint8 flags) =
            assemble.events(eventId);

        assertEq(basePrice, 0.1 ether);
        assertEq(startTime, block.timestamp + 1 days);
        assertEq(capacity, 100);
        assertEq(venueId, 1);
        assertEq(visibility, uint8(Assemble.EventVisibility.PUBLIC));

        // Check ticket tiers
        (
            string memory tierName,
            uint256 price,
            uint256 maxSupply,
            uint256 sold,
            uint256 startSaleTime,
            uint256 endSaleTime,
            bool transferrable
        ) = assemble.ticketTiers(eventId, 0);

        assertEq(tierName, "Early Bird");
        assertEq(price, 0.1 ether);
        assertEq(maxSupply, 50);
        assertEq(sold, 0);
        assertEq(transferrable, true);
    }

    function test_ValidatePaymentSplits() public {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Test Event",
            description: "Test",
            imageUri: "ipfs://test",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 100,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "General",
            price: 0.1 ether,
            maxSupply: 100,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });

        // Test invalid splits (doesn't total 100%)
        Assemble.PaymentSplit[] memory invalidSplits = new Assemble.PaymentSplit[](2);
        invalidSplits[0] = Assemble.PaymentSplit(alice, 6000, "organizer"); // 60%
        invalidSplits[1] = Assemble.PaymentSplit(bob, 3000, "venue"); // 30% - total 90%

        vm.prank(alice);
        vm.expectRevert("!100%");
        assemble.createEvent(params, tiers, invalidSplits);

        // Test valid splits (totals 100%)
        Assemble.PaymentSplit[] memory validSplits = new Assemble.PaymentSplit[](2);
        validSplits[0] = Assemble.PaymentSplit(alice, 6000, "organizer"); // 60%
        validSplits[1] = Assemble.PaymentSplit(bob, 4000, "venue"); // 40% - total 100%

        vm.prank(alice);
        uint256 eventId = assemble.createEvent(params, tiers, validSplits);
        assertEq(eventId, 1);
    }

    function test_EventCreationValidation() public {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Test Event",
            description: "Test",
            imageUri: "ipfs://test",
            startTime: block.timestamp + 2 days, // Start time after end time - should fail
            endTime: block.timestamp + 1 days, // End time before start time
            capacity: 100,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "General",
            price: 0.1 ether,
            maxSupply: 100,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit(alice, 10_000, "organizer");

        vm.prank(alice);
        vm.expectRevert("Invalid end time");
        assemble.createEvent(params, tiers, splits);
    }

    function test_TokenIdGeneration() public {
        uint256 tokenId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, 1, 0, 1);

        // Verify token belongs to event 1
        assertTrue(assemble.isValidTicketForEvent(tokenId, 1));

        console.log("Generated token ID:", tokenId);
        console.log("Event ID from token:", (tokenId >> 184) & 0xFFFFFFFFFFFFFFFF);
    }

    /*//////////////////////////////////////////////////////////////
                        TICKET PURCHASING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PurchaseTickets() public {
        uint256 eventId = _createSampleEvent();

        // Purchase tickets as Bob
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);

        // Check ticket balance
        uint256 tokenId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);
        assertEq(assemble.balanceOf(bob, tokenId), 1);

        // Check tier sold count updated
        (,,, uint256 sold,,,) = assemble.ticketTiers(eventId, 0);
        assertEq(sold, 1);

        // Check payment distribution
        uint256 protocolFee = (0.1 ether * 50) / 10_000; // 0.5%
        uint256 netAmount = 0.1 ether - protocolFee;
        uint256 aliceShare = (netAmount * 7000) / 10_000; // 70%
        uint256 bobShare = (netAmount * 3000) / 10_000; // 30%

        assertEq(assemble.pendingWithdrawals(feeTo), protocolFee);
        assertEq(assemble.pendingWithdrawals(alice), aliceShare);
        assertEq(assemble.pendingWithdrawals(bob), bobShare);
    }

    function test_PurchaseTicketsWithSocialDiscount() public {
        uint256 eventId = _createSampleEvent();

        // Alice and Bob become friends
        vm.prank(alice);
        assemble.addFriend(bob);

        vm.prank(bob);
        assemble.addFriend(alice);

        // Alice RSVPs as going
        vm.prank(alice);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        // Calculate price for Bob (no social discount anymore)
        uint256 price = assemble.calculatePrice(eventId, 0, 1);

        // Purchase ticket
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        assemble.purchaseTickets{ value: price }(eventId, 0, 1);

        // Check ticket was minted
        uint256 tokenId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);
        assertEq(assemble.balanceOf(bob, tokenId), 1);
    }

    function test_ClaimFunds() public {
        uint256 eventId = _createSampleEvent();

        // Purchase tickets
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);

        uint256 initialBalance = alice.balance;
        uint256 pendingAmount = assemble.pendingWithdrawals(alice);

        // Alice claims her funds
        vm.prank(alice);
        assemble.claimFunds();

        assertEq(alice.balance, initialBalance + pendingAmount);
        assertEq(assemble.pendingWithdrawals(alice), 0);
    }

    function test_TipEvent() public {
        uint256 eventId = _createSampleEvent();

        // Tip the event
        vm.deal(charlie, 1 ether);
        vm.prank(charlie);
        assemble.tipEvent{ value: 0.5 ether }(eventId);

        // Check tip was distributed according to splits
        uint256 protocolFee = (0.5 ether * 50) / 10_000; // 0.5%
        uint256 netAmount = 0.5 ether - protocolFee;
        uint256 aliceShare = (netAmount * 7000) / 10_000; // 70%
        uint256 bobShare = (netAmount * 3000) / 10_000; // 30%

        assertEq(assemble.pendingWithdrawals(feeTo), protocolFee);
        assertEq(assemble.pendingWithdrawals(alice), aliceShare);
        assertEq(assemble.pendingWithdrawals(bob), bobShare);
    }

    /*//////////////////////////////////////////////////////////////
                        SOCIAL FEATURES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AddRemoveFriend() public {
        // Add friend
        vm.prank(alice);
        assemble.addFriend(bob);

        assertTrue(assemble.isFriend(alice, bob));

        address[] memory aliceFriends = assemble.getFriends(alice);
        assertEq(aliceFriends.length, 1);
        assertEq(aliceFriends[0], bob);

        // Remove friend
        vm.prank(alice);
        assemble.removeFriend(bob);

        assertFalse(assemble.isFriend(alice, bob));

        aliceFriends = assemble.getFriends(alice);
        assertEq(aliceFriends.length, 0);
    }

    function test_UpdateRSVP() public {
        uint256 eventId = _createSampleEvent();

        // RSVP as going
        vm.prank(alice);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        assertEq(uint8(assemble.rsvps(eventId, alice)), uint8(SocialLibrary.RSVPStatus.GOING));

        address[] memory attendees = assemble.getAttendees(eventId);
        assertEq(attendees.length, 1);
        assertEq(attendees[0], alice);

        // Change to not going
        vm.prank(alice);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.NOT_GOING);

        attendees = assemble.getAttendees(eventId);
        assertEq(attendees.length, 0);
    }

    function test_InviteFriends() public {
        uint256 eventId = _createSampleEvent();

        // Alice and Bob become friends
        vm.prank(alice);
        assemble.addFriend(bob);

        // Alice invites Bob
        address[] memory invitees = new address[](1);
        invitees[0] = bob;

        vm.prank(alice);
        assemble.inviteFriends(eventId, invitees, "Come to my party!");

        // Should emit InvitationSent event (tested via successful execution)
    }

    function test_GetFriendsAttending() public {
        uint256 eventId = _createSampleEvent();

        // Set up friendships
        vm.prank(alice);
        assemble.addFriend(bob);

        vm.prank(alice);
        assemble.addFriend(charlie);

        // Bob RSVPs as going
        vm.prank(bob);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        // Charlie RSVPs as interested (not going)
        vm.prank(charlie);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.INTERESTED);

        address[] memory friendsGoing = assemble.getFriendsAttending(eventId, alice);
        assertEq(friendsGoing.length, 1);
        assertEq(friendsGoing[0], bob);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC-6909 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ERC6909Transfer() public {
        uint256 eventId = _createSampleEvent();

        // Purchase ticket
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);

        uint256 tokenId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);

        // Transfer ticket to Bob
        vm.prank(alice);
        assemble.transfer(alice, bob, tokenId, 1);

        assertEq(assemble.balanceOf(alice, tokenId), 0);
        assertEq(assemble.balanceOf(bob, tokenId), 1);
    }

    function test_ERC6909Approve() public {
        uint256 eventId = _createSampleEvent();

        // Purchase ticket
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);

        uint256 tokenId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);

        // Approve Bob to transfer
        vm.prank(alice);
        assemble.approve(bob, tokenId, 1);

        assertEq(assemble.allowance(alice, bob, tokenId), 1);

        // Bob transfers on behalf of Alice
        vm.prank(bob);
        assemble.transfer(alice, charlie, tokenId, 1);

        assertEq(assemble.balanceOf(alice, tokenId), 0);
        assertEq(assemble.balanceOf(charlie, tokenId), 1);
        assertEq(assemble.allowance(alice, bob, tokenId), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetFeeTo() public {
        address newFeeTo = makeAddr("newFeeTo");

        vm.prank(feeTo);
        assemble.setFeeTo(newFeeTo);

        assertEq(assemble.feeTo(), newFeeTo);
    }

    function test_SetProtocolFee() public {
        vm.prank(feeTo);
        assemble.setProtocolFee(100); // 1%

        assertEq(assemble.protocolFeeBps(), 100);
    }

    function test_SetProtocolFeeRevertsTooHigh() public {
        vm.prank(feeTo);
        vm.expectRevert("too high");
        assemble.setProtocolFee(1100); // 11% - above MAX_PROTOCOL_FEE
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createSampleEvent() internal returns (uint256 eventId) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Test Event",
            description: "A test event",
            imageUri: "ipfs://test",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 100,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "General",
            price: 0.1 ether,
            maxSupply: 100,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](2);
        splits[0] = Assemble.PaymentSplit(alice, 7000, "organizer"); // 70%
        splits[1] = Assemble.PaymentSplit(bob, 3000, "venue"); // 30%

        vm.prank(alice);
        return assemble.createEvent(params, tiers, splits);
    }

    /*//////////////////////////////////////////////////////////////
                        ATTENDANCE & BADGES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CheckInAndAttendanceBadge() public {
        uint256 eventId = _createSampleEvent();

        // Purchase ticket first
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);

        uint256 ticketId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);

        // Fast forward to event start time
        vm.warp(block.timestamp + 1 days);

        // Check in to event
        vm.prank(bob);
        assemble.checkIn(eventId, ticketId);

        // Verify attendance badge was minted
        uint256 badgeId = assemble.generateTokenId(Assemble.TokenType.ATTENDANCE_BADGE, eventId, 0, 0);
        assertEq(assemble.balanceOf(bob, badgeId), 1);

        // Verify hasAttended returns true
        assertTrue(assemble.hasAttended(bob, eventId));
    }

    function test_CheckInFailsWithoutTicket() public {
        uint256 eventId = _createSampleEvent();

        uint256 fakeTicketId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);

        vm.warp(block.timestamp + 1 days);

        vm.prank(bob);
        vm.expectRevert("!ticket");
        assemble.checkIn(eventId, fakeTicketId);
    }

    function test_CheckInFailsBeforeEventStart() public {
        uint256 eventId = _createSampleEvent();

        // Purchase ticket
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);

        uint256 ticketId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);

        // Try to check in before event starts
        vm.prank(bob);
        vm.expectRevert("!started");
        assemble.checkIn(eventId, ticketId);
    }

    function test_OrganizerCredential() public {
        uint256 eventId = _createSampleEvent();

        // Fast forward past event completion (start + 1 day + buffer)
        vm.warp(block.timestamp + 2 days + 1 hours);

        // Alice (organizer) claims credential
        vm.prank(alice);
        assemble.claimOrganizerCredential(eventId);

        // Verify organizer credential was minted
        uint256 credId = assemble.generateTokenId(Assemble.TokenType.ORGANIZER_CRED, eventId, 0, 0);
        assertEq(assemble.balanceOf(alice, credId), 1);
    }

    function test_OrganizerCredentialFailsNotOrganizer() public {
        uint256 eventId = _createSampleEvent();

        vm.warp(block.timestamp + 2 days + 1 hours);

        vm.prank(bob);
        vm.expectRevert("!organizer");
        assemble.claimOrganizerCredential(eventId);
    }

    function test_SoulboundTokensCannotBeTransferred() public {
        uint256 eventId = _createSampleEvent();

        // Purchase and check in
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);

        uint256 ticketId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);

        vm.warp(block.timestamp + 1 days);
        vm.prank(bob);
        assemble.checkIn(eventId, ticketId);

        uint256 badgeId = assemble.generateTokenId(Assemble.TokenType.ATTENDANCE_BADGE, eventId, 0, 0);

        // Try to transfer soulbound badge (should fail)
        vm.prank(bob);
        vm.expectRevert("soulbound");
        assemble.transfer(bob, charlie, badgeId, 1);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FullEventLifecycle() public {
        // 1. Create event
        uint256 eventId = _createSampleEvent();

        // 2. Add friends and RSVP
        vm.prank(alice);
        assemble.addFriend(bob);

        vm.prank(bob);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        // 3. Purchase tickets with social discount
        vm.deal(charlie, 1 ether);
        vm.prank(charlie);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);

        // 4. Check into event
        vm.warp(block.timestamp + 1 days);

        uint256 ticketId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);

        vm.prank(charlie);
        assemble.checkIn(eventId, ticketId);

        // 5. Claim organizer credential after event
        vm.warp(block.timestamp + 1 days + 1 hours);

        vm.prank(alice);
        assemble.claimOrganizerCredential(eventId);

        // 6. Verify final state
        assertTrue(assemble.hasAttended(charlie, eventId));

        uint256 credId = assemble.generateTokenId(Assemble.TokenType.ORGANIZER_CRED, eventId, 0, 0);
        assertEq(assemble.balanceOf(alice, credId), 1);

        // 7. Claim funds
        vm.prank(alice);
        assemble.claimFunds();

        assertEq(assemble.pendingWithdrawals(alice), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    EVENT CANCELLATION & REFUND TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CancelEvent() public {
        uint256 eventId = _createSampleEvent();
        
        // Purchase tickets
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);
        
        // Send tips
        vm.deal(charlie, 1 ether);
        vm.prank(charlie);
        assemble.tipEvent{ value: 0.05 ether }(eventId);
        
        // Cancel event
        vm.prank(alice);
        assemble.cancelEvent(eventId);
        
        assertTrue(assemble.eventCancelled(eventId));
        
        // Check refund amounts
        (uint256 ticketRefund, uint256 tipRefund) = assemble.getRefundAmounts(eventId, bob);
        assertEq(ticketRefund, 0.1 ether);
        assertEq(tipRefund, 0);
        
        (ticketRefund, tipRefund) = assemble.getRefundAmounts(eventId, charlie);
        assertEq(ticketRefund, 0);
        assertEq(tipRefund, 0.05 ether);
    }

    function test_ClaimTicketRefund() public {
        uint256 eventId = _createSampleEvent();
        
        // Purchase tickets
        vm.deal(bob, 1 ether);
        uint256 bobBalanceAfterPurchase = bob.balance - 0.1 ether; // After purchase
        vm.prank(bob);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);
        
        // Cancel event
        vm.prank(alice);
        assemble.cancelEvent(eventId);
        
        // Claim refund
        vm.prank(bob);
        assemble.claimTicketRefund(eventId);
        
        // Check Bob got full refund (should be back to original balance)
        assertEq(bob.balance, 1 ether);
        
        // Check refund amount is now zero
        (uint256 ticketRefund,) = assemble.getRefundAmounts(eventId, bob);
        assertEq(ticketRefund, 0);
    }

    function test_ClaimTipRefund() public {
        uint256 eventId = _createSampleEvent();
        
        // Send tips
        vm.deal(charlie, 1 ether);
        vm.prank(charlie);
        assemble.tipEvent{ value: 0.05 ether }(eventId);
        
        // Cancel event
        vm.prank(alice);
        assemble.cancelEvent(eventId);
        
        // Claim refund
        vm.prank(charlie);
        assemble.claimTipRefund(eventId);
        
        // Check Charlie got full refund (should be back to original balance)
        assertEq(charlie.balance, 1 ether);
        
        // Check refund amount is now zero
        (, uint256 tipRefund) = assemble.getRefundAmounts(eventId, charlie);
        assertEq(tipRefund, 0);
    }

    function test_CannotCancelAfterEventStarts() public {
        uint256 eventId = _createSampleEvent();
        
        // Warp to event start time
        vm.warp(block.timestamp + 1 days);
        
        vm.prank(alice);
        vm.expectRevert("Event already started");
        assemble.cancelEvent(eventId);
    }

    function test_CannotClaimRefundForActivEvent() public {
        uint256 eventId = _createSampleEvent();
        
        // Purchase tickets
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);
        
        // Try to claim refund without cancellation
        vm.prank(bob);
        vm.expectRevert("Event not cancelled");
        assemble.claimTicketRefund(eventId);
    }

    function test_OnlyOrganizerCanCancel() public {
        uint256 eventId = _createSampleEvent();
        
        vm.prank(bob);
        vm.expectRevert("Not event organizer");
        assemble.cancelEvent(eventId);
    }

    function test_EmergencyRefund() public {
        uint256 eventId = _createSampleEvent();
        
        // Purchase tickets
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);
        
        // Cancel event
        vm.prank(alice);
        assemble.cancelEvent(eventId);
        
        // Protocol admin can emergency refund
        address[] memory users = new address[](1);
        users[0] = bob;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0.1 ether;
        
        uint256 bobBalanceBefore = bob.balance;
        
        vm.deal(address(assemble), 1 ether); // Ensure contract has funds
        vm.prank(feeTo);
        assemble.emergencyRefund(eventId, users, amounts);
        
        assertEq(bob.balance, bobBalanceBefore + 0.1 ether);
    }
}
