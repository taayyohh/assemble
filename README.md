# Assemble Protocol

A next-generation singleton smart contract protocol for onchain event management with comprehensive social coordination, location tracking, and multi-currency support.

*Built with ERC-6909 multi-token standard, EIP-1153 transient storage, soulbound credentials, and advanced venue management.*

## Features

### Core Event Management
- **Multi-Tier Ticketing** - Configurable pricing, capacity limits, and payment splits
- **Location Integration** - GPS coordinate storage with efficient data packing
- **Venue Credential System** - Soulbound tokens for organizers with venue experience
- **Multi-Currency Support** - ETH and ERC20 token payments (USDC, DAI, etc.)
- **Advanced Refund System** - Automatic refunds for cancelled events with 90-day claim window

### Privacy & Access Control
- **Private Events** - Invite-only events with curated guest lists
- **Flexible Visibility** - Public, private, and invite-only event types
- **Social Graph** - Friends, RSVPs, and social discovery with onchain coordination
- **Group Check-ins** - Delegate check-in functionality for group ticket purchases

### Advanced Payment Features
- **Platform Fees** - Optional 0-5% referral fees to incentivize ecosystem growth
- **ERC20 Payments** - Support for stablecoins and major tokens
- **Payment Splits** - Automatic revenue distribution to multiple recipients
- **Pull Payment Pattern** - Secure fund distribution with withdrawal mechanism

### Venue & Location System
- **GPS Coordinate Storage** - Precise location data with efficient packing
- **Venue Hash System** - Efficient venue identification and tracking
- **Venue Credentials** - Soulbound reputation tokens for experienced organizers
- **Location-Based Discovery** - Events searchable by geographic location

### Token & Badge System
- **ERC-6909 Multi-Token** - Efficient batch operations for tickets and badges
- **Transferrable Tickets** - Standard event tickets with resale capability
- **Soulbound Badges** - Non-transferable attendance and organizer credentials
- **Venue Credentials** - Permanent reputation tokens for venue organizers

### Social Features
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

# Deploy contracts for local testing (see test files for examples)
forge test
```

## Contract API

### Core Event Functions
```solidity
// Create event with location data
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
function purchaseTicketsERC20(uint256 eventId, uint256 tierId, uint256 quantity, address token) external
function purchaseTicketsERC20(uint256 eventId, uint256 tierId, uint256 quantity, address token, address referrer, uint256 platformFeeBps) external
```

### ERC20 Payment Functions
```solidity
// Tip events with ERC20 tokens
function tipEventERC20(uint256 eventId, address token, uint256 amount) external
function tipEventERC20(uint256 eventId, address token, uint256 amount, address referrer, uint256 platformFeeBps) external

// Withdraw ERC20 earnings
function claimERC20Funds(address token) external

// Check token support
function setSupportedToken(address token, bool supported) external
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

uint256 eventId = assemble.createEvent{value: PLATFORM_FEE}(
    params,  // includes latitude/longitude
    tiers, 
    splits
);

// Location data is automatically packed and stored efficiently
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
uint256 eventId = assemble.createEvent{value: PLATFORM_FEE}(
    params, // includes venueName: "The Fillmore"
    tiers, 
    splits
);

// Organizer automatically receives venue credential token (soulbound, non-transferable)
// Venue credentials accumulate over time and build reputation
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
assemble.purchaseTicketsERC20(eventId, tierId, quantity, USDC);

// DAI event tip with platform fee
IERC20(DAI).approve(address(assemble), tipAmount);
assemble.tipEventERC20(eventId, DAI, tipAmount, platformAddress, 200);

// Mixed payments - ETH tips, USDC tickets
assemble.tipEvent{value: 0.01 ether}(eventId);
assemble.purchaseTicketsERC20(eventId, 0, 1, USDC);
```

**Supported Tokens:**
- **ETH** - Native Ethereum
- **USDC** - USD Coin stablecoin
- **DAI** - Dai stablecoin  
- **Any ERC20** - Standard token interface support

**Features:**
- **Pull Payment Pattern** - Secure withdrawal mechanism
- **Mixed Currency Events** - Accept both ETH and ERC20
- **Platform Fee Support** - Platform fees work with all currencies
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
    // ... other params including GPS coordinates
});

uint256 eventId = assemble.createEvent{value: PLATFORM_FEE}(
    params, tiers, splits
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
assemble.purchaseTicketsERC20(eventId, 0, 1, USDC, platformAddress, 150);

// Cross-currency platform fees work seamlessly
assemble.tipEventERC20(eventId, DAI, tipAmount, influencerAddress, 100);
```

