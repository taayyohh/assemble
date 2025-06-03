// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 ██████╗ ███████╗███████╗███████╗███╗   ███╗██████╗ ██╗     ███████╗
██╔═══██╗██╔════╝██╔════╝██╔════╝████╗ ████║██╔══██╗██║     ██╔════╝
███████║███████╗███████╗█████╗  ██╔████╔██║██████╔╝██║     █████╗  
██╔══██║╚════██║╚════██║██╔══╝  ██║╚██╔╝██║██╔══██╗██║     ██╔══╝  
██║  ██║███████║███████║███████╗██║ ╚═╝ ██║██████╔╝███████╗███████╗
╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝     ╚═╝╚═════╝ ╚══════╝╚══════╝
                                                                     
    🌟 Decentralized Event Management Protocol 🌟
         Building the future of events onchain
*/

import { SocialLibrary } from "./libraries/SocialLibrary.sol";
import { CommentLibrary } from "./libraries/CommentLibrary.sol";

/// @title Assemble - Decentralized Event Management Protocol
/// @notice A comprehensive protocol for managing events, tickets, social interactions, and payments onchain
/// @dev Uses ERC-6909 for multi-token functionality and EIP-1153 for gas optimization
/// @author taayyohh
contract Assemble {
    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    // Validation errors (consolidated address/input validation)
    error BadInput(); // Replaces: BadAddr, BadRef, BadRecipient, BadContent, BadQty, BadCap
    
    // Timing errors (consolidated time-related errors)  
    error BadTiming(); // Replaces: BadTime, BadEndTime, BadSaleTimes, NotStarted, Ended, EventOver, NotEventTime
    
    // Authorization errors (consolidated permission errors)
    error NotAuth(); // Keeps existing, replaces: NotOrganizer, NoPerms, WrongOrg
    
    // Supply/capacity errors (consolidated quantity errors)
    error NoSupply(); // Keeps existing, replaces: NoSpace, NoTiers
    
    // Payment errors (consolidated fee/payment errors)
    error BadPayment(); // Replaces: BadBps, BadTotal, FeeHigh, PlatformHigh, NeedMore, NeedValue
    
    // State errors (consolidated state validation)
    error BadState(); // Replaces: NotActive, Started, Cancelled, NotCancelled, Used, NotDone, NotExpired
    
    // Resource errors (consolidated missing resource errors)
    error NotFound(); // Replaces: NoEvent, NoTier, NoParent, NoSplits, NoTicket, NoFunds, NoRefund
    
    // Operation errors (consolidated operation failures)
    error OpFailed(); // Replaces: TransferFail, RefundFail, Expired, Soulbound
    
    // Social errors (consolidated social feature errors)
    error SocialError(); // Replaces: CantAddSelf, AlreadyFriends, NotFriends, AlreadyInvited, NotInvited, NotPrivate
    
    // Keep essential specific errors that are used frequently
    error TooMany();
    error UnsupportedToken();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum number of payment splits per event for gas optimization
    uint256 public constant MAX_PAYMENT_SPLITS = 20;

    /// @notice Maximum ticket quantity per purchase to prevent gas limit issues
    uint256 public constant MAX_TICKET_QUANTITY = 50;

    /// @notice Maximum protocol fee (10%) for governance limits
    uint256 public constant MAX_PROTOCOL_FEE = 1000;

    /// @notice Maximum platform fee (5%) to prevent abuse while incentivizing platforms
    uint256 public constant MAX_PLATFORM_FEE = 500;

    /// @notice Refund claim deadline (90 days after cancellation)
    uint256 public constant REFUND_CLAIM_DEADLINE = 90 days;

    /*//////////////////////////////////////////////////////////////
                        TRANSIENT STORAGE SLOTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transient storage slot for reentrancy protection
    uint256 private constant REENTRANCY_SLOT = 0x1003;

    /*//////////////////////////////////////////////////////////////
                                ENUMS & STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Token types for ERC-6909 multi-token system
    enum TokenType {
        NONE,
        EVENT_TICKET, // Transferrable event tickets
        ATTENDANCE_BADGE, // Soulbound attendance proof (ERC-5192)
        ORGANIZER_CRED, // Soulbound organizer reputation
        VENUE_CRED // Soulbound venue credentials
    }

    /// @notice Event visibility levels
    enum EventVisibility {
        PUBLIC,
        PRIVATE,
        INVITE_ONLY
    }

    /// @notice Event status for cancellation handling
    enum EventStatus {
        ACTIVE,
        CANCELLED,
        COMPLETED
    }

    /// @notice ULTRA-OPTIMIZED storage for events (64 bytes, 2 slots)
    struct PackedEventData {
        // SLOT 1: 32 bytes
        uint128 basePrice;          // 16 bytes: Event base price
        uint128 locationData;       // 16 bytes: lat(8) + lng(8) packed
        
        // SLOT 2: 32 bytes
        uint64 startTime;           // 8 bytes: Event start timestamp
        uint32 capacity;            // 4 bytes: Max attendees
        uint64 venueHash;           // 8 bytes: Venue identifier hash
        uint16 tierCount;           // 2 bytes: Number of ticket tiers
        uint8 visibility;           // 1 byte: Public/Private/Invite
        uint8 status;               // 1 byte: Active/Cancelled/Complete
        uint8 flags;                // 1 byte: Feature flags
        uint8 reserved;             // 1 byte: Future expansion
        uint32 padding;             // 4 bytes: Alignment
    }

    /// @notice Event creation parameters
    struct EventParams {
        string title;
        string description;
        string imageUri; // IPFS hash for event image
        uint256 startTime;
        uint256 endTime;
        uint256 capacity;
        int64 latitude;             // 1e-7 precision (11mm accuracy)
        int64 longitude;            // 1e-7 precision
        string venueName;           // Venue name for hash generation
        EventVisibility visibility;
    }

    /// @notice Ticket tier configuration
    struct TicketTier {
        string name; // "Early Bird", "VIP", "General"
        uint256 price; // Price in wei
        uint256 maxSupply; // Maximum tickets for this tier
        uint256 sold; // Tickets sold so far
        uint256 startSaleTime; // When this tier becomes available
        uint256 endSaleTime; // When this tier stops being available
        bool transferrable; // Whether tickets can be resold
    }

    /// @notice Payment split configuration for revenue distribution
    struct PaymentSplit {
        address recipient;
        uint256 basisPoints;
    }

    /// @notice Token ID structure for ERC-6909 (256 bits)
    struct TokenId {
        uint8 tokenType;
        uint64 eventId;
        uint32 tierId;
        uint64 serialNumber;
        uint88 metadata;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Next event ID counter
    uint256 public nextEventId = 1;

    /// @notice Next comment ID counter
    uint256 public nextCommentId = 1;

    /// @notice Protocol fee in basis points (0.5% = 50 bps)
    uint256 public protocolFeeBps = 50;

    /// @notice Address that receives protocol fees
    address public feeTo;

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/

    // Core event data (keep public for external queries)
    mapping(uint256 => PackedEventData) public events;
    mapping(uint256 => address) public eventOrganizers;
    mapping(uint256 => mapping(uint256 => TicketTier)) public ticketTiers;

    // Make most mappings private to save bytecode
    mapping(uint256 => string) private eventMetadata;
    mapping(uint256 => PaymentSplit[]) private eventPaymentSplits;

    // Comment system - keep essential ones public
    mapping(uint256 => CommentLibrary.Comment) public comments;
    mapping(uint256 => uint256[]) private eventComments;

    // Security: Pull payment pattern
    mapping(address => uint256) public pendingWithdrawals;

    // Social graph - make private except core ones
    mapping(address => mapping(address => bool)) public isFriend;
    mapping(address => address[]) private friendLists;
    mapping(uint256 => mapping(address => SocialLibrary.RSVPStatus)) public rsvps;

    // ERC-6909 core storage (keep public for standard compliance)
    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public allowance;
    mapping(address => mapping(address => bool)) public isOperator;
    mapping(uint256 => uint256) public totalSupply;

    // Refund tracking - make public for test access
    mapping(uint256 => mapping(address => uint256)) public userTicketPayments;
    mapping(uint256 => mapping(address => uint256)) public userTipPayments;
    mapping(uint256 => uint256) private eventCancellationTime;

    // Attendance tracking
    mapping(uint256 => bool) public usedTickets;

    // Invite system for private events
    mapping(uint256 => mapping(address => bool)) public eventInvites;

    // V2.0 MINIMAL ADDITIONS - Reuse existing patterns for size efficiency
    
    /// @notice Venue tracking - reuse totalReferralFees pattern for size efficiency
    mapping(uint64 => uint256) public venueEventCount;
    
    /// @notice Simple token whitelist - minimal storage
    mapping(address => bool) public supportedTokens;

    /// @notice ERC20 pending withdrawals - essential for multi-currency
    mapping(address => mapping(address => uint256)) public pendingERC20Withdrawals;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    // Core protocol events
    event EventCreated(uint256 indexed eventId, address indexed organizer, uint256 startTime);
    event TicketPurchased(uint256 indexed eventId, address indexed buyer, uint256 quantity, uint256 price);
    event FundsClaimed(address indexed recipient, uint256 amount);
    event EventTipped(uint256 indexed eventId, address indexed tipper, uint256 amount);

    // Comment system events
    event CommentPosted(uint256 indexed eventId, uint256 indexed commentId, address indexed author, uint256 parentId);

    // Admin events
    event FeeToUpdated(address indexed oldFeeTo, address indexed newFeeTo);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event EventCancelled(uint256 indexed eventId, address indexed organizer, uint256 timestamp);
    event RefundClaimed(uint256 indexed eventId, address indexed user, uint256 amount);

    // Platform fee events
    event PlatformFeeAllocated(uint256 indexed eventId, address indexed referrer, uint256 amount, uint256 feeBps);

    // ERC-6909 events
    event Transfer(address indexed caller, address indexed from, address indexed to, uint256 id, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);
    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    // Invite system events
    event UserInvited(uint256 indexed eventId, address indexed invitee, address indexed organizer);

    // V2.0 events
    event VenueCredentialMinted(address indexed organizer, uint64 indexed venueHash);
    event TokenSupportUpdated(address indexed token, bool supported);
    event ERC20FundsClaimed(address indexed user, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reentrancy protection using EIP-1153 transient storage
    modifier nonReentrant() {
        assembly {
            if tload(REENTRANCY_SLOT) { revert(0, 0) }
            tstore(REENTRANCY_SLOT, 1)
        }
        _;
        assembly {
            tstore(REENTRANCY_SLOT, 0)
        }
    }

    /// @notice Only fee recipient modifier
    modifier onlyFeeTo() {
        if (msg.sender != feeTo) revert NotAuth();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Assemble protocol
    /// @param _feeTo Initial fee recipient address
    constructor(address _feeTo) {
        if (_feeTo == address(0)) revert BadPayment();
        feeTo = _feeTo;
        emit FeeToUpdated(address(0), _feeTo);
    }

    /*//////////////////////////////////////////////////////////////
                        CORE PROTOCOL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a new event with ticket tiers and payment splits
    /// @param params Event configuration parameters
    /// @param tiers Array of ticket tier configurations
    /// @param splits Array of payment split configurations
    /// @return eventId The ID of the created event
    function createEvent(
        EventParams calldata params,
        TicketTier[] calldata tiers,
        PaymentSplit[] calldata splits
    )
        external
        returns (uint256 eventId)
    {
        // Input validation
        if (params.startTime <= block.timestamp) revert BadTiming();
        if (params.endTime <= params.startTime) revert BadTiming();
        if (tiers.length == 0) revert NoSupply();
        if (params.capacity == 0) revert BadPayment();

        // Inline coordinate validation (more efficient than library call)
        if (params.latitude < -900000000 || params.latitude > 900000000) revert BadInput();
        if (params.longitude < -1800000000 || params.longitude > 1800000000) revert BadInput();

        // Validate payment splits
        _validatePaymentSplits(splits);

        // Generate event ID
        eventId = nextEventId++;

        // Inline venue hash generation (more efficient than library call)
        uint64 venueHash = uint64(uint256(keccak256(abi.encodePacked(params.venueName))));

        // Inline location packing (more efficient than library call)
        uint128 locationData = (uint128(uint64(params.latitude)) << 64) | uint128(uint64(params.longitude));

        // Pack event data for gas efficiency
        events[eventId] = PackedEventData({
            basePrice: uint128(tiers[0].price),
            locationData: locationData,
            startTime: uint64(params.startTime),
            capacity: uint32(params.capacity),
            venueHash: venueHash,
            tierCount: uint16(tiers.length),
            visibility: uint8(params.visibility),
            status: 0, // ACTIVE = 0, avoid enum cast
            flags: 0,
            reserved: 0,
            padding: 0
        });

        // Store metadata and organizer
        eventMetadata[eventId] = params.imageUri;
        eventOrganizers[eventId] = msg.sender;

        // Update venue event count and mint credential for organizers at this venue (soulbound)
        venueEventCount[venueHash]++;
        
        // Check if this organizer already has a credential for this venue
        uint256 credentialTokenId = generateTokenId(TokenType.VENUE_CRED, 0, venueHash, 0);
        if (balanceOf[msg.sender][credentialTokenId] == 0) {
            _mint(msg.sender, credentialTokenId, 1);
            emit VenueCredentialMinted(msg.sender, venueHash);
        }

        // Store ticket tiers
        uint256 tiersLength = tiers.length;
        for (uint256 i = 0; i < tiersLength;) {
            if (tiers[i].maxSupply == 0) revert NoSupply();
            if (tiers[i].startSaleTime > tiers[i].endSaleTime) revert BadTiming();
            ticketTiers[eventId][i] = tiers[i];
            unchecked {
                ++i;
            }
        }

        // Store payment splits
        uint256 splitsLength = splits.length;
        for (uint256 i = 0; i < splitsLength;) {
            eventPaymentSplits[eventId].push(splits[i]);
            unchecked {
                ++i;
            }
        }

        emit EventCreated(eventId, msg.sender, params.startTime);
    }

    /*//////////////////////////////////////////////////////////////
                        TICKET PURCHASING SYSTEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Purchase tickets for an event with dynamic pricing
    /// @param eventId The event to purchase tickets for
    /// @param tierId The ticket tier to purchase
    /// @param quantity Number of tickets to purchase
    function purchaseTickets(uint256 eventId, uint256 tierId, uint256 quantity) external payable nonReentrant {
        _purchaseTickets(eventId, tierId, quantity, address(0), 0);
    }

    /// @notice Purchase tickets with platform fee support
    /// @param eventId The event to purchase tickets for
    /// @param tierId The ticket tier to purchase
    /// @param quantity Number of tickets to purchase
    /// @param referrer Optional platform/referrer address to receive platform fee
    /// @param platformFeeBps Platform fee in basis points (0-500, max 5%)
    function purchaseTickets(
        uint256 eventId,
        uint256 tierId,
        uint256 quantity,
        address referrer,
        uint256 platformFeeBps
    )
        external
        payable
        nonReentrant
    {
        _purchaseTickets(eventId, tierId, quantity, referrer, platformFeeBps);
    }

    /// @notice Internal function to handle ticket purchases with optional platform fees
    function _purchaseTickets(
        uint256 eventId,
        uint256 tierId,
        uint256 quantity,
        address referrer,
        uint256 platformFeeBps
    )
        internal
    {
        // CHECKS: Validate inputs and event state
        if (events[eventId].startTime == 0) revert NotFound();
        if (quantity == 0 || quantity > MAX_TICKET_QUANTITY) revert BadPayment();

        TicketTier storage tier = ticketTiers[eventId][tierId];
        if (tier.maxSupply == 0) revert NoSupply();
        if (block.timestamp < tier.startSaleTime) revert BadTiming();
        if (block.timestamp > tier.endSaleTime) revert BadTiming();
        if (tier.sold + quantity > tier.maxSupply) revert BadPayment();

        // Validate platform fee parameters
        if (platformFeeBps > MAX_PLATFORM_FEE) revert BadPayment();
        if (platformFeeBps > 0 && referrer == address(0)) revert BadInput();
        if (referrer == msg.sender) revert BadInput(); // Prevent self-referral

        // Check event visibility and access permissions
        if (
            events[eventId].visibility == 2 && !eventInvites[eventId][msg.sender]
        ) {
            revert SocialError();
        }

        // INLINE price calculation (eliminating calculatePrice function)
        uint256 basePrice = tier.price;
        uint256 totalCost = basePrice * quantity;
        if (totalCost == 0 && basePrice > 0) totalCost = 1; // Minimum price for paid tickets
        
        if (msg.value < totalCost) revert BadPayment();

        // EFFECTS: Update state before external calls
        tier.sold += quantity;

        // Track payment for potential refunds
        userTicketPayments[eventId][msg.sender] += totalCost;

        // Mint ERC-6909 tickets - use unique IDs to avoid collisions
        for (uint256 i = 0; i < quantity;) {
            uint256 tokenId = generateTokenId(TokenType.EVENT_TICKET, eventId, tierId, tier.sold - quantity + i + 1);
            _mint(msg.sender, tokenId, 1);
            unchecked { ++i; }
        }

        // Calculate and distribute payments
        // Order: Platform fee -> Protocol fee -> Event payment splits
        uint256 platformFee = 0;
        if (referrer != address(0) && platformFeeBps > 0) {
            platformFee = (totalCost * platformFeeBps) / 10_000;
            pendingWithdrawals[referrer] += platformFee;
            emit PlatformFeeAllocated(eventId, referrer, platformFee, platformFeeBps);
        }

        uint256 remainingAmount = totalCost - platformFee;
        uint256 protocolFee = (remainingAmount * protocolFeeBps) / 10_000;
        uint256 netAmount = remainingAmount - protocolFee;

        // Add protocol fee to pending withdrawals
        if (protocolFee > 0 && feeTo != address(0)) {
            pendingWithdrawals[feeTo] += protocolFee;
        }

        // Distribute net amount according to payment splits
        _distributePayment(eventId, netAmount);

        // INTERACTIONS: Refund excess payment last
        if (msg.value > totalCost) {
            (bool success,) = payable(msg.sender).call{ value: msg.value - totalCost }("");
            if (!success) revert OpFailed();
        }

        emit TicketPurchased(eventId, msg.sender, quantity, totalCost);
    }

    /// @notice Tip an event directly (independent of ticket sales)
    /// @param eventId Event to tip
    /// @dev Tips are distributed according to the event's payment splits, allowing flexible recipient allocation
    /// @dev Example: Birthday party where birthday person gets 80%, organizer gets 20% via payment splits
    function tipEvent(uint256 eventId) external payable nonReentrant {
        _tipEvent(eventId, address(0), 0);
    }

    /// @notice Tip an event with platform fee support
    /// @param eventId Event to tip
    /// @param referrer Optional platform/referrer address to receive platform fee
    /// @param platformFeeBps Platform fee in basis points (0-500, max 5%)
    function tipEvent(uint256 eventId, address referrer, uint256 platformFeeBps) external payable nonReentrant {
        _tipEvent(eventId, referrer, platformFeeBps);
    }

    /// @notice Internal function to handle event tips with optional platform fees
    function _tipEvent(uint256 eventId, address referrer, uint256 platformFeeBps) internal {
        if (events[eventId].startTime == 0) revert NotFound();
        if (msg.value == 0) revert BadPayment();

        // Validate platform fee parameters
        if (platformFeeBps > MAX_PLATFORM_FEE) revert BadPayment();
        if (platformFeeBps > 0 && referrer == address(0)) revert BadInput();
        if (referrer == msg.sender) revert BadInput();

        // Track tip for potential refunds
        userTipPayments[eventId][msg.sender] += msg.value;

        // Calculate and distribute fees
        // Order: Platform fee -> Protocol fee -> Event payment splits
        uint256 platformFee = 0;
        if (referrer != address(0) && platformFeeBps > 0) {
            platformFee = (msg.value * platformFeeBps) / 10_000;
            pendingWithdrawals[referrer] += platformFee;
            emit PlatformFeeAllocated(eventId, referrer, platformFee, platformFeeBps);
        }

        uint256 remainingAmount = msg.value - platformFee;
        uint256 protocolFee = (remainingAmount * protocolFeeBps) / 10_000;
        uint256 netAmount = remainingAmount - protocolFee;

        // Add protocol fee to pending withdrawals
        if (protocolFee > 0 && feeTo != address(0)) {
            pendingWithdrawals[feeTo] += protocolFee;
        }

        // Distribute net amount according to payment splits (can direct tips to specific recipients!)
        _distributePayment(eventId, netAmount);

        emit EventTipped(eventId, msg.sender, msg.value);
    }

    /// @notice Claim pending funds (pull payment pattern)
    function claimFunds() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert NotFound();

        // Effects before interactions
        pendingWithdrawals[msg.sender] = 0;

        // Safe transfer
        (bool success,) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert OpFailed();

        emit FundsClaimed(msg.sender, amount);
    }

    /// @notice Purchase tickets using ERC20 (minimal implementation)
    function purchaseTicketsERC20(uint256 eventId, uint256 tierId, uint256 quantity, address token) external nonReentrant {
        if (events[eventId].startTime == 0) revert NotFound();
        if (!supportedTokens[token]) revert UnsupportedToken();
        if (quantity == 0 || quantity > MAX_TICKET_QUANTITY) revert BadPayment();

        TicketTier storage tier = ticketTiers[eventId][tierId];
        if (tier.maxSupply == 0) revert NoSupply();
        if (block.timestamp < tier.startSaleTime) revert BadTiming();
        if (block.timestamp > tier.endSaleTime) revert BadTiming();
        if (tier.sold + quantity > tier.maxSupply) revert BadPayment();

        if (events[eventId].visibility == 2 && !eventInvites[eventId][msg.sender]) revert SocialError();

        uint256 totalCost = tier.price * quantity;
        if (totalCost == 0) revert BadPayment();

        tier.sold += quantity;

        for (uint256 i = 0; i < quantity;) {
            uint256 tokenId = generateTokenId(TokenType.EVENT_TICKET, eventId, tierId, tier.sold - quantity + i + 1);
            _mint(msg.sender, tokenId, 1);
            unchecked { ++i; }
        }

        (bool success,) = token.call(abi.encodeWithSelector(0x23b872dd, msg.sender, address(this), totalCost));
        if (!success) revert OpFailed();

        uint256 protocolFee = (totalCost * protocolFeeBps) / 10_000;
        uint256 netAmount = totalCost - protocolFee;

        if (protocolFee > 0) pendingERC20Withdrawals[token][feeTo] += protocolFee;

        PaymentSplit[] storage splits = eventPaymentSplits[eventId];
        for (uint256 i = 0; i < splits.length;) {
            uint256 payment = (netAmount * splits[i].basisPoints) / 10_000;
            pendingERC20Withdrawals[token][splits[i].recipient] += payment;
            unchecked { ++i; }
        }

        emit TicketPurchased(eventId, msg.sender, quantity, totalCost);
    }

    /// @notice Purchase tickets using ERC20 with platform fee
    function purchaseTicketsERC20(uint256 eventId, uint256 tierId, uint256 quantity, address token, address referrer, uint256 platformFeeBps) external nonReentrant {
        if (events[eventId].startTime == 0) revert NotFound();
        if (!supportedTokens[token]) revert UnsupportedToken();
        if (platformFeeBps > MAX_PLATFORM_FEE) revert BadPayment();
        if (platformFeeBps > 0 && referrer == address(0)) revert BadInput();
        if (referrer == msg.sender) revert BadInput();
        if (quantity == 0 || quantity > MAX_TICKET_QUANTITY) revert BadPayment();

        TicketTier storage tier = ticketTiers[eventId][tierId];
        if (tier.maxSupply == 0) revert NoSupply();
        if (block.timestamp < tier.startSaleTime) revert BadTiming();
        if (block.timestamp > tier.endSaleTime) revert BadTiming();
        if (tier.sold + quantity > tier.maxSupply) revert BadPayment();

        if (events[eventId].visibility == 2 && !eventInvites[eventId][msg.sender]) revert SocialError();

        uint256 totalCost = tier.price * quantity;
        if (totalCost == 0) revert BadPayment();

        tier.sold += quantity;

        for (uint256 i = 0; i < quantity;) {
            uint256 tokenId = generateTokenId(TokenType.EVENT_TICKET, eventId, tierId, tier.sold - quantity + i + 1);
            _mint(msg.sender, tokenId, 1);
            unchecked { ++i; }
        }

        (bool success,) = token.call(abi.encodeWithSelector(0x23b872dd, msg.sender, address(this), totalCost));
        if (!success) revert OpFailed();

        uint256 platformFee = (totalCost * platformFeeBps) / 10_000;
        uint256 remainingAmount = totalCost - platformFee;
        uint256 protocolFee = (remainingAmount * protocolFeeBps) / 10_000;
        uint256 netAmount = remainingAmount - protocolFee;

        if (platformFee > 0) {
            pendingERC20Withdrawals[token][referrer] += platformFee;
            emit PlatformFeeAllocated(eventId, referrer, platformFee, platformFeeBps);
        }

        if (protocolFee > 0) pendingERC20Withdrawals[token][feeTo] += protocolFee;

        PaymentSplit[] storage splits = eventPaymentSplits[eventId];
        for (uint256 i = 0; i < splits.length;) {
            uint256 payment = (netAmount * splits[i].basisPoints) / 10_000;
            pendingERC20Withdrawals[token][splits[i].recipient] += payment;
            unchecked { ++i; }
        }

        emit TicketPurchased(eventId, msg.sender, quantity, totalCost);
    }

    /// @notice Tip event using ERC20 (minimal implementation)
    function tipEventERC20(uint256 eventId, address token, uint256 amount) external nonReentrant {
        if (events[eventId].startTime == 0) revert NotFound();
        if (!supportedTokens[token]) revert UnsupportedToken();
        if (amount == 0) revert BadPayment();

        (bool success,) = token.call(abi.encodeWithSelector(0x23b872dd, msg.sender, address(this), amount));
        if (!success) revert OpFailed();

        uint256 protocolFee = (amount * protocolFeeBps) / 10_000;
        uint256 netAmount = amount - protocolFee;

        if (protocolFee > 0) pendingERC20Withdrawals[token][feeTo] += protocolFee;

        PaymentSplit[] storage splits = eventPaymentSplits[eventId];
        for (uint256 i = 0; i < splits.length;) {
            uint256 payment = (netAmount * splits[i].basisPoints) / 10_000;
            pendingERC20Withdrawals[token][splits[i].recipient] += payment;
            unchecked { ++i; }
        }

        emit EventTipped(eventId, msg.sender, amount);
    }

    /// @notice Tip event using ERC20 with platform fee
    function tipEventERC20(uint256 eventId, address token, uint256 amount, address referrer, uint256 platformFeeBps) external nonReentrant {
        if (events[eventId].startTime == 0) revert NotFound();
        if (!supportedTokens[token]) revert UnsupportedToken();
        if (platformFeeBps > MAX_PLATFORM_FEE) revert BadPayment();
        if (platformFeeBps > 0 && referrer == address(0)) revert BadInput();
        if (referrer == msg.sender) revert BadInput();
        if (amount == 0) revert BadPayment();

        (bool success,) = token.call(abi.encodeWithSelector(0x23b872dd, msg.sender, address(this), amount));
        if (!success) revert OpFailed();

        uint256 platformFee = (amount * platformFeeBps) / 10_000;
        uint256 remainingAmount = amount - platformFee;
        uint256 protocolFee = (remainingAmount * protocolFeeBps) / 10_000;
        uint256 netAmount = remainingAmount - protocolFee;

        if (platformFee > 0) {
            pendingERC20Withdrawals[token][referrer] += platformFee;
            emit PlatformFeeAllocated(eventId, referrer, platformFee, platformFeeBps);
        }

        if (protocolFee > 0) pendingERC20Withdrawals[token][feeTo] += protocolFee;

        PaymentSplit[] storage splits = eventPaymentSplits[eventId];
        for (uint256 i = 0; i < splits.length;) {
            uint256 payment = (netAmount * splits[i].basisPoints) / 10_000;
            pendingERC20Withdrawals[token][splits[i].recipient] += payment;
            unchecked { ++i; }
        }

        emit EventTipped(eventId, msg.sender, amount);
    }

    /// @notice Claim ERC20 funds (minimal implementation)
    function claimERC20Funds(address token) external nonReentrant {
        uint256 amount = pendingERC20Withdrawals[token][msg.sender];
        if (amount == 0) revert NotFound();

        pendingERC20Withdrawals[token][msg.sender] = 0;

        (bool success,) = token.call(abi.encodeWithSelector(0xa9059cbb, msg.sender, amount));
        if (!success) revert OpFailed();

        emit ERC20FundsClaimed(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        SOCIAL GRAPH SYSTEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a friend to your social graph
    /// @param friend Address to add as friend
    function addFriend(address friend) external {
        if (friend == msg.sender) revert SocialError();
        if (friend == address(0)) revert BadInput();
        if (isFriend[msg.sender][friend]) revert SocialError();

        isFriend[msg.sender][friend] = true;
        friendLists[msg.sender].push(friend);
    }

    /// @notice Remove a friend from your social graph
    /// @param friend Address to remove as friend
    function removeFriend(address friend) external {
        if (!isFriend[msg.sender][friend]) revert SocialError();

        isFriend[msg.sender][friend] = false;

        // Remove from friend list
        address[] storage friends = friendLists[msg.sender];
        for (uint256 i = 0; i < friends.length; i++) {
            if (friends[i] == friend) {
                friends[i] = friends[friends.length - 1];
                friends.pop();
                break;
            }
        }
    }

    /// @notice Update RSVP status for an event
    /// @param eventId Event identifier
    /// @param status New RSVP status
    function updateRSVP(uint256 eventId, SocialLibrary.RSVPStatus status) external {
        if (events[eventId].startTime == 0) revert NotFound();
        // Inline the simple library call (just one line)
        rsvps[eventId][msg.sender] = status;
    }

    /*//////////////////////////////////////////////////////////////
                        INVITE SYSTEM (PRIVATE EVENTS)
    //////////////////////////////////////////////////////////////*/

    /// @notice Invite users to a private event
    /// @param eventId Event to invite users to
    /// @param invitees Array of addresses to invite
    function inviteToEvent(uint256 eventId, address[] calldata invitees) external {
        if (eventOrganizers[eventId] != msg.sender) revert NotAuth();
        if (events[eventId].visibility != 2) revert SocialError();

        uint256 inviteesLength = invitees.length;
        for (uint256 i = 0; i < inviteesLength;) {
            address invitee = invitees[i];
            if (eventInvites[eventId][invitee]) revert SocialError();

            eventInvites[eventId][invitee] = true;
            emit UserInvited(eventId, invitee, msg.sender);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        COMMENT SYSTEM
    //////////////////////////////////////////////////////////////*/

    function postComment(uint256 eventId, string calldata content, uint256 parentId) external {
        if (events[eventId].startTime == 0) revert NotFound();
        if (bytes(content).length == 0 || bytes(content).length > 1000) revert BadInput();

        // Validate parent comment if replying (simplified)
        if (parentId > 0) {
            if (comments[parentId].timestamp == 0) revert NotFound();
        }

        uint256 commentId = nextCommentId++;

        comments[commentId] = CommentLibrary.Comment({
            author: msg.sender,
            timestamp: block.timestamp,
            content: content,
            parentId: parentId
        });

        eventComments[eventId].push(commentId);
        emit CommentPosted(eventId, commentId, msg.sender, parentId);
    }

    // Simplified view functions
    function getEventComments(uint256 eventId) external view returns (uint256[] memory) {
        return eventComments[eventId];
    }

    function getComment(uint256 commentId) external view returns (CommentLibrary.Comment memory) {
        return comments[commentId];
    }

    /*//////////////////////////////////////////////////////////////
                        ERC-6909 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    function transfer(address from, address to, uint256 id, uint256 amount) external {
        if (msg.sender != from && !isOperator[from][msg.sender] && allowance[from][msg.sender][id] < amount) {
            revert NotAuth();
        }

        // Inline soulbound check (more efficient than enum cast)
        uint256 tokenType = id >> 248;
        if (tokenType == 2 || tokenType == 3 || tokenType == 4) revert SocialError(); // ATTENDANCE_BADGE=2, ORGANIZER_CRED=3, VENUE_CRED=4

        if (msg.sender != from && !isOperator[from][msg.sender]) {
            allowance[from][msg.sender][id] -= amount;
        }

        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;

        emit Transfer(msg.sender, from, to, id, amount);
    }

    function approve(address spender, uint256 id, uint256 amount) external {
        allowance[msg.sender][spender][id] = amount;
        emit Approval(msg.sender, spender, id, amount);
    }

    function setOperator(address operator, bool approved) external {
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id, uint256 amount) internal {
        balanceOf[to][id] += amount;
        totalSupply[id] += amount;
        emit Transfer(msg.sender, address(0), to, id, amount);
    }

    function _distributePayment(uint256 eventId, uint256 amount) internal {
        PaymentSplit[] storage splits = eventPaymentSplits[eventId];
        uint256 length = splits.length;

        for (uint256 i = 0; i < length;) {
            PaymentSplit storage split = splits[i];
            uint256 payment = (amount * split.basisPoints) / 10_000;
            pendingWithdrawals[split.recipient] += payment;
            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validatePaymentSplits(PaymentSplit[] calldata splits) internal pure {
        uint256 length = splits.length;
        if (length == 0) revert NotFound();
        if (length > MAX_PAYMENT_SPLITS) revert TooMany();

        uint256 totalBps = 0;
        for (uint256 i = 0; i < length;) {
            PaymentSplit calldata split = splits[i];
            if (split.recipient == address(0)) revert BadInput();
            if (split.basisPoints == 0) revert BadPayment();
            totalBps += split.basisPoints;
            unchecked {
                ++i;
            }
        }
        if (totalBps != 10_000) revert BadPayment();
    }

    function generateTokenId(
        TokenType tokenType,
        uint256 eventId,
        uint256 tierId,
        uint256 serialNumber
    )
        public
        pure
        returns (uint256 tokenId)
    {
        return (uint256(tokenType) << 248) | (eventId << 184) | (tierId << 152) | serialNumber;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getFriends(address user) external view returns (address[] memory) {
        return friendLists[user];
    }

    // Consolidated price calculation (minimal for test compatibility)
    function calculatePrice(uint256 eventId, uint256 tierId, uint256 quantity) external view returns (uint256) {
        return ticketTiers[eventId][tierId].price * quantity;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setFeeTo(address newFeeTo) external onlyFeeTo {
        if (newFeeTo == address(0)) revert BadPayment();
        address oldFeeTo = feeTo;
        feeTo = newFeeTo;
        emit FeeToUpdated(oldFeeTo, newFeeTo);
    }

    function setProtocolFee(uint256 newFeeBps) external onlyFeeTo {
        if (newFeeBps > MAX_PROTOCOL_FEE) revert BadPayment();
        uint256 oldFee = protocolFeeBps;
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(oldFee, newFeeBps);
    }

    /// @notice Add or remove supported ERC20 token
    /// @param token ERC20 token address
    /// @param supported Whether token should be supported
    function setSupportedToken(address token, bool supported) external onlyFeeTo {
        if (token == address(0)) revert BadInput();
        supportedTokens[token] = supported;
        emit TokenSupportUpdated(token, supported);
    }

    /*//////////////////////////////////////////////////////////////
                    EVENT CANCELLATION & REFUNDS
    //////////////////////////////////////////////////////////////*/

    /// @notice Cancel event and enable refunds
    /// @param eventId Event to cancel
    function cancelEvent(uint256 eventId) external {
        if (eventOrganizers[eventId] != msg.sender) revert NotAuth();
        if (events[eventId].status != 0) revert BadState();
        if (block.timestamp >= events[eventId].startTime) revert BadTiming();

        events[eventId].status = 1; // CANCELLED = 1
        eventCancellationTime[eventId] = block.timestamp;

        emit EventCancelled(eventId, msg.sender, block.timestamp);
    }

    /// @notice Claim refund for cancelled event tickets
    /// @param eventId Cancelled event ID
    function claimTicketRefund(uint256 eventId) external nonReentrant {
        if (events[eventId].status != 1) revert BadState();
        if (block.timestamp > eventCancellationTime[eventId] + REFUND_CLAIM_DEADLINE) revert BadTiming();

        uint256 refundAmount = userTicketPayments[eventId][msg.sender];
        if (refundAmount == 0) revert NotFound();

        // Clear payment tracking to prevent re-claiming
        userTicketPayments[eventId][msg.sender] = 0;

        // Transfer refund
        (bool success,) = payable(msg.sender).call{ value: refundAmount }("");
        if (!success) revert OpFailed();

        emit RefundClaimed(eventId, msg.sender, refundAmount);
    }

    /// @notice Claim refund for cancelled event tips
    /// @param eventId Cancelled event ID
    function claimTipRefund(uint256 eventId) external nonReentrant {
        if (events[eventId].status != 1) revert BadState();
        if (block.timestamp > eventCancellationTime[eventId] + REFUND_CLAIM_DEADLINE) revert BadTiming();

        uint256 refundAmount = userTipPayments[eventId][msg.sender];
        if (refundAmount == 0) revert NotFound();

        // Clear payment tracking to prevent re-claiming
        userTipPayments[eventId][msg.sender] = 0;

        // Transfer refund
        (bool success,) = payable(msg.sender).call{ value: refundAmount }("");
        if (!success) revert OpFailed();

        emit RefundClaimed(eventId, msg.sender, refundAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        ATTENDANCE & BADGES SYSTEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Basic event check-in (user-level)
    /// @param eventId Event to check into
    /// @dev Mints a single attendance badge per user per event
    function checkIn(uint256 eventId) external {
        PackedEventData memory eventData = events[eventId];
        if (eventData.startTime == 0) revert NotFound();
        if (block.timestamp < eventData.startTime) revert BadTiming();
        if (block.timestamp > eventData.startTime + 86_400) revert BadTiming();

        uint256 badgeId = generateTokenId(TokenType.ATTENDANCE_BADGE, eventId, 0, 0);
        if (balanceOf[msg.sender][badgeId] == 0) {
            _mint(msg.sender, badgeId, 1);
        }
    }

    /// @notice Check-in with specific ticket verification
    /// @param eventId Event to check into
    /// @param ticketTokenId Specific ticket token ID to verify and mark as used
    /// @dev Verifies ticket ownership and mints tier-specific attendance badge
    function checkInWithTicket(uint256 eventId, uint256 ticketTokenId) external {
        PackedEventData memory eventData = events[eventId];
        if (eventData.startTime == 0) revert NotFound();
        if (block.timestamp < eventData.startTime) revert BadTiming();
        if (block.timestamp > eventData.startTime + 86_400) revert BadTiming();

        if (balanceOf[msg.sender][ticketTokenId] == 0) revert NotFound();
        if (((ticketTokenId >> 184) & 0xFFFFFFFFFFFFFFFF) != eventId) revert SocialError();

        uint256 tierId = (ticketTokenId >> 152) & 0xFFFFFFFF;
        if (usedTickets[ticketTokenId]) revert SocialError();

        usedTickets[ticketTokenId] = true;
        uint256 badgeId = generateTokenId(TokenType.ATTENDANCE_BADGE, eventId, tierId, 0);

        if (balanceOf[msg.sender][badgeId] == 0) {
            _mint(msg.sender, badgeId, 1);
        }
    }

    function claimOrganizerCredential(uint256 eventId) external {
        if (eventOrganizers[eventId] != msg.sender) revert NotAuth();

        PackedEventData memory eventData = events[eventId];
        if (block.timestamp <= eventData.startTime + 86_400) revert BadTiming();

        uint256 credId = generateTokenId(TokenType.ORGANIZER_CRED, eventId, 0, 0);

        if (balanceOf[msg.sender][credId] == 0) {
            _mint(msg.sender, credId, 1);
        }
    }

    /// @notice Check-in someone else using a ticket you own
    /// @param eventId Event to check into
    /// @param ticketTokenId Specific ticket token ID to verify and mark as used
    /// @param attendee Address of the person checking in (who will receive the badge)
    /// @dev Allows ticket purchaser to check in friends/family using tickets they bought
    function checkInDelegate(uint256 eventId, uint256 ticketTokenId, address attendee) external {
        PackedEventData memory eventData = events[eventId];
        if (eventData.startTime == 0) revert NotFound();
        if (block.timestamp < eventData.startTime) revert BadTiming();
        if (block.timestamp > eventData.startTime + 86_400) revert BadTiming();

        if (balanceOf[msg.sender][ticketTokenId] == 0) revert NotFound();
        if (((ticketTokenId >> 184) & 0xFFFFFFFFFFFFFFFF) != eventId) revert SocialError();

        uint256 tierId = (ticketTokenId >> 152) & 0xFFFFFFFF;
        if (usedTickets[ticketTokenId]) revert SocialError();

        usedTickets[ticketTokenId] = true;
        uint256 badgeId = generateTokenId(TokenType.ATTENDANCE_BADGE, eventId, tierId, 0);

        if (balanceOf[attendee][badgeId] == 0) {
            _mint(attendee, badgeId, 1);
        }
    }
}
