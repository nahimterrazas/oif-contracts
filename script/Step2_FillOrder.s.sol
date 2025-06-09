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
        
        console.log("=== STEP 2: FILL ORDER ON DESTINATION CHAIN ===");
        console.log("Solver:", solver);
        console.log("Chain ID:", block.chainid);
        
        // Read order data from Step1
        string memory jsonData = vm.readFile("order_data.json");
        
        // Parse key values from JSON (simplified parsing for this demo)
        bytes32 orderId = vm.parseJsonBytes32(jsonData, ".orderInfo.orderId");
        address user = vm.parseJsonAddress(jsonData, ".orderInfo.user");
        uint256 outputAmount = vm.parseJsonUint(jsonData, ".orderInfo.outputAmount");
        
        // Parse destination chain addresses
        address coinFillerAddr = vm.parseJsonAddress(jsonData, ".contractAddresses.destinationChain.coinFiller");
        address destinationTokenAddr = vm.parseJsonAddress(jsonData, ".contractAddresses.destinationChain.destinationToken");
        address remoteOracleAddr = vm.parseJsonAddress(jsonData, ".contractAddresses.destinationChain.remoteOracle");
        
        console.log("User:", user);
        console.log("Order ID:", vm.toString(orderId));
        console.log("Output Amount:", outputAmount / 10**18);
        
        vm.startBroadcast(solverPrivateKey);
        
        // Destination chain contracts
        CoinFiller coinFiller = CoinFiller(coinFillerAddr);
        MockERC20 destinationToken = MockERC20(destinationTokenAddr);
        
        // Ensure solver has tokens and approve CoinFiller
        destinationToken.mint(solver, outputAmount);
        destinationToken.approve(address(coinFiller), outputAmount);
        console.log("Solver minted and approved", outputAmount / 10**18, "tokens");
        
        // Create the output structure using data from JSON
        MandateOutput memory output = MandateOutput({
            remoteOracle: bytes32(uint256(uint160(remoteOracleAddr))),
            remoteFiller: bytes32(uint256(uint160(coinFillerAddr))),
            chainId: vm.parseJsonUint(jsonData, ".contractAddresses.destinationChain.chainId"),
            token: bytes32(uint256(uint160(destinationTokenAddr))),
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