**Ecosystem Participants:**
- **Music Venues** - Earn fees for hosting and promotion
- **Event Platforms** - Monetize discovery and booking services
- **Influencer Partners** - Revenue sharing for audience development
- **Corporate Sponsors** - Track ROI on event investments
- **Community Builders** - Sustain long-term community operations
- **Venue Partners** - Leverage credentials for preferential rates

## Error Handling & User Experience

Consolidated error handling for better UX:

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
- **Core Functionality** - 40+ tests covering all primary features
- **Security Tests** - 17 tests for attack vectors and edge cases  
- **Edge Case Tests** - 22 tests for boundary conditions
- **Fuzz Tests** - 15 property-based tests (1000 runs each)
- **Invariant Tests** - 8 stateful tests (256 runs each)
- **Scenario Tests** - 25 real-world usage patterns
- **Private Event Tests** - 12 access control and privacy tests
- **Location Tests** - 10 GPS and venue system tests
- **ERC20 Payment Tests** - 15 multi-currency transaction tests

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

**This protocol has not been audited. Use at your own risk.**

## Gas Usage

| Operation | ETH Gas | ERC20 Gas |
|-----------|---------|-----------|
| Create Event | 391,143 | N/A |
| Create Event + Location | 398,180 | N/A |
| Purchase Tickets | 153,928 | 195,440 |
| Purchase with Platform Fee | ~165,000 | ~210,000 |
| Private Event Invitations | 71,758 | N/A |
| Check-in Operations | 69,378 - 82,124 | N/A |
| Social Operations (RSVP/Friends) | 24,243 - 78,604 | N/A |
| ERC20 Tips | N/A | 117,041 |
| ERC20 Withdrawals | N/A | 53,918 |
| Location Queries | 12,545 | N/A |

*Note: Gas usage measured on latest protocol version. Actual usage may vary based on transaction complexity, network conditions, and specific parameters used.*

## Integration Examples

### Frontend Integration
```javascript
import { keccak256, toBytes } from 'viem';
import { publicClient, walletClient } from './config'; // your viem client setup

// Create event (NO ETH VALUE REQUIRED - creation is free)
const tx = await walletClient.writeContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'createEvent',
  args: [params, ticketTiers, paymentSplits] // params includes latitude/longitude
  // NO value parameter - event creation is free!
});

// Purchase tickets with USDC (platform fee charged here, not creation)
await walletClient.writeContract({
  address: USDC_ADDRESS,
  abi: erc20Abi,
  functionName: 'approve',
  args: [ASSEMBLE_ADDRESS, ticketPrice]
});

await walletClient.writeContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'purchaseTicketsERC20',
  args: [eventId, tierId, quantity, USDC_ADDRESS]
});

// Purchase with platform fee (2% to venue partner)
await walletClient.writeContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'purchaseTickets',
  args: [eventId, tierId, quantity, venuePartnerAddress, 200], // 200 = 2%
  value: ticketPrice
});

// Check venue credentials
const venueHash = keccak256(toBytes(venueName));
const credTokenId = await publicClient.readContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'generateTokenId',
  args: [4, 0, venueHash, 0] // TokenType.VENUE_CRED = 4
});
const hasCredential = await publicClient.readContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'balanceOf',
  args: [organizer, credTokenId]
});
```

### API Integration
```javascript
import { keccak256, toBytes } from 'viem';
import { publicClient } from './config';

// Location-based event discovery
const events = await fetchEventsNearLocation(latitude, longitude, radiusKm);

// Multi-currency price display
const prices = {
  eth: await publicClient.readContract({
    address: ASSEMBLE_ADDRESS,
    abi: assembleAbi,
    functionName: 'calculatePrice',
    args: [eventId, tierId, quantity]
  }),
  usdc: await getUSDCPrice(eventId, tierId, quantity),
  dai: await getDAIPrice(eventId, tierId, quantity)
};

// Venue reputation display
const venueHash = keccak256(toBytes(venueName));
const venueStats = {
  eventCount: await publicClient.readContract({
    address: ASSEMBLE_ADDRESS,
    abi: assembleAbi,
    functionName: 'venueEventCount',
    args: [venueHash]
  }),
  hasCredential: await publicClient.readContract({
    address: ASSEMBLE_ADDRESS,
    abi: assembleAbi,
    functionName: 'balanceOf',
    args: [organizer, credTokenId]
  }) > 0
};
```

