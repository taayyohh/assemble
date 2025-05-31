# Assemble Protocol

A singleton smart contract protocol for onchain event management with social coordination features.

*Built with ERC-6909 multi-token standard, EIP-1153 transient storage, and soulbound credentials.*

## Features

- **Event Management** - Multi-tier ticketing with configurable pricing and payment splits
- **Private Events** - Invite-only events with access control and curated guest lists
- **Social Graph** - Friends, RSVPs, and social discovery with onchain coordination
- **ERC-6909 Tokens** - Transferrable event tickets and soulbound attendance badges
- **Transient Storage** - Gas-optimized operations using EIP-1153 for batch processing
- **Refund System** - Automatic refunds for cancelled events with 90-day claim window
- **Comment System** - Threaded event discussions with moderation controls
- **Group Check-ins** - Delegate check-in functionality for group ticket purchases

## Architecture

**Singleton Design** - Single contract manages all events, users, and social interactions  
**Multi-Token Standard** - ERC-6909 enables efficient batch operations for tickets and badges  
**Gas Optimization** - EIP-1153 transient storage reduces gas costs for complex operations  
**Soulbound Credentials** - Non-transferable tokens for attendance proof and organizer reputation

### Token Types
- `EVENT_TICKET` - Transferrable tickets for event access
- `ATTENDANCE_BADGE` - Soulbound proof of attendance (ERC-5192)  
- `ORGANIZER_CRED` - Soulbound reputation tokens for event organizers

### Event Visibility Levels
- `PUBLIC` - Open to all users
- `PRIVATE` - Limited visibility  
- `INVITE_ONLY` - Curated guest list with access control

## Quick Start

### Install Dependencies
```bash
forge install
```

### Run Tests
```bash
forge test
```

### Deploy Locally
```bash
# Start local testnet
anvil

# Deploy
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

## Contract API

### Core Functions
```solidity
function createEvent(EventParams calldata params, TicketTier[] calldata tiers, PaymentSplit[] calldata splits) external returns (uint256 eventId)
function purchaseTickets(uint256 eventId, uint256 tierId, uint256 quantity) external payable
function cancelEvent(uint256 eventId) external
function checkIn(uint256 eventId) external
function checkInWithTicket(uint256 eventId, uint256 ticketTokenId) external
function checkInDelegate(uint256 eventId, uint256 ticketTokenId, address attendee) external
```

### Private Event Functions
```solidity
function inviteToEvent(uint256 eventId, address[] calldata invitees) external
function removeInvitation(uint256 eventId, address invitee) external  
function isInvited(uint256 eventId, address user) external view returns (bool)
```

### Social Functions  
```solidity
function addFriend(address friend) external
function updateRSVP(uint256 eventId, RSVPStatus status) external
function postComment(uint256 eventId, string calldata content, uint256 parentId) external
```

## Token ID Structure (ERC-6909)

```
┌─────────────┬─────────────┬─────────────┬─────────────┬─────────────┐
│  TokenType  │   EventId   │   TierId    │ SerialNum   │  Metadata   │
│   (8 bits)  │  (64 bits)  │  (32 bits)  │ (64 bits)   │  (88 bits)  │
└─────────────┴─────────────┴─────────────┴─────────────┴─────────────┘
```

Single uint256 encodes token type, event reference, tier information, and unique serial number.

## Private Events

Perfect for exclusive gatherings, private parties, corporate events, and curated experiences:

```solidity
// Create invite-only event
EventParams memory params = EventParams({
    // ... event details ...
    visibility: EventVisibility.INVITE_ONLY
});
uint256 eventId = assemble.createEvent(params, tiers, splits);

// Invite guests
address[] memory guests = [alice, bob, charlie];
assemble.inviteToEvent(eventId, guests);

// Only invited users can purchase tickets
// assemble.purchaseTickets{value: price}(eventId, 0, 1); // ✅ Invited users
// assemble.purchaseTickets{value: price}(eventId, 0, 1); // ❌ Non-invited users revert
```

**Use Cases:**
- Wedding celebrations with guest list management
- Exclusive art gallery openings
- Private corporate retreats
- VIP product launches
- Community gatherings with controlled access

## Security

- **126 comprehensive tests** with fuzz and invariant testing
- **Static analysis** clean (Slither, zero security issues)
- **EIP-1153 reentrancy protection** via transient storage guards
- **Pull payment pattern** for secure fund distribution
- **Soulbound token enforcement** prevents credential transfer
- **Gas-optimized** contract under 24KB limit (23,816 bytes runtime)

⚠️ **This protocol has not been audited. Use at your own risk.**

## Gas Usage

| Operation | Gas |
|-----------|-----|
| Create Event | 538,611 |
| Purchase Tickets | 221,345 |
| Private Invitations | 78,968 |
| Check-in Operations | 74,163 |
| Social Operations | 33,080 - 91,663 |

## Testing Coverage

- **32** core functionality tests
- **17** security tests  
- **23** edge case tests
- **9** fuzz tests (1000 runs each)
- **8** invariant tests (256 runs each)
- **25** real-world scenario tests
- **12** private event tests

## License

MIT