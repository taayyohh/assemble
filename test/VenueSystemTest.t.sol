// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";

/**
 * @title VenueSystemTest
 * @notice Comprehensive tests for Assemble Protocol V2.0 Venue System
 * @dev Tests venue hash generation, soulbound credentials, and venue-event relationships
 */
contract VenueSystemTest is Test {
    Assemble public assemble;

    address public feeTo = makeAddr("feeTo");
    address public organizer1 = makeAddr("organizer1");
    address public organizer2 = makeAddr("organizer2");
    address public venue1 = makeAddr("venue1");
    address public venue2 = makeAddr("venue2");

    function setUp() public {
        assemble = new Assemble(feeTo);
    }

    /// @notice Helper function to generate venue hash inline (matching main contract)
    function _generateVenueHash(string memory venueName) internal pure returns (uint64) {
        return uint64(uint256(keccak256(abi.encodePacked(venueName))));
    }

    // ========================================
    // VENUE HASH GENERATION TESTS
    // ========================================

    function test_VenueHashGeneration() public {
        // Test consistent hashing
        uint64 hash1 = _generateVenueHash("Madison Square Garden");
        uint64 hash2 = _generateVenueHash("Madison Square Garden");
        assertEq(hash1, hash2, "Same venue should generate same hash");

        // Test different venues have different hashes
        uint64 hash3 = _generateVenueHash("Brooklyn Bowl");
        assertNotEq(hash1, hash3, "Different venues should have different hashes");

        console.log("Madison Square Garden hash:", hash1);
        console.log("Brooklyn Bowl hash:", hash3);
    }

    function test_VenueHashEmpty() public {
        // Empty venue name should still generate a hash (main contract allows it)
        uint64 hash = _generateVenueHash("");
        assertTrue(hash > 0, "Even empty venue should generate non-zero hash");
    }

    function test_VenueHashVariations() public {
        // Test that slight variations produce different hashes
        uint64 hash1 = _generateVenueHash("Central Park");
        uint64 hash2 = _generateVenueHash("Central Park ");
        uint64 hash3 = _generateVenueHash("central park");
        uint64 hash4 = _generateVenueHash("Central Park NYC");

        // All should be different due to case sensitivity and exact matching
        assertNotEq(hash1, hash2, "Trailing space should change hash");
        assertNotEq(hash1, hash3, "Case should change hash");
        assertNotEq(hash1, hash4, "Additional text should change hash");
    }

    function test_VenueHashLongName() public {
        // Test with very long venue name
        uint64 hash = _generateVenueHash("Very Long Venue Name That Could Potentially Cause Issues With Hash Generation");
        assertTrue(hash > 0, "Long venue name should generate valid hash");
    }

    // ========================================
    // VENUE EVENT TRACKING TESTS
    // ========================================

    function test_VenueEventCountIncrement() public {
        string memory venueName = "Madison Square Garden";
        
        // Initially should be 0
        assertEq(assemble.getVenueEventCount(venueName), 0, "Initial venue event count should be 0");

        // Create first event
        uint256 eventId1 = _createTestEvent(organizer1, venueName);
        assertEq(assemble.getVenueEventCount(venueName), 1, "Venue event count should be 1 after first event");

        // Create second event at same venue
        uint256 eventId2 = _createTestEvent(organizer2, venueName);
        assertEq(assemble.getVenueEventCount(venueName), 2, "Venue event count should be 2 after second event");

        // Verify events have same venue hash
        (,,, uint32 capacity1, uint64 venueHash1,,,,,,) = assemble.events(eventId1);
        (,,, uint32 capacity2, uint64 venueHash2,,,,,,) = assemble.events(eventId2);
        assertEq(venueHash1, venueHash2, "Same venue should have same hash across events");
    }

    function test_MultipleVenueTracking() public {
        string memory venue1Name = "Madison Square Garden";
        string memory venue2Name = "Brooklyn Bowl";

        // Create events at different venues
        _createTestEvent(organizer1, venue1Name);
        _createTestEvent(organizer1, venue2Name);
        _createTestEvent(organizer2, venue1Name);

        // Check counts
        assertEq(assemble.getVenueEventCount(venue1Name), 2, "Venue 1 should have 2 events");
        assertEq(assemble.getVenueEventCount(venue2Name), 1, "Venue 2 should have 1 event");
    }

    // ========================================
    // SOULBOUND VENUE CREDENTIALS TESTS
    // ========================================

    function test_VenueCredentialMinting() public {
        string memory venueName = "Madison Square Garden";
        
        // Initially no credential
        assertFalse(assemble.hasVenueCredential(organizer1, venueName), "Should not have credential initially");

        // Create first event - should mint credential
        _createTestEvent(organizer1, venueName);
        assertTrue(assemble.hasVenueCredential(organizer1, venueName), "Should have credential after first event");

        // Create second event - should not mint another credential
        uint64 venueHash = _generateVenueHash(venueName);
        uint256 credTokenId = assemble.generateTokenId(Assemble.TokenType.VENUE_CRED, 0, venueHash, 0);
        uint256 balanceBefore = assemble.balanceOf(organizer1, credTokenId);
        _createTestEvent(organizer1, venueName);
        uint256 balanceAfter = assemble.balanceOf(organizer1, credTokenId);
        assertEq(balanceBefore, balanceAfter, "Should not mint additional credential for same organizer/venue");
    }

    function test_MultipleOrganizersVenueCredentials() public {
        string memory venueName = "Madison Square Garden";

        // Different organizers at same venue should each get credentials
        _createTestEvent(organizer1, venueName);
        _createTestEvent(organizer2, venueName);

        assertTrue(assemble.hasVenueCredential(organizer1, venueName), "Organizer 1 should have credential");
        assertTrue(assemble.hasVenueCredential(organizer2, venueName), "Organizer 2 should have credential");
    }

    function test_VenueCredentialSoulbound() public {
        string memory venueName = "Madison Square Garden";
        
        // Create event to mint credential
        _createTestEvent(organizer1, venueName);
        
        // Get credential token ID
        uint64 venueHash = _generateVenueHash(venueName);
        uint256 credentialTokenId = assemble.generateTokenId(
            Assemble.TokenType.VENUE_CRED, 
            0, 
            venueHash, 
            0
        );

        // Verify credential exists
        assertEq(assemble.balanceOf(organizer1, credentialTokenId), 1, "Should have 1 credential");

        // Try to transfer - should fail (soulbound)
        vm.prank(organizer1);
        vm.expectRevert(); // Should revert as soulbound tokens cannot be transferred
        assemble.transfer(organizer1, organizer2, credentialTokenId, 1);
    }

    // ========================================
    // VENUE INTEGRATION TESTS
    // ========================================

    function test_EventVenueDataRetrieval() public {
        string memory venueName = "Madison Square Garden";
        uint256 eventId = _createTestEvent(organizer1, venueName);

        // Test venue hash retrieval
        (,,, uint32 capacity, uint64 venueHash,,,,,,) = assemble.events(eventId);
        uint64 expectedHash = _generateVenueHash(venueName);
        assertEq(venueHash, expectedHash, "Event venue hash should match generated hash");

        // Test venue name resolution (if implemented)
        // Note: This would require reverse mapping which may not be implemented for size optimization
    }

    function test_VenueEventHistory() public {
        string memory venueName = "Madison Square Garden";
        
        // Create multiple events
        uint256 eventId1 = _createTestEvent(organizer1, venueName);
        uint256 eventId2 = _createTestEvent(organizer2, venueName);
        
        // Both events should have same venue hash
        (,,, uint32 cap1, uint64 hash1,,,,,,) = assemble.events(eventId1);
        (,,, uint32 cap2, uint64 hash2,,,,,,) = assemble.events(eventId2);
        assertEq(hash1, hash2, "Events at same venue should have same hash");

        // Venue event count should be accurate
        assertEq(assemble.getVenueEventCount(venueName), 2, "Venue should have 2 events");
    }

    // ========================================
    // SIZE OPTIMIZATION TESTS
    // ========================================

    function test_VenueHashStorageEfficiency() public {
        // Test that venue hash fits in allocated space (8 bytes = uint64)
        string memory longVenueName = "A Very Long Venue Name That Could Potentially Cause Storage Issues If Not Handled Properly In The Contract";
        uint64 hash = _generateVenueHash(longVenueName);
        
        // Should fit in uint64
        assertTrue(hash <= type(uint64).max, "Venue hash should fit in uint64");
        assertTrue(hash > 0, "Venue hash should be non-zero");
    }

    function test_VenueSystemContractSize() public {
        // Verify contract size hasn't exceeded limits due to venue system
        address assembleAddr = address(assemble);
        uint256 size;
        assembly { size := extcodesize(assembleAddr) }
        
        console.log("Contract size with venue system:", size, "bytes");
        assertLt(size, 24_576, "Contract size should not exceed 24KB limit");
        
        // Log remaining margin
        uint256 remaining = 24_576 - size;
        console.log("Remaining size margin:", remaining, "bytes");
    }

    // ========================================
    // EDGE CASES AND ERROR HANDLING
    // ========================================

    function test_VenueCredentialTokenIdGeneration() public {
        string memory venueName = "Madison Square Garden";
        uint64 venueHash = _generateVenueHash(venueName);
        
        uint256 tokenId = assemble.generateTokenId(
            Assemble.TokenType.VENUE_CRED,
            0,
            venueHash,
            0
        );
        
        // Verify token type
        uint8 tokenType = uint8((tokenId >> 248) & 0xFF);
        assertEq(tokenType, uint8(Assemble.TokenType.VENUE_CRED), "Token should be venue credential type");
    }

    // ========================================
    // HELPER FUNCTIONS
    // ========================================

    function _createTestEvent(address organizer, string memory venueName) internal returns (uint256) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Test Event",
            description: "Test Description",
            imageUri: "ipfs://test",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 100,
            latitude: 404052000, // NYC coordinates
            longitude: -739979000,
            venueName: venueName,
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "General",
            price: 0.1 ether,
            maxSupply: 50,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit({
            recipient: organizer,
            basisPoints: 10_000
        });

        vm.prank(organizer);
        return assemble.createEvent(params, tiers, splits);
    }
} 