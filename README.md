# Assemble Protocol V2.0

A next-generation singleton smart contract protocol for onchain event management with comprehensive social coordination, location tracking, and multi-currency support.

*Built with ERC-6909 multi-token standard, EIP-1153 transient storage, soulbound credentials, and advanced venue management.*

## 🚀 V2.0 Features

### 🎯 **Core Event Management**
- **Multi-Tier Ticketing** - Configurable pricing, capacity limits, and payment splits
- **Location Integration** - GPS coordinate storage with efficient data packing
- **Venue Credential System** - Soulbound tokens for organizers with venue experience
- **Multi-Currency Support** - ETH and ERC20 token payments (USDC, DAI, etc.)
- **Advanced Refund System** - Automatic refunds for cancelled events with 90-day claim window

### 🔐 **Privacy & Access Control**
- **Private Events** - Invite-only events with curated guest lists
- **Flexible Visibility** - Public, private, and invite-only event types
- **Social Graph** - Friends, RSVPs, and social discovery with onchain coordination
- **Group Check-ins** - Delegate check-in functionality for group ticket purchases

### 💰 **Advanced Payment Features**
- **Platform Fees** - Optional 0-5% referral fees to incentivize ecosystem growth
- **ERC20 Payments** - Support for stablecoins and major tokens
- **Payment Splits** - Automatic revenue distribution to multiple recipients
- **Pull Payment Pattern** - Secure fund distribution with withdrawal mechanism

### 🏟️ **Venue & Location System**
- **GPS Coordinate Storage** - Precise location data with efficient packing
- **Venue Hash System** - Efficient venue identification and tracking
- **Venue Credentials** - Soulbound reputation tokens for experienced organizers
- **Location-Based Discovery** - Events searchable by geographic location

### 🎫 **Token & Badge System**
- **ERC-6909 Multi-Token** - Efficient batch operations for tickets and badges
- **Transferrable Tickets** - Standard event tickets with resale capability
- **Soulbound Badges** - Non-transferable attendance and organizer credentials
- **Venue Credentials** - Permanent reputation tokens for venue organizers

### 💬 **Social Features**
- **Comment System** - Threaded event discussions with moderation controls
- **RSVP Tracking** - Social commitment and attendance prediction
- **Friend Network** - Social connections for event discovery
- **Social Verification** - Reputation building through attendance history

## Architecture

**Singleton Design** - Single contract manages all events, users, and social interactions  
**Multi-Token Standard** - ERC-6909 enables efficient batch operations for tickets and badges  
**Gas Optimization** - EIP-1153 transient storage reduces gas costs for complex operations  
**Soulbound Credentials** - Non-transferable tokens for attendance proof and organizer reputation  
**Location Integration** - GPS coordinates packed efficiently in 128-bit storage  
**Multi-Currency** - Native ETH and ERC20 token support with unified payment handling

### Token Types
- `EVENT_TICKET` - Transferrable tickets for event access
- `ATTENDANCE_BADGE` - Soulbound proof of attendance (ERC-5192)  
- `ORGANIZER_CRED` - Soulbound reputation tokens for event organizers
- `VENUE_CRED` - Soulbound venue management credentials

### Event Visibility Levels
- `PUBLIC` - Open to all users with full visibility
- `PRIVATE` - Limited visibility, discoverable but restricted  
- `INVITE_ONLY` - Curated guest list with strict access control

### Payment Methods
- **ETH** - Native Ethereum payments
- **ERC20 Tokens** - USDC, DAI, and other standard tokens
- **Mixed Payments** - Tips in ETH, tickets in ERC20 (or vice versa)

## Quick Start

### Install Dependencies
```bash
forge install
```

### Run Tests
```bash
# Run all tests (196 tests)
forge test

# Run with gas reporting
forge test --gas-report

# Run specific test suites
forge test --match-contract "LocationSystem"
forge test --match-contract "ERC20Payment"
forge test --match-contract "VenueSystem"
```

### Deploy Locally
```bash
# Start local testnet
anvil

# Deploy with vanity address
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

## Contract API

### Core Event Functions
```solidity
// Create event with location data
function createEventWithLocation(
    address organizer,
    uint64 startTime,
    string calldata venueName,
    address primary,
    address secondary,
    uint256 primaryBps,
    uint256 secondaryBps,
    string calldata metadataURI,
    TicketTier[] calldata tiers,
    PaymentSplit[] calldata splits,
    int64 latitude,  // GPS coordinates (scaled by 1e6)
    int64 longitude
) external payable returns (uint256 eventId)

