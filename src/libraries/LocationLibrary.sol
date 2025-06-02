// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LocationLibrary
/// @notice Library for handling geospatial coordinate packing/unpacking
/// @dev Extracted from main contract to reduce bytecode size
library LocationLibrary {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    
    error InvalidLatitude();
    error InvalidLongitude();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Maximum latitude value (90 degrees * 1e7 precision)
    int64 private constant MAX_LATITUDE = 900000000;
    
    /// @notice Minimum latitude value (-90 degrees * 1e7 precision)
    int64 private constant MIN_LATITUDE = -900000000;
    
    /// @notice Maximum longitude value (180 degrees * 1e7 precision)
    int64 private constant MAX_LONGITUDE = 1800000000;
    
    /// @notice Minimum longitude value (-180 degrees * 1e7 precision)  
    int64 private constant MIN_LONGITUDE = -1800000000;

    /*//////////////////////////////////////////////////////////////
                        COORDINATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Pack latitude and longitude into a single uint128
    /// @param lat Latitude in 1e-7 degrees (11mm precision)
    /// @param lng Longitude in 1e-7 degrees (11mm precision)
    /// @return packed Packed coordinates as uint128
    function packCoordinates(int64 lat, int64 lng) external pure returns (uint128 packed) {
        // Validate coordinate bounds
        if (lat < MIN_LATITUDE || lat > MAX_LATITUDE) revert InvalidLatitude();
        if (lng < MIN_LONGITUDE || lng > MAX_LONGITUDE) revert InvalidLongitude();
        
        // Pack: lat(8 bytes) + lng(8 bytes) = 16 bytes total
        packed = (uint128(uint64(lat)) << 64) | uint128(uint64(lng));
    }

    /// @notice Unpack coordinates from uint128 back to lat/lng
    /// @param packed Packed coordinate data
    /// @return lat Latitude in 1e-7 degrees
    /// @return lng Longitude in 1e-7 degrees
    function unpackCoordinates(uint128 packed) external pure returns (int64 lat, int64 lng) {
        lat = int64(uint64(packed >> 64));
        lng = int64(uint64(packed));
    }

    /// @notice Validate coordinate bounds without packing
    /// @param lat Latitude to validate
    /// @param lng Longitude to validate
    /// @return valid Whether coordinates are within valid ranges
    function validateCoordinates(int64 lat, int64 lng) external pure returns (bool valid) {
        return (lat >= MIN_LATITUDE && lat <= MAX_LATITUDE && 
                lng >= MIN_LONGITUDE && lng <= MAX_LONGITUDE);
    }

    /// @notice Calculate rough distance between two coordinate pairs (simplified)
    /// @param lat1 First latitude
    /// @param lng1 First longitude
    /// @param lat2 Second latitude
    /// @param lng2 Second longitude
    /// @return distance Approximate distance (not precise haversine)
    function roughDistance(
        int64 lat1, 
        int64 lng1, 
        int64 lat2, 
        int64 lng2
    ) external pure returns (uint256 distance) {
        // Simple Euclidean distance for rough proximity (gas efficient)
        int256 deltaLat = int256(lat2) - int256(lat1);
        int256 deltaLng = int256(lng2) - int256(lng1);
        
        // Avoid overflow in multiplication
        if (deltaLat < 0) deltaLat = -deltaLat;
        if (deltaLng < 0) deltaLng = -deltaLng;
        
        // Simple distance approximation
        distance = uint256(deltaLat + deltaLng);
    }
} 