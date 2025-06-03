# Assemble Protocol Enhancement PRD (Final)
## Version 2.0 - Multi-Currency, Location & Venue System

---

## 🤖 DETAILED LLM IMPLEMENTATION PROMPT

**MISSION**: Implement Assemble Protocol V2.0 enhancements with EXTREME size optimization. This PRD is the definitive source of truth.

### 🚨 CRITICAL CONSTRAINTS
- **ABSOLUTE SIZE LIMIT**: 24,576 bytes (currently 24,034 bytes = 542 bytes margin)
- **PRIORITY**: Size optimization > Feature completeness
- **FAILURE CONDITION**: Contract exceeds size limit = deployment impossible

### 📋 IMPLEMENTATION ROADMAP

#### Step 1: Size Monitoring Setup (MANDATORY FIRST)
```bash
# Add to every build
forge build --sizes | grep Assemble
# STOP if size > 24,500 bytes
```

#### Step 2: Library Extraction (Primary Size Reduction)
```solidity
// Extract to src/libraries/ BEFORE adding features
library PaymentLibrary {
    function processERC20(...) external;  // ~200 bytes saved
}
library LocationLibrary {
    function packCoordinates(...) external pure; // ~100 bytes saved  
}
library VenueLibrary {
    function generateHash(...) external pure; // ~50 bytes saved
}
```

#### Step 3: Storage Optimization (Critical)
```solidity
// ULTRA-OPTIMIZED struct (64 bytes total, 2 storage slots)
struct PackedEventData {
    // SLOT 1 (32 bytes)
    uint128 basePrice;      // 16 bytes
    uint128 location;       // 16 bytes: packed lat(8) + lng(8) + venueId(8) + flags(8)
    
    // SLOT 2 (32 bytes)  
    uint64 startTime;       // 8 bytes
    uint32 capacity;        // 4 bytes
    uint32 reserved;        // 4 bytes for future use
    uint16 tierCount;       // 2 bytes
    uint8 visibility;       // 1 byte
    uint8 status;           // 1 byte
    uint8 currency;         // 1 byte
    uint8 flags;            // 1 byte
    // 10 bytes remaining for expansion
}
```

#### Step 4: Function Implementation Order
1. **Core storage changes** (test size after each)
2. **Location packing** (minimal bytecode impact)
3. **Venue hash system** (simple hash only)
4. **ERC20 payments** (library-based, add last)

#### Step 5: Testing Strategy
```solidity
// Size monitoring test
function test_ContractSize() public {
    uint256 size;
    assembly { size := extcodesize(address(assemble)) }
    assertLt(size, 24_576, "Contract too large");
}
```

### 🔧 OPTIMIZATION TECHNIQUES (MANDATORY)

#### Bytecode Reduction
- Use `external` not `public`
- Pack function parameters
- Eliminate redundant checks
- Use assembly for bit operations
- Minimize string operations
- Cache storage reads

#### Data Packing Strategy
```solidity
// Pack multiple values into single slots
uint256 packed = (uint256(a) << 224) | (uint256(b) << 192) | (uint256(c) << 160);
```

#### Library Pattern
```solidity
using PaymentLibrary for *;
// Reduces contract bytecode, moves complexity to libraries
```

### ⚠️ FALLBACK STRATEGY
If size exceeded:
1. Remove ERC20 payments
2. Remove complex venue features  
3. Simplify location to basic lat/lng
4. Last resort: Remove soulbound tokens

---

## 📊 EXECUTIVE SUMMARY

**Goal**: Add venue identification, location data, and multi-currency payments to Assemble protocol while maintaining <24,576 byte contract size.

**Approach**: Ultra-optimized storage packing + library extraction + minimal feature complexity

**Critical Success Factor**: Contract size monitoring at every step

---

## 🔍 CURRENT STATE ANALYSIS

### Size Constraints (CRITICAL)
- **Current Size**: 24,034 bytes
- **Available Margin**: 542 bytes  
- **Risk Level**: EXTREME - Must optimize existing code to add features

