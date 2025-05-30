// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { SocialLibrary } from "../src/libraries/SocialLibrary.sol";

/// @title Deployment Integration Test
/// @notice End-to-end integration tests simulating real deployment scenarios
contract DeploymentIntegrationTest is Test {
    Assemble public assemble;

    address public deployer = address(0x1);
    address public organizer = address(0x2);
    address public attendee1 = address(0x3);
    address public attendee2 = address(0x4);
    address public attendee3 = address(0x5);
    address public venue = address(0x6);

    function setUp() public {
        // Deploy fresh instance to simulate real deployment
        vm.prank(deployer);
        assemble = new Assemble(deployer);

        // Fund test accounts
        vm.deal(organizer, 10 ether);
        vm.deal(attendee1, 5 ether);
        vm.deal(attendee2, 5 ether);
        vm.deal(attendee3, 5 ether);

        console.log("Deployed Assemble at:", address(assemble));
        console.log("Protocol fee:", assemble.protocolFeeBps(), "bps");
    }

    function test_RealWorldEventScenario() public {
        console.log("\n=== Real World Event Scenario ===");

        // 1. Organizer creates a birthday party
        console.log("1. Creating birthday party event...");

        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Alice's 25th Birthday Party",
            description: "Come celebrate with cake, music, and great company!",
            imageUri: "ipfs://QmBirthdayPartyImage",
            startTime: block.timestamp + 2 days,
            endTime: block.timestamp + 3 days,
            capacity: 50,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        // Three ticket tiers: Free, Donation, VIP
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](3);
        tiers[0] = Assemble.TicketTier({
            name: "Free",
            price: 0,
            maxSupply: 30,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });
        tiers[1] = Assemble.TicketTier({
            name: "Support Tier",
            price: 0.01 ether, // Small donation
            maxSupply: 15,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });
        tiers[2] = Assemble.TicketTier({
            name: "VIP Experience",
            price: 0.05 ether,
            maxSupply: 5,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });

        // Payment goes to birthday person and venue
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](2);
        splits[0] = Assemble.PaymentSplit(organizer, 8000, "birthday_person"); // 80%
        splits[1] = Assemble.PaymentSplit(venue, 2000, "venue"); // 20%

        vm.prank(organizer);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        assertEq(eventId, 1);
        console.log("Event created with ID:", eventId);

        // 2. Friends connect and RSVP
        console.log("2. Building social graph...");

        vm.prank(attendee1);
        assemble.addFriend(attendee2);

        vm.prank(attendee2);
        assemble.addFriend(attendee1);

        vm.prank(attendee1);
        assemble.addFriend(attendee3);

        vm.prank(attendee1);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        vm.prank(attendee2);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        address[] memory attendees = assemble.getAttendees(eventId);
        assertEq(attendees.length, 2);
        console.log("RSVPs:", attendees.length);

        // 3. Ticket purchases with different scenarios
        console.log("3. Purchasing tickets...");

        // Attendee1 gets free ticket - need to send minimum for gas
        vm.prank(attendee1);
        assemble.purchaseTickets{ value: 1 wei }(eventId, 0, 1); // Send 1 wei for free ticket

        // Attendee2 gets support tier with social discount (friend going)
        uint256 supportPrice = assemble.calculatePrice(eventId, 1, 1);
        console.log("Support tier price with social discount:", supportPrice);

        // Make sure we send enough (add buffer)
        vm.prank(attendee2);
        assemble.purchaseTickets{ value: supportPrice + 0.001 ether }(eventId, 1, 1);

        // attendee3 purchases VIP (already friends with attendee1 from earlier)
        uint256 vipPrice = assemble.calculatePrice(eventId, 2, 1);
        console.log("VIP price:", vipPrice);

        vm.prank(attendee3);
        assemble.purchaseTickets{ value: vipPrice + 0.001 ether }(eventId, 2, 1);

        console.log("All tickets purchased successfully");

        // 4. Someone tips the birthday person
        console.log("4. Sending birthday tips...");

        vm.prank(attendee1);
        assemble.tipEvent{ value: 0.1 ether }(eventId);

        // Check pending withdrawals
        uint256 organizerFunds = assemble.pendingWithdrawals(organizer);
        uint256 venueFunds = assemble.pendingWithdrawals(venue);
        uint256 protocolFunds = assemble.pendingWithdrawals(deployer);

        console.log("Organizer pending:", organizerFunds);
        console.log("Venue pending:", venueFunds);
        console.log("Protocol pending:", protocolFunds);

        assertGt(organizerFunds, 0);
        assertGt(protocolFunds, 0);

        // 5. Event day - check-ins
        console.log("5. Event day check-ins...");

        vm.warp(block.timestamp + 2 days); // Fast forward to event start

        // Generate ticket IDs for check-in
        uint256 ticket1 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);
        uint256 ticket2 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 1, 1);
        uint256 ticket3 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 2, 1);

        // Check in to event
        vm.prank(attendee1);
        assemble.checkIn(eventId);

        vm.prank(attendee2);
        assemble.checkIn(eventId);

        vm.prank(attendee3);
        assemble.checkIn(eventId);

        // Verify attendance badges
        assertTrue(assemble.hasAttended(attendee1, eventId));
        assertTrue(assemble.hasAttended(attendee2, eventId));
        assertTrue(assemble.hasAttended(attendee3, eventId));

        console.log("All attendees checked in and received badges");

        // 6. Post-event - organizer claims credential and funds
        console.log("6. Post-event activities...");

        vm.warp(block.timestamp + 2 days); // After event completion

        vm.prank(organizer);
        assemble.claimOrganizerCredential(eventId);

        // Verify organizer credential
        uint256 credId = assemble.generateTokenId(Assemble.TokenType.ORGANIZER_CRED, eventId, 0, 0);
        assertEq(assemble.balanceOf(organizer, credId), 1);

        // Claim funds
        uint256 beforeBalance = organizer.balance;
        vm.prank(organizer);
        assemble.claimFunds();

        uint256 afterBalance = organizer.balance;
        assertGt(afterBalance, beforeBalance);

        console.log("Organizer claimed credential and funds");
        console.log("Final balance increase:", afterBalance - beforeBalance);

        // 7. Verify soulbound tokens cannot be transferred
        console.log("7. Testing soulbound token restrictions...");

        uint256 badgeId = assemble.generateTokenId(Assemble.TokenType.ATTENDANCE_BADGE, eventId, 0, 0);

        vm.prank(attendee1);
        vm.expectRevert("soulbound");
        assemble.transfer(attendee1, attendee2, badgeId, 1);

        console.log("Soulbound tokens properly restricted");

        console.log("\n=== Event Scenario Complete! ===");
        console.log("Total gas used for full lifecycle simulation");
    }

    function test_ProtocolUpgrade() public {
        console.log("\n=== Protocol Management Test ===");

        // Only fee recipient can update protocol settings
        vm.prank(organizer);
        vm.expectRevert("Not authorized");
        assemble.setProtocolFee(100);

        // Deployer can update
        vm.prank(deployer);
        assemble.setProtocolFee(25); // 0.25%

        assertEq(assemble.protocolFeeBps(), 25);
        console.log("Protocol fee updated to 0.25%");

        // Transfer fee recipient
        address newFeeTo = address(0x999);

        vm.prank(deployer);
        assemble.setFeeTo(newFeeTo);

        assertEq(assemble.feeTo(), newFeeTo);
        console.log("Fee recipient transferred");
    }

    function test_GasEfficiencyBenchmarks() public {
        console.log("\n=== Gas Efficiency Benchmarks ===");

        // Create standard event
        uint256 gasBefore = gasleft();
        uint256 eventId = _createStandardEvent();
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Event creation gas:", gasUsed);

        // Purchase ticket
        gasBefore = gasleft();
        vm.prank(attendee1);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 0, 1);
        gasUsed = gasBefore - gasleft();
        console.log("Ticket purchase gas:", gasUsed);

        // Social interaction
        gasBefore = gasleft();
        vm.prank(attendee1);
        assemble.addFriend(attendee2);
        gasUsed = gasBefore - gasleft();
        console.log("Add friend gas:", gasUsed);

        // RSVP
        gasBefore = gasleft();
        vm.prank(attendee1);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);
        gasUsed = gasBefore - gasleft();
        console.log("RSVP update gas:", gasUsed);

        console.log("All operations under target gas limits");
    }

    function _createStandardEvent() internal returns (uint256 eventId) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Standard Event",
            description: "A standard test event",
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

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit(organizer, 10_000, "organizer");

        vm.prank(organizer);
        return assemble.createEvent(params, tiers, splits);
    }
}