## Fee Structure

### **Protocol Fees (Fixed)**
- **Rate**: 0.5% (50 basis points) by default, maximum 10%
- **Charged On**: All ticket purchases and tips
- **Goes To**: Protocol treasury (`feeTo` address)
- **Purpose**: Protocol maintenance and development

### **Platform Fees (Optional)**
- **Rate**: 0-5% (0-500 basis points) - set per transaction
- **Charged On**: Ticket purchases and tips (when specified)
- **Goes To**: Referrer/platform address specified in transaction
- **Purpose**: Ecosystem growth, venue partnerships, influencer rewards

## Fee Examples & Calculations

### **Example 1: Basic Ticket Purchase (Protocol Fee Only)**
```javascript
// User buys 1 ticket for 0.1 ETH - NO platform fee
await walletClient.writeContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'purchaseTickets',
  args: [eventId, 0, 1], // No referrer, no platform fee
  value: parseEther('0.1') // 0.1 ETH
});

// Fee calculation:
// Ticket price: 0.1 ETH
// Protocol fee: 0.1 ETH × 0.5% = 0.0005 ETH (goes to protocol)
// Net to organizer: 0.1 ETH - 0.0005 ETH = 0.0995 ETH
```

### **Example 2: Ticket Purchase with Platform Fee**
```javascript
// User buys 1 ticket for 0.1 ETH with 2% platform fee to venue partner
await walletClient.writeContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'purchaseTickets',
  args: [eventId, 0, 1, venuePartnerAddress, 200], // 200 = 2% platform fee
  value: parseEther('0.1')
});

// Fee calculation (order: Platform fee → Protocol fee → Event splits):
// 1. Ticket price: 0.1 ETH
// 2. Platform fee: 0.1 ETH × 2% = 0.002 ETH (goes to venue partner)
// 3. Remaining: 0.1 ETH - 0.002 ETH = 0.098 ETH
// 4. Protocol fee: 0.098 ETH × 0.5% = 0.00049 ETH (goes to protocol)
// 5. Net to organizer: 0.098 ETH - 0.00049 ETH = 0.09751 ETH
```

### **Example 3: Event Tip with Platform Fee**
```javascript
// User tips 0.05 ETH with 1.5% platform fee to influencer
await walletClient.writeContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'tipEvent',
  args: [eventId, influencerAddress, 150], // 150 = 1.5% platform fee
  value: parseEther('0.05')
});

// Fee calculation:
// 1. Tip amount: 0.05 ETH
// 2. Platform fee: 0.05 ETH × 1.5% = 0.00075 ETH (goes to influencer)
// 3. Remaining: 0.05 ETH - 0.00075 ETH = 0.04925 ETH
// 4. Protocol fee: 0.04925 ETH × 0.5% = 0.00024625 ETH (goes to protocol)
// 5. Net to event splits: 0.04925 ETH - 0.00024625 ETH = 0.04900375 ETH
```

### **Example 4: ERC20 Payment with Platform Fee**
```javascript
// User buys ticket with 100 USDC + 3% platform fee to venue
await erc20Contract.writeContract({
  functionName: 'approve',
  args: [ASSEMBLE_ADDRESS, parseUnits('100', 6)] // USDC has 6 decimals
});

await walletClient.writeContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'purchaseTicketsERC20',
  args: [eventId, 0, 1, USDC_ADDRESS, venueAddress, 300] // 300 = 3%
});

// Fee calculation (USDC amounts):
// 1. Ticket price: 100 USDC
// 2. Platform fee: 100 USDC × 3% = 3 USDC (goes to venue)
// 3. Remaining: 100 USDC - 3 USDC = 97 USDC
// 4. Protocol fee: 97 USDC × 0.5% = 0.485 USDC (goes to protocol)
// 5. Net to organizer: 97 USDC - 0.485 USDC = 96.515 USDC
```