### Storage Inefficiencies (Opportunities)
```solidity
// Current waste in PackedEventData:
struct PackedEventData {
    uint128 basePrice;  // 16 bytes ✓
    uint64 startTime;   // 8 bytes ✓  
    uint32 capacity;    // 4 bytes ✓
    uint16 venueId;     // 2 bytes ❌ UNUSED
    uint8 visibility;   // 1 byte ✓
    uint8 status;       // 1 byte ✓
    // Total: 32 bytes (1 slot) + wasted potential
}
```

---

## 🏢 ENHANCEMENT 1: SIMPLIFIED VENUE SYSTEM

### Problem
- `venueId` field exists but is meaningless
- No venue verification or incentives
- Missing venue-event relationship

### Solution: Minimal Venue Hash System

#### Core Design (Simplified)
```solidity
// NO complex venue registry - just hash identification
struct PackedEventData {
    uint128 basePrice;      
    uint128 locationData;   // lat(8) + lng(8) + venueHash(8) + flags(8)
    uint64 startTime;       
    uint32 capacity;        
    // ... rest optimized
}

// Minimal venue tracking
mapping(uint64 => uint256) public venueEventCount; // 8-byte venue hash -> event count
```

#### Venue Hash Generation
```solidity
library VenueLibrary {
    // Generate 8-byte venue hash (not 32-byte)
    function generateVenueHash(string calldata venue) external pure returns (uint64) {
        return uint64(uint256(keccak256(abi.encodePacked(venue))));
    }
}
```

#### Soulbound Tokens (When Earned)
```solidity
// Mint venue credential after hosting first event
function _mintVenueCredential(uint64 venueHash) internal {
    if (venueEventCount[venueHash] == 1) { // First event
        uint256 tokenId = generateTokenId(TokenType.VENUE_CRED, 0, venueHash, 0);
        _mint(msg.sender, tokenId, 1);
    }
}
```

### Benefits
- **Minimal Bytecode**: No complex registry
- **Venue Identity**: 8-byte hash sufficient for identification  
- **Incentives**: Soulbound tokens for active venues
- **External Integration**: Hash works with any venue system

---

## 🌍 ENHANCEMENT 2: ULTRA-OPTIMIZED LOCATION STORAGE

### Problem
- No geospatial data
- Missing location-based discovery

### Solution: Packed Coordinate System

#### Maximum Storage Efficiency
```solidity
library LocationLibrary {
    // Pack lat/lng into 16 bytes (8 bytes each)
    function packCoordinates(int64 lat, int64 lng) external pure returns (uint128) {
        require(lat >= -900000000 && lat <= 900000000, "Invalid latitude");
        require(lng >= -1800000000 && lng <= 1800000000, "Invalid longitude");
        return (uint128(uint64(lat)) << 64) | uint128(uint64(lng));
    }
    
    function unpackCoordinates(uint128 packed) external pure returns (int64 lat, int64 lng) {
        lat = int64(uint64(packed >> 64));
        lng = int64(uint64(packed));
    }
}
```

#### Integration with Events
```solidity
struct EventParams {
    // ... existing fields ...
    int64 latitude;     // 1e-7 precision (11mm accuracy)
    int64 longitude;    // 1e-7 precision
    uint64 venueHash;   // 8-byte venue identifier
}
```

#### Location Queries (Gas Optimized)
```solidity
function getEventLocation(uint256 eventId) external view returns (int64, int64) {
    uint128 locationData = events[eventId].locationData;
    return LocationLibrary.unpackCoordinates(locationData & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
}
```

---

## 💰 ENHANCEMENT 3: ERC20 PAYMENT SYSTEM

### Problem  
- ETH-only payments limit accessibility
- No stablecoin support

### Solution: Library-Based Multi-Currency

#### Minimal ERC20 Integration
```solidity
library PaymentLibrary {
    function processERC20Payment(
        address token,
        address from,
        uint256 amount,
        address[] memory recipients,
        uint256[] memory amounts
    ) external returns (bool) {
        IERC20(token).transferFrom(from, address(this), amount);
        
        for (uint256 i = 0; i < recipients.length; i++) {
            IERC20(token).transfer(recipients[i], amounts[i]);
        }
        return true;
    }
}
```