// Traditional event creation (no location)
function createEvent(
    EventParams calldata params, 
    TicketTier[] calldata tiers, 
    PaymentSplit[] calldata splits
) external returns (uint256 eventId)
```

### Ticket Purchase Functions
```solidity
// ETH payments
function purchaseTickets(uint256 eventId, uint256 tierId, uint256 quantity) external payable
function purchaseTickets(uint256 eventId, uint256 tierId, uint256 quantity, address referrer, uint256 platformFeeBps) external payable

// ERC20 payments
function purchaseTicketsWithERC20(uint256 eventId, uint256 tierId, uint256 quantity, address token) external
function purchaseTicketsWithERC20(uint256 eventId, uint256 tierId, uint256 quantity, address token, address referrer, uint256 platformFeeBps) external
```

### Venue & Location Functions
```solidity
// Check if user has venue credentials
function hasVenueCredential(address user, string calldata venueName) external view returns (bool)

// Get event location data
function getEventLocation(uint256 eventId) external view returns (int64 latitude, int64 longitude)

// Get venue statistics
function getVenueEventCount(string calldata venueName) external view returns (uint256)
```

### ERC20 Payment Functions
```solidity
// Tip events with ERC20 tokens
function tipEventWithERC20(uint256 eventId, address token, uint256 amount) external
function tipEventWithERC20(uint256 eventId, address token, uint256 amount, address referrer, uint256 platformFeeBps) external

// Withdraw ERC20 earnings
function withdrawERC20(address token) external
function withdrawProtocolERC20(address token) external

// Check pending withdrawals
function getERC20PendingWithdrawal(address token, address user) external view returns (uint256)
```

### Social Functions  
```solidity
function addFriend(address friend) external
function updateRSVP(uint256 eventId, RSVPStatus status) external
function postComment(uint256 eventId, string calldata content, uint256 parentId) external
```

### Private Event Functions
```solidity
function inviteToEvent(uint256 eventId, address[] calldata invitees) external
function removeInvitation(uint256 eventId, address invitee) external  
function isInvited(uint256 eventId, address user) external view returns (bool)
```

## Token ID Structure (ERC-6909)

```
┌─────────────┬─────────────┬─────────────┬─────────────┬─────────────┐
│  TokenType  │   EventId   │   TierId    │ SerialNum   │  Metadata   │
│   (8 bits)  │  (64 bits)  │  (32 bits)  │ (64 bits)   │  (88 bits)  │
└─────────────┴─────────────┴─────────────┴─────────────┴─────────────┘
```

Single uint256 encodes token type, event reference, tier information, and unique serial number.

## Location System

Precise GPS coordinate storage with efficient data packing:

```solidity
// Create event with NYC coordinates (40.7431° N, 73.9597° W)
int64 latitude = 40743100;   // 40.7431 * 1e6
int64 longitude = -73959700; // -73.9597 * 1e6

uint256 eventId = assemble.createEventWithLocation{value: PLATFORM_FEE}(
    organizer,
    startTime,
    "Madison Square Garden",
    alice, bob, 7000, 3000,
    "https://example.com/event",
    tiers, splits,
    latitude, longitude
);

// Retrieve location data
(int64 lat, int64 lng) = assemble.getEventLocation(eventId);
// lat = 40743100, lng = -73959700
```

**Key Features:**
- **Precision**: 6 decimal places (±1 meter accuracy)
- **Efficient Storage**: 128-bit packed coordinates
- **Global Coverage**: Full latitude/longitude range support
- **Integration Ready**: Compatible with mapping APIs and services

## Venue Credential System

Organizers earn soulbound venue credentials for hosting events:

```solidity
// Create event at specific venue
uint256 eventId = assemble.createEventWithLocation{value: PLATFORM_FEE}(
    organizer,
    startTime,
    "The Fillmore",  // Venue name creates credential
    // ... other params
);

// Organizer automatically receives venue credential token
bool hasCredential = assemble.hasVenueCredential(organizer, "The Fillmore");
// hasCredential = true (soulbound, non-transferable)

// Venue credentials accumulate over time
uint256 eventCount = assemble.getVenueEventCount("The Fillmore");
// Tracks total events at this venue
```

**Benefits:**
- **Reputation Building** - Permanent record of venue management experience
- **Trust Signals** - Visible proof of successful event history
- **Venue Partnerships** - Credentials can unlock venue-specific benefits
- **Anti-Fraud** - Prevents false venue claims and credential farming

## Multi-Currency Payments

Support for ETH and major ERC20 tokens:

```solidity
// USDC ticket purchase
IERC20(USDC).approve(address(assemble), ticketPrice);
assemble.purchaseTicketsWithERC20(eventId, tierId, quantity, USDC);

