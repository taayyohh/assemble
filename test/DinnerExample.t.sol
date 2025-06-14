// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { SocialLibrary } from "../src/libraries/SocialLibrary.sol";

/// @title Dinner Event Example
/// @notice Demonstrates restaurant events with chef revenue splits and social dining
/// @author @taayyohh
contract DinnerExampleTest is Test {
    Assemble public assemble;

    address public chef = makeAddr("chef");
    address public restaurant = makeAddr("restaurant");
    address public organizer = makeAddr("organizer");
    address public diner1 = makeAddr("diner1");
    address public diner2 = makeAddr("diner2");
    address public diner3 = makeAddr("diner3");
    address public diner4 = makeAddr("diner4");

    function setUp() public {
        assemble = new Assemble(address(this));

        // Fund dinner guests
        vm.deal(diner1, 2 ether);
        vm.deal(diner2, 2 ether);
        vm.deal(diner3, 2 ether);
        vm.deal(diner4, 2 ether);
    }

    function test_ExclusiveDinnerExperience() public {
        console.log("\n=== Exclusive Chef's Table Experience ===");
        console.log("Multi-course tasting menu with wine pairings and chef interaction");

        // Create exclusive dinner event
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Intimate Italian Dinner",
            description: "A small, cozy dinner featuring homemade pasta and local wines",
            imageUri: "QmItalianDinnerImage",
            startTime: block.timestamp + 3 days,
            endTime: block.timestamp + 3 days + 3 hours,
            capacity: 8,
            latitude: 407608000, // NYC: 40.7608 * 1e7
            longitude: -739970000, // NYC: -73.9970 * 1e7
            venueName: "Cozy Italian Bistro",
            visibility: Assemble.EventVisibility.PUBLIC
        });

        // Dinner pricing tiers
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](3);
        tiers[0] = Assemble.TicketTier({
            name: "Tasting Menu",
            price: 0.1 ether, // $150 per person
            maxSupply: 4, // Changed from 12 to fit capacity
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: true
        });
        tiers[1] = Assemble.TicketTier({
            name: "Wine Pairing Add-on",
            price: 0.05 ether, // $75 wine pairing
            maxSupply: 2, // Changed from 12 to fit capacity
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: true
        });
        tiers[2] = Assemble.TicketTier({
            name: "Chef's Table VIP",
            price: 0.2 ether, // $300 premium experience
            maxSupply: 2, // Changed from 4 to fit capacity (total now 4+2+2=8)
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: false // Exclusive experience
         });

        // Restaurant revenue splits
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](3);
        splits[0] = Assemble.PaymentSplit(chef, 4000); // 40%
        splits[1] = Assemble.PaymentSplit(restaurant, 5000); // 50%
        splits[2] = Assemble.PaymentSplit(organizer, 1000); // 10%

        vm.prank(organizer);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Exclusive dinner event created!");
        console.log("Revenue splits: 40% chef, 50% restaurant, 10% coordinator");

        // Food enthusiasts make reservations
        uint256 tastingPrice1 = assemble.calculatePrice(eventId, 0, 1);
        vm.prank(diner1);
        assemble.purchaseTickets{ value: tastingPrice1 }(eventId, 0, 1); // Tasting menu only

        uint256 winePrice = assemble.calculatePrice(eventId, 1, 1);
        vm.prank(diner1);
        assemble.purchaseTickets{ value: winePrice }(eventId, 1, 1); // Wine pairing add-on

        uint256 tastingPrice2 = assemble.calculatePrice(eventId, 0, 1);
        vm.prank(diner2);
        assemble.purchaseTickets{ value: tastingPrice2 }(eventId, 0, 1); // Tasting only

        uint256 vipPrice = assemble.calculatePrice(eventId, 2, 1);
        vm.prank(diner3);
        assemble.purchaseTickets{ value: vipPrice }(eventId, 2, 1); // Chef's table VIP

        console.log("Dinner reservations made:");
        console.log("  Diner 1: Tasting menu + wine pairing");
        console.log("  Diner 2: Tasting menu");
        console.log("  Diner 3: Chef's table VIP experience");

        // Social dining - diners connect before event
        vm.prank(diner1);
        assemble.addFriend(diner2);

        vm.prank(diner2);
        assemble.addFriend(diner1);

        vm.prank(diner1);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        vm.prank(diner2);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        console.log("Diners connected and confirmed attendance");

        // Group purchase for friends (late addition with social discount)
        vm.prank(diner4);
        assemble.addFriend(diner1);

        vm.prank(diner1);
        assemble.addFriend(diner4);

        uint256 friendPrice = assemble.calculatePrice(eventId, 0, 1);
        vm.prank(diner4);
        assemble.purchaseTickets{ value: friendPrice }(eventId, 0, 1); // Regular purchase

        console.log("Friend joined dinner party!");

        // Appreciation tip for exceptional meal
        vm.prank(diner3);
        assemble.tipEvent{ value: 0.03 ether }(eventId);

        console.log("Diner tipped for amazing experience!");

        // Check chef earnings
        uint256 totalRevenue = tastingPrice1 + winePrice + tastingPrice2 + vipPrice + friendPrice + 0.03 ether;
        uint256 protocolFee = (totalRevenue * 50) / 10_000;
        uint256 netRevenue = totalRevenue - protocolFee;

        uint256 chefEarnings = (netRevenue * 4000) / 10_000;
        assertGt(assemble.pendingWithdrawals(chef), 0);

        console.log("Chef earnings:", chefEarnings);
        console.log("Supporting culinary artistry!");

        // Dinner attendance
        vm.warp(block.timestamp + 3 days + 1 hours); // Event started 1 hour ago

        uint256 ticket1 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);
        vm.prank(diner1);
        assemble.checkIn(eventId);

        uint256 badgeId = assemble.generateTokenId(Assemble.TokenType.ATTENDANCE_BADGE, eventId, 0, 0);
        assertTrue(assemble.balanceOf(diner1, badgeId) > 0);
        console.log("Diner attended and received culinary experience badge!");
        console.log("Bon appetit! What an unforgettable meal!");
    }

    function test_CommunityDinnerSeries() public {
        console.log("\n=== Community Dinner Series Example ===");
        console.log("Monthly neighborhood dinners building local connections");

        // Community dinner event
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "French Cuisine Experience",
            description: "Three-course French meal with wine pairings",
            imageUri: "QmFrenchDinnerImage",
            startTime: block.timestamp + 7 days,
            endTime: block.timestamp + 7 days + 3 hours,
            capacity: 12,
            latitude: 407614000, // NYC: 40.7614 * 1e7
            longitude: -739960000, // NYC: -73.9960 * 1e7
            venueName: "Le Petit Restaurant",
            visibility: Assemble.EventVisibility.PUBLIC
        });

        // Affordable community pricing
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](3);
        tiers[0] = Assemble.TicketTier({
            name: "Community Dinner",
            price: 0.02 ether, // $30 affordable pricing
            maxSupply: 6, // Changed from 40 to fit capacity
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 13 days,
            transferrable: true
        });
        tiers[1] = Assemble.TicketTier({
            name: "Support Local Food",
            price: 0.04 ether, // $60 supporter tier
            maxSupply: 4, // Changed from 8 to fit capacity
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 13 days,
            transferrable: true
        });
        tiers[2] = Assemble.TicketTier({
            name: "Sponsor a Neighbor",
            price: 0.06 ether, // $90 - sponsors someone else's meal
            maxSupply: 2, // Changed from 5 to fit capacity (total now 6+4+2=12)
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 13 days,
            transferrable: false
        });

        // Community-focused splits
        address localFoodBank = makeAddr("localFoodBank");
        address communityCenter = makeAddr("communityCenter");

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](4);
        splits[0] = Assemble.PaymentSplit(chef, 3000); // 30%
        splits[1] = Assemble.PaymentSplit(restaurant, 4000); // 40%
        splits[2] = Assemble.PaymentSplit(localFoodBank, 2000); // 20%
        splits[3] = Assemble.PaymentSplit(communityCenter, 1000); // 10%

        vm.prank(organizer);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Community dinner series launched!");
        console.log("Funds support chef, venue, food bank, and community programs");
        console.log("Building stronger neighborhoods through shared meals!");
    }
}
