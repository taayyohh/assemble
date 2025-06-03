// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";

// Simple ERC20 mock for testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}

/**
 * @title ProtocolFeeWithdrawalTest
 * @notice Test protocol fee collection and withdrawal functionality
 */
contract ProtocolFeeWithdrawalTest is Test {
    Assemble public assemble;
    MockERC20 public usdc;
    MockERC20 public dai;

    address public feeTo = makeAddr("feeTo");
    address public organizer = makeAddr("organizer");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    uint256 public eventId;

    function setUp() public {
        // Deploy contracts
        assemble = new Assemble(feeTo);
        usdc = new MockERC20("USD Coin", "USDC", 18);
        dai = new MockERC20("Dai Stablecoin", "DAI", 18);

        // Setup tokens
        vm.prank(feeTo);
        assemble.setSupportedToken(address(usdc), true);
        vm.prank(feeTo);
        assemble.setSupportedToken(address(dai), true);

        // Create test event
        eventId = _createTestEvent();

        // Give users tokens and approve
        usdc.mint(user1, 1000e18);
        dai.mint(user2, 1000e18);
        
        vm.prank(user1);
        usdc.approve(address(assemble), type(uint256).max);
        vm.prank(user2);
        dai.approve(address(assemble), type(uint256).max);
    }

    function test_ETHProtocolFeeCollection() public {
        uint256 ticketPrice = 0.1 ether; // Use tier 1 price
        uint256 protocolFeeBps = assemble.protocolFeeBps(); // Should be 50 bps (0.5%)
        uint256 expectedFee = (ticketPrice * protocolFeeBps) / 10_000;

        // Check initial state
        assertEq(assemble.pendingWithdrawals(feeTo), 0, "feeTo should start with 0 pending");
        
        // User purchases ticket - use tier 1 (0.1 ether)
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        assemble.purchaseTickets{value: ticketPrice}(eventId, 1, 1);

        // Verify protocol fee is pending
        assertEq(assemble.pendingWithdrawals(feeTo), expectedFee, "Protocol fee should be pending for feeTo");

        // feeTo withdraws protocol fee
        uint256 balanceBefore = feeTo.balance;
        vm.prank(feeTo);
        assemble.claimFunds();

        // Verify withdrawal
        assertEq(feeTo.balance, balanceBefore + expectedFee, "feeTo should receive protocol fee");
        assertEq(assemble.pendingWithdrawals(feeTo), 0, "feeTo pending should be cleared");
    }

    function test_ERC20ProtocolFeeCollection() public {
        uint256 tierPrice = 0.025 ether; // Match tier 0 from ERC20 test (25e18 tokens)
        uint256 protocolFeeBps = assemble.protocolFeeBps();
        uint256 expectedFee = (tierPrice * protocolFeeBps) / 10_000;

        // Check initial state
        assertEq(assemble.pendingERC20Withdrawals(address(usdc), feeTo), 0, "feeTo should start with 0 pending USDC");
        
        // User purchases ticket with USDC (tier 0 = 0.025 ether)
        vm.prank(user1);
        assemble.purchaseTicketsERC20(eventId, 0, 1, address(usdc));

        // Verify protocol fee is pending
        assertEq(assemble.pendingERC20Withdrawals(address(usdc), feeTo), expectedFee, "Protocol fee should be pending for feeTo");

        // feeTo withdraws protocol fee
        uint256 balanceBefore = usdc.balanceOf(feeTo);
        vm.prank(feeTo);
        assemble.claimERC20Funds(address(usdc));

        // Verify withdrawal
        assertEq(usdc.balanceOf(feeTo), balanceBefore + expectedFee, "feeTo should receive protocol fee in USDC");
        assertEq(assemble.pendingERC20Withdrawals(address(usdc), feeTo), 0, "feeTo USDC pending should be cleared");
    }

    function test_MultiCurrencyProtocolFees() public {
        uint256 usdcAmount = 0.025 ether; // Tier 0 price for ticket purchase
        uint256 daiAmount = 25e18;   // 25 DAI for tip
        uint256 ethAmount = 0.2 ether; // 0.2 ETH for tip
        uint256 protocolFeeBps = assemble.protocolFeeBps();

        uint256 expectedUsdcFee = (usdcAmount * protocolFeeBps) / 10_000;
        uint256 expectedDaiFee = (daiAmount * protocolFeeBps) / 10_000;
        uint256 expectedEthFee = (ethAmount * protocolFeeBps) / 10_000;

        // User1 purchases with USDC (tier 0)
        vm.prank(user1);
        assemble.purchaseTicketsERC20(eventId, 0, 1, address(usdc));

        // User2 tips with DAI
        vm.prank(user2);
        assemble.tipEventERC20(eventId, address(dai), daiAmount);

        // User1 tips with ETH
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        assemble.tipEvent{value: ethAmount}(eventId);

        // Verify fees are pending in each currency
        assertEq(assemble.pendingERC20Withdrawals(address(usdc), feeTo), expectedUsdcFee, "USDC fee should be pending");
        assertEq(assemble.pendingERC20Withdrawals(address(dai), feeTo), expectedDaiFee, "DAI fee should be pending");
        assertEq(assemble.pendingWithdrawals(feeTo), expectedEthFee, "ETH fee should be pending");

        // feeTo withdraws each currency
        uint256 usdcBefore = usdc.balanceOf(feeTo);
        uint256 daiBefore = dai.balanceOf(feeTo);
        uint256 ethBefore = feeTo.balance;

        vm.startPrank(feeTo);
        assemble.claimERC20Funds(address(usdc));
        assemble.claimERC20Funds(address(dai));
        assemble.claimFunds();
        vm.stopPrank();

        // Verify all withdrawals
        assertEq(usdc.balanceOf(feeTo), usdcBefore + expectedUsdcFee, "feeTo should receive USDC fees");
        assertEq(dai.balanceOf(feeTo), daiBefore + expectedDaiFee, "feeTo should receive DAI fees");
        assertEq(feeTo.balance, ethBefore + expectedEthFee, "feeTo should receive ETH fees");

        // Verify all pending fees cleared
        assertEq(assemble.pendingERC20Withdrawals(address(usdc), feeTo), 0, "USDC pending should be cleared");
        assertEq(assemble.pendingERC20Withdrawals(address(dai), feeTo), 0, "DAI pending should be cleared");
        assertEq(assemble.pendingWithdrawals(feeTo), 0, "ETH pending should be cleared");
    }

    function test_AccumulatedFeesOverTime() public {
        uint256 ticketPrice = 0.1 ether; // Use tier 1 price
        uint256 expectedFeePerTicket = (ticketPrice * assemble.protocolFeeBps()) / 10_000;

        // Multiple purchases over time
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        // Purchase 1 - use tier 1
        vm.prank(user1);
        assemble.purchaseTickets{value: ticketPrice}(eventId, 1, 1);

        // Purchase 2 - use tier 1
        vm.prank(user2);
        assemble.purchaseTickets{value: ticketPrice}(eventId, 1, 1);

        // Purchase 3 - use tier 1
        vm.prank(user1);
        assemble.purchaseTickets{value: ticketPrice}(eventId, 1, 1);

        // Verify accumulated fees
        uint256 expectedTotalFees = expectedFeePerTicket * 3;
        assertEq(assemble.pendingWithdrawals(feeTo), expectedTotalFees, "Should accumulate all protocol fees");

        // Single withdrawal gets all accumulated fees
        uint256 balanceBefore = feeTo.balance;
        vm.prank(feeTo);
        assemble.claimFunds();

        assertEq(feeTo.balance, balanceBefore + expectedTotalFees, "Should receive all accumulated fees");
        assertEq(assemble.pendingWithdrawals(feeTo), 0, "Pending should be cleared");
    }

    function _createTestEvent() internal returns (uint256) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Test Event",
            description: "Test Description",
            imageUri: "ipfs://test",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 100,
            latitude: 404052000,
            longitude: -739979000,
            venueName: "Test Venue",
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](2);
        tiers[0] = Assemble.TicketTier({
            name: "Early Bird",
            price: 0.025 ether, // Tier 0 price
            maxSupply: 50,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });
        tiers[1] = Assemble.TicketTier({
            name: "General",
            price: 0.1 ether, // Tier 1 price
            maxSupply: 50,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit({
            recipient: organizer,
            basisPoints: 10_000 // 100% to organizer
        });

        vm.prank(organizer);
        return assemble.createEvent(params, tiers, splits);
    }
} 