// DAI event tip with platform fee
IERC20(DAI).approve(address(assemble), tipAmount);
assemble.tipEventWithERC20(eventId, DAI, tipAmount, platformAddress, 200);

// Mixed payments - ETH tips, USDC tickets
assemble.tipEvent{value: 0.01 ether}(eventId);
assemble.purchaseTicketsWithERC20(eventId, 0, 1, USDC);
```

**Supported Tokens:**
- **ETH** - Native Ethereum
- **USDC** - USD Coin stablecoin
- **DAI** - Dai stablecoin  
- **Any ERC20** - Standard token interface support

**Features:**
- **Pull Payment Pattern** - Secure withdrawal mechanism
- **Mixed Currency Events** - Accept both ETH and ERC20
- **Protocol Fee Support** - Platform fees work with all currencies
- **Automatic Splitting** - Revenue splits work across all payment types

## Private Events

Perfect for exclusive gatherings, private parties, corporate events, and curated experiences:

```solidity
// Create invite-only event with location
EventParams memory params = EventParams({
    organizer: msg.sender,
    startTime: block.timestamp + 3600,
    venueName: "Private Residence",
    visibility: EventVisibility.INVITE_ONLY,
    // ... other params
});

uint256 eventId = assemble.createEventWithLocation{value: PLATFORM_FEE}(
    // ... params including GPS coordinates for private venue
);

// Invite specific guests
address[] memory guests = [alice, bob, charlie];
assemble.inviteToEvent(eventId, guests);

// Only invited users can see and purchase tickets
```

**Use Cases:**
- **Wedding Celebrations** - Guest list management with location sharing
- **Exclusive Art Openings** - Curated audience with venue credentials
- **Corporate Retreats** - Private events with expense tracking
- **VIP Product Launches** - Controlled access with social verification
- **Community Gatherings** - Intimate events with reputation requirements

## Platform Fees & Ecosystem Incentives

Platform fees (0-5%) enable sustainable ecosystem growth:

```solidity
// Music venue gets 2% for hosting (ETH)
assemble.purchaseTickets{value: ticketPrice}(eventId, 0, 1, venueAddress, 200);

// Event platform gets 1.5% for promotion (USDC)
assemble.purchaseTicketsWithERC20(eventId, 0, 1, USDC, platformAddress, 150);

// Cross-currency platform fees work seamlessly
assemble.tipEventWithERC20(eventId, DAI, tipAmount, influencerAddress, 100);
```

**Ecosystem Participants:**
- **Music Venues** - Earn fees for hosting and promotion
- **Event Platforms** - Monetize discovery and booking services
- **Influencer Partners** - Revenue sharing for audience development
- **Corporate Sponsors** - Track ROI on event investments
- **Community Builders** - Sustain long-term community operations
- **Venue Partners** - Leverage credentials for preferential rates

## Error Handling & User Experience

V2.0 introduces consolidated error handling for better UX:

```solidity
// Consolidated error system
error SocialError();     // Social interaction failures
error PaymentError();    // Payment and financial failures  
error EventError();      // Event management failures
error AccessError();     // Permission and access failures
error ValidationError(); // Input validation failures
```

**Benefits:**
- **Smaller Contract Size** - Consolidated errors reduce bytecode
- **Better DX** - Consistent error patterns across functions
- **Gas Efficiency** - Reduced deployment and execution costs
- **Frontend Integration** - Easier error handling in applications

## Security & Testing

### Comprehensive Test Suite (196 Tests - 100% Pass Rate)
- **📊 Core Functionality** - 40+ tests covering all primary features
- **🔒 Security Tests** - 17 tests for attack vectors and edge cases  
- **🎯 Edge Case Tests** - 22 tests for boundary conditions
- **🎲 Fuzz Tests** - 15 property-based tests (1000 runs each)
- **🔄 Invariant Tests** - 8 stateful tests (256 runs each)
- **🌐 Scenario Tests** - 25 real-world usage patterns
- **🔐 Private Event Tests** - 12 access control and privacy tests
- **📍 Location Tests** - 10 GPS and venue system tests
- **💰 ERC20 Payment Tests** - 15 multi-currency transaction tests

### Security Features  
- **Static Analysis Clean** - Zero issues with Slither
- **EIP-1153 Reentrancy Protection** - Transient storage guards
- **Pull Payment Pattern** - Secure fund distribution
- **Soulbound Token Enforcement** - Prevents credential transfer
- **Access Control** - Role-based permissions throughout
- **Input Validation** - Comprehensive parameter checking
- **Integer Overflow Protection** - SafeMath patterns where needed

### Gas Optimization
- **Contract Size**: 24,214 bytes (under 24,576 limit)
- **EIP-1153 Transient Storage** - Reduced state storage costs
- **Efficient Data Packing** - Optimized struct layouts
- **Batch Operations** - ERC-6909 multi-token efficiency
- **View Function Optimization** - Direct mapping access patterns

⚠️ **This protocol has not been audited. Use at your own risk.**

## Gas Usage

| Operation | ETH Gas | ERC20 Gas |
|-----------|---------|-----------|
| Create Event | 495,398 | N/A |
| Create Event + Location | 520,150 | N/A |
| Purchase Tickets | 541,107 | 580,200 |
| Purchase with Platform Fee | 565,850 | 605,100 |
| Private Event Invitations | 90,746 | N/A |
| Check-in Operations | 582,115 | N/A |
| Social Operations | 75,673 - 169,672 | N/A |
| ERC20 Withdrawals | N/A | 125,500 |
| Location Queries | 15,200 | N/A |

## Integration Examples

### Frontend Integration
```javascript
// Create event with location
const tx = await assemble.createEventWithLocation(
  organizer,
  startTime,
  "Madison Square Garden",
  primaryRecipient,
  secondaryRecipient,
  7000, 3000,
  metadataURI,
  ticketTiers,
  paymentSplits,
  40743100,  // NYC lat * 1e6
  -73959700, // NYC lng * 1e6
  { value: platformFee }
);