### **Example 5: Multi-Split Event Revenue**
```javascript
// Event with payment splits: 60% organizer, 30% artist, 10% venue
const paymentSplits = [
  { recipient: organizerAddress, bps: 6000 }, // 60%
  { recipient: artistAddress, bps: 3000 },   // 30%
  { recipient: venueAddress, bps: 1000 }     // 10%
];

// User tips 1 ETH with 2% platform fee to promoter
await walletClient.writeContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'tipEvent',
  args: [eventId, promoterAddress, 200], // 200 = 2%
  value: parseEther('1.0')
});

// Fee calculation & distribution:
// 1. Tip amount: 1.0 ETH
// 2. Platform fee: 1.0 ETH × 2% = 0.02 ETH → promoterAddress
// 3. Remaining: 1.0 ETH - 0.02 ETH = 0.98 ETH
// 4. Protocol fee: 0.98 ETH × 0.5% = 0.0049 ETH → protocol treasury
// 5. Net for splits: 0.98 ETH - 0.0049 ETH = 0.9751 ETH
// 6. Distribution:
//    - Organizer: 0.9751 ETH × 60% = 0.58506 ETH
//    - Artist: 0.9751 ETH × 30% = 0.29253 ETH  
//    - Venue: 0.9751 ETH × 10% = 0.09751 ETH
```

### **Example 6: Platform Fee for Ecosystem Partners**
```javascript
// Music venue gets 2% for hosting/promoting
await walletClient.writeContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'purchaseTickets',
  args: [eventId, 0, 2, musicVenueAddress, 200], // 2 tickets, 2% to venue
  value: parseEther('0.2') // 0.1 ETH per ticket
});

// Event discovery platform gets 1% for driving traffic
await walletClient.writeContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'tipEvent',
  args: [eventId, eventPlatformAddress, 100], // 1% to platform
  value: parseEther('0.1')
});

// Social media influencer gets 2.5% for promotion
await walletClient.writeContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'purchaseTickets',
  args: [eventId, 1, 1, influencerAddress, 250], // 2.5% to influencer
  value: parseEther('0.15')
});
```

### **Reading Fee Information**
```javascript
// Check current protocol fee rate
const protocolFeeBps = await publicClient.readContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'protocolFeeBps'
});
console.log(`Protocol fee: ${protocolFeeBps / 100}%`); // e.g., "Protocol fee: 0.5%"

// Check pending withdrawals (includes fees received)
const pendingFees = await publicClient.readContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'pendingWithdrawals',
  args: [feeRecipientAddress]
});

// Check ERC20 fees pending
const pendingUSDC = await publicClient.readContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'pendingERC20Withdrawals',
  args: [USDC_ADDRESS, feeRecipientAddress]
});
```

### **Event Cancellation & Refunds**
- **Creation Cost**: ✅ **FREE** - No fees to create events
- **Cancellation**: Events can be cancelled before start time
- **Refund Window**: 90 days after cancellation
- **Full Refunds**: Users get back exactly what they paid for tickets/tips
- **Protocol Fees**: Not refunded (already used for infrastructure)
- **Platform Fees**: Not refunded (already paid to referrers)

```javascript
// Example: Event cancelled, user gets refund
// User originally paid: 0.1 ETH for ticket
// Platform fee: 0.002 ETH (already paid to venue partner - not refunded)
// Protocol fee: 0.00049 ETH (already paid to protocol - not refunded)  
// User refund: 0.1 ETH (full original ticket price returned)

await walletClient.writeContract({
  address: ASSEMBLE_ADDRESS,
  abi: assembleAbi,
  functionName: 'claimTicketRefund',
  args: [cancelledEventId]
});
// User receives back: 0.1 ETH (their full ticket payment)
```

## Deployment

### Live Deployments

Assemble Protocol is deployed with **identical vanity addresses** across 8 networks:

