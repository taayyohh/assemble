// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { SocialLibrary } from "../src/libraries/SocialLibrary.sol";

/// @title Private Event Tests
/// @notice Test suite for invite-only private events
contract PrivateEventTests is Test {
    Assemble public assemble;

    address public feeTo = makeAddr("feeTo");
    address public organizer = makeAddr("organizer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public unauthorized = makeAddr("unauthorized");

    uint256 public privateEventId;

    function setUp() public {
        assemble = new Assemble(feeTo);

        // Fund accounts
        vm.deal(organizer, 10 ether);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        vm.deal(unauthorized, 10 ether);

        // Create a private event
        privateEventId = _createPrivateEvent();
    }

    /*//////////////////////////////////////////////////////////////
                        INVITE SYSTEM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateInviteOnlyEvent() public {
        // Verify event was created with correct visibility
        (,,,,,, uint8 visibility,,,,) = assemble.events(privateEventId);
        assertEq(visibility, uint8(Assemble.EventVisibility.INVITE_ONLY));
        assertEq(assemble.eventOrganizers(privateEventId), organizer);
    }

    function test_InviteUsers() public {
        address[] memory invitees = new address[](2);
        invitees[0] = alice;
        invitees[1] = bob;

        vm.prank(organizer);
        assemble.inviteToEvent(privateEventId, invitees);

        // Verify invitations using eventInvites mapping directly
        assertTrue(assemble.eventInvites(privateEventId, alice), "Alice should be invited");
        assertTrue(assemble.eventInvites(privateEventId, bob), "Bob should be invited");
        assertFalse(assemble.eventInvites(privateEventId, charlie), "Charlie should not be invited");
        assertFalse(assemble.eventInvites(privateEventId, unauthorized), "Unauthorized should not be invited");
    }

    function test_OnlyOrganizerCanInvite() public {
        address[] memory invitees = new address[](1);
        invitees[0] = alice;

        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSignature("NotAuth()"));
        assemble.inviteToEvent(privateEventId, invitees);
    }

    function test_CannotInviteToPublicEvent() public {
        // Create public event
        uint256 publicEventId = _createPublicEvent();

        address[] memory invitees = new address[](1);
        invitees[0] = alice;

        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSignature("SocialError()"));
        assemble.inviteToEvent(publicEventId, invitees);
    }

    function test_CannotInviteAlreadyInvited() public {
        address[] memory invitees = new address[](1);
        invitees[0] = alice;

        vm.prank(organizer);
        assemble.inviteToEvent(privateEventId, invitees);

        // Try to invite again
        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSignature("SocialError()"));
        assemble.inviteToEvent(privateEventId, invitees);
    }

    /*//////////////////////////////////////////////////////////////
                        TICKET PURCHASE ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_InvitedUserCanPurchaseTickets() public {
        // Invite Alice
        address[] memory invitees = new address[](1);
        invitees[0] = alice;

        vm.prank(organizer);
        assemble.inviteToEvent(privateEventId, invitees);

        // Alice can purchase tickets
        uint256 ticketPrice = 0.1 ether;
        vm.prank(alice);
        assemble.purchaseTickets{ value: ticketPrice }(privateEventId, 0, 1);

        // Verify purchase successful
        uint256 tokenId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, privateEventId, 0, 1);
        assertEq(assemble.balanceOf(alice, tokenId), 1);
    }

    function test_NonInvitedUserCannotPurchaseTickets() public {
        // Try to purchase without invitation
        uint256 ticketPrice = 0.1 ether;
        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSignature("SocialError()"));
        assemble.purchaseTickets{ value: ticketPrice }(privateEventId, 0, 1);
    }

    function test_PublicEventAllowsAnyPurchase() public {
        uint256 publicEventId = _createPublicEvent();

        // Anyone can purchase from public event
        uint256 ticketPrice = 0.1 ether;
        vm.prank(unauthorized);
        assemble.purchaseTickets{ value: ticketPrice }(publicEventId, 0, 1);

        uint256 tokenId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, publicEventId, 0, 1);
        assertEq(assemble.balanceOf(unauthorized, tokenId), 1);
    }

    /*//////////////////////////////////////////////////////////////
                        REAL-WORLD SCENARIOS
    //////////////////////////////////////////////////////////////*/

    function test_ExclusiveArtShow() public {
        console.log("\n=== Exclusive Art Gallery Opening ===");
        console.log("Private art show with curated guest list");

        // Create exclusive art show
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Exclusive Art Gallery Opening",
            description: "Private viewing of contemporary art collection",
            imageUri: "QmArtGalleryImage",
            startTime: block.timestamp + 14 days,
            endTime: block.timestamp + 14 days + 3 hours,
            capacity: 50,
            latitude: 407589000, // NYC: 40.7589 * 1e7
            longitude: -739929000, // NYC: -73.9929 * 1e7
            venueName: "Private Art Gallery",
            visibility: Assemble.EventVisibility.INVITE_ONLY
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](2);
        tiers[0] = Assemble.TicketTier({
            name: "VIP Collector Access",
            price: 0.2 ether, // $300 exclusive access
            maxSupply: 20,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: false // Non-transferrable exclusive access
         });
        tiers[1] = Assemble.TicketTier({
            name: "Artist & Curator Invite",
            price: 0, // Free for artists and curators
            maxSupply: 30,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: false
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](2);
        splits[0] = Assemble.PaymentSplit(organizer, 6000); // 60%
        splits[1] = Assemble.PaymentSplit(alice, 4000); // 40%

        vm.prank(organizer);
        uint256 artShowId = assemble.createEvent(params, tiers, splits);

        // Curate exclusive guest list
        address collector1 = makeAddr("collector1");
        address collector2 = makeAddr("collector2");
        address artist = makeAddr("artist");
        address curator = makeAddr("curator");

        vm.deal(collector1, 1 ether);
        vm.deal(collector2, 1 ether);

        address[] memory vipInvites = new address[](4);
        vipInvites[0] = collector1;
        vipInvites[1] = collector2;
        vipInvites[2] = artist;
        vipInvites[3] = curator;

        vm.prank(organizer);
        assemble.inviteToEvent(artShowId, vipInvites);

        console.log("Art show created with exclusive guest list");

        // VIP collector purchases premium access
        vm.prank(collector1);
        assemble.purchaseTickets{ value: 0.2 ether }(artShowId, 0, 1);

        // Artist gets free access
        vm.prank(artist);
        assemble.purchaseTickets{ value: 0 }(artShowId, 1, 1);

        console.log("Exclusive purchases completed successfully");

        // Verify exclusivity - random person cannot attend
        address randomPerson = makeAddr("randomPerson");
        vm.deal(randomPerson, 1 ether);

        vm.prank(randomPerson);
        vm.expectRevert(abi.encodeWithSignature("SocialError()"));
        assemble.purchaseTickets{ value: 0.2 ether }(artShowId, 0, 1);

        console.log("Exclusivity maintained - uninvited users blocked");
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createPrivateEvent() internal returns (uint256 eventId) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Private Birthday Party",
            description: "Exclusive birthday celebration for close friends and family",
            imageUri: "QmPrivateBirthdayImage",
            startTime: block.timestamp + 7 days,
            endTime: block.timestamp + 7 days + 4 hours,
            capacity: 30,
            latitude: 404052000, // NYC: 40.4052 * 1e7
            longitude: -739979000, // NYC: -73.9979 * 1e7
            venueName: "Private Residence",
            visibility: Assemble.EventVisibility.INVITE_ONLY
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Private Access",
            price: 0.1 ether,
            maxSupply: 50,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: false
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit(organizer, 10_000);

        vm.prank(organizer);
        return assemble.createEvent(params, tiers, splits);
    }

    function _createPublicEvent() internal returns (uint256 eventId) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Corporate Board Meeting",
            description: "Quarterly board meeting for company stakeholders",
            imageUri: "QmBoardMeetingImage",
            startTime: block.timestamp + 21 days,
            endTime: block.timestamp + 21 days + 2 hours,
            capacity: 15,
            latitude: 407614000, // NYC: 40.7614 * 1e7
            longitude: -739960000, // NYC: -73.9960 * 1e7
            venueName: "Corporate Boardroom",
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "General Access",
            price: 0.1 ether,
            maxSupply: 100,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit(organizer, 10_000);

        vm.prank(organizer);
        return assemble.createEvent(params, tiers, splits);
    }
}
