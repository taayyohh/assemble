// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";

/// @title Wedding Celebration Example
/// @notice Demonstrates wedding events with gift registry and honeymoon fund integration
/// @author @taayyohh
contract WeddingExampleTest is Test {
    Assemble public assemble;

    address public bride = makeAddr("bride");
    address public groom = makeAddr("groom");
    address public venue = makeAddr("venue");
    address public honeymoonFund = makeAddr("honeymoonFund");
    address public guest1 = makeAddr("guest1");
    address public guest2 = makeAddr("guest2");
    address public guest3 = makeAddr("guest3");

    function setUp() public {
        assemble = new Assemble(address(this));

        // Fund wedding guests
        vm.deal(guest1, 3 ether);
        vm.deal(guest2, 3 ether);
        vm.deal(guest3, 3 ether);
    }

    function test_WeddingCelebration() public {
        console.log("\n=== Wedding Celebration Example ===");
        console.log("Private wedding with RSVP system and gift contributions");

        // Create wedding event
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Sarah & Michael's Wedding",
            description: "Join us as we celebrate our love! Your presence is the greatest gift.",
            imageUri: "ipfs://wedding-invitation",
            startTime: block.timestamp + 60 days,
            endTime: block.timestamp + 60 days + 8 hours,
            capacity: 150,
            venueId: 1,
            visibility: Assemble.EventVisibility.INVITE_ONLY
        });

        // Wedding attendance tiers (gifts optional)
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](4);
        tiers[0] = Assemble.TicketTier({
            name: "Wedding Guest",
            price: 0, // Free attendance
            maxSupply: 120,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 45 days,
            transferrable: false // Personal invitation
         });
        tiers[1] = Assemble.TicketTier({
            name: "Gift Contribution - Small",
            price: 0.05 ether, // $75 gift equivalent
            maxSupply: 50,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 45 days,
            transferrable: false
        });
        tiers[2] = Assemble.TicketTier({
            name: "Gift Contribution - Generous",
            price: 0.15 ether, // $225 gift equivalent
            maxSupply: 30,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 45 days,
            transferrable: false
        });
        tiers[3] = Assemble.TicketTier({
            name: "Honeymoon Sponsor",
            price: 0.5 ether, // $750 honeymoon contribution
            maxSupply: 10,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 45 days,
            transferrable: false
        });

        // Wedding gift distribution
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](3);
        splits[0] = Assemble.PaymentSplit(bride, 4000, "bride_gifts"); // 40%
        splits[1] = Assemble.PaymentSplit(groom, 4000, "groom_gifts"); // 40%
        splits[2] = Assemble.PaymentSplit(honeymoonFund, 2000, "honeymoon_trip"); // 20%

        vm.prank(bride);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Wedding invitation sent!");
        console.log("Gift distribution: 40% bride, 40% groom, 20% honeymoon fund");

        // Guests RSVP and contribute gifts
        vm.prank(guest1);
        assemble.purchaseTickets{ value: 0 }(eventId, 0, 2); // +1 guest

        vm.prank(guest1);
        assemble.updateRSVP(eventId, Assemble.RSVPStatus.GOING);

        vm.prank(guest2);
        assemble.purchaseTickets{ value: 0 }(eventId, 0, 1); // Free attendance

        vm.prank(guest2);
        assemble.updateRSVP(eventId, Assemble.RSVPStatus.GOING);

        vm.prank(guest3);
        assemble.purchaseTickets{ value: 0 }(eventId, 0, 1); // Free attendance

        vm.prank(guest3);
        assemble.updateRSVP(eventId, Assemble.RSVPStatus.GOING);

        console.log("Guests RSVPed for the wedding:");
        console.log("  Guest 1: Attending with +1");
        console.log("  Guest 2: Confirmed attendance");
        console.log("  Guest 3: Confirmed attendance");

        // Check attendee list for planning
        address[] memory attendees = assemble.getAttendees(eventId);
        assertEq(attendees.length, 3);
        console.log("Wedding planning: 3 confirmed guests attending");

        // Guests send wedding gifts via tips (this works perfectly!)
        vm.prank(guest1);
        assemble.tipEvent{ value: 0.2 ether }(eventId); // Family contribution

        vm.prank(guest2);
        assemble.tipEvent{ value: 0.15 ether }(eventId); // Wedding gift

        vm.prank(guest3);
        assemble.tipEvent{ value: 0.5 ether }(eventId); // Generous gift

        console.log("Guests sent wedding gifts!");

        // Check gift distribution (simplified)
        assertGt(assemble.pendingWithdrawals(bride), 0);
        assertGt(assemble.pendingWithdrawals(groom), 0);
        assertGt(assemble.pendingWithdrawals(honeymoonFund), 0);

        console.log("Wedding gifts received and distributed!");
        console.log("Supporting the happy couple's new journey!");
    }

    function test_WeddingRegistrySystem() public {
        console.log("\n=== Digital Wedding Registry Example ===");
        console.log("Onchain gift registry with specific item funding");

        // Registry event for specific gifts
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Sarah & Michael's Gift Registry",
            description: "Help us start our new life together! Each gift tier represents a specific item.",
            imageUri: "ipfs://wedding-registry",
            startTime: block.timestamp + 30 days,
            endTime: block.timestamp + 90 days,
            capacity: 200,
            venueId: 0, // Virtual registry
            visibility: Assemble.EventVisibility.PUBLIC
        });

        // Specific gift items as tiers
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](5);
        tiers[0] = Assemble.TicketTier({
            name: "Kitchen Appliance Set",
            price: 0.2 ether, // $300
            maxSupply: 1, // Only need one
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 89 days,
            transferrable: false
        });
        tiers[1] = Assemble.TicketTier({
            name: "Dining Table",
            price: 0.5 ether, // $750
            maxSupply: 1,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 89 days,
            transferrable: false
        });
        tiers[2] = Assemble.TicketTier({
            name: "Honeymoon Activities",
            price: 0.1 ether, // $150 per activity
            maxSupply: 10, // Multiple activities
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 89 days,
            transferrable: false
        });
        tiers[3] = Assemble.TicketTier({
            name: "Home Down Payment",
            price: 1 ether, // $1500 contribution
            maxSupply: 20, // Multiple contributions
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 89 days,
            transferrable: false
        });
        tiers[4] = Assemble.TicketTier({
            name: "General Gift Fund",
            price: 0.03 ether, // $50 any amount
            maxSupply: 100,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 89 days,
            transferrable: false
        });

        // All gifts go to couple equally
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](2);
        splits[0] = Assemble.PaymentSplit(bride, 5000, "bride_share"); // 50%
        splits[1] = Assemble.PaymentSplit(groom, 5000, "groom_share"); // 50%

        vm.prank(bride);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Digital wedding registry created!");
        console.log("Guests can fund specific items or contribute to general fund");
        console.log("Perfect for modern couples starting their journey together!");
    }
}
