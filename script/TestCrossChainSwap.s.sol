// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { SettlerCompact } from "../src/settlers/compact/SettlerCompact.sol";
import { CoinFiller } from "../src/fillers/coin/CoinFiller.sol";
import { AlwaysYesOracle } from "../test/mocks/AlwaysYesOracle.sol";
import { MockERC20 } from "../test/mocks/MockERC20.sol";

import { StandardOrder, StandardOrderType } from "../src/settlers/types/StandardOrderType.sol";
import { MandateOutput } from "../src/libs/MandateOutputEncodingLib.sol";

import { TheCompact } from "the-compact/src/TheCompact.sol";
import { AlwaysOKAllocator } from "the-compact/src/test/AlwaysOKAllocator.sol";

contract TestCrossChainSwap is Script {
    // These addresses should be updated with actual deployed addresses
    struct DeploymentAddresses {
        // Origin chain contracts
        address theCompact;
        address alwaysOKAllocator;
        uint96 alwaysOKAllocatorId;
        address settlerCompact;
        address originOracle;
        address originTokenA;
        address originTokenB;
        
        // Destination chain contracts
        address coinFiller;
        address destinationOracle;
        address destinationTokenA;
        address destinationTokenB;
        
        // Cross-chain info
        uint256 originChainId;
        uint256 destinationChainId;
    }
    
    function demonstrateSwap(DeploymentAddresses memory addrs) external {
        uint256 userPrivateKey = vm.envUint("USER_PRIVATE_KEY");
        uint256 solverPrivateKey = vm.envUint("SOLVER_PRIVATE_KEY");
        
        address user = vm.addr(userPrivateKey);
        address solver = vm.addr(solverPrivateKey);
        
        console.log("=== CATALYST CROSS-CHAIN SWAP DEMONSTRATION ===");
        console.log("User:", user);
        console.log("Solver:", solver);
        console.log("Origin Chain ID:", addrs.originChainId);
        console.log("Destination Chain ID:", addrs.destinationChainId);
        
        // Step 1: User deposits tokens on origin chain
        console.log("\n--- Step 1: User deposits on origin chain ---");
        
        // Switch to origin chain context (simulated)
        console.log("Switching to origin chain (Chain ID:", addrs.originChainId, ")");
        
        vm.startBroadcast(userPrivateKey);
        
        TheCompact theCompact = TheCompact(addrs.theCompact);
        MockERC20 originToken = MockERC20(addrs.originTokenA);
        SettlerCompact settlerCompact = SettlerCompact(addrs.settlerCompact);
        
        uint256 inputAmount = 100 * 10**18; // 100 tokens
        uint256 outputAmount = 99 * 10**18;  // 99 tokens (1% fee simulated)
        
        // Ensure user has tokens and approve TheCompact
        originToken.mint(user, inputAmount);
        originToken.approve(address(theCompact), inputAmount);
        console.log("User minted and approved", inputAmount / 10**18, "tokens");
        
        // Deposit tokens into TheCompact
        bytes12 allocatorLockTag = bytes12(addrs.alwaysOKAllocatorId);
        uint256 tokenId = theCompact.depositERC20(
            address(originToken), 
            allocatorLockTag, 
            inputAmount, 
            user
        );
        console.log("Deposited tokens, received tokenId:", tokenId);
        
        // Create order structure
        uint256[2][] memory inputs = new uint256[2][](1);
        inputs[0] = [tokenId, inputAmount];
        
        MandateOutput[] memory outputs = new MandateOutput[](1);
        outputs[0] = MandateOutput({
            remoteOracle: bytes32(uint256(uint160(addrs.destinationOracle))),
            remoteFiller: bytes32(uint256(uint160(addrs.coinFiller))),
            chainId: addrs.destinationChainId,
            token: bytes32(uint256(uint160(addrs.destinationTokenB))),
            amount: outputAmount,
            recipient: bytes32(uint256(uint160(user))),
            remoteCall: hex"",
            fulfillmentContext: hex""
        });
        
        StandardOrder memory order = StandardOrder({
            user: user,
            nonce: 0,
            originChainId: addrs.originChainId,
            expires: type(uint32).max,
            fillDeadline: type(uint32).max,
            localOracle: addrs.originOracle,
            inputs: inputs,
            outputs: outputs
        });
        
        bytes32 orderId = settlerCompact.orderIdentifier(order);
        console.log("Created order with ID:", vm.toString(orderId));
        
        vm.stopBroadcast();
        
        // Step 2: Solver fills on destination chain
        console.log("\n--- Step 2: Solver fills on destination chain ---");
        console.log("Switching to destination chain (Chain ID:", addrs.destinationChainId, ")");
        
        vm.startBroadcast(solverPrivateKey);
        
        CoinFiller coinFiller = CoinFiller(addrs.coinFiller);
        MockERC20 destinationToken = MockERC20(addrs.destinationTokenB);
        
        // Ensure solver has tokens and approve CoinFiller
        destinationToken.mint(solver, outputAmount);
        destinationToken.approve(address(coinFiller), outputAmount);
        console.log("Solver minted and approved", outputAmount / 10**18, "tokens");
        
        // Fill the order
        bytes32 solverIdentifier = bytes32(uint256(uint160(solver)));
        coinFiller.fill(type(uint32).max, orderId, outputs[0], solverIdentifier);
        console.log("Solver filled order, user should receive tokens");
        
        vm.stopBroadcast();
        
        // Step 3: Finalize on origin chain
        console.log("\n--- Step 3: Finalize on origin chain ---");
        console.log("Switching back to origin chain");
        
        vm.startBroadcast(solverPrivateKey);
        
        // Create signature for finalization (simplified for AlwaysYesOracle)
        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = uint32(block.timestamp);
        
        // Since we're using AlwaysYesOracle, we can finalize immediately
        // In practice, this would require proper signatures and oracle proofs
        bytes memory signatures = hex""; // Empty signature for this demo
        
        settlerCompact.finaliseSelf(order, signatures, timestamps, solverIdentifier);
        console.log("Order finalized, solver should receive input tokens");
        
        vm.stopBroadcast();
        
        console.log("\n=== SWAP COMPLETED SUCCESSFULLY ===");
        console.log("User swapped", inputAmount / 10**18, "TokenA on origin chain");
        console.log("for", outputAmount / 10**18, "TokenB on destination chain");
    }
    
    function run() external {
        console.log("This is a demonstration script.");
        console.log("Please call demonstrateSwap() with actual deployed addresses.");
        console.log("Example usage in a separate script or test.");
    }
} 