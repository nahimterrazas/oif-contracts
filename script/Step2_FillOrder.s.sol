// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { CoinFiller } from "../src/fillers/coin/CoinFiller.sol";
import { MockERC20 } from "../test/mocks/MockERC20.sol";
import { MandateOutput } from "../src/libs/MandateOutputEncodingLib.sol";

contract Step2_FillOrder is Script {
    function run() external {
        uint256 solverPrivateKey = vm.envUint("SOLVER_PRIVATE_KEY");
        address solver = vm.addr(solverPrivateKey);
        address user = vm.addr(vm.envUint("USER_PRIVATE_KEY"));
        
        // You need to update this with the order ID from Step 1
        bytes32 orderId = 0x1e2ea3d9eae653c8f502001f236d2bd467cef329dea6f78c90f85eee75a32265;
        
        console.log("=== STEP 2: FILL ORDER ON DESTINATION CHAIN ===");
        console.log("Solver:", solver);
        console.log("User:", user);
        console.log("Chain ID:", block.chainid);
        console.log("Order ID:", vm.toString(orderId));
        
        vm.startBroadcast(solverPrivateKey);
        
        // Destination chain contract addresses
        CoinFiller coinFiller = CoinFiller(0x5FbDB2315678afecb367f032d93F642f64180aa3);
        MockERC20 destinationToken = MockERC20(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);
        
        uint256 outputAmount = 99 * 10**18;  // 99 tokens
        
        // Ensure solver has tokens and approve CoinFiller
        destinationToken.mint(solver, outputAmount);
        destinationToken.approve(address(coinFiller), outputAmount);
        console.log("Solver minted and approved", outputAmount / 10**18, "tokens");
        
        // Create the output structure
        MandateOutput memory output = MandateOutput({
            remoteOracle: bytes32(uint256(uint160(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512))),
            remoteFiller: bytes32(uint256(uint160(0x5FbDB2315678afecb367f032d93F642f64180aa3))),
            chainId: 1338,
            token: bytes32(uint256(uint160(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9))),
            amount: outputAmount,
            recipient: bytes32(uint256(uint160(user))),
            remoteCall: hex"",
            fulfillmentContext: hex""
        });
        
        // Fill the order
        bytes32 solverIdentifier = bytes32(uint256(uint160(solver)));
        coinFiller.fill(type(uint32).max, orderId, output, solverIdentifier);
        console.log("Solver filled order, user should receive tokens");
        
        // Check user's balance
        uint256 userBalance = destinationToken.balanceOf(user);
        console.log("User's destination token balance:", userBalance / 10**18);
        
        vm.stopBroadcast();
        
        console.log("\n=== ORDER FILLED SUCCESSFULLY ===");
        console.log("Next: Run Step3_FinalizeOrder.s.sol on origin chain");
        console.log("Solver ID to use:", vm.toString(solverIdentifier));
    }
} 