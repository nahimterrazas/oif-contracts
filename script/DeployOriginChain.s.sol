// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { SettlerCompact } from "../src/settlers/compact/SettlerCompact.sol";
import { AlwaysYesOracle } from "../test/mocks/AlwaysYesOracle.sol";
import { MockERC20 } from "../test/mocks/MockERC20.sol";

import { TheCompact } from "the-compact/src/TheCompact.sol";
import { AlwaysOKAllocator } from "the-compact/src/test/AlwaysOKAllocator.sol";
import { SimpleAllocator } from "the-compact/src/examples/allocator/SimpleAllocator.sol";

contract DeployOriginChain is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying to Origin Chain...");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // 1. Deploy TheCompact (resource lock mechanism)
        TheCompact theCompact = new TheCompact();
        console.log("TheCompact deployed at:", address(theCompact));
        
        // 2. Deploy AlwaysOKAllocator
        AlwaysOKAllocator alwaysOKAllocator = new AlwaysOKAllocator();
        console.log("AlwaysOKAllocator deployed at:", address(alwaysOKAllocator));
        
        // 3. Register AlwaysOKAllocator with TheCompact
        uint96 alwaysOkAllocatorId = theCompact.__registerAllocator(address(alwaysOKAllocator), "");
        bytes12 alwaysOkAllocatorLockTag = bytes12(alwaysOkAllocatorId);
        console.log("AlwaysOKAllocator ID:", uint256(alwaysOkAllocatorId));
        
        // 4. Deploy SimpleAllocator
        SimpleAllocator simpleAllocator = new SimpleAllocator(deployer, address(theCompact));
        console.log("SimpleAllocator deployed at:", address(simpleAllocator));
        
        // 5. Register SimpleAllocator with TheCompact
        uint96 simpleAllocatorId = theCompact.__registerAllocator(address(simpleAllocator), "");
        bytes12 simpleAllocatorLockTag = bytes12(simpleAllocatorId);
        console.log("SimpleAllocator ID:", uint256(simpleAllocatorId));
        
        // 6. Deploy SettlerCompact (main settler)
        SettlerCompact settlerCompact = new SettlerCompact(address(theCompact));
        console.log("SettlerCompact deployed at:", address(settlerCompact));
        
        // 7. Deploy AlwaysYesOracle (custom oracle)
        AlwaysYesOracle alwaysYesOracle = new AlwaysYesOracle();
        console.log("AlwaysYesOracle deployed at:", address(alwaysYesOracle));
        
        // 8. Deploy test tokens
        MockERC20 tokenA = new MockERC20("Token A", "TKNA", 18);
        MockERC20 tokenB = new MockERC20("Token B", "TKNB", 18);
        console.log("TokenA deployed at:", address(tokenA));
        console.log("TokenB deployed at:", address(tokenB));
        
        // 9. Mint test tokens to deployer
        tokenA.mint(deployer, 1000 * 10**18);
        tokenB.mint(deployer, 1000 * 10**18);
        console.log("Minted 1000 tokens each to deployer");
        
        vm.stopBroadcast();
        
        // Output deployment addresses in a structured format
        console.log("\n=== ORIGIN CHAIN DEPLOYMENT SUMMARY ===");
        console.log("Chain ID:", block.chainid);
        console.log("TheCompact:", address(theCompact));
        console.log("AlwaysOKAllocator:", address(alwaysOKAllocator));
        console.log("AlwaysOKAllocator ID:", uint256(alwaysOkAllocatorId));
        console.log("SimpleAllocator:", address(simpleAllocator));
        console.log("SimpleAllocator ID:", uint256(simpleAllocatorId));
        console.log("SettlerCompact:", address(settlerCompact));
        console.log("AlwaysYesOracle:", address(alwaysYesOracle));
        console.log("TokenA:", address(tokenA));
        console.log("TokenB:", address(tokenB));
        console.log("========================================");
    }
} 