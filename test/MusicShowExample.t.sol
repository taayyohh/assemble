// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { SocialLibrary } from "../src/libraries/SocialLibrary.sol";

/// @title Music Concert Example
/// @notice Demonstrates concert events with artist revenue splits and VIP experiences
/// @author @taayyohh
contract MusicShowExampleTest is Test {
    Assemble public assemble;

    address public artist = makeAddr("artist");
    address public venue = makeAddr("venue");
    address public soundEngineer = makeAddr("soundEngineer");
    address public manager = makeAddr("manager");
    address public fan1 = makeAddr("fan1");
    address public fan2 = makeAddr("fan2");
    address public fan3 = makeAddr("fan3");

    function setUp() public {
        assemble = new Assemble(address(this));

        // Fund music fans
        vm.deal(fan1, 3 ether);
        vm.deal(fan2, 3 ether);
        vm.deal(fan3, 3 ether);
    }

    function test_IndieRockConcert() public {
        console.log("\n=== Indie Rock Concert Example ===");
        console.log("Multi-tier concert with artist revenue splits and VIP packages");

        // Create concert event
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "The Midnight Echoes - World Tour",
            description: "Indie rock sensation live! Meet & greet, signed merch, and unforgettable music.",
            imageUri: "ipfs://midnight-echoes-tour",
            startTime: block.timestamp + 14 days,
            endTime: block.timestamp + 14 days + 4 hours,
            capacity: 1000,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        // Concert ticket tiers with VIP experiences
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](4);
        tiers[0] = Assemble.TicketTier({
            name: "General Admission",
            price: 0.05 ether, // $75
            maxSupply: 700,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 13 days,
            transferrable: true
        });
        tiers[1] = Assemble.TicketTier({
            name: "Reserved Seating",
            price: 0.08 ether, // $120
            maxSupply: 200,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 13 days,
            transferrable: true
        });
        tiers[2] = Assemble.TicketTier({
            name: "VIP Experience",
            price: 0.15 ether, // $225 - includes meet & greet
            maxSupply: 80,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 13 days,
            transferrable: true
        });
        tiers[3] = Assemble.TicketTier({
            name: "Platinum Package",
            price: 0.3 ether, // $450 - backstage, signed items, photo
            maxSupply: 20,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 13 days,
            transferrable: false // Exclusive experience
         });

        // Music industry revenue splits
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](4);
        splits[0] = Assemble.PaymentSplit(artist, 5500, "artist_performance"); // 55%
        splits[1] = Assemble.PaymentSplit(venue, 2500, "venue_rental"); // 25%
        splits[2] = Assemble.PaymentSplit(manager, 1500, "artist_management"); // 15%
        splits[3] = Assemble.PaymentSplit(soundEngineer, 500, "sound_production"); // 5%

        vm.prank(manager);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Concert event created!");
        console.log("Revenue splits: 55% artist, 25% venue, 15% management, 5% sound");

        // Fans purchase different ticket tiers
        uint256 gaPrice = assemble.calculatePrice(eventId, 0, 2);
        vm.prank(fan1);
        assemble.purchaseTickets{ value: gaPrice }(eventId, 0, 2); // GA for friends

        uint256 vipPrice = assemble.calculatePrice(eventId, 2, 1);
        vm.prank(fan2);
        assemble.purchaseTickets{ value: vipPrice }(eventId, 2, 1); // VIP experience

        uint256 platinumPrice = assemble.calculatePrice(eventId, 3, 1);
        vm.prank(fan3);
        assemble.purchaseTickets{ value: platinumPrice }(eventId, 3, 1); // Platinum package

        console.log("Fans purchased tickets:");
        console.log("  2x General Admission");
        console.log("  1x VIP Experience");
        console.log("  1x Platinum Package");

        // Concert social features - fans connect
        vm.prank(fan1);
        assemble.addFriend(fan2);

        vm.prank(fan2);
        assemble.addFriend(fan1);

        vm.prank(fan1);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        // Check social discount for fan2 (friend is going)
        uint256 discountedPrice = assemble.calculatePrice(eventId, 0, 1);
        console.log("Social discount available for friend attending");

        // Fans tip artist for amazing previous shows
        vm.prank(fan2);
        assemble.tipEvent{ value: 0.02 ether }(eventId);

        console.log("Fan tipped artist for previous performances!");

        // Check artist earnings
        uint256 totalRevenue = gaPrice + vipPrice + platinumPrice + 0.02 ether; // All purchases + tip
        uint256 protocolFee = (totalRevenue * 50) / 10_000;
        uint256 netRevenue = totalRevenue - protocolFee;

        uint256 artistEarnings = (netRevenue * 5500) / 10_000;
        assertGt(assemble.pendingWithdrawals(artist), 0);

        console.log("Artist earnings:", artistEarnings);
        console.log("Supporting independent musicians!");

        // Concert night attendance
        vm.warp(block.timestamp + 14 days);

        // Generate specific ticket IDs for check-in
        uint256 gaTicket1 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);
        uint256 gaTicket2 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 2);
        uint256 vipTicket = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 2, 1);
        uint256 platinumTicket = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 3, 1);

        // Different check-in scenarios
        vm.prank(fan1);
        assemble.checkInWithTicket(eventId, gaTicket1); // GA ticket holder

        vm.prank(fan2);
        assemble.checkInWithTicket(eventId, vipTicket); // VIP access

        vm.prank(fan3);
        assemble.checkInWithTicket(eventId, platinumTicket); // Platinum backstage

        // Verify tier-specific access
        assertTrue(assemble.hasAttendedTier(fan1, eventId, 0), "GA ticket holder should have GA badge");
        assertTrue(assemble.hasAttendedTier(fan2, eventId, 2), "VIP ticket holder should have VIP badge");
        assertTrue(assemble.hasAttendedTier(fan3, eventId, 3), "Platinum holder should have Platinum badge");
        
        // Verify access restrictions - GA holder shouldn't get VIP badge
        assertFalse(assemble.hasAttendedTier(fan1, eventId, 2), "GA holder shouldn't have VIP access");
        assertFalse(assemble.hasAttendedTier(fan1, eventId, 3), "GA holder shouldn't have Platinum access");

        console.log("Concert attendance with access verification:");
        console.log("  GA fan: General admission access");
        console.log("  VIP fan: Meet & greet access verified");
        console.log("  Platinum fan: Backstage access verified");
        console.log("What an incredible show!");
    }

    function test_FestivalMultiArtist() public {
        console.log("\n=== Music Festival Example ===");
        console.log("Multi-day festival with complex artist splits");

        // Festival event
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "SoundWave Festival 2024",
            description: "3 days of incredible music featuring 20+ artists across 4 stages",
            imageUri: "ipfs://soundwave-festival",
            startTime: block.timestamp + 30 days,
            endTime: block.timestamp + 33 days,
            capacity: 5000,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        // Festival passes and day tickets
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](3);
        tiers[0] = Assemble.TicketTier({
            name: "3-Day Festival Pass",
            price: 0.2 ether, // $300
            maxSupply: 3000,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 29 days,
            transferrable: true
        });
        tiers[1] = Assemble.TicketTier({
            name: "VIP Festival Pass",
            price: 0.4 ether, // $600 - includes food, backstage area
            maxSupply: 500,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 29 days,
            transferrable: true
        });
        tiers[2] = Assemble.TicketTier({
            name: "Artist Access Pass",
            price: 0.8 ether, // $1200 - meet artists, exclusive areas
            maxSupply: 100,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 29 days,
            transferrable: false
        });

        // Festival revenue distribution
        address artistsPool = makeAddr("artistsPool");
        address production = makeAddr("production");
        address marketing = makeAddr("marketing");

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](4);
        splits[0] = Assemble.PaymentSplit(artistsPool, 4000, "artists_collective"); // 40%
        splits[1] = Assemble.PaymentSplit(venue, 3000, "venue_operations"); // 30%
        splits[2] = Assemble.PaymentSplit(production, 2000, "stage_production"); // 20%
        splits[3] = Assemble.PaymentSplit(marketing, 1000, "marketing_promo"); // 10%

        vm.prank(production);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Music festival launched!");
        console.log("Revenue distributed across artists, venue, production, and marketing");
        console.log("Supporting the entire music ecosystem!");
    }
}
