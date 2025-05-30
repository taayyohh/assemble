// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Assemble Protocol
/// @notice A foundational singleton smart contract protocol for onchain social coordination and event management
/// @dev Built with ERC-6909 multi-token architecture and EIP-1153 transient storage for gas optimization
/// @author Assemble Protocol Team
contract Assemble {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum number of payment splits per event for gas optimization
    uint256 public constant MAX_PAYMENT_SPLITS = 20;
    
    /// @notice Maximum ticket quantity per purchase to prevent gas limit issues
    uint256 public constant MAX_TICKET_QUANTITY = 50;
    
    /// @notice Maximum price multiplier (3x) to prevent manipulation
    uint256 public constant MAX_PRICE_MULTIPLIER = 300;
    
    /// @notice Maximum social discount (20%) to prevent exploitation
    uint256 public constant MAX_SOCIAL_DISCOUNT = 2000;
    
    /// @notice Maximum protocol fee (10%) for governance limits
    uint256 public constant MAX_PROTOCOL_FEE = 1000;

    /*//////////////////////////////////////////////////////////////
                        TRANSIENT STORAGE SLOTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transient storage slot for pricing calculations
    uint256 private constant PRICING_SLOT = 0x1001;
    
    /// @notice Transient storage slot for batch operations
    uint256 private constant BATCH_OPERATION_SLOT = 0x1002;
    
    /// @notice Transient storage slot for reentrancy protection
    uint256 private constant REENTRANCY_SLOT = 0x1003;

    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Token types for ERC-6909 multi-token system
    enum TokenType {
        NONE,
        EVENT_TICKET,       // Transferrable event tickets
        ATTENDANCE_BADGE,   // Soulbound attendance proof (ERC-5192)
        ORGANIZER_CRED     // Soulbound organizer reputation
    }

    /// @notice RSVP status for social coordination
    enum RSVPStatus {
        NO_RESPONSE,
        GOING,
        INTERESTED,
        NOT_GOING
    }

    /// @notice Event visibility levels
    enum EventVisibility {
        PUBLIC,
        PRIVATE,
        INVITE_ONLY
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Packed storage for events (optimized for gas)
    struct PackedEventData {
        uint128 basePrice;      // Sufficient for most pricing
        uint64 startTime;       // Unix timestamp
        uint32 capacity;        // 4B max attendees
        uint16 venueId;         // 65k venues
        uint8 visibility;       // Event visibility
        uint8 flags;            // Boolean flags packed
    }

    /// @notice Event creation parameters
    struct EventParams {
        string title;
        string description;
        string imageUri;        // IPFS hash for event image
        uint256 startTime;
        uint256 endTime;
        uint256 capacity;
        uint256 venueId;        // Reference to venue registry
        EventVisibility visibility;
    }

    /// @notice Ticket tier configuration
    struct TicketTier {
        string name;            // "Early Bird", "VIP", "General"
        uint256 price;          // Price in wei
        uint256 maxSupply;      // Maximum tickets for this tier
        uint256 sold;           // Tickets sold so far
        uint256 startSaleTime;  // When this tier becomes available
        uint256 endSaleTime;    // When this tier stops being available
        bool transferrable;     // Whether tickets can be resold
    }

    /// @notice Payment split configuration for revenue distribution
    struct PaymentSplit {
        address recipient;      // Address to receive funds
        uint256 basisPoints;    // Share out of 10000 (100%)
        string role;           // "organizer", "venue", "artist", etc.
    }

    /// @notice Token ID structure for ERC-6909 (256 bits)
    struct TokenId {
        uint8 tokenType;        // TokenType enum value
        uint64 eventId;         // Primary event identifier
        uint32 tierId;          // Ticket tier or badge type
        uint64 serialNumber;    // Individual token serial
        uint88 metadata;        // Additional type-specific data
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Next event ID counter
    uint256 public nextEventId = 1;
    
    /// @notice Protocol fee in basis points (0.5% = 50 bps)
    uint256 public protocolFeeBps = 50;
    
    /// @notice Address that receives protocol fees
    address public feeTo;

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/

    // Core event data
    mapping(uint256 => PackedEventData) public events;
    mapping(uint256 => string) public eventMetadata;
    mapping(uint256 => mapping(uint256 => TicketTier)) public ticketTiers;
    mapping(uint256 => PaymentSplit[]) public eventPaymentSplits;
    mapping(uint256 => address) public eventOrganizers;

    // Security: Pull payment pattern
    mapping(address => uint256) public pendingWithdrawals;
    mapping(uint256 => mapping(address => uint256)) public eventPendingFunds;

    // Social graph
    mapping(address => mapping(address => bool)) public isFriend;
    mapping(address => address[]) public friendLists;
    mapping(uint256 => mapping(address => RSVPStatus)) public rsvps;
    mapping(uint256 => address[]) public attendeeLists;

    // ERC-6909 core storage
    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public allowance;
    mapping(address => mapping(address => bool)) public isOperator;
    mapping(uint256 => uint256) public totalSupply;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    // Core protocol events
    event EventCreated(uint256 indexed eventId, address indexed organizer, uint256 startTime);
    event TicketPurchased(uint256 indexed eventId, address indexed buyer, uint256 quantity, uint256 price);
    event RSVPUpdated(uint256 indexed eventId, address indexed user, RSVPStatus status);
    event FriendAdded(address indexed user1, address indexed user2);
    event FriendRemoved(address indexed user1, address indexed user2);
    event InvitationSent(uint256 indexed eventId, address indexed inviter, address indexed invitee);
    event PaymentAllocated(uint256 indexed eventId, address indexed recipient, uint256 amount, string role);
    event FundsClaimed(address indexed recipient, uint256 amount);
    event EventTipped(uint256 indexed eventId, address indexed tipper, uint256 amount);
    event AttendanceVerified(uint256 indexed eventId, address indexed attendee);

    // Admin events
    event FeeToUpdated(address indexed oldFeeTo, address indexed newFeeTo);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);

    // ERC-6909 events
    event Transfer(
        address indexed caller,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 indexed id,
        uint256 amount
    );
    event OperatorSet(address indexed owner, address indexed operator, bool approved);

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
        assembly { tstore(REENTRANCY_SLOT, 0) }
    }

    /// @notice Only event organizer modifier
    modifier onlyOrganizer(uint256 eventId) {
        require(eventOrganizers[eventId] == msg.sender, "Not event organizer");
        _;
    }

    /// @notice Only fee recipient modifier
    modifier onlyFeeTo() {
        require(msg.sender == feeTo, "Not authorized");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Assemble protocol
    /// @param _feeTo Initial fee recipient address
    constructor(address _feeTo) {
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
    ) external returns (uint256 eventId) {
        // Input validation
        require(params.startTime > block.timestamp, "Event must be in future");
        require(params.endTime > params.startTime, "Invalid end time");
        require(tiers.length > 0, "Must have at least one tier");
        require(params.capacity > 0, "Capacity must be greater than 0");
        
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
            flags: 0
        });
        
        // Store metadata and organizer
        eventMetadata[eventId] = params.imageUri;
        eventOrganizers[eventId] = msg.sender;
        
        // Store ticket tiers
        for (uint256 i = 0; i < tiers.length; i++) {
            require(tiers[i].maxSupply > 0, "Tier must have supply");
            require(tiers[i].startSaleTime <= tiers[i].endSaleTime, "Invalid sale times");
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
    function purchaseTickets(
        uint256 eventId,
        uint256 tierId,
        uint256 quantity
    ) external payable nonReentrant {
        // CHECKS: Validate inputs and event state
        require(events[eventId].startTime > 0, "Event does not exist");
        require(quantity > 0 && quantity <= MAX_TICKET_QUANTITY, "Invalid quantity");
        
        TicketTier storage tier = ticketTiers[eventId][tierId];
        require(tier.maxSupply > 0, "Tier does not exist");
        require(block.timestamp >= tier.startSaleTime, "Sales not started");
        require(block.timestamp <= tier.endSaleTime, "Sales ended");
        require(tier.sold + quantity <= tier.maxSupply, "Exceeds tier capacity");
        
        // Calculate total cost with dynamic pricing
        uint256 totalCost = calculatePrice(eventId, tierId, quantity, msg.sender);
        require(msg.value >= totalCost, "Insufficient payment");
        
        // EFFECTS: Update state before external calls
        tier.sold += quantity;
        
        // Mint ERC-6909 tickets
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _generateTokenId(
                TokenType.EVENT_TICKET,
                eventId,
                tierId,
                tier.sold - quantity + i + 1
            );
            _mint(msg.sender, tokenId, 1);
        }
        
        // Calculate and distribute payments
        uint256 protocolFee = (totalCost * protocolFeeBps) / 10000;
        uint256 netAmount = totalCost - protocolFee;
        
        // Add protocol fee to pending withdrawals
        if (protocolFee > 0 && feeTo != address(0)) {
            pendingWithdrawals[feeTo] += protocolFee;
        }
        
        // Distribute net amount according to payment splits
        _distributePayment(eventId, netAmount);
        
        // INTERACTIONS: Refund excess payment last
        if (msg.value > totalCost) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - totalCost}("");
            require(success, "Refund failed");
        }
        
        emit TicketPurchased(eventId, msg.sender, quantity, totalCost);
    }

    /// @notice Calculate ticket price with dynamic pricing and social discounts
    /// @param eventId Event identifier
    /// @param tierId Ticket tier identifier
    /// @param quantity Number of tickets
    /// @param buyer Address of the buyer
    /// @return totalPrice Final price including all adjustments
    function calculatePrice(
        uint256 eventId,
        uint256 tierId,
        uint256 quantity,
        address buyer
    ) public view returns (uint256 totalPrice) {
        TicketTier storage tier = ticketTiers[eventId][tierId];
        require(tier.maxSupply > 0, "Tier does not exist");
        
        uint256 basePrice = tier.price;
        
        // Calculate demand multiplier (simple linear model)
        uint256 demandMultiplier = _calculateDemandMultiplier(eventId, tierId);
        
        // Apply pricing formula: base * quantity * demand
        totalPrice = (basePrice * quantity * demandMultiplier) / 1000;
        
        // Calculate and apply social discount
        uint256 socialDiscount = _calculateSocialDiscount(eventId, buyer);
        
        // Apply social discount (ensure no underflow)
        if (socialDiscount > 0 && socialDiscount < totalPrice) {
            totalPrice -= socialDiscount;
        } else if (socialDiscount >= totalPrice) {
            // If discount equals or exceeds price, set minimum price (small amount to prevent free tickets)
            totalPrice = basePrice / 100; // 1% minimum
        }
        
        // Ensure minimum price of at least 1 wei
        if (totalPrice == 0) {
            totalPrice = 1;
        }
    }

    /// @notice Tip an event directly (independent of ticket sales)
    /// @param eventId Event to tip
    function tipEvent(uint256 eventId) external payable nonReentrant {
        require(msg.value > 0, "Must send some value");
        require(events[eventId].startTime > 0, "Event does not exist");
        
        // Calculate protocol fee
        uint256 protocolFee = (msg.value * protocolFeeBps) / 10000;
        uint256 netAmount = msg.value - protocolFee;
        
        // Add protocol fee to pending withdrawals
        if (protocolFee > 0 && feeTo != address(0)) {
            pendingWithdrawals[feeTo] += protocolFee;
        }
        
        // Distribute net amount according to payment splits
        _distributePayment(eventId, netAmount);
        
        emit EventTipped(eventId, msg.sender, msg.value);
    }

    /// @notice Claim pending funds (pull payment pattern)
    function claimFunds() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to claim");
        
        // Effects before interactions
        pendingWithdrawals[msg.sender] = 0;
        
        // Safe transfer
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit FundsClaimed(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        SOCIAL GRAPH SYSTEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a friend to your social graph
    /// @param friend Address to add as friend
    function addFriend(address friend) external {
        require(friend != msg.sender, "Cannot add yourself");
        require(friend != address(0), "Invalid address");
        require(!isFriend[msg.sender][friend], "Already friends");
        
        isFriend[msg.sender][friend] = true;
        friendLists[msg.sender].push(friend);
        
        emit FriendAdded(msg.sender, friend);
    }

    /// @notice Remove a friend from your social graph
    /// @param friend Address to remove as friend
    function removeFriend(address friend) external {
        require(isFriend[msg.sender][friend], "Not friends");
        
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
    function updateRSVP(uint256 eventId, RSVPStatus status) external {
        require(events[eventId].startTime > 0, "Event does not exist");
        
        RSVPStatus oldStatus = rsvps[eventId][msg.sender];
        rsvps[eventId][msg.sender] = status;
        
        // Update attendee list if status changed to/from GOING
        if (oldStatus != RSVPStatus.GOING && status == RSVPStatus.GOING) {
            attendeeLists[eventId].push(msg.sender);
        } else if (oldStatus == RSVPStatus.GOING && status != RSVPStatus.GOING) {
            // Remove from attendee list
            address[] storage attendees = attendeeLists[eventId];
            for (uint256 i = 0; i < attendees.length; i++) {
                if (attendees[i] == msg.sender) {
                    attendees[i] = attendees[attendees.length - 1];
                    attendees.pop();
                    break;
                }
            }
        }
        
        emit RSVPUpdated(eventId, msg.sender, status);
    }

    /// @notice Invite friends to an event using EIP-1153 for gas optimization
    /// @param eventId Event to invite friends to
    /// @param friends Array of friend addresses to invite
    /// @param message Optional invitation message
    function inviteFriends(
        uint256 eventId,
        address[] calldata friends,
        string calldata message
    ) external {
        require(events[eventId].startTime > 0, "Event does not exist");
        
        // Use transient storage for batch operations
        assembly {
            tstore(BATCH_OPERATION_SLOT, eventId)
        }
        
        for (uint256 i = 0; i < friends.length; i++) {
            require(isFriend[msg.sender][friends[i]], "Not friends");
            emit InvitationSent(eventId, msg.sender, friends[i]);
        }
        
        // Clear transient storage
        assembly {
            tstore(BATCH_OPERATION_SLOT, 0)
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ERC-6909 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer tokens between addresses
    /// @param from Source address
    /// @param to Destination address
    /// @param id Token ID
    /// @param amount Amount to transfer
    function transfer(address from, address to, uint256 id, uint256 amount) external {
        require(
            msg.sender == from || isOperator[from][msg.sender] || allowance[from][msg.sender][id] >= amount,
            "Insufficient permission"
        );
        
        // Check if token is soulbound (attendance badges, organizer creds)
        TokenType tokenType = TokenType(id >> 248);
        require(
            tokenType == TokenType.EVENT_TICKET || 
            (tokenType != TokenType.ATTENDANCE_BADGE && tokenType != TokenType.ORGANIZER_CRED),
            "Soulbound token"
        );
        
        if (msg.sender != from && !isOperator[from][msg.sender]) {
            allowance[from][msg.sender][id] -= amount;
        }
        
        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;
        
        emit Transfer(msg.sender, from, to, id, amount);
    }

    /// @notice Approve spending of tokens
    /// @param spender Address to approve
    /// @param id Token ID
    /// @param amount Amount to approve
    function approve(address spender, uint256 id, uint256 amount) external {
        allowance[msg.sender][spender][id] = amount;
        emit Approval(msg.sender, spender, id, amount);
    }

    /// @notice Set operator status for all tokens
    /// @param operator Address to set operator status for
    /// @param approved Whether operator is approved
    function setOperator(address operator, bool approved) external {
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint new tokens (internal)
    /// @param to Recipient address
    /// @param id Token ID
    /// @param amount Amount to mint
    function _mint(address to, uint256 id, uint256 amount) internal {
        balanceOf[to][id] += amount;
        totalSupply[id] += amount;
        emit Transfer(msg.sender, address(0), to, id, amount);
    }

    /// @notice Distribute payment according to event splits
    /// @param eventId Event identifier
    /// @param amount Amount to distribute
    function _distributePayment(uint256 eventId, uint256 amount) internal {
        PaymentSplit[] memory splits = eventPaymentSplits[eventId];
        
        for (uint256 i = 0; i < splits.length; i++) {
            uint256 payment = (amount * splits[i].basisPoints) / 10000;
            
            // SECURE: Add to pending withdrawals instead of direct transfer
            pendingWithdrawals[splits[i].recipient] += payment;
            eventPendingFunds[eventId][splits[i].recipient] += payment;
            
            emit PaymentAllocated(eventId, splits[i].recipient, payment, splits[i].role);
        }
    }

    /// @notice Calculate demand-based pricing multiplier
    /// @param eventId Event identifier
    /// @param tierId Tier identifier
    /// @return multiplier Demand multiplier (1000 = 1x, 1500 = 1.5x)
    function _calculateDemandMultiplier(uint256 eventId, uint256 tierId) internal view returns (uint256 multiplier) {
        TicketTier storage tier = ticketTiers[eventId][tierId];
        
        if (tier.maxSupply == 0) return 1000; // No demand calculation for invalid tier
        
        // Simple linear demand model: price increases as tickets sell out
        uint256 soldPercentage = (tier.sold * 1000) / tier.maxSupply;
        
        // Base 1x, increases linearly. Cap soldPercentage to prevent overflow
        if (soldPercentage > 1000) {
            soldPercentage = 1000; // 100% cap
        }
        
        // Calculate multiplier: 1000 (1x) + up to 2000 (2x more) = max 3000 (3x total)
        uint256 additionalMultiplier = (soldPercentage * 2000) / 1000; // Max 2000 additional
        multiplier = 1000 + additionalMultiplier;
        
        // Final safety cap at configured maximum
        if (multiplier > (1000 + MAX_PRICE_MULTIPLIER)) {
            multiplier = 1000 + MAX_PRICE_MULTIPLIER;
        }
    }

    /// @notice Calculate social discount based on friends attending
    /// @param eventId Event identifier
    /// @param buyer Buyer address
    /// @return discount Discount amount in wei
    function _calculateSocialDiscount(uint256 eventId, address buyer) internal view returns (uint256 discount) {
        address[] memory friends = friendLists[buyer];
        uint256 friendsAttending = 0;
        
        for (uint256 i = 0; i < friends.length; i++) {
            if (rsvps[eventId][friends[i]] == RSVPStatus.GOING) {
                friendsAttending++;
            }
        }
        
        // 2% discount per friend attending, max 20%
        uint256 discountBps = friendsAttending * 200; // 2% = 200 bps
        if (discountBps > MAX_SOCIAL_DISCOUNT) {
            discountBps = MAX_SOCIAL_DISCOUNT;
        }
        
        // Only calculate discount if there are friends attending and event exists
        if (discountBps == 0 || events[eventId].startTime == 0) {
            return 0;
        }
        
        // Calculate discount based on base price from first tier
        TicketTier storage tier = ticketTiers[eventId][0];
        if (tier.maxSupply == 0) {
            return 0; // No valid tier found
        }
        
        discount = (tier.price * discountBps) / 10000;
    }

    /*//////////////////////////////////////////////////////////////
                            UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validate payment splits total 100% and meet constraints
    /// @param splits Array of payment splits to validate
    function _validatePaymentSplits(PaymentSplit[] calldata splits) internal pure {
        require(splits.length > 0, "Must have at least one payment split");
        require(splits.length <= MAX_PAYMENT_SPLITS, "Too many payment splits");
        
        uint256 totalBps = 0;
        for (uint256 i = 0; i < splits.length; i++) {
            require(splits[i].recipient != address(0), "Invalid recipient");
            require(splits[i].basisPoints > 0, "Split must be greater than 0");
            totalBps += splits[i].basisPoints;
        }
        require(totalBps == 10000, "Splits must total exactly 100%");
    }

    /// @notice Generate token ID from components
    /// @param tokenType Type of token being created
    /// @param eventId Event identifier
    /// @param tierId Tier identifier
    /// @param serialNumber Unique serial number
    /// @return tokenId Packed 256-bit token identifier
    function _generateTokenId(
        TokenType tokenType,
        uint256 eventId,
        uint256 tierId,
        uint256 serialNumber
    ) public pure returns (uint256 tokenId) {
        return (uint256(tokenType) << 248) | (eventId << 184) | (tierId << 152) | serialNumber;
    }

    /// @notice Check if token ID is valid for an event
    /// @param tokenId Token to validate
    /// @param eventId Event to check against
    /// @return isValid Whether token belongs to the event
    function _isValidTicketForEvent(uint256 tokenId, uint256 eventId) public pure returns (bool isValid) {
        uint256 tokenEventId = (tokenId >> 184) & 0xFFFFFFFFFFFFFFFF;
        return tokenEventId == eventId;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get list of friends for a user
    /// @param user Address to get friends for
    /// @return friends Array of friend addresses
    function getFriends(address user) external view returns (address[] memory friends) {
        return friendLists[user];
    }

    /// @notice Get attendees going to an event
    /// @param eventId Event identifier
    /// @return attendees Array of addresses going to the event
    function getAttendees(uint256 eventId) external view returns (address[] memory attendees) {
        return attendeeLists[eventId];
    }

    /// @notice Get mutual friends attending an event
    /// @param eventId Event identifier
    /// @param user User to check mutual friends for
    /// @return mutualFriends Array of mutual friends attending
    function getMutualFriendsAttending(
        uint256 eventId,
        address user
    ) external view returns (address[] memory mutualFriends) {
        address[] memory friends = friendLists[user];
        address[] memory attendees = attendeeLists[eventId];
        
        // Count mutual friends first
        uint256 count = 0;
        for (uint256 i = 0; i < friends.length; i++) {
            for (uint256 j = 0; j < attendees.length; j++) {
                if (friends[i] == attendees[j]) {
                    count++;
                    break;
                }
            }
        }
        
        // Build result array
        mutualFriends = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < friends.length; i++) {
            for (uint256 j = 0; j < attendees.length; j++) {
                if (friends[i] == attendees[j]) {
                    mutualFriends[index] = friends[i];
                    index++;
                    break;
                }
            }
        }
    }

    /// @notice Get friends attending an event
    /// @param eventId Event identifier
    /// @param user User to check friends for
    /// @return friendsGoing Array of friends attending the event
    function getFriendsAttending(
        uint256 eventId,
        address user
    ) external view returns (address[] memory friendsGoing) {
        address[] memory friends = friendLists[user];
        
        // Count friends going first
        uint256 count = 0;
        for (uint256 i = 0; i < friends.length; i++) {
            if (rsvps[eventId][friends[i]] == RSVPStatus.GOING) {
                count++;
            }
        }
        
        // Build result array
        friendsGoing = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < friends.length; i++) {
            if (rsvps[eventId][friends[i]] == RSVPStatus.GOING) {
                friendsGoing[index] = friends[i];
                index++;
            }
        }
    }

    /// @notice Check if user has attended an event (for external protocol integration)
    /// @param user Address to check
    /// @param eventId Event identifier
    /// @return attended Whether user has attendance badge for the event
    function hasAttended(address user, uint256 eventId) external view returns (bool attended) {
        uint256 badgeId = _generateTokenId(TokenType.ATTENDANCE_BADGE, eventId, 0, 0);
        return balanceOf[user][badgeId] > 0;
    }

    /// @notice Get reputation score for a user (for external protocol integration)
    /// @param user Address to check reputation for
    /// @return score Reputation score based on events organized and attended
    function getReputationScore(address user) external view returns (uint256 score) {
        // Simple reputation model: points for organizing + attending events
        // This could be expanded with more sophisticated scoring
        score = 0;
        
        // Count events organized (assuming we track this in future versions)
        // For now, return a placeholder that could be extended
        return score;
    }

    /// @notice Check if an event is currently active
    /// @param eventId Event identifier
    /// @return isActive Whether the event is currently happening
    function isEventActive(uint256 eventId) external view returns (bool isActive) {
        PackedEventData memory eventData = events[eventId];
        return block.timestamp >= eventData.startTime && 
               block.timestamp <= (eventData.startTime + 1 days); // Assume 1 day duration
    }

    /// @notice Get payment splits for an event
    /// @param eventId Event identifier
    /// @return splits Array of payment split configurations
    function getPaymentSplits(uint256 eventId) external view returns (PaymentSplit[] memory splits) {
        return eventPaymentSplits[eventId];
    }

    /// @notice Get pending funds for an address in a specific event
    /// @param eventId Event identifier
    /// @param recipient Address to check funds for
    /// @return amount Pending funds amount
    function getEventPendingFunds(uint256 eventId, address recipient) external view returns (uint256 amount) {
        return eventPendingFunds[eventId][recipient];
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update fee recipient (only current fee recipient can call)
    /// @param newFeeTo New fee recipient address
    function setFeeTo(address newFeeTo) external onlyFeeTo {
        address oldFeeTo = feeTo;
        feeTo = newFeeTo;
        emit FeeToUpdated(oldFeeTo, newFeeTo);
    }

    /// @notice Update protocol fee (only fee recipient can call)
    /// @param newFeeBps New fee in basis points
    function setProtocolFee(uint256 newFeeBps) external onlyFeeTo {
        require(newFeeBps <= MAX_PROTOCOL_FEE, "Fee too high");
        uint256 oldFee = protocolFeeBps;
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(oldFee, newFeeBps);
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute multiple calls in a single transaction using EIP-1153
    /// @param data Array of encoded function calls
    /// @return results Array of return data from each call
    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        
        assembly {
            tstore(BATCH_OPERATION_SLOT, 1)
        }
        
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            require(success, "Multicall failed");
            results[i] = result;
        }
        
        assembly {
            tstore(BATCH_OPERATION_SLOT, 0)
        }
        
        return results;
    }

    /*//////////////////////////////////////////////////////////////
                        ATTENDANCE & BADGES SYSTEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Check into an event and mint attendance badge
    /// @param eventId Event to check into
    /// @param tokenId Ticket token ID (must own valid ticket)
    function checkIn(uint256 eventId, uint256 tokenId) external {
        require(balanceOf[msg.sender][tokenId] > 0, "Must own ticket");
        require(_isValidTicketForEvent(tokenId, eventId), "Invalid ticket for event");
        
        PackedEventData memory eventData = events[eventId];
        require(eventData.startTime > 0, "Event does not exist");
        require(block.timestamp >= eventData.startTime, "Event not started");
        require(block.timestamp <= eventData.startTime + 1 days, "Event ended"); // 1 day event duration
        
        // Generate attendance badge ID (soulbound)
        uint256 badgeId = _generateTokenId(TokenType.ATTENDANCE_BADGE, eventId, 0, 0);
        
        // Only mint if user doesn't already have badge
        if (balanceOf[msg.sender][badgeId] == 0) {
            _mint(msg.sender, badgeId, 1);
            emit AttendanceVerified(eventId, msg.sender);
        }
    }

    /// @notice Verify event organizer and mint organizer credential
    /// @param eventId Event that was organized
    /// @dev Only callable by event organizer after event completion
    function claimOrganizerCredential(uint256 eventId) external {
        require(eventOrganizers[eventId] == msg.sender, "Not event organizer");
        
        PackedEventData memory eventData = events[eventId];
        require(block.timestamp > eventData.startTime + 1 days, "Event not completed");
        
        // Generate organizer credential ID (soulbound)
        uint256 credId = _generateTokenId(TokenType.ORGANIZER_CRED, eventId, 0, 0);
        
        // Only mint if organizer doesn't already have credential
        if (balanceOf[msg.sender][credId] == 0) {
            _mint(msg.sender, credId, 1);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GROUP PURCHASE FEATURES
    //////////////////////////////////////////////////////////////*/

    /// @notice Purchase tickets with friends for group discount
    /// @param eventId Event to purchase for
    /// @param tierId Ticket tier
    /// @param friends Array of friend addresses to purchase with
    function purchaseWithFriends(
        uint256 eventId,
        uint256 tierId,
        address[] calldata friends
    ) external payable nonReentrant {
        require(friends.length > 0, "Must include friends");
        require(friends.length <= 10, "Too many friends"); // Reasonable limit
        
        // Verify all are friends
        for (uint256 i = 0; i < friends.length; i++) {
            require(isFriend[msg.sender][friends[i]], "Not all are friends");
        }
        
        uint256 groupSize = friends.length + 1; // Include caller
        uint256 groupDiscount = _calculateGroupDiscount(groupSize);
        
        // Calculate price with group discount
        uint256 basePrice = calculatePrice(eventId, tierId, 1, msg.sender);
        uint256 discountAmount = (basePrice * groupDiscount) / 10000;
        uint256 finalPrice = basePrice > discountAmount ? basePrice - discountAmount : basePrice / 100;
        
        require(msg.value >= finalPrice, "Insufficient payment");
        
        // Purchase single ticket with group discount
        TicketTier storage tier = ticketTiers[eventId][tierId];
        require(tier.sold + 1 <= tier.maxSupply, "Exceeds tier capacity");
        
        tier.sold += 1;
        
        // Mint ticket
        uint256 tokenId = _generateTokenId(TokenType.EVENT_TICKET, eventId, tierId, tier.sold);
        _mint(msg.sender, tokenId, 1);
        
        // Distribute payment
        uint256 protocolFee = (finalPrice * protocolFeeBps) / 10000;
        uint256 netAmount = finalPrice - protocolFee;
        
        if (protocolFee > 0 && feeTo != address(0)) {
            pendingWithdrawals[feeTo] += protocolFee;
        }
        
        _distributePayment(eventId, netAmount);
        
        // Refund excess
        if (msg.value > finalPrice) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - finalPrice}("");
            require(success, "Refund failed");
        }
        
        emit TicketPurchased(eventId, msg.sender, 1, finalPrice);
    }

    /// @notice Calculate group discount based on group size
    /// @param groupSize Number of people in group purchase
    /// @return discount Discount in basis points
    function _calculateGroupDiscount(uint256 groupSize) public pure returns (uint256 discount) {
        if (groupSize >= 10) return 1000; // 10%
        if (groupSize >= 5) return 500;   // 5%
        if (groupSize >= 3) return 250;   // 2.5%
        return 0;
    }
} 