// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { SocialLibrary } from "../src/libraries/SocialLibrary.sol";
import { CommentLibrary } from "../src/libraries/CommentLibrary.sol";

/// @title Birthday Party Tip Example
/// @notice Demonstrates how tips can be directed to different recipients (birthday person vs organizer)
/// @author @taayyohh
contract BirthdayExampleTest is Test {
    Assemble public assemble;

    address public organizer = makeAddr("organizer"); // Person organizing the party
    address public birthdayPerson = makeAddr("birthday"); // Whose birthday it is
    address public venue = makeAddr("venue"); // Venue owner
    address public tipper = makeAddr("tipper"); // Someone giving tips

    function setUp() public {
        assemble = new Assemble(address(this));

        // Fund accounts
        vm.deal(organizer, 5 ether);
        vm.deal(tipper, 5 ether);
    }

    function test_BirthdayPartyTipScenario() public {
        console.log("\n=== Birthday Party Tip Example ===");
        console.log("Organizer (Alice) is throwing a party for Birthday Person (Bob)");
        console.log("Tips should go mostly to Bob, with small thank you to Alice for organizing");

        // 1. Organizer creates birthday party with custom payment splits
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Surprise Birthday Party",
            description: "John's 30th surprise birthday celebration with cake, music, and fun!",
            imageUri: "QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR",
            startTime: block.timestamp + 7 days,
            endTime: block.timestamp + 7 days + 4 hours,
            capacity: 25,
            latitude: 404052000, // NYC: 40.4052 * 1e7
            longitude: -739979000, // NYC: -73.9979 * 1e7
            venueName: "Madison Square Park",
            visibility: Assemble.EventVisibility.PRIVATE
        });

        // Free party with payment splits directing tips to birthday person
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Free Entry",
            price: 0,
            maxSupply: 25,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });

        // Payment split: Birthday person gets most tips, organizer gets thank you amount
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](3);
        splits[0] = Assemble.PaymentSplit(birthdayPerson, 7000); // 70% to birthday person
        splits[1] = Assemble.PaymentSplit(organizer, 2000); // 20% thank you to organizer
        splits[2] = Assemble.PaymentSplit(venue, 1000); // 10% to venue

        vm.prank(organizer);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Event created! Payment splits:");
        console.log("  Birthday Person (Bob): 70%");
        console.log("  Organizer (Alice): 20%");
        console.log("  Venue: 10%");

        // 2. Friends tip the birthday person through the event
        uint256 tipAmount = 1 ether;

        vm.prank(tipper);
        assemble.tipEvent{ value: tipAmount }(eventId);

        console.log("\nTip of 1 ETH sent to the event");

        // 3. Check how tips were distributed
        uint256 protocolFee = (tipAmount * 50) / 10_000; // 0.5% protocol fee
        uint256 netTip = tipAmount - protocolFee;

        uint256 birthdayPersonShare = (netTip * 7000) / 10_000; // 70%
        uint256 organizerShare = (netTip * 2000) / 10_000; // 20%
        uint256 venueShare = (netTip * 1000) / 10_000; // 10%

        assertEq(assemble.pendingWithdrawals(birthdayPerson), birthdayPersonShare);
        assertEq(assemble.pendingWithdrawals(organizer), organizerShare);
        assertEq(assemble.pendingWithdrawals(venue), venueShare);

        console.log("Tip distribution (after 0.5% protocol fee):");
        console.log("  Birthday Person pending:", birthdayPersonShare);
        console.log("  Organizer pending:", organizerShare);
        console.log("  Venue pending:", venueShare);
        console.log("  Protocol fee:", protocolFee);

        // 4. Birthday person claims their tips
        uint256 beforeBalance = birthdayPerson.balance;

        vm.prank(birthdayPerson);
        assemble.claimFunds();

        uint256 afterBalance = birthdayPerson.balance;
        uint256 received = afterBalance - beforeBalance;

        assertEq(received, birthdayPersonShare);
        console.log("\nBirthday person claimed:", received, "wei");
        console.log("Perfect! Tips went to the right person!");

        // 5. Organizer can also claim their thank you amount
        vm.prank(organizer);
        assemble.claimFunds();

        console.log("Organizer claimed their thank you amount");
        console.log("\n=== Birthday Tip Example Complete! ===");
    }

    function test_FlexiblePaymentSplits() public {
        console.log("\n=== Flexible Payment Split Examples ===");

        // Example 1: All tips go to birthday person (0% to organizer)
        Assemble.PaymentSplit[] memory splits1 = new Assemble.PaymentSplit[](1);
        splits1[0] = Assemble.PaymentSplit(birthdayPerson, 10_000); // 100%

        // Example 2: Split between birthday person and charity
        address charity = makeAddr("charity");
        Assemble.PaymentSplit[] memory splits2 = new Assemble.PaymentSplit[](2);
        splits2[0] = Assemble.PaymentSplit(birthdayPerson, 5000); // 50%
        splits2[1] = Assemble.PaymentSplit(charity, 5000); // 50%

        // Example 3: Complex multi-recipient split
        address band = makeAddr("band");
        Assemble.PaymentSplit[] memory splits3 = new Assemble.PaymentSplit[](4);
        splits3[0] = Assemble.PaymentSplit(birthdayPerson, 4000); // 40%
        splits3[1] = Assemble.PaymentSplit(band, 3000); // 30%
        splits3[2] = Assemble.PaymentSplit(venue, 2000); // 20%
        splits3[3] = Assemble.PaymentSplit(organizer, 1000); // 10%

        console.log("Payment split examples:");
        console.log("1. 100% to birthday person");
        console.log("2. 50% birthday person, 50% charity");
        console.log("3. 40% birthday person, 30% band, 20% venue, 10% organizer");
        console.log("Tips can be directed anywhere!");
    }

    function test_BirthdayPartyWithComments() public {
        console.log("\n=== Birthday Party with Comments ===");
        console.log("Demonstrating comment integration with birthday celebrations");

        // Create additional friend for this test
        address friend = makeAddr("friend");
        vm.deal(friend, 1 ether);

        // Create birthday event
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Birthday Follow-up Event",
            description: "Follow-up celebration",
            imageUri: "QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR",
            startTime: block.timestamp + 14 days,
            endTime: block.timestamp + 14 days + 3 hours,
            capacity: 15,
            latitude: 404052000,
            longitude: -739979000,
            venueName: "Central Park",
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Party Guest",
            price: 0, // Free birthday party
            maxSupply: 15,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 4 days,
            transferrable: false
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit(birthdayPerson, 10_000);

        vm.prank(organizer);
        uint256 eventId = assemble.createEvent(params, tiers, splits);

        console.log("Birthday party event created!");

        // Friends RSVP and start chatting in comments
        vm.prank(tipper);
        assemble.purchaseTickets{ value: 0 }(eventId, 0, 1);

        vm.prank(tipper);
        assemble.updateRSVP(eventId, SocialLibrary.RSVPStatus.GOING);

        vm.prank(tipper);
        assemble.postComment(eventId, "So excited for your birthday Sarah! Should I bring anything?", 0);

        // Organizer responds with party details
        vm.prank(organizer);
        assemble.postComment(eventId, "Just bring yourselves! We have food and drinks covered. Can't wait!", 1);

        // Friend joins the conversation
        vm.prank(friend);
        assemble.purchaseTickets{ value: 0 }(eventId, 0, 1);

        vm.prank(friend);
        assemble.postComment(eventId, "Will there be karaoke? I'm ready to serenade the birthday girl!", 0);

        // Birthday person responds
        vm.prank(birthdayPerson);
        assemble.postComment(eventId, "OMG yes! I can't wait to hear your amazing voice!", 3);

        // Friends respond to each other (Note: like system removed for optimization)
        // Comments provide engagement through threading instead

        console.log("Friends are chatting and getting excited for the party!");

        // Last minute update from organizer
        vm.prank(organizer);
        assemble.postComment(eventId, "UPDATE: Party moved to the backyard - weather is perfect!", 0);

        // Someone sends a birthday tip with comment
        vm.prank(tipper);
        assemble.tipEvent{ value: 0.1 ether }(eventId);

        vm.prank(tipper);
        assemble.postComment(eventId, "Sent a little birthday gift! Have an amazing day Sarah!", 0);

        console.log("Comments create buzz and excitement before the party!");

        // Check all comments were created
        uint256[] memory comments = assemble.getEventComments(eventId);
        assertEq(comments.length, 6, "Should have 6 comments total");

        // Note: Comment likes removed for bytecode optimization
        // Threaded conversations provide sufficient community engagement

        console.log("Birthday party comments bring the community together!");
        console.log("Perfect integration of social features!");

        // Add new comment from sister
        address sister = makeAddr("sister");
        vm.deal(sister, 1 ether);

        vm.prank(sister);
        assemble.postComment(eventId, "Let's do karaoke after dinner!", 0);

        // Note: Comment liking system removed for bytecode optimization
        // Comments still provide community engagement through threading

        console.log("Family building excitement through comments");
    }
}
