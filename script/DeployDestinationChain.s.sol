// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { CoinFiller } from "../src/fillers/coin/CoinFiller.sol";
import { AlwaysYesOracle } from "../test/mocks/AlwaysYesOracle.sol";
import { MockERC20 } from "../test/mocks/MockERC20.sol";

contract DeployDestinationChain is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying to Destination Chain...");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // 1. Deploy CoinFiller (main filler contract)
        CoinFiller coinFiller = new CoinFiller();
        console.log("CoinFiller deployed at:", address(coinFiller));
        
        // 2. Deploy AlwaysYesOracle (custom oracle)
        AlwaysYesOracle alwaysYesOracle = new AlwaysYesOracle();
        console.log("AlwaysYesOracle deployed at:", address(alwaysYesOracle));
        
        // 3. Deploy test tokens (same names for consistency, but different addresses)
        MockERC20 tokenA = new MockERC20("Token A", "TKNA", 18);
        MockERC20 tokenB = new MockERC20("Token B", "TKNB", 18);
        console.log("TokenA deployed at:", address(tokenA));
        console.log("TokenB deployed at:", address(tokenB));
        
        // 4. Mint test tokens to deployer
        tokenA.mint(deployer, 1000 * 10**18);
        tokenB.mint(deployer, 1000 * 10**18);
        console.log("Minted 1000 tokens each to deployer");
        
        vm.stopBroadcast();
        
        // Output deployment addresses in a structured format
        console.log("\n=== DESTINATION CHAIN DEPLOYMENT SUMMARY ===");
        console.log("Chain ID:", block.chainid);
        console.log("CoinFiller:", address(coinFiller));
        console.log("AlwaysYesOracle:", address(alwaysYesOracle));
        console.log("TokenA:", address(tokenA));
        console.log("TokenB:", address(tokenB));
        console.log("==============================================");
    }
} 