// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { Assemble } from "../src/Assemble.sol";

/// @title Assemble Protocol Deployment Script
/// @notice Deploy the Assemble protocol singleton contract
/// @author @taayyohh
contract DeployScript is Script {
    /// @notice Deploy the Assemble protocol
    /// @dev Uses CREATE2 for deterministic deployment across chains
    function run() external {
        // Get deployment configuration
        address deployer = vm.envAddress("DEPLOYER");
        address feeTo = vm.envOr("FEE_TO", deployer); // Default to deployer if not set

        console.log("Deploying Assemble Protocol...");
        console.log("Deployer:", deployer);
        console.log("Fee Recipient:", feeTo);

        vm.startBroadcast(deployer);

        // Deploy Assemble protocol
        Assemble assemble = new Assemble(feeTo);

        vm.stopBroadcast();

        console.log("Assemble Protocol deployed at:", address(assemble));
        console.log("Initial configuration:");
        console.log("  - Fee recipient:", assemble.feeTo());
        console.log("  - Protocol fee:", assemble.protocolFeeBps(), "bps (0.5%)");
        console.log("  - Next event ID:", assemble.nextEventId());

        // Verify contract if on a public network
        if (block.chainid != 31_337) {
            // Not Anvil
            console.log("\nRun the following command to verify on Etherscan:");
            console.log("forge verify-contract");
            console.log("Address:", address(assemble));
            console.log("Contract: src/Assemble.sol:Assemble");
            console.log("Constructor args:", vm.toString(abi.encode(feeTo)));
        }
    }

    /// @notice Deploy with custom configuration
    /// @param _feeTo Custom fee recipient
    /// @return assemble Deployed contract instance
    function deployWithConfig(address _feeTo) external returns (Assemble assemble) {
        console.log("Deploying Assemble with custom config...");
        console.log("Fee Recipient:", _feeTo);

        vm.startBroadcast();

        assemble = new Assemble(_feeTo);

        vm.stopBroadcast();

        console.log("Assemble deployed at:", address(assemble));
        return assemble;
    }
}
