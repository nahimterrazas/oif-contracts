// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { SettlerCompact } from "../src/settlers/compact/SettlerCompact.sol";
import { MockERC20 } from "../test/mocks/MockERC20.sol";
import { StandardOrder } from "../src/settlers/types/StandardOrderType.sol";
import { MandateOutput } from "../src/libs/MandateOutputEncodingLib.sol";
import { TheCompact } from "the-compact/src/TheCompact.sol";

contract Step1_CreateOrder is Script {
    function run() external {
        uint256 userPrivateKey = vm.envUint("USER_PRIVATE_KEY");
        address user = vm.addr(userPrivateKey);
        
        console.log("=== STEP 1: CREATE ORDER ON ORIGIN CHAIN ===");
        console.log("User:", user);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(userPrivateKey);
        
        // Origin chain contract addresses
        TheCompact theCompact = TheCompact(0x5FbDB2315678afecb367f032d93F642f64180aa3);
        MockERC20 originToken = MockERC20(0xa513E6E4b8f2a923D98304ec87F64353C4D5C853);
        SettlerCompact settlerCompact = SettlerCompact(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);
        
        uint256 inputAmount = 100 * 10**18; // 100 tokens
        uint256 outputAmount = 99 * 10**18;  // 99 tokens (1% fee simulated)
        
        // Ensure user has tokens and approve TheCompact
        originToken.mint(user, inputAmount);
        originToken.approve(address(theCompact), inputAmount);
        console.log("User minted and approved", inputAmount / 10**18, "tokens");
        
        // Deposit tokens into TheCompact
        bytes12 allocatorLockTag = bytes12(uint96(158859850115136955957052690));
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
            remoteOracle: bytes32(uint256(uint160(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512))),
            remoteFiller: bytes32(uint256(uint160(0x5FbDB2315678afecb367f032d93F642f64180aa3))),
            chainId: 1338,
            token: bytes32(uint256(uint160(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9))),
            amount: outputAmount,
            recipient: bytes32(uint256(uint160(user))),
            remoteCall: hex"",
            fulfillmentContext: hex""
        });
        
        StandardOrder memory order = StandardOrder({
            user: user,
            nonce: 0,
            originChainId: 1337,
            expires: type(uint32).max,
            fillDeadline: type(uint32).max,
            localOracle: 0x0165878A594ca255338adfa4d48449f69242Eb8F,
            inputs: inputs,
            outputs: outputs
        });
        
        bytes32 orderId = settlerCompact.orderIdentifier(order);
        console.log("Created order with ID:", vm.toString(orderId));
        
        vm.stopBroadcast();
        
        console.log("\n=== ORDER CREATED SUCCESSFULLY ===");
        console.log("Next: Run Step2_FillOrder.s.sol on destination chain");
        console.log("Order ID to use:", vm.toString(orderId));
    }
} 