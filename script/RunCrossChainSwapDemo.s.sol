// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { TestCrossChainSwap } from "./TestCrossChainSwap.s.sol";

contract RunCrossChainSwapDemo is Script {
    function run() external {
        console.log("=== STARTING CROSS-CHAIN SWAP DEMO ===");
        
        // Create the deployment addresses struct with your actual deployed addresses
        TestCrossChainSwap.DeploymentAddresses memory addrs = TestCrossChainSwap.DeploymentAddresses({
            // Origin chain contracts (FROM YOUR ORIGIN CHAIN DEPLOYMENT - FILLED)
            theCompact: 0x5FbDB2315678afecb367f032d93F642f64180aa3,
            alwaysOKAllocator: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512,
            alwaysOKAllocatorId: 158859850115136955957052690, // AlwaysOKAllocator ID from deployment
            settlerCompact: 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707,
            originOracle: 0x0165878A594ca255338adfa4d48449f69242Eb8F,
            originTokenA: 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853,
            originTokenB: 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6,
            
            // Destination chain contracts (FROM YOUR DESTINATION CHAIN DEPLOYMENT - FILLED)
            coinFiller: 0x5FbDB2315678afecb367f032d93F642f64180aa3,
            destinationOracle: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512,
            destinationTokenA: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0,
            destinationTokenB: 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9,
            
            // Cross-chain info
            originChainId: 1337,  // Your origin chain ID
            destinationChainId: 1338  // Your destination chain ID
        });
        
        // Create and run the test
        TestCrossChainSwap testSwap = new TestCrossChainSwap();
        testSwap.demonstrateSwap(addrs);
        
        console.log("=== DEMO COMPLETED ===");
    }
} 