# Assemble Protocol

A singleton smart contract protocol for onchain event management with social coordination features.

*Built with ERC-6909 multi-token standard, EIP-1153 transient storage, and soulbound credentials.*

## Features

- **Event Management** - Multi-tier ticketing with configurable pricing and payment splits
- **Social Graph** - Friends, RSVPs, and social discovery with onchain coordination
- **ERC-6909 Tokens** - Transferrable event tickets and soulbound attendance badges
- **Transient Storage** - Gas-optimized operations using EIP-1153 for batch processing
- **Refund System** - Automatic refunds for cancelled events with 90-day claim window
- **Comment System** - Threaded event discussions with moderation controls

## Architecture

**Singleton Design** - Single contract manages all events, users, and social interactions  
**Multi-Token Standard** - ERC-6909 enables efficient batch operations for tickets and badges  
**Gas Optimization** - EIP-1153 transient storage reduces gas costs for complex operations  
**Soulbound Credentials** - Non-transferable tokens for attendance proof and organizer reputation

### Token Types
- `EVENT_TICKET` - Transferrable tickets for event access
- `ATTENDANCE_BADGE` - Soulbound proof of attendance (ERC-5192)  
- `ORGANIZER_CRED` - Soulbound reputation tokens for event organizers

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

## Security

- **111 comprehensive tests** with fuzz and invariant testing
- **Static analysis** clean (Slither)
- **EIP-1153 reentrancy protection** via transient storage guards
- **Pull payment pattern** for secure fund distribution
- **Soulbound token enforcement** prevents credential transfer

⚠️ **This protocol has not been audited. Use at your own risk.**

## Gas Usage

| Operation | Gas |
|-----------|-----|
| Create Event | ~319k |
| Purchase Tickets | ~158k |
| Social Operations | ~30-140k |

## License

MIT