#### New Payment Functions (Minimal)
```solidity
// Keep existing ETH functions unchanged
function purchaseTicketsERC20(
    uint256 eventId,
    uint256 tierId,
    uint256 quantity,
    address token
) external {
    // Validate token whitelist
    require(supportedTokens[token], "Unsupported token");
    
    // Use library for payment processing
    PaymentLibrary.processERC20Payment(/*...*/);
}
```

#### Token Management (Simple)
```solidity
mapping(address => bool) public supportedTokens;

function addSupportedToken(address token) external onlyFeeTo {
    supportedTokens[token] = true;
}
```

---

## 📦 ULTRA-OPTIMIZED STORAGE LAYOUT

### Final PackedEventData (64 bytes, 2 slots)
```solidity
struct PackedEventData {
    // SLOT 1: 32 bytes
    uint128 basePrice;          // 16 bytes: Event base price
    uint128 locationData;       // 16 bytes: lat(8) + lng(8) + PACKED
    
    // SLOT 2: 32 bytes
    uint64 startTime;           // 8 bytes: Event start timestamp
    uint32 capacity;            // 4 bytes: Max attendees
    uint64 venueHash;           // 8 bytes: Venue identifier  
    uint16 tierCount;           // 2 bytes: Number of ticket tiers
    uint8 visibility;           // 1 byte: Public/Private/Invite
    uint8 status;               // 1 byte: Active/Cancelled/Complete
    uint8 defaultCurrency;      // 1 byte: 0=ETH, 1=ERC20
    uint8 flags;                // 1 byte: Feature flags
    uint32 reserved;            // 4 bytes: Future expansion
}
```

### Bit Packing Utilities
```solidity
library BitPacking {
    function packLocationVenue(
        int64 lat,
        int64 lng, 
        uint64 venueHash
    ) external pure returns (uint128) {
        // Pack: lat(8) + lng(8) in first 16 bytes
        // venueHash stored separately for gas efficiency
        return (uint128(uint64(lat)) << 64) | uint128(uint64(lng));
    }
}
```

---

## 🧪 SIZE-AWARE TESTING STRATEGY

### Mandatory Size Tests
```solidity
contract SizeMonitoring {
    function test_ContractSizeLimit() public {
        address assembleAddr = address(assemble);
        uint256 size;
        assembly { size := extcodesize(assembleAddr) }
        
        console.log("Contract size:", size, "bytes");
        console.log("Remaining margin:", 24576 - size, "bytes");
        assertLt(size, 24_576, "Contract exceeds size limit");
    }
    
    function test_LibrarySizes() public {
        // Test each library individually
        assertLt(_getContractSize(address(paymentLib)), 5000, "PaymentLibrary too large");
        assertLt(_getContractSize(address(locationLib)), 3000, "LocationLibrary too large");
        assertLt(_getContractSize(address(venueLib)), 2000, "VenueLibrary too large");
    }
}
```

### Feature Testing
```solidity
contract FeatureTests {
    function test_VenueHashGeneration() public {
        uint64 hash1 = VenueLibrary.generateVenueHash("Madison Square Garden");
        uint64 hash2 = VenueLibrary.generateVenueHash("Brooklyn Bowl");
        assertNotEq(hash1, hash2, "Hash collision");
    }
    
    function test_LocationPacking() public {
        int64 lat = 404052000; // 40.4052 * 1e7 (NYC)
        int64 lng = -739979000; // -73.9979 * 1e7
        
        uint128 packed = LocationLibrary.packCoordinates(lat, lng);
        (int64 unpackedLat, int64 unpackedLng) = LocationLibrary.unpackCoordinates(packed);
        
        assertEq(lat, unpackedLat, "Latitude packing failed");
        assertEq(lng, unpackedLng, "Longitude packing failed");
    }
    
    function test_ERC20Payment() public {
        // Test ERC20 payment flow
        MockERC20 token = new MockERC20();
        token.mint(user, 1000e18);
        
        vm.prank(user);
        token.approve(address(assemble), 100e18);
        
        vm.prank(user);
        assemble.purchaseTicketsERC20(eventId, 0, 1, address(token));
        
        assertEq(assemble.balanceOf(user, tokenId), 1, "Ticket not minted");
    }
}
```

