// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { Assemble } from "../src/Assemble.sol";

/// @title Vanity Deployment with Immediate Transfer Script
/// @notice Deploy Assemble to a vanity address and transfer control to multisig
/// @author @taayyohh
contract DeployVanityWithTransferScript is Script {
    // Configuration
    address constant INITIAL_DEPLOYER = 0xc1951eF408265A3b90d07B0BE030e63CCc7da6c6;
    address constant MULTISIG = 0x1481ECEaBEb85124A82793CFf46FFA5fbFB1f3bF;

    /// @notice Deploy with vanity salt and transfer to multisig
    /// @param salt The CREATE2 salt found by the vanity script
    function run(bytes32 salt) external {
        console.log("=== Assemble Vanity Deployment with Transfer ===");
        console.log("Initial deployer:", INITIAL_DEPLOYER);
        console.log("Target multisig:", MULTISIG);
        console.log("Using salt:", vm.toString(salt));
        
        // Predict the deployment address
        address predictedAddress = vm.computeCreate2Address(
            salt,
            keccak256(abi.encodePacked(type(Assemble).creationCode, abi.encode(INITIAL_DEPLOYER)))
        );
        console.log("Predicted address:", predictedAddress);
        
        // Verify this is a vanity address (starts with 0x0000000)
        require(
            uint160(predictedAddress) >> 132 == 0, 
            "Address does not start with 0x0000000"
        );
        
        vm.startBroadcast(INITIAL_DEPLOYER);

        // Deploy using CREATE2 with the vanity salt
        Assemble assemble = new Assemble{salt: salt}(INITIAL_DEPLOYER);
        
        console.log(">> Assemble deployed at:", address(assemble));
        console.log("Verification: Address matches prediction:", address(assemble) == predictedAddress);
        
        // Immediately transfer control to multisig
        console.log(">> Transferring control to multisig...");
        assemble.setFeeTo(MULTISIG);
        
        vm.stopBroadcast();
        
        console.log(">> Control transferred to multisig");
        console.log("Final state:");
        console.log("  - Contract address:", address(assemble));
        console.log("  - Fee recipient:", assemble.feeTo());
        console.log("  - Protocol fee:", assemble.protocolFeeBps(), "bps");
        console.log("  - Next event ID:", assemble.nextEventId());
        
        console.log("");
        console.log(">> Deployment complete!");
        console.log("Contract deployed to vanity address and control transferred to multisig");
    }

    /// @notice Helper function to verify a salt produces the expected vanity address
    /// @param salt The salt to test
    /// @return isVanity True if the salt produces an address starting with 0x0000000
    function verifyVanitySalt(bytes32 salt) external view returns (bool isVanity) {
        address predicted = vm.computeCreate2Address(
            salt,
            keccak256(abi.encodePacked(type(Assemble).creationCode, abi.encode(INITIAL_DEPLOYER)))
        );
        
        // Check if address starts with 0x0000000 (7 zeros)
        isVanity = uint160(predicted) >> 132 == 0;
        
        if (isVanity) {
            console.log(">> Salt produces vanity address:", predicted);
        } else {
            console.log("XX Salt does not produce vanity address:", predicted);
        }
        
        return isVanity;
    }

    /// @notice Deploy without vanity (fallback)
    /// @dev Use this if vanity address isn't found or for testing
    function deployNormal() external {
        console.log("=== Normal Deployment with Transfer ===");
        console.log("Deployer:", INITIAL_DEPLOYER);
        console.log("Target multisig:", MULTISIG);
        
        vm.startBroadcast(INITIAL_DEPLOYER);

        // Regular deployment
        Assemble assemble = new Assemble(INITIAL_DEPLOYER);
        
        console.log(">> Assemble deployed at:", address(assemble));
        
        // Transfer control to multisig
        console.log(">> Transferring control to multisig...");
        assemble.setFeeTo(MULTISIG);
        
        vm.stopBroadcast();
        
        console.log(">> Control transferred to multisig");
        console.log("Final state:");
        console.log("  - Contract address:", address(assemble));
        console.log("  - Fee recipient:", assemble.feeTo());
        console.log("  - Protocol fee:", assemble.protocolFeeBps(), "bps");
        
        console.log("");
        console.log(">> Normal deployment complete!");
    }
} 