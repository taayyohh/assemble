// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";

/// @title Theatre Production Example
/// @notice Demonstrates ticketed theatre events with revenue splits to cast and crew
/// @author @taayyohh
contract TheatreExampleTest is Test {
    Assemble public assemble;

    address public theatre = makeAddr("theatre");
    address public director = makeAddr("director");
    address public castCrew = makeAddr("castCrew");
    address public theatergoer1 = makeAddr("theatergoer1");
    address public theatergoer2 = makeAddr("theatergoer2");

    function setUp() public {
        assemble = new Assemble(address(this));

        // Fund accounts
        vm.deal(theatergoer1, 2 ether);
        vm.deal(theatergoer2, 2 ether);
    }

    function test_TheatreProduction() public {
        console.log("\n=== Theatre Production Example ===");
        console.log("Ticketed show with revenue splits to cast, crew, and venue");

        // Create theatre event
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Shakespeare's Hamlet - Opening Night",
            description: "A timeless classic performed by our talented local theatre company.",
            imageUri: "ipfs://hamlet-poster",
            startTime: block.timestamp + 7 days,
            endTime: block.timestamp + 7 days + 3 hours,
            capacity: 200,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        // Multiple seating tiers with different pricing
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](4);
        tiers[0] = Assemble.TicketTier({
            name: "Student/Senior",
            price: 0.02 ether, // $30 equivalent
            maxSupply: 30,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: true
        });
        tiers[1] = Assemble.TicketTier({
            name: "General Admission",
            price: 0.04 ether, // $60 equivalent
            maxSupply: 120,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: true
        });
        tiers[2] = Assemble.TicketTier({
            name: "Premium Seats",
            price: 0.08 ether, // $120 equivalent
            maxSupply: 40,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: true
        });
        tiers[3] = Assemble.TicketTier({
            name: "VIP Box Seats",
            price: 0.15 ether, // $225 equivalent
            maxSupply: 10,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: true
        });

        // Revenue splits for theatre production
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](4);
        splits[0] = Assemble.PaymentSplit(castCrew, 4000, "cast_and_crew"); // 40%
        splits[1] = Assemble.PaymentSplit(director, 2000, "director"); // 20%
        splits[2] = Assemble.PaymentSplit(theatre, 3000, "theatre_venue"); // 30%
        splits[3] = Assemble.PaymentSplit(theatre, 1000, "production_costs"); // 10%

        vm.prank(director);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Theatre production event created!");
        console.log("Revenue splits: 40% cast/crew, 20% director, 40% theatre/costs");

        // Theatre enthusiasts purchase tickets
        uint256 gaPrice = assemble.calculatePrice(eventId, 1, 2, theatergoer1);
        vm.prank(theatergoer1);
        assemble.purchaseTickets{ value: gaPrice }(eventId, 1, 2); // General admission x2

        uint256 premiumPrice = assemble.calculatePrice(eventId, 2, 1, theatergoer2);
        vm.prank(theatergoer2);
        assemble.purchaseTickets{ value: premiumPrice }(eventId, 2, 1); // Premium seat

        console.log("Tickets purchased:");
        console.log("  2x General Admission");
        console.log("  1x Premium Seat");

        // Opening night tip for exceptional performance
        vm.prank(theatergoer1);
        assemble.tipEvent{ value: 0.05 ether }(eventId);

        console.log("Opening night tip sent for amazing performance!");

        // Check revenue distribution
        uint256 totalRevenue = gaPrice + premiumPrice + 0.05 ether; // Tickets + tip
        uint256 protocolFee = (totalRevenue * 50) / 10_000;
        uint256 netRevenue = totalRevenue - protocolFee;

        uint256 castCrewEarnings = (netRevenue * 4000) / 10_000;
        uint256 directorEarnings = (netRevenue * 2000) / 10_000;

        assertGt(assemble.pendingWithdrawals(castCrew), 0);
        assertGt(assemble.pendingWithdrawals(director), 0);

        console.log("Cast & crew earnings:", castCrewEarnings);
        console.log("Director earnings:", directorEarnings);

        // Show night attendance
        vm.warp(block.timestamp + 7 days);

        uint256 ticket1 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 1, 1);
        vm.prank(theatergoer1);
        assemble.checkIn(eventId, ticket1);

        assertTrue(assemble.hasAttended(theatergoer1, eventId));
        console.log("Theatre patron attended and received show badge!");
        console.log("Break a leg! The show was fantastic!");
    }

    function test_SeasonTickets() public {
        console.log("\n=== Theatre Season Pass Example ===");
        console.log("Annual subscription model for theatre season");

        // Season pass event
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "2024 Theatre Season Pass",
            description: "Access to all 8 shows in our 2024 season + exclusive events",
            imageUri: "ipfs://season-pass",
            startTime: block.timestamp + 30 days,
            endTime: block.timestamp + 365 days,
            capacity: 100,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](2);
        tiers[0] = Assemble.TicketTier({
            name: "Individual Season Pass",
            price: 0.4 ether, // $600 for full season
            maxSupply: 80,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 29 days,
            transferrable: false // Personal season pass
         });
        tiers[1] = Assemble.TicketTier({
            name: "Family Season Pass",
            price: 0.7 ether, // $1000 for family
            maxSupply: 20,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 29 days,
            transferrable: false
        });

        // Season revenue splits
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](3);
        splits[0] = Assemble.PaymentSplit(castCrew, 5000, "artists_fund"); // 50%
        splits[1] = Assemble.PaymentSplit(theatre, 4000, "operations"); // 40%
        splits[2] = Assemble.PaymentSplit(director, 1000, "artistic_director"); // 10%

        vm.prank(theatre);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Season pass program launched!");
        console.log("Supporting local theatre year-round!");
    }
}
