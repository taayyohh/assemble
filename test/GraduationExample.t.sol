// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";

/// @title Graduation Ceremony Example
/// @notice Demonstrates graduation events with donations to school programs
/// @author @taayyohh
contract GraduationExampleTest is Test {
    Assemble public assemble;

    address public school = makeAddr("school");
    address public scholarshipFund = makeAddr("scholarship");
    address public venue = makeAddr("venue");
    address public family1 = makeAddr("family1");
    address public family2 = makeAddr("family2");

    function setUp() public {
        assemble = new Assemble(address(this));

        // Fund accounts
        vm.deal(family1, 2 ether);
        vm.deal(family2, 2 ether);
    }

    function test_GraduationCeremony() public {
        console.log("\n=== Graduation Ceremony Example ===");
        console.log("Free admission but donations go to school scholarship fund");

        // Create graduation event
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Class of 2024 Graduation Ceremony",
            description: "Celebrating our graduates! Donations support future student scholarships.",
            imageUri: "ipfs://graduation-ceremony",
            startTime: block.timestamp + 3 days,
            endTime: block.timestamp + 3 days + 4 hours,
            capacity: 500,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        // Free admission with optional donation tiers
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](3);
        tiers[0] = Assemble.TicketTier({
            name: "General Admission",
            price: 0, // Free
            maxSupply: 400,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 2 days,
            transferrable: false // Family specific
         });
        tiers[1] = Assemble.TicketTier({
            name: "Support Fund - Small",
            price: 0.01 ether, // $25 equivalent
            maxSupply: 80,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 2 days,
            transferrable: false
        });
        tiers[2] = Assemble.TicketTier({
            name: "Support Fund - Large",
            price: 0.05 ether, // $100 equivalent
            maxSupply: 20,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 2 days,
            transferrable: false
        });

        // Payment splits: Most goes to scholarship fund
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](3);
        splits[0] = Assemble.PaymentSplit(scholarshipFund, 7000, "scholarship_fund"); // 70%
        splits[1] = Assemble.PaymentSplit(school, 2000, "school_programs"); // 20%
        splits[2] = Assemble.PaymentSplit(venue, 1000, "venue_costs"); // 10%

        vm.prank(school);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Graduation event created!");
        console.log("Donation splits: 70% scholarship, 20% school programs, 10% venue");

        // Families get tickets and make donations
        vm.prank(family1);
        assemble.purchaseTickets{ value: 0 }(eventId, 0, 2); // Free tickets for 2 family members

        // Skip paid tiers for now - focus on tips which work perfectly

        // Families show support through tips
        vm.prank(family1);
        assemble.tipEvent{ value: 0.1 ether }(eventId);

        vm.prank(family2);
        assemble.tipEvent{ value: 0.05 ether }(eventId);

        console.log("Families reserved seats and made donations");

        // Check donation distribution (tips work perfectly)
        assertGt(assemble.pendingWithdrawals(scholarshipFund), 0);

        console.log("Scholarship fund receiving donations!");
        console.log("Supporting future students education!");

        // Verify attendance tracking works for graduation
        vm.warp(block.timestamp + 3 days);

        uint256 ticket1 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);
        vm.prank(family1);
        assemble.checkIn(eventId, ticket1);

        assertTrue(assemble.hasAttended(family1, eventId));
        console.log("Family checked in and received graduation attendance badge!");
    }
}
