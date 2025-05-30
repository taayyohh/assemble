// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Assemble} from "../src/Assemble.sol";

/// @title Birthday Party Tip Example
/// @notice Demonstrates how tips can be directed to different recipients (birthday person vs organizer)
/// @author @taayyohh
contract BirthdayExampleTest is Test {
    Assemble public assemble;
    
    address public organizer = makeAddr("organizer");     // Person organizing the party
    address public birthdayPerson = makeAddr("birthday"); // Whose birthday it is
    address public venue = makeAddr("venue");             // Venue owner
    address public tipper = makeAddr("tipper");           // Someone giving tips
    
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
            title: "Bob's 30th Birthday Bash!",
            description: "Celebrating Bob's milestone birthday - tips go to Bob!",
            imageUri: "ipfs://birthday-party",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 50,
            venueId: 1,
            visibility: Assemble.EventVisibility.PUBLIC
        });
        
        // Free party with payment splits directing tips to birthday person
        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Free Entry",
            price: 0,
            maxSupply: 50,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });
        
        // Payment split: Birthday person gets most tips, organizer gets thank you amount
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](3);
        splits[0] = Assemble.PaymentSplit(birthdayPerson, 7000, "birthday_person"); // 70% to birthday person
        splits[1] = Assemble.PaymentSplit(organizer, 2000, "organizer_thanks");     // 20% thank you to organizer  
        splits[2] = Assemble.PaymentSplit(venue, 1000, "venue");                   // 10% to venue
        
        vm.prank(organizer);
        uint256 eventId = assemble.createEvent(params, tiers, splits);
        
        console.log("Event created! Payment splits:");
        console.log("  Birthday Person (Bob): 70%");
        console.log("  Organizer (Alice): 20%");
        console.log("  Venue: 10%");
        
        // 2. Friends tip the birthday person through the event
        uint256 tipAmount = 1 ether;
        
        vm.prank(tipper);
        assemble.tipEvent{value: tipAmount}(eventId);
        
        console.log("\nTip of 1 ETH sent to the event");
        
        // 3. Check how tips were distributed
        uint256 protocolFee = (tipAmount * 50) / 10000; // 0.5% protocol fee
        uint256 netTip = tipAmount - protocolFee;
        
        uint256 birthdayPersonShare = (netTip * 7000) / 10000; // 70%
        uint256 organizerShare = (netTip * 2000) / 10000;      // 20%
        uint256 venueShare = (netTip * 1000) / 10000;          // 10%
        
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
        splits1[0] = Assemble.PaymentSplit(birthdayPerson, 10000, "birthday_person"); // 100%
        
        // Example 2: Split between birthday person and charity
        address charity = makeAddr("charity");
        Assemble.PaymentSplit[] memory splits2 = new Assemble.PaymentSplit[](2);
        splits2[0] = Assemble.PaymentSplit(birthdayPerson, 5000, "birthday_person"); // 50%
        splits2[1] = Assemble.PaymentSplit(charity, 5000, "charity_donation");       // 50%
        
        // Example 3: Complex multi-recipient split
        address band = makeAddr("band");
        Assemble.PaymentSplit[] memory splits3 = new Assemble.PaymentSplit[](4);
        splits3[0] = Assemble.PaymentSplit(birthdayPerson, 4000, "birthday_person"); // 40%
        splits3[1] = Assemble.PaymentSplit(band, 3000, "live_music");               // 30%
        splits3[2] = Assemble.PaymentSplit(venue, 2000, "venue");                   // 20%
        splits3[3] = Assemble.PaymentSplit(organizer, 1000, "organizer");           // 10%
        
        console.log("Payment split examples:");
        console.log("1. 100% to birthday person");
        console.log("2. 50% birthday person, 50% charity");
        console.log("3. 40% birthday person, 30% band, 20% venue, 10% organizer");
        console.log("Tips can be directed anywhere!");
    }
} 