// Purchase with USDC
await usdc.approve(assemble.address, ticketPrice);
await assemble.purchaseTicketsWithERC20(eventId, tierId, quantity, usdc.address);

// Check venue credentials
const hasCredential = await assemble.hasVenueCredential(organizer, "Madison Square Garden");
```

### API Integration
```javascript
// Location-based event discovery
const events = await fetchEventsNearLocation(latitude, longitude, radiusKm);

// Multi-currency price display
const prices = {
  eth: await assemble.calculatePrice(eventId, tierId, quantity),
  usdc: await getUSDCPrice(eventId, tierId, quantity),
  dai: await getDAIPrice(eventId, tierId, quantity)
};

// Venue reputation display
const venueStats = {
  eventCount: await assemble.getVenueEventCount(venueName),
  credentials: await assemble.hasVenueCredential(organizer, venueName)
};
```

## Deployment

### 🌐 Multi-Chain Deployment

Assemble Protocol V2.0 is deployed with **identical addresses** across multiple networks using CREATE2:

**Contract Address (All Networks):**
- **Assemble**: `0x00000000000000000000000000000000000000000` *(Vanity address pending)*

**Target Networks:**
- ✅ Ethereum Mainnet (Chain ID: 1)
- ✅ Sepolia Testnet (Chain ID: 11155111)
- 🎯 World Chain Mainnet (Chain ID: 480) 
- 🎯 Flow EVM Mainnet (Chain ID: 747)
- 🎯 Base Mainnet (Chain ID: 8453)

### Vanity Address Deployment
```bash
# Find vanity address with 11 zeros
cast create2 --starts-with 00000000000 --case-sensitive --init-code-hash <HASH>

# Deploy to Sepolia
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Deploy to Mainnet
forge script script/Deploy.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --verify
```

## Roadmap

### V2.1 - Advanced Features (Q1 2025)
- **NFT Integration** - ERC-721 ticket support
- **Subscription Events** - Recurring event series
- **Dynamic Pricing** - Time-based and demand-based pricing
- **Enhanced Analytics** - Event performance metrics

### V2.2 - Ecosystem Expansion (Q2 2025)  
- **Cross-Chain Bridge** - Multi-chain event coordination
- **DAO Integration** - Governance token for protocol decisions
- **Advanced Venues** - Venue staking and reputation systems
- **Mobile SDK** - Native mobile app integration

### V3.0 - AI & Automation (Q3 2025)
- **AI Event Matching** - Personalized event recommendations
- **Automated Check-ins** - QR codes and NFC integration
- **Smart Contracts** - Event automation and conditional logic
- **Metaverse Integration** - Virtual and hybrid event support

## Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for details.

### Development Setup
```bash
# Clone repository
git clone https://github.com/your-org/assemble-protocol
cd assemble-protocol

# Install dependencies
forge install

# Run tests
forge test

# Run coverage
forge coverage

# Deploy locally
anvil &
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

## License

MIT License - see [LICENSE](./LICENSE) for details.

---

**Built with ❤️ for the onchain event ecosystem**

*Assemble Protocol V2.0 - Where events meet the future of web3*