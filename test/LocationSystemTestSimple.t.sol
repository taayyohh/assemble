// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";
import { LocationLibrary } from "../src/libraries/LocationLibrary.sol";

/**
 * @title LocationSystemTestSimple  
 * @notice Basic tests for location functionality that's actually implemented
 */
contract LocationSystemTestSimple is Test {
    Assemble public assemble;

    address public feeTo = makeAddr("feeTo");
    address public organizer = makeAddr("organizer");

    // Test coordinates with 11mm precision (1e-7 degrees)
    int64 constant NYC_LAT = 404052000;      // 40.4052000° N (Times Square)
    int64 constant NYC_LNG = -739979000;     // -73.9979000° W

    function setUp() public {
        assemble = new Assemble(feeTo);
    }

    function test_LocationLibraryFunctions() public {
        // Test the library functions directly
        uint128 packed = LocationLibrary.packCoordinates(NYC_LAT, NYC_LNG);
        (int64 unpackedLat, int64 unpackedLng) = LocationLibrary.unpackCoordinates(packed);

        assertEq(unpackedLat, NYC_LAT, "Latitude should match");
        assertEq(unpackedLng, NYC_LNG, "Longitude should match");

        console.log("Packed coordinates:", packed);
        console.log("Unpacked lat/lng:", uint64(unpackedLat), uint64(unpackedLng));
    }

    function test_EventLocationIntegration() public {
        // Test that events store and retrieve location correctly
        uint256 eventId = _createTestEvent();

        // Test location retrieval
        (, uint128 locationData,,,,,,,,,) = assemble.events(eventId);
        int64 retrievedLat = int64(uint64(locationData >> 64));
        int64 retrievedLng = int64(uint64(locationData));
        assertEq(retrievedLat, NYC_LAT, "Retrieved latitude should match");
        assertEq(retrievedLng, NYC_LNG, "Retrieved longitude should match");

        console.log("Event location:", uint64(retrievedLat), uint64(retrievedLng));
    }

    function test_CoordinateBounds() public {
        // Test valid boundaries
        LocationLibrary.packCoordinates(900000000, 1800000000);   // Max valid
        LocationLibrary.packCoordinates(-900000000, -1800000000); // Min valid

        // Test invalid boundaries
        vm.expectRevert();
        LocationLibrary.packCoordinates(900000001, 0); // Invalid lat

        vm.expectRevert(); 
        LocationLibrary.packCoordinates(0, 1800000001); // Invalid lng
    }

    function _createTestEvent() internal returns (uint256) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Test Event",
            description: "Test Description", 
            imageUri: "ipfs://test",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 100,
            latitude: NYC_LAT,
            longitude: NYC_LNG,
            venueName: "Test Venue",
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