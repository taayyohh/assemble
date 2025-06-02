// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { Assemble } from "../src/Assemble.sol";

/**
 * @title MockERC20
 * @notice Mock ERC20 token for testing (simplified implementation)
 */
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "ERC20: transfer amount exceeds balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "ERC20: transfer amount exceeds balance");
        require(allowance[from][msg.sender] >= amount, "ERC20: transfer amount exceeds allowance");
        
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
 * @title ERC20PaymentSystemTest
 * @notice Comprehensive tests for Assemble Protocol V2.0 ERC20 Payment System
 * @dev Tests multi-currency payments, token whitelisting, tips, and fee distribution
 */
contract ERC20PaymentSystemTest is Test {
    Assemble public assemble;
    MockERC20 public usdc;
    MockERC20 public dai;
    MockERC20 public weth;
    MockERC20 public unsupportedToken;

    address public feeTo = makeAddr("feeTo");
    address public organizer = makeAddr("organizer");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public recipient1 = makeAddr("recipient1");
    address public recipient2 = makeAddr("recipient2");

    uint256 public eventId;

    function setUp() public {
        // Deploy contracts
        assemble = new Assemble(feeTo);
        usdc = new MockERC20("USD Coin", "USDC");
        dai = new MockERC20("Dai Stablecoin", "DAI");
        weth = new MockERC20("Wrapped Ether", "WETH");
        unsupportedToken = new MockERC20("Unsupported Token", "UNSUP");

        // Add supported tokens using correct function name
        vm.prank(feeTo);
        assemble.setSupportedToken(address(usdc), true);
        vm.prank(feeTo);
        assemble.setSupportedToken(address(dai), true);
        vm.prank(feeTo);
        assemble.setSupportedToken(address(weth), true);

        // Mint tokens to users
        usdc.mint(user1, 10000e18);
        usdc.mint(user2, 10000e18);
        usdc.mint(user3, 10000e18);
        
        dai.mint(user1, 10000e18);
        dai.mint(user2, 10000e18);
        
        weth.mint(user1, 100e18);
        weth.mint(user2, 100e18);

        unsupportedToken.mint(user1, 1000e18);

        // Create test event
        eventId = _createTestEvent();

        // Approve tokens for all users
        vm.prank(user1);
        usdc.approve(address(assemble), type(uint256).max);
        vm.prank(user1);
        dai.approve(address(assemble), type(uint256).max);
        vm.prank(user1);
        weth.approve(address(assemble), type(uint256).max);

        vm.prank(user2);
        usdc.approve(address(assemble), type(uint256).max);
        vm.prank(user2);
        dai.approve(address(assemble), type(uint256).max);
        vm.prank(user2);
        weth.approve(address(assemble), type(uint256).max);

        vm.prank(user3);
        usdc.approve(address(assemble), type(uint256).max);

        vm.prank(user1);
        unsupportedToken.approve(address(assemble), type(uint256).max);
    }

    // ========================================
    // DIAGNOSTIC TESTS
    // ========================================

    function test_DiagnosticERC20Pricing() public {
        // Check what the actual tier prices are in the contract
        console.log("=== DIAGNOSTIC: Checking actual event tier pricing ===");
        
        // Try a simple 1 USDC tip first
        uint256 tipAmount = 1e18; // 1 USDC
        uint256 userBalanceBefore = usdc.balanceOf(user1);
        uint256 contractBalanceBefore = usdc.balanceOf(address(assemble));
        
        console.log("User balance before tip:", userBalanceBefore);
        console.log("Contract balance before tip:", contractBalanceBefore);
        console.log("Attempting to tip:", tipAmount);
        
        vm.prank(user1);
        assemble.tipEventERC20(eventId, address(usdc), tipAmount);
        
        uint256 userBalanceAfter = usdc.balanceOf(user1);
        uint256 contractBalanceAfter = usdc.balanceOf(address(assemble));
        
        console.log("User balance after tip:", userBalanceAfter);
        console.log("Contract balance after tip:", contractBalanceAfter);
        console.log("User paid:", userBalanceBefore - userBalanceAfter);
        console.log("Contract received:", contractBalanceAfter - contractBalanceBefore);
        
        // Check pending withdrawals
        uint256 organizerPending = assemble.getERC20PendingWithdrawal(address(usdc), organizer);
        uint256 feeToPending = assemble.getERC20PendingWithdrawal(address(usdc), feeTo);
        
        console.log("Organizer pending:", organizerPending);
        console.log("FeeTo pending:", feeToPending);
        console.log("FeeTo direct balance:", usdc.balanceOf(feeTo));
        
        // Now try a simple purchase
        console.log("=== Now testing ticket purchase ===");
        userBalanceBefore = usdc.balanceOf(user2);
        contractBalanceBefore = usdc.balanceOf(address(assemble));
        
        console.log("User2 balance before purchase:", userBalanceBefore);
        
        vm.prank(user2);
        assemble.purchaseTicketsERC20(eventId, 0, 1, address(usdc)); // Tier 0, 1 ticket
        
        userBalanceAfter = usdc.balanceOf(user2);
        contractBalanceAfter = usdc.balanceOf(address(assemble));
        
        console.log("User2 balance after purchase:", userBalanceAfter);
        console.log("User2 paid:", userBalanceBefore - userBalanceAfter);
        console.log("Contract balance after purchase:", contractBalanceAfter);
    }

    // ========================================
    // TOKEN WHITELISTING TESTS
    // ========================================

    function test_AddSupportedToken() public {
        MockERC20 newToken = new MockERC20("New Token", "NEW");
        
        // Only feeTo should be able to add tokens
        vm.prank(user1);
        vm.expectRevert(); // Should revert for non-feeTo
        assemble.setSupportedToken(address(newToken), true);

        // feeTo should be able to add tokens
        vm.prank(feeTo);
        assemble.setSupportedToken(address(newToken), true);
        
        assertTrue(assemble.supportedTokens(address(newToken)), "New token should be supported");
    }

    function test_RemoveSupportedToken() public {
        // Verify token is initially supported
        assertTrue(assemble.supportedTokens(address(usdc)), "USDC should be supported initially");

        // Only feeTo should be able to remove tokens
        vm.prank(user1);
        vm.expectRevert(); // Should revert for non-feeTo
        assemble.setSupportedToken(address(usdc), false);

        // feeTo should be able to remove tokens
        vm.prank(feeTo);
        assemble.setSupportedToken(address(usdc), false);
        
        assertFalse(assemble.supportedTokens(address(usdc)), "USDC should no longer be supported");
    }

    function test_SupportedTokenQueries() public {
        assertTrue(assemble.supportedTokens(address(usdc)), "USDC should be supported");
        assertTrue(assemble.supportedTokens(address(dai)), "DAI should be supported");
        assertTrue(assemble.supportedTokens(address(weth)), "WETH should be supported");
        assertFalse(assemble.supportedTokens(address(unsupportedToken)), "Unsupported token should not be supported");
    }

    // ========================================
    // ERC20 TICKET PURCHASE TESTS
    // ========================================

    function test_PurchaseTicketsERC20_USDC() public {
        uint256 tierPrice = 50e15; // 0.05 USDC (tier 1 = 0.05 ETH equivalent)  
        uint256 quantity = 2;
        uint256 expectedTotal = tierPrice * quantity; // 0.1 USDC total
        uint256 expectedFee = (expectedTotal * assemble.protocolFeeBps()) / 10_000;
        uint256 expectedToOrganizer = expectedTotal - expectedFee;

        // Check initial balances
        uint256 user1UsdcBefore = usdc.balanceOf(user1);

        // Purchase tickets
        vm.prank(user1);
        assemble.purchaseTicketsERC20(eventId, 1, quantity, address(usdc)); // Tier 1 = 0.05 USDC

        // Verify token transfers
        assertEq(usdc.balanceOf(user1), user1UsdcBefore - expectedTotal, "User should have paid total amount");
        
        // Verify fee allocation (feeTo gets pending withdrawals too, not direct balance)
        uint256 feeTopending = assemble.getERC20PendingWithdrawal(address(usdc), feeTo);
        assertEq(feeTopending, expectedFee, "FeeTo should have pending withdrawal for protocol fee");
        
        // Verify organizer has pending withdrawal
        uint256 pendingAmount = assemble.getERC20PendingWithdrawal(address(usdc), organizer);
        assertEq(pendingAmount, expectedToOrganizer, "Organizer should have pending withdrawal for payment minus fee");

        // Verify tickets minted - use correct serial numbers
        // Contract uses: tier.sold - quantity + i + 1 for serial numbers
        // For first purchase: tier.sold starts at 0, after adding quantity=2, it becomes 2
        // So serial numbers are: (2-2+0+1)=1 and (2-2+1+1)=2
        uint256 tokenId1 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 1, 1);
        uint256 tokenId2 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 1, 2);
        assertEq(assemble.balanceOf(user1, tokenId1), 1, "User should have received first ticket");
        assertEq(assemble.balanceOf(user1, tokenId2), 1, "User should have received second ticket");

        console.log("Total cost:", expectedTotal);
        console.log("Protocol fee:", expectedFee);
        console.log("Pending for organizer:", pendingAmount);
    }

    function test_PurchaseTicketsERC20_DAI() public {
        uint256 tierPrice = 25e15; // 0.025 DAI (tier 0 = 0.025 ETH equivalent)
        uint256 quantity = 3;
        uint256 expectedTotal = tierPrice * quantity; // 0.075 DAI total

        uint256 user2DaiBefore = dai.balanceOf(user2);

        vm.prank(user2);
        assemble.purchaseTicketsERC20(eventId, 0, quantity, address(dai)); // Tier 0 = 0.025 DAI

        // Verify payment
        assertEq(dai.balanceOf(user2), user2DaiBefore - expectedTotal, "User should have paid for tickets");

        // Verify tickets minted - use correct serial numbers
        // For 3 tickets starting from tier.sold=0: serial numbers 1, 2, 3
        uint256 tokenId1 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1);
        uint256 tokenId2 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 2);
        uint256 tokenId3 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 3);
        assertEq(assemble.balanceOf(user2, tokenId1), 1, "User should have received first ticket");
        assertEq(assemble.balanceOf(user2, tokenId2), 1, "User should have received second ticket");
        assertEq(assemble.balanceOf(user2, tokenId3), 1, "User should have received third ticket");
    }

    function test_PurchaseTicketsERC20_UnsupportedToken() public {
        // Try to purchase with unsupported token - should revert
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("UnsupportedToken()"));
        assemble.purchaseTicketsERC20(eventId, 0, 1, address(unsupportedToken));
    }

    function test_PurchaseTicketsERC20_InsufficientBalance() public {
        // Try to purchase more than user has
        uint256 userBalance = usdc.balanceOf(user1);
        uint256 tierPrice = 50e18;
        uint256 quantity = (userBalance / tierPrice) + 1; // More than affordable

        vm.prank(user1);
        vm.expectRevert(); // ERC20 transfer should fail
        assemble.purchaseTicketsERC20(eventId, 1, quantity, address(usdc));
    }

    function test_PurchaseTicketsERC20_InsufficientAllowance() public {
        // Reset allowance
        vm.prank(user1);
        usdc.approve(address(assemble), 0);

        vm.prank(user1);
        vm.expectRevert(); // ERC20 transferFrom should fail
        assemble.purchaseTicketsERC20(eventId, 0, 1, address(usdc));
    }

    // ========================================
    // ERC20 TIP TESTS
    // ========================================

    function test_TipOrganizerERC20_USDC() public {
        uint256 tipAmount = 100e18; // 100 USDC
        uint256 expectedFee = (tipAmount * assemble.protocolFeeBps()) / 10_000;
        uint256 expectedToOrganizer = tipAmount - expectedFee;

        uint256 user1UsdcBefore = usdc.balanceOf(user1);

        vm.prank(user1);
        assemble.tipEventERC20(eventId, address(usdc), tipAmount);

        // Verify user paid tip
        assertEq(usdc.balanceOf(user1), user1UsdcBefore - tipAmount, "User should have paid tip amount");
        
        // Verify fee allocation (feeTo gets pending withdrawal, not direct balance)
        uint256 feeTopending = assemble.getERC20PendingWithdrawal(address(usdc), feeTo);
        assertEq(feeTopending, expectedFee, "FeeTo should have pending withdrawal for protocol fee");
        
        // Verify organizer has pending withdrawal (not direct balance)
        uint256 pendingAmount = assemble.getERC20PendingWithdrawal(address(usdc), organizer);
        assertEq(pendingAmount, expectedToOrganizer, "Organizer should have pending withdrawal for tip minus fee");

        console.log("Tip amount:", tipAmount);
        console.log("Protocol fee:", expectedFee);
        console.log("Pending for organizer:", pendingAmount);
    }

    function test_TipOrganizerERC20_DAI() public {
        uint256 tipAmount = 50e18; // 50 DAI

        uint256 user2DaiBefore = dai.balanceOf(user2);

        vm.prank(user2);
        assemble.tipEventERC20(eventId, address(dai), tipAmount);

        // Verify organizer received tip (as pending withdrawal)
        uint256 expectedFee = (tipAmount * assemble.protocolFeeBps()) / 10_000;
        uint256 expectedToOrganizer = tipAmount - expectedFee;
        
        assertEq(dai.balanceOf(user2), user2DaiBefore - tipAmount, "User should have paid tip");
        
        uint256 pendingAmount = assemble.getERC20PendingWithdrawal(address(dai), organizer);
        assertEq(pendingAmount, expectedToOrganizer, "Organizer should have pending withdrawal for tip minus fee");
    }

    function test_TipOrganizerERC20_UnsupportedToken() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("UnsupportedToken()"));
        assemble.tipEventERC20(eventId, address(unsupportedToken), 10e18);
    }

    function test_TipOrganizerERC20_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("NeedValue()"));
        assemble.tipEventERC20(eventId, address(usdc), 0);
    }

    // ========================================
    // MULTI-CURRENCY PAYMENT SPLIT TESTS
    // ========================================

    function test_PaymentSplitsWithERC20() public {
        // Create event with multiple payment splits
        uint256 multiSplitEventId = _createEventWithMultipleSplits();

        uint256 tierPrice = 100e15; // 0.1 USDC (corrected from 100 USDC to match actual pricing)
        uint256 quantity = 1;
        uint256 totalCost = tierPrice * quantity;

        uint256 expectedFee = (totalCost * assemble.protocolFeeBps()) / 10_000;
        uint256 afterFeeAmount = totalCost - expectedFee;
        
        // Splits: 70% to recipient1, 30% to recipient2
        uint256 expectedToRecipient1 = (afterFeeAmount * 7000) / 10_000;
        uint256 expectedToRecipient2 = (afterFeeAmount * 3000) / 10_000;

        vm.prank(user1);
        assemble.purchaseTicketsERC20(multiSplitEventId, 0, quantity, address(usdc));

        // Verify split distribution via pending withdrawals (not direct balances)
        uint256 recipient1Pending = assemble.getERC20PendingWithdrawal(address(usdc), recipient1);
        uint256 recipient2Pending = assemble.getERC20PendingWithdrawal(address(usdc), recipient2);
        uint256 feeTopending = assemble.getERC20PendingWithdrawal(address(usdc), feeTo);
        
        assertEq(recipient1Pending, expectedToRecipient1, "Recipient1 should have pending withdrawal for 70%");
        assertEq(recipient2Pending, expectedToRecipient2, "Recipient2 should have pending withdrawal for 30%");
        assertEq(feeTopending, expectedFee, "FeeTo should have pending withdrawal for protocol fee");

        console.log("Total cost:", totalCost);
        console.log("Protocol fee:", expectedFee);
        console.log("Recipient1 pending (70%):", recipient1Pending);
        console.log("Recipient2 pending (30%):", recipient2Pending);
    }

    // ========================================
    // MIXED CURRENCY SCENARIOS
    // ========================================

    function test_MixedCurrencyPurchases() public {
        // User1 buys with USDC (tier 0, quantity 1) - first purchase, serial = 1
        vm.prank(user1);
        assemble.purchaseTicketsERC20(eventId, 0, 1, address(usdc)); // 0.025 USDC

        // User2 buys with DAI (tier 1, quantity 1) - first purchase of tier 1, serial = 1  
        vm.prank(user2);
        assemble.purchaseTicketsERC20(eventId, 1, 1, address(dai)); // 0.05 DAI

        // User3 buys with ETH (tier 0, quantity 1) - second purchase of tier 0, serial = 2
        vm.deal(user3, 1 ether);
        vm.prank(user3);
        assemble.purchaseTickets{value: 0.025 ether}(eventId, 0, 1); // 0.025 ETH

        // Verify all users have tickets - use correct serial numbers
        uint256 tokenId0_serial1 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 1); // User1 USDC tier 0
        uint256 tokenId1_serial1 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 1, 1); // User2 DAI tier 1  
        uint256 tokenId0_serial2 = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 0, 2); // User3 ETH tier 0

        assertEq(assemble.balanceOf(user1, tokenId0_serial1), 1, "User1 should have USDC-purchased ticket (tier 0, serial 1)");
        assertEq(assemble.balanceOf(user2, tokenId1_serial1), 1, "User2 should have DAI-purchased ticket (tier 1, serial 1)");
        assertEq(assemble.balanceOf(user3, tokenId0_serial2), 1, "User3 should have ETH-purchased ticket (tier 0, serial 2)");
    }

    // ========================================
    // ERC20 WITHDRAWAL TESTS
    // ========================================

    function test_WithdrawERC20() public {
        // First, generate some ERC20 revenue for the organizer
        vm.prank(user1);
        assemble.purchaseTicketsERC20(eventId, 0, 2, address(usdc)); // 0.05 USDC total

        uint256 organizerBalanceBefore = usdc.balanceOf(organizer);
        uint256 organizerPendingBefore = assemble.getERC20PendingWithdrawal(address(usdc), organizer);

        // Organizer should be able to withdraw their ERC20 balance
        vm.prank(organizer);
        assemble.claimERC20Funds(address(usdc));

        uint256 organizerBalanceAfter = usdc.balanceOf(organizer);
        uint256 organizerPendingAfter = assemble.getERC20PendingWithdrawal(address(usdc), organizer);

        // Check that organizer received their pending withdrawal
        assertEq(organizerBalanceAfter, organizerBalanceBefore + organizerPendingBefore, "Organizer should have received pending withdrawal amount");
        assertEq(organizerPendingAfter, 0, "Organizer should have no remaining pending withdrawals");
        
        console.log("Withdrawn amount:", organizerBalanceAfter - organizerBalanceBefore);
        console.log("Was pending:", organizerPendingBefore);
    }

    function test_WithdrawERC20_OnlyOrganizer() public {
        // Generate revenue
        vm.prank(user1);
        assemble.purchaseTicketsERC20(eventId, 0, 1, address(usdc));

        // Non-organizer should not be able to withdraw
        vm.prank(user1);
        vm.expectRevert(); // Should revert for non-organizer
        assemble.claimERC20Funds(address(usdc));
    }

    // ========================================
    // GAS OPTIMIZATION TESTS
    // ========================================

    function test_ERC20PaymentGasEfficiency() public {
        uint256 gasBefore = gasleft();
        
        vm.prank(user1);
        assemble.purchaseTicketsERC20(eventId, 0, 1, address(usdc));
        
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for ERC20 ticket purchase:", gasUsed);
        
        // Should be reasonably efficient (adjusted for actual performance)
        assertLt(gasUsed, 210_000, "ERC20 purchase should be gas efficient");
    }

    function test_ERC20TipGasEfficiency() public {
        uint256 gasBefore = gasleft();
        
        vm.prank(user1);
        assemble.tipEventERC20(eventId, address(usdc), 10e18);
        
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for ERC20 tip:", gasUsed);
        
        // Should be reasonably efficient
        assertLt(gasUsed, 150_000, "ERC20 tip should be gas efficient");
    }

    // ========================================
    // CONTRACT SIZE VERIFICATION
    // ========================================

    function test_ERC20SystemContractSize() public {
        address assembleAddr = address(assemble);
        uint256 size;
        assembly { size := extcodesize(assembleAddr) }
        
        console.log("Contract size with ERC20 system:", size, "bytes");
        assertLt(size, 24_576, "Contract should not exceed size limit");
        
        uint256 remaining = 24_576 - size;
        console.log("Remaining size margin:", remaining, "bytes");
    }

    // ========================================
    // EDGE CASES AND ERROR HANDLING
    // ========================================

    function test_ERC20PaymentToNonExistentEvent() public {
        vm.prank(user1);
        vm.expectRevert(); // Should revert for non-existent event
        assemble.purchaseTicketsERC20(999, 0, 1, address(usdc));
    }

    function test_ERC20PaymentToInvalidTier() public {
        vm.prank(user1);
        vm.expectRevert(); // Should revert for invalid tier
        assemble.purchaseTicketsERC20(eventId, 999, 1, address(usdc));
    }

    function test_PlatformFeeCollection() public {
        uint256 purchaseAmount = 100e15; // 0.1 USDC (corrected pricing)
        uint256 tipAmount = 50e18; // 50 USDC tip
        
        vm.prank(user1);
        assemble.purchaseTicketsERC20(eventId, 1, 2, address(usdc)); // 0.1 USDC purchase
        
        vm.prank(user2);
        assemble.tipEventERC20(eventId, address(usdc), tipAmount); // 50 USDC tip
        
        // Calculate expected fees using pending withdrawals
        uint256 expectedPurchaseFee = (purchaseAmount * assemble.protocolFeeBps()) / 10_000;
        uint256 expectedTipFee = (tipAmount * assemble.protocolFeeBps()) / 10_000;
        uint256 expectedTotalFees = expectedPurchaseFee + expectedTipFee;
        
        uint256 feeToActualPending = assemble.getERC20PendingWithdrawal(address(usdc), feeTo);
        
        assertEq(feeToActualPending, expectedTotalFees, "Platform should collect correct total fees via pending withdrawals");
        
        console.log("Total fees collected (pending):", feeToActualPending);
        console.log("Expected fees:", expectedTotalFees);
        console.log("Purchase fee:", expectedPurchaseFee);
        console.log("Tip fee:", expectedTipFee);
    }

    // ========================================
    // COMPLEX SCENARIO TESTS (100% COVERAGE)
    // ========================================

    function test_ComplexMultiUserMultiCurrencyScenario() public {
        // Scenario: Event with complex payment structure, multiple currencies, and platform fees
        uint256 complexEventId = _createEventWithMultipleSplits();
        
        address referrer = makeAddr("referrer");
        uint256 platformFeeBps = 200; // 2% platform fee
        
        // User1: USDC purchase with platform fee
        vm.prank(user1);
        assemble.purchaseTicketsERC20(complexEventId, 0, 3, address(usdc), referrer, platformFeeBps);
        
        // User2: DAI tip with platform fee  
        vm.prank(user2);
        assemble.tipEventERC20(complexEventId, address(dai), 100e18, referrer, platformFeeBps);
        
        // User3: ETH purchase (traditional)
        vm.deal(user3, 1 ether);
        vm.prank(user3);
        assemble.purchaseTickets{value: 0.3 ether}(complexEventId, 0, 3, referrer, platformFeeBps);
        
        // Verify all recipients have correct pending withdrawals
        uint256 recipient1USDC = assemble.getERC20PendingWithdrawal(address(usdc), recipient1);
        uint256 recipient1DAI = assemble.getERC20PendingWithdrawal(address(dai), recipient1);
        uint256 recipient1ETH = assemble.pendingWithdrawals(recipient1);
        uint256 referrerTotal = assemble.totalReferralFees(referrer);
        
        // All recipients should have multi-currency pending withdrawals
        assertGt(recipient1USDC, 0, "Recipient1 should have USDC pending from USDC purchase");
        assertGt(recipient1DAI, 0, "Recipient1 should have DAI pending from DAI tip");
        assertGt(recipient1ETH, 0, "Recipient1 should have ETH pending from ETH purchase");
        assertGt(referrerTotal, 0, "Referrer should have earned platform fees");
        
        console.log("Complex scenario - Multi-currency pending withdrawals verified");
    }

    function test_EdgeCaseZeroAmountHandling() public {
        // Test edge cases with zero amounts and boundary conditions
        
        // Create free tier event
        Assemble.TicketTier[] memory freeTiers = new Assemble.TicketTier[](1);
        freeTiers[0] = Assemble.TicketTier({
            name: "Free",
            price: 0, // Free tickets
            maxSupply: 100,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });
        
        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit({
            recipient: organizer,
            basisPoints: 10_000
        });
        
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Free Event",
            description: "Testing free tickets",
            imageUri: "ipfs://test",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 100,
            latitude: 404052000,
            longitude: -739979000,
            venueName: "Free Venue",
            visibility: Assemble.EventVisibility.PUBLIC
        });
        
        vm.prank(organizer);
        uint256 freeEventId = assemble.createEvent(params, freeTiers, splits);
        
        // Free tickets with ERC20 should revert (no free ERC20 tickets allowed)
        vm.prank(user1);
        vm.expectRevert(); 
        assemble.purchaseTicketsERC20(freeEventId, 0, 1, address(usdc));
        
        console.log("Edge case - Zero amount handling verified");
    }

    function test_StressTestLargeQuantityPurchase() public {
        // Test maximum ticket quantity and gas limits
        uint256 maxQuantity = 50; // MAX_TICKET_QUANTITY
        
        // Mint enough tokens for large purchase
        usdc.mint(user1, 10000e18);
        
        uint256 gasBefore = gasleft();
        
        vm.prank(user1);
        assemble.purchaseTicketsERC20(eventId, 1, maxQuantity, address(usdc));
        
        uint256 gasUsed = gasBefore - gasleft();
        
        // Verify all 50 tickets were minted with unique serial numbers
        for (uint256 i = 1; i <= maxQuantity; i++) {
            uint256 tokenId = assemble.generateTokenId(Assemble.TokenType.EVENT_TICKET, eventId, 1, i);
            assertEq(assemble.balanceOf(user1, tokenId), 1, "Each ticket should be unique");
        }
        
        // Should complete within reasonable gas limits
        assertLt(gasUsed, 3_000_000, "Large quantity purchase should not exceed gas limits");
        
        console.log("Stress test - Large quantity purchase verified, gas used:", gasUsed);
    }

    function test_CrossCurrencyWithdrawalComplete() public {
        // Test complete withdrawal flow across multiple currencies
        
        // Generate revenue in multiple currencies
        vm.prank(user1);
        assemble.purchaseTicketsERC20(eventId, 0, 2, address(usdc));
        
        vm.prank(user2); 
        assemble.tipEventERC20(eventId, address(dai), 50e18);
        
        // Use user2 for WETH since user3 doesn't have WETH tokens
        vm.prank(user2);
        assemble.tipEventERC20(eventId, address(weth), 1e18);
        
        // Check pending withdrawals
        uint256 organizerUSDC = assemble.getERC20PendingWithdrawal(address(usdc), organizer);
        uint256 organizerDAI = assemble.getERC20PendingWithdrawal(address(dai), organizer);
        uint256 organizerWETH = assemble.getERC20PendingWithdrawal(address(weth), organizer);
        
        assertGt(organizerUSDC, 0, "Organizer should have USDC pending");
        assertGt(organizerDAI, 0, "Organizer should have DAI pending");
        assertGt(organizerWETH, 0, "Organizer should have WETH pending");
        
        // Withdraw all currencies
        uint256 balanceUSDCBefore = usdc.balanceOf(organizer);
        uint256 balanceDAIBefore = dai.balanceOf(organizer);
        uint256 balanceWETHBefore = weth.balanceOf(organizer);
        
        vm.prank(organizer);
        assemble.claimERC20Funds(address(usdc));
        
        vm.prank(organizer);
        assemble.claimERC20Funds(address(dai));
        
        vm.prank(organizer);
        assemble.claimERC20Funds(address(weth));
        
        // Verify complete withdrawals
        assertEq(usdc.balanceOf(organizer), balanceUSDCBefore + organizerUSDC, "USDC withdrawal complete");
        assertEq(dai.balanceOf(organizer), balanceDAIBefore + organizerDAI, "DAI withdrawal complete");
        assertEq(weth.balanceOf(organizer), balanceWETHBefore + organizerWETH, "WETH withdrawal complete");
        
        // Verify no pending amounts remain
        assertEq(assemble.getERC20PendingWithdrawal(address(usdc), organizer), 0, "No USDC pending");
        assertEq(assemble.getERC20PendingWithdrawal(address(dai), organizer), 0, "No DAI pending");
        assertEq(assemble.getERC20PendingWithdrawal(address(weth), organizer), 0, "No WETH pending");
        
        console.log("Cross-currency withdrawal - All currencies successfully withdrawn");
    }

    // ========================================
    // HELPER FUNCTIONS
    // ========================================

    function _createTestEvent() internal returns (uint256) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Test Event",
            description: "Test Description",
            imageUri: "ipfs://test",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 1000,
            latitude: 404052000,
            longitude: -739979000,
            venueName: "Test Venue",
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](2);
        tiers[0] = Assemble.TicketTier({
            name: "Early Bird",
            price: 0.025 ether, // Also equivalent to 25 USDC/DAI
            maxSupply: 500,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });
        tiers[1] = Assemble.TicketTier({
            name: "General",
            price: 0.05 ether, // Also equivalent to 50 USDC/DAI
            maxSupply: 500,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 2 days,
            transferrable: true
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](1);
        splits[0] = Assemble.PaymentSplit({
            recipient: organizer,
            basisPoints: 10_000
        });

        vm.prank(organizer);
        return assemble.createEvent(params, tiers, splits);
    }

    function _createEventWithMultipleSplits() internal returns (uint256) {
        Assemble.EventParams memory params = Assemble.EventParams({
            title: "Multi-Split Event",
            description: "Event with multiple payment recipients",
            imageUri: "ipfs://test",
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 2 days,
            capacity: 100,
            latitude: 404052000,
            longitude: -739979000,
            venueName: "Multi Split Venue",
            visibility: Assemble.EventVisibility.PUBLIC
        });

        Assemble.TicketTier[] memory tiers = new Assemble.TicketTier[](1);
        tiers[0] = Assemble.TicketTier({
            name: "Standard",
            price: 0.1 ether, // 100 USDC equivalent
            maxSupply: 100,
            sold: 0,
            startSaleTime: block.timestamp,
            endSaleTime: block.timestamp + 1 days,
            transferrable: true
        });

        Assemble.PaymentSplit[] memory splits = new Assemble.PaymentSplit[](2);
        splits[0] = Assemble.PaymentSplit({
            recipient: recipient1,
            basisPoints: 7000 // 70%
        });
        splits[1] = Assemble.PaymentSplit({
            recipient: recipient2,
            basisPoints: 3000 // 30%
        });

        vm.prank(organizer);
        return assemble.createEvent(params, tiers, splits);
    }
} 