---

## 📋 IMPLEMENTATION CHECKLIST

### Phase 1: Core Optimization ✅
- [ ] Add size monitoring to build process
- [ ] Extract PaymentLibrary, LocationLibrary, VenueLibrary  
- [ ] Optimize PackedEventData to 64 bytes (2 slots)
- [ ] Verify size reduction before adding features

### Phase 2: Venue System ✅
- [ ] Replace venueId with 8-byte hash
- [ ] Add venue hash generation utility
- [ ] Implement soulbound venue credentials
- [ ] Add venue event counting

### Phase 3: Location System ✅  
- [ ] Add coordinate packing/unpacking functions
- [ ] Integrate location data into event creation
- [ ] Add location query functions
- [ ] Validate coordinate bounds

### Phase 4: ERC20 Payments ✅
- [ ] Implement ERC20 payment library
- [ ] Add token whitelist management
- [ ] Create ERC20 purchase/tip functions
- [ ] Extend reentrancy protection

### Phase 5: Final Validation ✅
- [ ] Comprehensive size testing
- [ ] Gas optimization analysis  
- [ ] Security audit preparation
- [ ] Migration compatibility testing

---

## 🎯 SUCCESS METRICS

### Technical Requirements
- **Contract Size**: <24,576 bytes (MANDATORY)
- **Gas Costs**: ERC20 payments <160k gas
- **Location Precision**: 11mm accuracy globally
- **Storage Efficiency**: 64 bytes per event base data

### Feature Completeness
- **Venue System**: Hash-based identification + soulbound tokens
- **Location Data**: Global coordinate support
- **Multi-Currency**: ETH + whitelisted ERC20 tokens
- **Backward Compatibility**: All existing functions preserved

---

## ⚠️ RISK MITIGATION

### Size Overflow Protection
```solidity
// Build-time size check
modifier sizeGuard() {
    uint256 size;
    assembly { size := extcodesize(address(this)) }
    require(size < 24_576, "Contract too large");
    _;
}
```

### Feature Degradation Plan
1. **First**: Remove complex venue features
2. **Second**: Simplify location to basic coordinates  
3. **Third**: Remove ERC20 payment variants
4. **Last**: Remove soulbound venue tokens

---

## 🏗️ FINAL ARCHITECTURE

### Storage Layout (Optimized)
```solidity
// 64 bytes per event (vs current 32 bytes)
// Trade: 32 bytes storage for massive functionality gain
struct PackedEventData {
    uint128 basePrice;          // Slot 1: 0-15
    uint128 locationData;       // Slot 1: 16-31 (lat+lng packed)
    uint64 startTime;           // Slot 2: 0-7  
    uint32 capacity;            // Slot 2: 8-11
    uint64 venueHash;           // Slot 2: 12-19
    uint16 tierCount;           // Slot 2: 20-21
    uint8 visibility;           // Slot 2: 22
    uint8 status;               // Slot 2: 23
    uint8 defaultCurrency;      // Slot 2: 24
    uint8 flags;                // Slot 2: 25
    uint32 reserved;            // Slot 2: 26-29
    uint16 padding;             // Slot 2: 30-31
}
```

### Library Architecture (Size Optimized)
```solidity
library PaymentLibrary {
    function processERC20Payment(address,address,uint256,address[],uint256[]) external;
}
library LocationLibrary {
    function packCoordinates(int64,int64) external pure returns(uint128);
    function unpackCoordinates(uint128) external pure returns(int64,int64);
}
library VenueLibrary {
    function generateVenueHash(string calldata) external pure returns(uint64);
}
```

---

**This PRD is the definitive specification for Assemble Protocol V2.0. Size optimization is the primary constraint that drives all implementation decisions.** 