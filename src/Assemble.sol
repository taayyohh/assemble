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
import { RefundLibrary } from "./libraries/RefundLibrary.sol";

/// @title Assemble - Decentralized Event Management Protocol
/// @notice A comprehensive protocol for managing events, tickets, social interactions, and payments onchain
/// @dev Uses ERC-6909 for multi-token functionality and EIP-1153 for gas optimization
/// @author taayyohh
contract Assemble {
    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOrganizer();
    error NotAuth();
    error BadFeeTo();
    error BadTime();
    error BadEndTime();
    error NoTiers();
    error BadCap();
    error NoSupply();
    error BadSaleTimes();
    error NoEvent();
    error BadQty();
    error NoTier();
    error NotStarted();
    error Ended();
    error NoSpace();
    error NeedMore();
    error RefundFail();
    error NeedValue();
    error NoFunds();
    error TransferFail();
    error CantAddSelf();
    error BadAddr();
    error AlreadyFriends();
    error NotFriends();
    error Banned();
    error BadContent();
    error NoParent();
    error ParentDel();
    error AlreadyLiked();
    error NotLiked();
    error NoComment();
    error NoSplits();
    error TooMany();
    error BadRecipient();
    error BadBps();
    error BadTotal();
    error FeeHigh();
    error NotActive();
    error Started();
    error Cancelled();
    error NotCancelled();
    error Expired();
    error NoRefund();
    error NotEventTime();
    error EventOver();
    error WrongOrg();
    error NotDone();
    error NotExpired();
    error AlreadyBan();
    error NotBan();
    error NoPerms();
    error Soulbound();
    error NoTicket();
    error WrongEvent();
    error Used();

    /// @notice Invite system errors
    error NotInvited();
    error AlreadyInvited();
    error NotPrivate();

    /// @notice Platform fee errors
    error PlatformHigh();
    error BadRef();

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
        ORGANIZER_CRED // Soulbound organizer reputation

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

    /// @notice Packed storage for events (optimized for gas)
    struct PackedEventData {
        uint128 basePrice; // Sufficient for most pricing
        uint64 startTime; // Unix timestamp
        uint32 capacity; // 4B max attendees
        uint16 venueId; // 65k venues
        uint8 visibility; // Event visibility
        uint8 status; // Event status (EventStatus enum)
    }

    /// @notice Event creation parameters
    struct EventParams {
        string title;
        string description;
        string imageUri; // IPFS hash for event image
        uint256 startTime;
        uint256 endTime;
        uint256 capacity;
        uint256 venueId; // Reference to venue registry
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
    mapping(uint256 => mapping(address => bool)) private commentLikes;
    mapping(address => bool) private bannedUsers;

    // Security: Pull payment pattern
    mapping(address => uint256) public pendingWithdrawals;

    // Social graph - make private except core ones
    mapping(address => mapping(address => bool)) public isFriend;
    mapping(address => address[]) private friendLists;
    mapping(uint256 => mapping(address => SocialLibrary.RSVPStatus)) public rsvps;
    mapping(uint256 => address[]) private attendeeLists;

    // ERC-6909 core storage (keep public for standard compliance)
    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public allowance;
    mapping(address => mapping(address => bool)) public isOperator;
    mapping(uint256 => uint256) public totalSupply;

    // Refund tracking - keep private except what tests need
    mapping(uint256 => bool) public eventCancelled;
    mapping(uint256 => mapping(address => uint256)) private userTicketPayments;
    mapping(uint256 => mapping(address => uint256)) private userTipPayments;
    mapping(uint256 => uint256) private eventCancellationTime;

    // Attendance tracking
    mapping(uint256 => bool) public usedTickets;

    // Invite system for private events
    mapping(uint256 => mapping(address => bool)) public eventInvites;

    // Platform fee tracking
    mapping(address => uint256) public totalReferralFees;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    // Core protocol events
    event EventCreated(uint256 indexed eventId, address indexed organizer, uint256 startTime);
    event TicketPurchased(uint256 indexed eventId, address indexed buyer, uint256 quantity, uint256 price);
    event RSVPUpdated(uint256 indexed eventId, address indexed user, SocialLibrary.RSVPStatus status);
    event FriendAdded(address indexed user1, address indexed user2);
    event FriendRemoved(address indexed user1, address indexed user2);
    event PaymentAllocated(uint256 indexed eventId, address indexed recipient, uint256 amount, string role);
    event FundsClaimed(address indexed recipient, uint256 amount);
    event EventTipped(uint256 indexed eventId, address indexed tipper, uint256 amount);
    event AttendanceVerified(uint256 indexed eventId, address indexed user);

    // Comment system events
    event CommentPosted(uint256 indexed eventId, uint256 indexed commentId, address indexed author, uint256 parentId);
    event CommentLiked(uint256 indexed commentId, address indexed user);
    event CommentUnliked(uint256 indexed commentId, address indexed user);
    event CommentDeleted(uint256 indexed commentId, address indexed deletedBy);
    event UserBanned(address indexed user, address indexed bannedBy);
    event UserUnbanned(address indexed user, address indexed unbannedBy);

    // Admin events
    event FeeToUpdated(address indexed oldFeeTo, address indexed newFeeTo);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event EventCancelled(uint256 indexed eventId, address indexed organizer, uint256 timestamp);
    event RefundClaimed(uint256 indexed eventId, address indexed user, uint256 amount, string refundType);

    // Platform fee events
    event PlatformFeeAllocated(uint256 indexed eventId, address indexed referrer, uint256 amount, uint256 feeBps);

    // ERC-6909 events
    event Transfer(address indexed caller, address indexed from, address indexed to, uint256 id, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);
    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    // New events
    event TicketUsed(uint256 indexed eventId, address indexed user, uint256 indexed ticketTokenId, uint256 tierId);

    // Invite system events
    event UserInvited(uint256 indexed eventId, address indexed invitee, address indexed organizer);
    event InvitationRevoked(uint256 indexed eventId, address indexed invitee, address indexed organizer);

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
        if (_feeTo == address(0)) revert BadFeeTo();
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
        if (params.startTime <= block.timestamp) revert BadTime();
        if (params.endTime <= params.startTime) revert BadEndTime();
        if (tiers.length == 0) revert NoTiers();
        if (params.capacity == 0) revert BadCap();

        // Validate payment splits
        _validatePaymentSplits(splits);

        // Generate event ID
        eventId = nextEventId++;

        // Pack event data for gas efficiency
        events[eventId] = PackedEventData({
            basePrice: uint128(tiers[0].price),
            startTime: uint64(params.startTime),
            capacity: uint32(params.capacity),
            venueId: uint16(params.venueId),
            visibility: uint8(params.visibility),
            status: 0 // ACTIVE = 0, avoid enum cast
        });

        // Store metadata and organizer
        eventMetadata[eventId] = params.imageUri;
        eventOrganizers[eventId] = msg.sender;

        // Store ticket tiers
        uint256 tiersLength = tiers.length;
        for (uint256 i = 0; i < tiersLength;) {
            if (tiers[i].maxSupply == 0) revert NoSupply();
            if (tiers[i].startSaleTime > tiers[i].endSaleTime) revert BadSaleTimes();
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
        if (events[eventId].startTime == 0) revert NoEvent();
        if (quantity == 0 || quantity > MAX_TICKET_QUANTITY) revert BadQty();

        TicketTier storage tier = ticketTiers[eventId][tierId];
        if (tier.maxSupply == 0) revert NoTier();
        if (block.timestamp < tier.startSaleTime) revert NotStarted();
        if (block.timestamp > tier.endSaleTime) revert Ended();
        if (tier.sold + quantity > tier.maxSupply) revert NoSpace();

        // Validate platform fee parameters
        if (platformFeeBps > MAX_PLATFORM_FEE) revert PlatformHigh();
        if (platformFeeBps > 0 && referrer == address(0)) revert BadRef();
        if (referrer == msg.sender) revert BadRef(); // Prevent self-referral

        // Check event visibility and access permissions
        if (
            events[eventId].visibility == 2 // INVITE_ONLY
                && !eventInvites[eventId][msg.sender]
        ) {
            revert NotInvited();
        }

        // Calculate total cost with dynamic pricing
        uint256 totalCost = calculatePrice(eventId, tierId, quantity);
        if (msg.value < totalCost) revert NeedMore();

        // EFFECTS: Update state before external calls
        tier.sold += quantity;

        // Track payment for potential refunds
        userTicketPayments[eventId][msg.sender] += totalCost;

        // Mint ERC-6909 tickets - use unique IDs to avoid collisions
        for (uint256 i = 0; i < quantity;) {
            uint256 tokenId = generateTokenId(TokenType.EVENT_TICKET, eventId, tierId, tier.sold - quantity + i + 1);
            _mint(msg.sender, tokenId, 1);
            unchecked {
                ++i;
            }
        }

        // Calculate and distribute payments
        // Order: Platform fee -> Protocol fee -> Event payment splits
        uint256 platformFee = 0;
        if (referrer != address(0) && platformFeeBps > 0) {
            platformFee = (totalCost * platformFeeBps) / 10_000;
            pendingWithdrawals[referrer] += platformFee;
            totalReferralFees[referrer] += platformFee;
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
            if (!success) revert RefundFail();
        }

        emit TicketPurchased(eventId, msg.sender, quantity, totalCost);
    }

    /// @notice Calculate ticket price (base price * quantity)
    /// @param eventId Event identifier
    /// @param tierId Ticket tier identifier
    /// @param quantity Number of tickets
    /// @return totalPrice Final price including all adjustments
    function calculatePrice(
        uint256 eventId,
        uint256 tierId,
        uint256 quantity
    )
        public
        view
        returns (uint256 totalPrice)
    {
        TicketTier storage tier = ticketTiers[eventId][tierId];
        if (tier.maxSupply == 0) revert NoTier();

        uint256 basePrice = tier.price;

        if (basePrice == 0) {
            return 0;
        }

        totalPrice = basePrice * quantity;

        // Ensure minimum price of at least 1 wei for paid tickets only
        if (totalPrice == 0) {
            totalPrice = 1;
        }
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
        if (msg.value == 0) revert NeedValue();
        if (events[eventId].startTime == 0) revert NoEvent();

        // Validate platform fee parameters
        if (platformFeeBps > MAX_PLATFORM_FEE) revert PlatformHigh();
        if (platformFeeBps > 0 && referrer == address(0)) revert BadRef();
        if (referrer == msg.sender) revert BadRef(); // Prevent self-referral

        // Track tip for potential refunds
        userTipPayments[eventId][msg.sender] += msg.value;

        // Calculate and distribute fees
        // Order: Platform fee -> Protocol fee -> Event payment splits
        uint256 platformFee = 0;
        if (referrer != address(0) && platformFeeBps > 0) {
            platformFee = (msg.value * platformFeeBps) / 10_000;
            pendingWithdrawals[referrer] += platformFee;
            totalReferralFees[referrer] += platformFee;
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
        if (amount == 0) revert NoFunds();

        // Effects before interactions
        pendingWithdrawals[msg.sender] = 0;

        // Safe transfer
        (bool success,) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert TransferFail();

        emit FundsClaimed(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        SOCIAL GRAPH SYSTEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a friend to your social graph
    /// @param friend Address to add as friend
    function addFriend(address friend) external {
        if (friend == msg.sender) revert CantAddSelf();
        if (friend == address(0)) revert BadAddr();
        if (isFriend[msg.sender][friend]) revert AlreadyFriends();

        isFriend[msg.sender][friend] = true;
        friendLists[msg.sender].push(friend);

        emit FriendAdded(msg.sender, friend);
    }

    /// @notice Remove a friend from your social graph
    /// @param friend Address to remove as friend
    function removeFriend(address friend) external {
        if (!isFriend[msg.sender][friend]) revert NotFriends();

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

        emit FriendRemoved(msg.sender, friend);
    }

    /// @notice Update RSVP status for an event
    /// @param eventId Event identifier
    /// @param status New RSVP status
    function updateRSVP(uint256 eventId, SocialLibrary.RSVPStatus status) external {
        if (events[eventId].startTime == 0) revert NoEvent();
        SocialLibrary.updateRSVP(rsvps, attendeeLists, eventId, msg.sender, status);
        emit RSVPUpdated(eventId, msg.sender, status);
    }

    /*//////////////////////////////////////////////////////////////
                        INVITE SYSTEM (PRIVATE EVENTS)
    //////////////////////////////////////////////////////////////*/

    /// @notice Invite users to a private event
    /// @param eventId Event to invite users to
    /// @param invitees Array of addresses to invite
    function inviteToEvent(uint256 eventId, address[] calldata invitees) external {
        if (eventOrganizers[eventId] != msg.sender) revert NotOrganizer();
        if (events[eventId].visibility != 2) revert NotPrivate(); // INVITE_ONLY = 2

        uint256 inviteesLength = invitees.length;
        for (uint256 i = 0; i < inviteesLength;) {
            address invitee = invitees[i];
            if (eventInvites[eventId][invitee]) revert AlreadyInvited();

            eventInvites[eventId][invitee] = true;
            emit UserInvited(eventId, invitee, msg.sender);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Remove invitation from a private event
    /// @param eventId Event to remove invitation from
    /// @param invitee Address to remove invitation for
    function removeInvitation(uint256 eventId, address invitee) external {
        if (eventOrganizers[eventId] != msg.sender) revert NotOrganizer();
        if (!eventInvites[eventId][invitee]) revert NotInvited();

        eventInvites[eventId][invitee] = false;
        emit InvitationRevoked(eventId, invitee, msg.sender);
    }

    /// @notice Check if an address is invited to an event
    /// @param eventId Event identifier
    /// @param user Address to check
    /// @return invited True if the user is invited
    function isInvited(uint256 eventId, address user) external view returns (bool invited) {
        return eventInvites[eventId][user];
    }

    /*//////////////////////////////////////////////////////////////
                        COMMENT SYSTEM
    //////////////////////////////////////////////////////////////*/

    function postComment(uint256 eventId, string calldata content, uint256 parentId) external {
        if (events[eventId].startTime == 0) revert NoEvent();
        if (bannedUsers[msg.sender]) revert Banned();
        if (bytes(content).length == 0 || bytes(content).length > 1000) revert BadContent();

        // Validate parent comment if replying
        if (parentId > 0) {
            if (comments[parentId].timestamp == 0) revert NoParent();
            if (comments[parentId].isDeleted) revert ParentDel();
        }

        uint256 commentId = nextCommentId++;

        comments[commentId] = CommentLibrary.Comment({
            author: msg.sender,
            timestamp: block.timestamp,
            content: content,
            parentId: parentId,
            isDeleted: false,
            likes: 0
        });

        eventComments[eventId].push(commentId);
        emit CommentPosted(eventId, commentId, msg.sender, parentId);
    }

    function likeComment(uint256 commentId) external {
        if (commentLikes[commentId][msg.sender]) revert AlreadyLiked();
        commentLikes[commentId][msg.sender] = true;
        comments[commentId].likes++;
        emit CommentLiked(commentId, msg.sender);
    }

    function unlikeComment(uint256 commentId) external {
        if (!commentLikes[commentId][msg.sender]) revert NotLiked();
        commentLikes[commentId][msg.sender] = false;
        comments[commentId].likes--;
        emit CommentUnliked(commentId, msg.sender);
    }

    function deleteComment(uint256 commentId, uint256 eventId) external {
        if (events[eventId].startTime == 0) revert NoEvent();

        CommentLibrary.Comment storage comment = comments[commentId];
        if (comment.timestamp == 0) revert NoComment();
        if (comment.author != msg.sender && eventOrganizers[eventId] != msg.sender && msg.sender != feeTo) {
            revert NotAuth();
        }

        comment.isDeleted = true;
        emit CommentDeleted(commentId, msg.sender);
    }

    // Simplified view functions
    function getEventComments(uint256 eventId) external view returns (uint256[] memory) {
        return eventComments[eventId];
    }

    function getComment(uint256 commentId) external view returns (CommentLibrary.Comment memory) {
        return comments[commentId];
    }

    function hasLikedComment(uint256 commentId, address user) external view returns (bool) {
        return commentLikes[commentId][user];
    }

    function banUser(address user, uint256 eventId) external {
        if (events[eventId].startTime == 0) revert NoEvent();
        if (eventOrganizers[eventId] != msg.sender && msg.sender != feeTo) revert NotAuth();
        if (bannedUsers[user]) revert AlreadyBan();

        bannedUsers[user] = true;
        emit UserBanned(user, msg.sender);
    }

    function unbanUser(address user, uint256 eventId) external {
        if (events[eventId].startTime == 0) revert NoEvent();
        if (eventOrganizers[eventId] != msg.sender && msg.sender != feeTo) revert NotAuth();
        if (!bannedUsers[user]) revert NotBan();

        bannedUsers[user] = false;
        emit UserUnbanned(user, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC-6909 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    function transfer(address from, address to, uint256 id, uint256 amount) external {
        if (msg.sender != from && !isOperator[from][msg.sender] && allowance[from][msg.sender][id] < amount) {
            revert NoPerms();
        }

        TokenType tokenType = TokenType(id >> 248);
        if (tokenType == TokenType.ATTENDANCE_BADGE || tokenType == TokenType.ORGANIZER_CRED) {
            revert Soulbound();
        }

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
            emit PaymentAllocated(eventId, split.recipient, payment, "");
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
        if (length == 0) revert NoSplits();
        if (length > MAX_PAYMENT_SPLITS) revert TooMany();

        uint256 totalBps = 0;
        for (uint256 i = 0; i < length;) {
            PaymentSplit calldata split = splits[i];
            if (split.recipient == address(0)) revert BadRecipient();
            if (split.basisPoints == 0) revert BadBps();
            totalBps += split.basisPoints;
            unchecked {
                ++i;
            }
        }
        if (totalBps != 10_000) revert BadTotal();
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

    function isValidTicketForEvent(uint256 tokenId, uint256 eventId) public pure returns (bool isValid) {
        uint256 tokenEventId = (tokenId >> 184) & 0xFFFFFFFFFFFFFFFF;
        return tokenEventId == eventId;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getFriends(address user) external view returns (address[] memory) {
        return friendLists[user];
    }

    function hasAttended(address user, uint256 eventId) external view returns (bool) {
        uint256 badgeId = generateTokenId(TokenType.ATTENDANCE_BADGE, eventId, 0, 0);
        return balanceOf[user][badgeId] > 0;
    }

    function getPaymentSplits(uint256 eventId) external view returns (PaymentSplit[] memory) {
        return eventPaymentSplits[eventId];
    }

    function isEventCancelled(uint256 eventId) external view returns (bool) {
        return eventCancelled[eventId];
    }

    function getRefundAmounts(
        uint256 eventId,
        address user
    )
        external
        view
        returns (uint256 ticketRefund, uint256 tipRefund)
    {
        return (userTicketPayments[eventId][user], userTipPayments[eventId][user]);
    }

    function getUserRSVP(uint256 eventId, address user) external view returns (SocialLibrary.RSVPStatus) {
        return rsvps[eventId][user];
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setFeeTo(address newFeeTo) external onlyFeeTo {
        if (newFeeTo == address(0)) revert BadFeeTo();
        address oldFeeTo = feeTo;
        feeTo = newFeeTo;
        emit FeeToUpdated(oldFeeTo, newFeeTo);
    }

    function setProtocolFee(uint256 newFeeBps) external onlyFeeTo {
        if (newFeeBps > MAX_PROTOCOL_FEE) revert FeeHigh();
        uint256 oldFee = protocolFeeBps;
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(oldFee, newFeeBps);
    }

    /*//////////////////////////////////////////////////////////////
                    EVENT CANCELLATION & REFUNDS
    //////////////////////////////////////////////////////////////*/

    /// @notice Cancel event and enable refunds
    /// @param eventId Event to cancel
    function cancelEvent(uint256 eventId) external {
        if (eventOrganizers[eventId] != msg.sender) revert NotOrganizer();
        if (events[eventId].status != 0) revert NotActive(); // 0 = ACTIVE
        if (block.timestamp >= events[eventId].startTime) revert Started();

        events[eventId].status = 1; // CANCELLED = 1
        eventCancellationTime[eventId] = block.timestamp;
        eventCancelled[eventId] = true;

        emit EventCancelled(eventId, msg.sender, block.timestamp);
    }

    /// @notice Claim refund for cancelled event tickets
    /// @param eventId Cancelled event ID
    function claimTicketRefund(uint256 eventId) external nonReentrant {
        if (!eventCancelled[eventId]) revert NotCancelled();
        if (block.timestamp > eventCancellationTime[eventId] + REFUND_CLAIM_DEADLINE) revert Expired();

        uint256 refundAmount = userTicketPayments[eventId][msg.sender];
        if (refundAmount == 0) revert NoRefund();

        // Clear payment tracking to prevent re-claiming
        userTicketPayments[eventId][msg.sender] = 0;

        // Transfer refund
        (bool success,) = payable(msg.sender).call{ value: refundAmount }("");
        if (!success) revert TransferFail();

        emit RefundClaimed(eventId, msg.sender, refundAmount, "");
    }

    /// @notice Claim refund for cancelled event tips
    /// @param eventId Cancelled event ID
    function claimTipRefund(uint256 eventId) external nonReentrant {
        if (!eventCancelled[eventId]) revert NotCancelled();
        if (block.timestamp > eventCancellationTime[eventId] + REFUND_CLAIM_DEADLINE) revert Expired();

        uint256 refundAmount = userTipPayments[eventId][msg.sender];
        if (refundAmount == 0) revert NoRefund();

        // Clear payment tracking to prevent re-claiming
        userTipPayments[eventId][msg.sender] = 0;

        // Transfer refund
        (bool success,) = payable(msg.sender).call{ value: refundAmount }("");
        if (!success) revert TransferFail();

        emit RefundClaimed(eventId, msg.sender, refundAmount, "");
    }

    /*//////////////////////////////////////////////////////////////
                        ATTENDANCE & BADGES SYSTEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Basic event check-in (user-level)
    /// @param eventId Event to check into
    /// @dev Mints a single attendance badge per user per event
    function checkIn(uint256 eventId) external {
        PackedEventData memory eventData = events[eventId];
        if (eventData.startTime == 0) revert NoEvent();
        if (block.timestamp < eventData.startTime) revert NotStarted();
        if (block.timestamp > eventData.startTime + 86_400) revert Ended();

        uint256 badgeId = generateTokenId(TokenType.ATTENDANCE_BADGE, eventId, 0, 0);

        if (balanceOf[msg.sender][badgeId] == 0) {
            _mint(msg.sender, badgeId, 1);
            emit AttendanceVerified(eventId, msg.sender);
        }
    }

    /// @notice Check-in with specific ticket verification
    /// @param eventId Event to check into
    /// @param ticketTokenId Specific ticket token ID to verify and mark as used
    /// @dev Verifies ticket ownership and mints tier-specific attendance badge
    function checkInWithTicket(uint256 eventId, uint256 ticketTokenId) external {
        PackedEventData memory eventData = events[eventId];
        if (eventData.startTime == 0) revert NoEvent();
        if (block.timestamp < eventData.startTime) revert NotStarted();
        if (block.timestamp > eventData.startTime + 86_400) revert Ended();

        if (balanceOf[msg.sender][ticketTokenId] == 0) revert NoTicket();
        if (!isValidTicketForEvent(ticketTokenId, eventId)) revert WrongEvent();

        uint256 tierId = (ticketTokenId >> 152) & 0xFFFFFFFF;
        if (usedTickets[ticketTokenId]) revert Used();

        usedTickets[ticketTokenId] = true;
        uint256 badgeId = generateTokenId(TokenType.ATTENDANCE_BADGE, eventId, tierId, 0);

        if (balanceOf[msg.sender][badgeId] == 0) {
            _mint(msg.sender, badgeId, 1);
        }

        emit TicketUsed(eventId, msg.sender, ticketTokenId, tierId);
        emit AttendanceVerified(eventId, msg.sender);
    }

    function claimOrganizerCredential(uint256 eventId) external {
        if (eventOrganizers[eventId] != msg.sender) revert WrongOrg();

        PackedEventData memory eventData = events[eventId];
        if (block.timestamp <= eventData.startTime + 86_400) revert NotDone();

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
        if (eventData.startTime == 0) revert NoEvent();
        if (block.timestamp < eventData.startTime) revert NotStarted();
        if (block.timestamp > eventData.startTime + 86_400) revert Ended();

        if (balanceOf[msg.sender][ticketTokenId] == 0) revert NoTicket();
        if (!isValidTicketForEvent(ticketTokenId, eventId)) revert WrongEvent();

        uint256 tierId = (ticketTokenId >> 152) & 0xFFFFFFFF;
        if (usedTickets[ticketTokenId]) revert Used();

        usedTickets[ticketTokenId] = true;
        uint256 badgeId = generateTokenId(TokenType.ATTENDANCE_BADGE, eventId, tierId, 0);

        if (balanceOf[attendee][badgeId] == 0) {
            _mint(attendee, badgeId, 1);
        }

        emit TicketUsed(eventId, attendee, ticketTokenId, tierId);
        emit AttendanceVerified(eventId, attendee);
    }
}
