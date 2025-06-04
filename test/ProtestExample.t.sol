// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { SocialLibrary } from "../src/libraries/SocialLibrary.sol";

/// @title Protest & Activism Example
/// @notice Demonstrates free protest events with donations to causes and organizing funds
/// @author @taayyohh
contract ProtestExampleTest is Test {
    Assemble public assemble;

    address public activist = makeAddr("activist");
    address public organization = makeAddr("organization");
    address public legalFund = makeAddr("legalFund");
    address public mutualAid = makeAddr("mutualAid");
    address public supporter1 = makeAddr("supporter1");
    address public supporter2 = makeAddr("supporter2");
    address public supporter3 = makeAddr("supporter3");

    function setUp() public {
        assemble = new Assemble(address(this));

        // Fund supporters
        vm.deal(supporter1, 2 ether);
        vm.deal(supporter2, 2 ether);
        vm.deal(supporter3, 2 ether);
    }

    function test_ClimateActionProtest() public {
        console.log("\n=== Climate Action Protest Example ===");
        console.log("Free public demonstration with donations to environmental causes");

        // Create protest event
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Climate Action Rally",
            description: "Join us in demanding immediate action on climate change! Peaceful demonstration for our planet's future.",
            imageUri: "QmClimateRallyImage",
            startTime: block.timestamp + 7 days,
            endTime: block.timestamp + 7 days + 4 hours,
            capacity: 5000,
            latitude: 389037000, // DC: 38.9037 * 1e7
            longitude: -770223000, // DC: -77.0223 * 1e7
            venueName: "National Mall",
            visibility: Assemble.EventVisibility.PUBLIC
        });

        // Free participation with optional support tiers
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](4);
        tiers[0] = Assemble.TicketTier({
            name: "March Participant",
            price: 0, // Free to attend
            maxSupply: 4000, // Changed from 9000 to fit capacity (4000+500+300+200=5000)
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 13 days,
            transferrable: false // Personal commitment
         });
        tiers[1] = Assemble.TicketTier({
            name: "Support Organizers",
            price: 0.01 ether, // $15 to cover organizing costs
            maxSupply: 500, // Keeping as is to fit total
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 13 days,
            transferrable: false
        });
        tiers[2] = Assemble.TicketTier({
            name: "Fund Legal Observers",
            price: 0.03 ether, // $50 for legal support
            maxSupply: 300, // Keeping as is to fit total
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 13 days,
            transferrable: false
        });
        tiers[3] = Assemble.TicketTier({
            name: "Climate Action Sponsor",
            price: 0.1 ether, // $150 major supporter
            maxSupply: 200, // Keeping as is to fit total
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 13 days,
            transferrable: false
        });

        // Cause-focused payment splits
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](4);
        splits[0] = Assemble.PaymentSplit(organization, 4000); // 40%
        splits[1] = Assemble.PaymentSplit(legalFund, 3000); // 30%
        splits[2] = Assemble.PaymentSplit(mutualAid, 2000); // 20%
        splits[3] = Assemble.PaymentSplit(activist, 1000); // 10%

        vm.prank(activist);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Climate protest organized!");
        console.log("Donations: 40% env org, 30% legal fund, 20% mutual aid, 10% organizing");

        // Supporters join and contribute
        vm.prank(supporter1);
        assemble.purchaseTickets{ value: 0 }(eventId, 0, 1); // Free participation

        vm.prank(supporter1);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        // Use generous amounts to cover dynamic pricing
        vm.prank(supporter2);
        assemble.purchaseTickets{ value: 0.1 ether }(eventId, 2, 1); // Very generous buffer

        vm.prank(supporter2);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        vm.prank(supporter3);
        assemble.purchaseTickets{ value: 0.3 ether }(eventId, 3, 1); // Very generous buffer

        vm.prank(supporter3);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        console.log("Supporters registered:");
        console.log("  Free participant confirmed");
        console.log("  Legal fund supporter");
        console.log("  Climate action sponsor");

        // Social organizing - building movement
        vm.prank(supporter1);
        assemble.addFriend(supporter2);

        vm.prank(supporter2);
        assemble.addFriend(supporter1);

        vm.prank(supporter1);
        assemble.addFriend(supporter3);

        vm.prank(supporter3);
        assemble.addFriend(supporter1);

        vm.prank(supporter2);
        assemble.addFriend(supporter3);

        vm.prank(supporter3);
        assemble.addFriend(supporter2);

        // Organizer invites friends to join the cause
        address[] memory invitees = new address[](2);
        invitees[0] = supporter1;
        invitees[1] = supporter2;

        // Note: inviteFriends function removed for bytecode optimization
        // Friend invitation validation can be done client-side

        // Additional donations for the cause
        vm.prank(supporter1);
        assemble.tipEvent{ value: 0.05 ether }(eventId); // Extra donation

        console.log("Additional donation sent to climate causes!");

        // Check cause funding
        uint256 totalDonations = 0.1 ether + 0.3 ether + 0.05 ether; // All contributions
        uint256 protocolFee = (totalDonations * 50) / 10_000;
        uint256 netDonations = totalDonations - protocolFee;

        uint256 orgFunding = (netDonations * 4000) / 10_000;
        uint256 legalFunding = (netDonations * 3000) / 10_000;
        uint256 mutualAidFunding = (netDonations * 2000) / 10_000;

        assertGt(assemble.pendingWithdrawals(organization), 0);
        assertGt(assemble.pendingWithdrawals(legalFund), 0);
        assertGt(assemble.pendingWithdrawals(mutualAid), 0);

        console.log("Cause funding allocated:");
        console.log("  Environmental org:", orgFunding);
        console.log("  Legal observers:", legalFunding);
        console.log("  Mutual aid:", mutualAidFunding);

        // Protest day participation
        vm.warp(block.timestamp + 7 days + 1 hours); // Event started 1 hour ago

        uint256 ticket1 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);
        vm.prank(supporter1);
        assemble.checkIn(eventId);

        uint256 badgeId = assemble.generateTokenId(Assemble.TokenType.ATTENDANCE_BADGE, eventId, 0, 0);
        assertTrue(assemble.balanceOf(supporter1, badgeId) > 0);
        console.log("Protester attended and received activism badge!");
        console.log("Fighting for our future! The movement grows stronger!");
    }

    function test_SocialJusticeRally() public {
        console.log("\n=== Social Justice Rally Example ===");
        console.log("Community rally with bail fund and organizing support");

        // Social justice event
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Community Safety Forum",
            description: "Open discussion about improving safety and police accountability in our neighborhood",
            imageUri: "QmSafetyForumImage",
            startTime: block.timestamp + 14 days,
            endTime: block.timestamp + 14 days + 3 hours,
            capacity: 200,
            latitude: 404052000, // NYC: 40.4052 * 1e7
            longitude: -739979000, // NYC: -73.9979 * 1e7
            venueName: "Community Center",
            visibility: Assemble.EventVisibility.PUBLIC
        });

        // Justice-focused support tiers
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](3);
        tiers[0] = Assemble.TicketTier({
            name: "Rally Attendee",
            price: 0, // Free participation
            maxSupply: 100, // Changed from 4500 to fit capacity (100+70+30=200)
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: false
        });
        tiers[1] = Assemble.TicketTier({
            name: "Bail Fund Support",
            price: 0.05 ether, // $75 bail fund contribution
            maxSupply: 70, // Changed from 400 to fit capacity
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: false
        });
        tiers[2] = Assemble.TicketTier({
            name: "Movement Builder",
            price: 0.2 ether, // $300 major organizer support
            maxSupply: 30, // Changed from 100 to fit capacity
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 6 days,
            transferrable: false
        });

        // Justice movement funding
        address bailFund = makeAddr("bailFund");
        address communityOrg = makeAddr("communityOrg");
        address defenseCoalition = makeAddr("defenseCoalition");

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](3);
        splits[0] = Assemble.PaymentSplit(bailFund, 5000); // 50%
        splits[1] = Assemble.PaymentSplit(communityOrg, 3000); // 30%
        splits[2] = Assemble.PaymentSplit(defenseCoalition, 2000); // 20%

        vm.prank(activist);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Social justice rally organized!");
        console.log("Funds: 50% bail fund, 30% community org, 20% legal defense");
        console.log("Building power for systemic change!");
    }

    function test_MutualAidNetwork() public {
        console.log("\n=== Mutual Aid Network Example ===");
        console.log("Community care event connecting resources and support");

        // Mutual aid organizing event
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Workers Rights March",
            description: "Standing together for fair wages, safe working conditions, and workers' dignity",
            imageUri: "QmWorkersRightsImage",
            startTime: block.timestamp + 21 days,
            endTime: block.timestamp + 21 days + 5 hours,
            capacity: 3000,
            latitude: 377826000, // SF: 37.7826 * 1e7
            longitude: -1224241000, // SF: -122.4241 * 1e7
            venueName: "Union Square",
            visibility: Assemble.EventVisibility.PUBLIC
        });

        // Resource sharing tiers
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](2);
        tiers[0] = Assemble.TicketTier({
            name: "Community Member",
            price: 0, // Free community building
            maxSupply: 450,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 2 days,
            transferrable: false
        });
        tiers[1] = Assemble.TicketTier({
            name: "Resource Contributor",
            price: 0.02 ether, // $30 mutual aid fund
            maxSupply: 50,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 2 days,
            transferrable: false
        });

        // Community-first splits
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](2);
        splits[0] = Assemble.PaymentSplit(mutualAid, 8000); // 80%
        splits[1] = Assemble.PaymentSplit(activist, 2000); // 20%

        vm.prank(activist);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Mutual aid network launched!");
        console.log("Community care: 80% emergency fund, 20% organizing materials");
        console.log("Neighbors helping neighbors!");
    }
}