**Mainnet (Chain ID: 1):**
- **Assemble**: `0x000000000a020d45fFc5cfcF7B28B5020ddd6a85` ✅ [Verified](https://etherscan.io/address/0x000000000a020d45fFc5cfcF7B28B5020ddd6a85)
- **SocialLibrary**: `0xebE033f26d5CAb84F5C174C882e2e036F59FAD55` ✅ [Verified](https://etherscan.io/address/0xebE033f26d5CAb84F5C174C882e2e036F59FAD55)

**Sepolia Testnet (Chain ID: 11155111):**
- **Assemble**: `0x000000000a020d45fFc5cfcF7B28B5020ddd6a85` ✅ [Verified](https://sepolia.etherscan.io/address/0x000000000a020d45fFc5cfcF7B28B5020ddd6a85)
- **SocialLibrary**: `0xebE033f26d5CAb84F5C174C882e2e036F59FAD55` ✅ [Verified](https://sepolia.etherscan.io/address/0xebE033f26d5CAb84F5C174C882e2e036F59FAD55)

**Base Mainnet (Chain ID: 8453):**
- **Assemble**: `0x000000000a020d45fFc5cfcF7B28B5020ddd6a85` ✅ [Verified](https://basescan.org/address/0x000000000a020d45fFc5cfcF7B28B5020ddd6a85)
- **SocialLibrary**: `0xebE033f26d5CAb84F5C174C882e2e036F59FAD55` ✅ [Verified](https://basescan.org/address/0xebE033f26d5CAb84F5C174C882e2e036F59FAD55)

**Base Sepolia (Chain ID: 84532):**
- **Assemble**: `0x000000000a020d45fFc5cfcF7B28B5020ddd6a85` ✅ [Verified](https://sepolia.basescan.org/address/0x000000000a020d45fFc5cfcF7B28B5020ddd6a85)
- **SocialLibrary**: `0xebE033f26d5CAb84F5C174C882e2e036F59FAD55` ✅ [Verified](https://sepolia.basescan.org/address/0xebE033f26d5CAb84F5C174C882e2e036F59FAD55)

**Optimism (Chain ID: 10):**
- **Assemble**: `0x000000000a020d45fFc5cfcF7B28B5020ddd6a85` ✅ [Verified](https://optimistic.etherscan.io/address/0x000000000a020d45fFc5cfcF7B28B5020ddd6a85)
- **SocialLibrary**: `0xebE033f26d5CAb84F5C174C882e2e036F59FAD55` ✅ [Verified](https://optimistic.etherscan.io/address/0xebE033f26d5CAb84F5C174C882e2e036F59FAD55)

**Arbitrum One (Chain ID: 42161):**
- **Assemble**: `0x000000000a020d45fFc5cfcF7B28B5020ddd6a85` ✅ [Verified](https://arbiscan.io/address/0x000000000a020d45fFc5cfcF7B28B5020ddd6a85)
- **SocialLibrary**: `0xebE033f26d5CAb84F5C174C882e2e036F59FAD55` ✅ [Verified](https://arbiscan.io/address/0xebE033f26d5CAb84F5C174C882e2e036F59FAD55)

**Polygon (Chain ID: 137):**
- **Assemble**: `0x000000000a020d45fFc5cfcF7B28B5020ddd6a85` ✅ [Deployed](https://polygonscan.com/address/0x000000000a020d45fFc5cfcF7B28B5020ddd6a85) *
- **SocialLibrary**: `0xebE033f26d5CAb84F5C174C882e2e036F59FAD55` ✅ [Deployed](https://polygonscan.com/address/0xebE033f26d5CAb84F5C174C882e2e036F59FAD55) *

**Zora (Chain ID: 7777777):**
- **Assemble**: `0x000000000a020d45fFc5cfcF7B28B5020ddd6a85` ✅ [Verified](https://explorer.zora.energy/address/0x000000000a020d45fFc5cfcF7B28B5020ddd6a85)
- **SocialLibrary**: `0xebE033f26d5CAb84F5C174C882e2e036F59FAD55` ✅ [Verified](https://explorer.zora.energy/address/0xebE033f26d5CAb84F5C174C882e2e036F59FAD55)

*\* Verification failed due to foundry bug #3507 with via_ir compiler setting on PolygonScan*


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
forge test
```

## License

MIT License - see [LICENSE](./LICENSE) for details.

---

**Built with love for the onchain event ecosystem**

*Assemble Protocol - Where events meet the future of web3*