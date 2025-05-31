// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SocialLibrary } from "./libraries/SocialLibrary.sol";
import { CommentLibrary } from "./libraries/CommentLibrary.sol";
import { RefundLibrary } from "./libraries/RefundLibrary.sol";

/// @title Assemble - Decentralized Event Management Protocol
/// @notice A comprehensive protocol for managing events, tickets, social interactions, and payments onchain
/// @dev Uses ERC-6909 for multi-token functionality and EIP-1153 for gas optimization
contract Assemble {
    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotEventOrganizer();
    error NotAuthorized();
    error InvalidFeeRecipient();
    error InvalidFutureTime();
    error InvalidEndTime();
    error NoTiers();
    error InvalidCapacity();
    error TierMustHaveSupply();
    error InvalidSaleTimes();
    error EventNotFound();
    error InvalidQuantity();
    error TierNotFound();
    error SaleNotStarted();
    error SaleEnded();
    error InsufficientCapacity();
    error InsufficientPayment();
    error RefundFailed();
    error MustSendValue();
    error NoFundsToClaim();
    error TransferFailed();
    error CannotAddYourself();
    error InvalidAddress();
    error AlreadyFriends();
    error NotFriends();
    error Banned();
    error InvalidContentLength();
    error ParentNotFound();
    error ParentDeleted();
    error AlreadyLiked();
    error NotLiked();
    error CommentNotFound();
    error NoSplits();
    error TooManySplits();
    error InvalidRecipient();
    error InvalidBasisPoints();
    error InvalidTotalBasisPoints();
    error FeeToHigh();
    error EventNotActive();
    error EventAlreadyStarted();
    error AlreadyCancelled();
    error EventNotCancelled();
    error RefundDeadlineExpired();
    error NoRefundAvailable();
    error EventNotStarted();
    error EventEnded();
    error NotOrganizer();
    error EventNotCompleted();
    error RefundDeadlineNotExpired();
    error AlreadyBanned();
    error NotBanned();
    error InsufficientPermission();
    error SoulboundToken();
    error TicketNotOwned();
    error InvalidTicketForEvent();
    error TicketAlreadyUsed();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum number of payment splits per event for gas optimization
    uint256 public constant MAX_PAYMENT_SPLITS = 20;

    /// @notice Maximum ticket quantity per purchase to prevent gas limit issues
    uint256 public constant MAX_TICKET_QUANTITY = 50;

    /// @notice Maximum protocol fee (10%) for governance limits
    uint256 public constant MAX_PROTOCOL_FEE = 1000;

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
        string role;
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

    // ERC-6909 events
    event Transfer(address indexed caller, address indexed from, address indexed to, uint256 id, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);
    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    // New events
    event TicketUsed(uint256 indexed eventId, address indexed user, uint256 indexed ticketTokenId, uint256 tierId);

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

    /// @notice Only event organizer modifier
    modifier onlyOrganizer(uint256 eventId) {
        if (eventOrganizers[eventId] != msg.sender) revert NotEventOrganizer();
        _;
    }

    /// @notice Only fee recipient modifier
    modifier onlyFeeTo() {
        if (msg.sender != feeTo) revert NotAuthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Assemble protocol
    /// @param _feeTo Initial fee recipient address
    constructor(address _feeTo) {
        if (_feeTo == address(0)) revert InvalidFeeRecipient();
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
        if (params.startTime <= block.timestamp) revert InvalidFutureTime();
        if (params.endTime <= params.startTime) revert InvalidEndTime();
        if (tiers.length == 0) revert NoTiers();
        if (params.capacity == 0) revert InvalidCapacity();

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
            status: uint8(EventStatus.ACTIVE)
        });

        // Store metadata and organizer
        eventMetadata[eventId] = params.imageUri;
        eventOrganizers[eventId] = msg.sender;

        // Store ticket tiers
        for (uint256 i = 0; i < tiers.length; i++) {
            if (tiers[i].maxSupply == 0) revert TierMustHaveSupply();
            if (tiers[i].startSaleTime > tiers[i].endSaleTime) revert InvalidSaleTimes();
            ticketTiers[eventId][i] = tiers[i];
        }

        // Store payment splits
        for (uint256 i = 0; i < splits.length; i++) {
            eventPaymentSplits[eventId].push(splits[i]);
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
        // CHECKS: Validate inputs and event state
        if (events[eventId].startTime == 0) revert EventNotFound();
        if (quantity == 0 || quantity > MAX_TICKET_QUANTITY) revert InvalidQuantity();

        TicketTier storage tier = ticketTiers[eventId][tierId];
        if (tier.maxSupply == 0) revert TierNotFound();
        if (block.timestamp < tier.startSaleTime) revert SaleNotStarted();
        if (block.timestamp > tier.endSaleTime) revert SaleEnded();
        if (tier.sold + quantity > tier.maxSupply) revert InsufficientCapacity();

        // Calculate total cost with dynamic pricing
        uint256 totalCost = calculatePrice(eventId, tierId, quantity);
        if (msg.value < totalCost) revert InsufficientPayment();

        // EFFECTS: Update state before external calls
        tier.sold += quantity;

        // Track payment for potential refunds
        userTicketPayments[eventId][msg.sender] += totalCost;

        // Mint ERC-6909 tickets - use unique IDs to avoid collisions
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = generateTokenId(TokenType.EVENT_TICKET, eventId, tierId, tier.sold - quantity + i + 1);
            _mint(msg.sender, tokenId, 1);
        }

        // Calculate and distribute payments
        uint256 protocolFee = (totalCost * protocolFeeBps) / 10_000;
        uint256 netAmount = totalCost - protocolFee;

        // Add protocol fee to pending withdrawals
        if (protocolFee > 0 && feeTo != address(0)) {
            pendingWithdrawals[feeTo] += protocolFee;
        }

        // Distribute net amount according to payment splits
        _distributePayment(eventId, netAmount);

        // INTERACTIONS: Refund excess payment last
        if (msg.value > totalCost) {
            (bool success,) = payable(msg.sender).call{ value: msg.value - totalCost }("");
            if (!success) revert RefundFailed();
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
        if (tier.maxSupply == 0) revert TierNotFound();

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
        if (msg.value == 0) revert MustSendValue();
        if (events[eventId].startTime == 0) revert EventNotFound();

        // Track tip for potential refunds
        userTipPayments[eventId][msg.sender] += msg.value;

        // Calculate protocol fee
        uint256 protocolFee = (msg.value * protocolFeeBps) / 10_000;
        uint256 netAmount = msg.value - protocolFee;

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
        if (amount == 0) revert NoFundsToClaim();

        // Effects before interactions
        pendingWithdrawals[msg.sender] = 0;

        // Safe transfer
        (bool success,) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert TransferFailed();

        emit FundsClaimed(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        SOCIAL GRAPH SYSTEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a friend to your social graph
    /// @param friend Address to add as friend
    function addFriend(address friend) external {
        if (friend == msg.sender) revert CannotAddYourself();
        if (friend == address(0)) revert InvalidAddress();
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
        if (events[eventId].startTime == 0) revert EventNotFound();
        SocialLibrary.updateRSVP(rsvps, attendeeLists, eventId, msg.sender, status);
        emit RSVPUpdated(eventId, msg.sender, status);
    }

    /// @notice Invite friends to an event
    /// @param eventId Event to invite friends to
    /// @param friends Array of friend addresses to invite
    function inviteFriends(uint256 eventId, address[] calldata friends) external view {
        if (events[eventId].startTime == 0) revert EventNotFound();

        for (uint256 i = 0; i < friends.length; i++) {
            if (!isFriend[msg.sender][friends[i]]) revert NotFriends();
        }
    }

    /*//////////////////////////////////////////////////////////////
                        COMMENT SYSTEM
    //////////////////////////////////////////////////////////////*/

    function postComment(uint256 eventId, string calldata content, uint256 parentId) external {
        if (events[eventId].startTime == 0) revert EventNotFound();
        if (bannedUsers[msg.sender]) revert Banned();
        if (bytes(content).length == 0 || bytes(content).length > 1000) revert InvalidContentLength();

        // Validate parent comment if replying
        if (parentId > 0) {
            if (comments[parentId].timestamp == 0) revert ParentNotFound();
            if (comments[parentId].isDeleted) revert ParentDeleted();
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
        if (events[eventId].startTime == 0) revert EventNotFound();

        CommentLibrary.Comment storage comment = comments[commentId];
        if (comment.timestamp == 0) revert CommentNotFound();
        if (comment.author != msg.sender && eventOrganizers[eventId] != msg.sender && msg.sender != feeTo) revert NotAuthorized();

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

    function getCommentReplies(uint256 parentId, uint256 eventId) external view returns (uint256[] memory) {
        uint256[] memory eventCommentIds = eventComments[eventId];
        uint256[] memory tempReplies = new uint256[](eventCommentIds.length); // Max possible size
        uint256 replyCount = 0;

        // Single loop to find replies
        for (uint256 i = 0; i < eventCommentIds.length; i++) {
            if (comments[eventCommentIds[i]].parentId == parentId) {
                tempReplies[replyCount] = eventCommentIds[i];
                replyCount++;
            }
        }

        // Create correctly sized array
        uint256[] memory replyIds = new uint256[](replyCount);
        for (uint256 i = 0; i < replyCount; i++) {
            replyIds[i] = tempReplies[i];
        }

        return replyIds;
    }

    function banUser(address user, uint256 eventId) external {
        if (events[eventId].startTime == 0) revert EventNotFound();
        if (eventOrganizers[eventId] != msg.sender && msg.sender != feeTo) revert NotAuthorized();
        if (bannedUsers[user]) revert AlreadyBanned();

        bannedUsers[user] = true;
        emit UserBanned(user, msg.sender);
    }

    function unbanUser(address user, uint256 eventId) external {
        if (events[eventId].startTime == 0) revert EventNotFound();
        if (eventOrganizers[eventId] != msg.sender && msg.sender != feeTo) revert NotAuthorized();
        if (!bannedUsers[user]) revert NotBanned();

        bannedUsers[user] = false;
        emit UserUnbanned(user, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC-6909 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    function transfer(address from, address to, uint256 id, uint256 amount) external {
        if (msg.sender != from && !isOperator[from][msg.sender] && allowance[from][msg.sender][id] < amount) {
            revert InsufficientPermission();
        }

        TokenType tokenType = TokenType(id >> 248);
        if (tokenType == TokenType.ATTENDANCE_BADGE || tokenType == TokenType.ORGANIZER_CRED) {
            revert SoulboundToken();
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
        PaymentSplit[] memory splits = eventPaymentSplits[eventId];

        for (uint256 i = 0; i < splits.length; i++) {
            uint256 payment = (amount * splits[i].basisPoints) / 10_000;
            pendingWithdrawals[splits[i].recipient] += payment;
            emit PaymentAllocated(eventId, splits[i].recipient, payment, splits[i].role);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validatePaymentSplits(PaymentSplit[] calldata splits) internal pure {
        if (splits.length == 0) revert NoSplits();
        if (splits.length > MAX_PAYMENT_SPLITS) revert TooManySplits();

        uint256 totalBps = 0;
        for (uint256 i = 0; i < splits.length; i++) {
            if (splits[i].recipient == address(0)) revert InvalidRecipient();
            if (splits[i].basisPoints == 0) revert InvalidBasisPoints();
            totalBps += splits[i].basisPoints;
        }
        if (totalBps != 10_000) revert InvalidTotalBasisPoints();
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

    function getAttendees(uint256 eventId) external view returns (address[] memory) {
        return attendeeLists[eventId];
    }

    function getFriendsAttending(uint256 eventId, address user) external view returns (address[] memory) {
        return SocialLibrary.getFriendsAttending(friendLists, rsvps, eventId, user);
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
        if (newFeeTo == address(0)) revert InvalidFeeRecipient();
        address oldFeeTo = feeTo;
        feeTo = newFeeTo;
        emit FeeToUpdated(oldFeeTo, newFeeTo);
    }

    function setProtocolFee(uint256 newFeeBps) external onlyFeeTo {
        if (newFeeBps > MAX_PROTOCOL_FEE) revert FeeToHigh();
        uint256 oldFee = protocolFeeBps;
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(oldFee, newFeeBps);
    }

    /*//////////////////////////////////////////////////////////////
                    EVENT CANCELLATION & REFUNDS
    //////////////////////////////////////////////////////////////*/

    /// @notice Cancel an event and enable refunds
    /// @param eventId Event to cancel
    /// @dev Only organizer can cancel before event starts
    function cancelEvent(uint256 eventId) external onlyOrganizer(eventId) nonReentrant {
        if (events[eventId].startTime == 0) revert EventNotFound();
        if (events[eventId].status != uint8(EventStatus.ACTIVE)) revert EventNotActive();
        if (block.timestamp >= events[eventId].startTime) revert EventAlreadyStarted();
        if (eventCancelled[eventId]) revert AlreadyCancelled();

        // Mark event as cancelled
        events[eventId].status = uint8(EventStatus.CANCELLED);
        eventCancelled[eventId] = true;

        // Set cancellation timestamp
        eventCancellationTime[eventId] = block.timestamp;

        emit EventCancelled(eventId, msg.sender, block.timestamp);
    }

    /// @notice Claim refund for cancelled event tickets
    /// @param eventId Cancelled event ID
    function claimTicketRefund(uint256 eventId) external nonReentrant {
        if (!eventCancelled[eventId]) revert EventNotCancelled();
        if (block.timestamp > eventCancellationTime[eventId] + REFUND_CLAIM_DEADLINE) revert RefundDeadlineExpired();

        uint256 refundAmount = userTicketPayments[eventId][msg.sender];
        if (refundAmount == 0) revert NoRefundAvailable();

        // Clear payment tracking to prevent re-claiming
        userTicketPayments[eventId][msg.sender] = 0;

        // Transfer refund
        (bool success,) = payable(msg.sender).call{ value: refundAmount }("");
        if (!success) revert TransferFailed();

        emit RefundClaimed(eventId, msg.sender, refundAmount, "ticket");
    }

    /// @notice Claim refund for cancelled event tips
    /// @param eventId Cancelled event ID
    function claimTipRefund(uint256 eventId) external nonReentrant {
        if (!eventCancelled[eventId]) revert EventNotCancelled();
        if (block.timestamp > eventCancellationTime[eventId] + REFUND_CLAIM_DEADLINE) revert RefundDeadlineExpired();

        uint256 refundAmount = userTipPayments[eventId][msg.sender];
        if (refundAmount == 0) revert NoRefundAvailable();

        // Clear payment tracking to prevent re-claiming
        userTipPayments[eventId][msg.sender] = 0;

        // Transfer refund
        (bool success,) = payable(msg.sender).call{ value: refundAmount }("");
        if (!success) revert TransferFailed();

        emit RefundClaimed(eventId, msg.sender, refundAmount, "tip");
    }

    /*//////////////////////////////////////////////////////////////
                        ATTENDANCE & BADGES SYSTEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Basic event check-in (user-level)
    /// @param eventId Event to check into
    /// @dev Mints a single attendance badge per user per event
    function checkIn(uint256 eventId) external {
        PackedEventData memory eventData = events[eventId];
        if (eventData.startTime == 0) revert EventNotFound();
        if (block.timestamp < eventData.startTime) revert EventNotStarted();
        if (block.timestamp > eventData.startTime + 86_400) revert EventEnded();

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
        if (eventData.startTime == 0) revert EventNotFound();
        if (block.timestamp < eventData.startTime) revert EventNotStarted();
        if (block.timestamp > eventData.startTime + 86_400) revert EventEnded();

        // Verify user owns the ticket
        if (balanceOf[msg.sender][ticketTokenId] == 0) revert TicketNotOwned();
        
        // Verify ticket is for this event
        if (!isValidTicketForEvent(ticketTokenId, eventId)) revert InvalidTicketForEvent();
        
        // Extract tier information from token ID
        uint256 tierId = (ticketTokenId >> 152) & 0xFFFFFFFF;
        
        // Check if this specific ticket was already used
        if (usedTickets[ticketTokenId]) revert TicketAlreadyUsed();
        
        // Mark ticket as used
        usedTickets[ticketTokenId] = true;
        
        // Mint tier-specific attendance badge
        uint256 badgeId = generateTokenId(TokenType.ATTENDANCE_BADGE, eventId, tierId, 0);
        
        if (balanceOf[msg.sender][badgeId] == 0) {
            _mint(msg.sender, badgeId, 1);
        }
        
        emit TicketUsed(eventId, msg.sender, ticketTokenId, tierId);
        emit AttendanceVerified(eventId, msg.sender);
    }

    /// @notice Check if a specific ticket has been used
    /// @param ticketTokenId Ticket token ID to check
    /// @return used True if ticket has been used for check-in
    function isTicketUsed(uint256 ticketTokenId) external view returns (bool used) {
        return usedTickets[ticketTokenId];
    }

    /// @notice Get attendance badge for specific tier
    /// @param user User address
    /// @param eventId Event ID 
    /// @param tierId Tier ID (0 for basic attendance)
    /// @return attended True if user has tier-specific attendance badge
    function hasAttendedTier(address user, uint256 eventId, uint256 tierId) external view returns (bool attended) {
        uint256 badgeId = generateTokenId(TokenType.ATTENDANCE_BADGE, eventId, tierId, 0);
        return balanceOf[user][badgeId] > 0;
    }

    function claimOrganizerCredential(uint256 eventId) external {
        if (eventOrganizers[eventId] != msg.sender) revert NotOrganizer();

        PackedEventData memory eventData = events[eventId];
        if (block.timestamp <= eventData.startTime + 86_400) revert EventNotCompleted();

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
        if (eventData.startTime == 0) revert EventNotFound();
        if (block.timestamp < eventData.startTime) revert EventNotStarted();
        if (block.timestamp > eventData.startTime + 86_400) revert EventEnded();

        // Verify caller owns the ticket (ticket purchaser can check in others)
        if (balanceOf[msg.sender][ticketTokenId] == 0) revert TicketNotOwned();
        
        // Verify ticket is for this event
        if (!isValidTicketForEvent(ticketTokenId, eventId)) revert InvalidTicketForEvent();
        
        // Extract tier information from token ID
        uint256 tierId = (ticketTokenId >> 152) & 0xFFFFFFFF;
        
        // Check if this specific ticket was already used
        if (usedTickets[ticketTokenId]) revert TicketAlreadyUsed();
        
        // Mark ticket as used
        usedTickets[ticketTokenId] = true;
        
        // Mint tier-specific attendance badge for the attendee (not ticket owner)
        uint256 badgeId = generateTokenId(TokenType.ATTENDANCE_BADGE, eventId, tierId, 0);
        
        if (balanceOf[attendee][badgeId] == 0) {
            _mint(attendee, badgeId, 1);
        }
        
        emit TicketUsed(eventId, attendee, ticketTokenId, tierId);
        emit AttendanceVerified(eventId, attendee);
    }
}
