// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/Assemble.sol";

contract DeployCreate2 is Script {
    function run() external {
        vm.startBroadcast();
        
        // Our vanity address parameters
        bytes32 salt = 0xb95ba17de8321bdb6cea9ac011b81186c48429eafbad5412755bb40aa4aef9f7;
        address feeTo = 0x1481ECEaBEb85124A82793CFf46FFA5fbFB1f3bF;
        
        // Deploy using CREATE2
        Assemble assemble = new Assemble{salt: salt}(feeTo);
        
        console.log("Deployed Assemble at:", address(assemble));
        console.log("Salt used:", vm.toString(salt));
        
        vm.stopBroadcast();
    }
} 