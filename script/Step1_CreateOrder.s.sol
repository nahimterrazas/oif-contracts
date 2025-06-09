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
            chainId: 31338,
            token: bytes32(uint256(uint160(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9))),
            amount: outputAmount,
            recipient: bytes32(uint256(uint160(user))),
            remoteCall: hex"",
            fulfillmentContext: hex""
        });
        
        StandardOrder memory order = StandardOrder({
            user: user,
            nonce: 0,
            originChainId: 31337,
            expires: type(uint32).max,
            fillDeadline: type(uint32).max,
            localOracle: 0x0165878A594ca255338adfa4d48449f69242Eb8F,
            inputs: inputs,
            outputs: outputs
        });
        
        bytes32 orderId = settlerCompact.orderIdentifier(order);
        console.log("Created order with ID:", vm.toString(orderId));
        
        // Generate sponsor signature HERE (user authorizes token release for this order)
        bytes memory sponsorSig = _getCompactBatchWitnessSignature(
            userPrivateKey,
            address(settlerCompact),
            user,
            0,
            type(uint32).max,
            inputs,
            _witnessHash(order),
            theCompact.DOMAIN_SEPARATOR()
        );
        
        // Store signature for use in Step3 (in real app, this would be stored/broadcasted)
        console.log("Generated sponsor signature length:", sponsorSig.length);
        console.log("Sponsor signature (hex):", vm.toString(sponsorSig));
        
        // Save all order data to a JSON file for use in subsequent steps
        uint256 solverPrivateKey = vm.envUint("SOLVER_PRIVATE_KEY");
        address solver = vm.addr(solverPrivateKey);
        _saveOrderData(order, orderId, sponsorSig, tokenId, inputAmount, outputAmount, user, solver);
        
        vm.stopBroadcast();
        
        console.log("\n=== ORDER CREATED SUCCESSFULLY ===");
        console.log("Next: Run Step2_FillOrder.s.sol on destination chain");
        console.log("Order ID to use:", vm.toString(orderId));
        console.log("IMPORTANT: Order data saved to order_data.json");
    }
    
    function _getCompactBatchWitnessSignature(
        uint256 privateKey,
        address arbiter,
        address sponsor,
        uint256 nonce,
        uint256 expires,
        uint256[2][] memory idsAndAmounts,
        bytes32 witness,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        keccak256(
                            bytes(
                                "BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts,Mandate mandate)Mandate(uint32 fillDeadline,address localOracle,MandateOutput[] outputs)MandateOutput(bytes32 remoteOracle,bytes32 remoteFiller,uint256 chainId,bytes32 token,uint256 amount,bytes32 recipient,bytes remoteCall,bytes fulfillmentContext)"
                            )
                        ),
                        arbiter,
                        sponsor,
                        nonce,
                        expires,
                        keccak256(abi.encodePacked(idsAndAmounts)),
                        witness
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function _witnessHash(StandardOrder memory order) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    bytes(
                        "Mandate(uint32 fillDeadline,address localOracle,MandateOutput[] outputs)MandateOutput(bytes32 remoteOracle,bytes32 remoteFiller,uint256 chainId,bytes32 token,uint256 amount,bytes32 recipient,bytes remoteCall,bytes fulfillmentContext)"
                    )
                ),
                order.fillDeadline,
                order.localOracle,
                _outputsHash(order.outputs)
            )
        );
    }

    function _outputsHash(MandateOutput[] memory outputs) internal pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](outputs.length);
        for (uint256 i = 0; i < outputs.length; ++i) {
            MandateOutput memory output = outputs[i];
            hashes[i] = keccak256(
                abi.encode(
                    keccak256(
                        bytes(
                            "MandateOutput(bytes32 remoteOracle,bytes32 remoteFiller,uint256 chainId,bytes32 token,uint256 amount,bytes32 recipient,bytes remoteCall,bytes fulfillmentContext)"
                        )
                    ),
                    output.remoteOracle,
                    output.remoteFiller,
                    output.chainId,
                    output.token,
                    output.amount,
                    output.recipient,
                    keccak256(output.remoteCall),
                    keccak256(output.fulfillmentContext)
                )
            );
        }
        return keccak256(abi.encodePacked(hashes));
    }

    function _saveOrderData(
        StandardOrder memory order,
        bytes32 orderId,
        bytes memory sponsorSig,
        uint256 tokenId,
        uint256 inputAmount,
        uint256 outputAmount,
        address user,
        address solver
    ) internal {
        // Create JSON string with all the data needed for Steps 2 & 3
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "orderInfo": {\n',
            '    "orderId": "', vm.toString(orderId), '",\n',
            '    "user": "', vm.toString(user), '",\n',
            '    "solver": "', vm.toString(solver), '",\n',
            '    "inputAmount": "', vm.toString(inputAmount), '",\n',
            '    "outputAmount": "', vm.toString(outputAmount), '",\n',
            '    "tokenId": "', vm.toString(tokenId), '"\n',
            '  },\n',
            '  "signatures": {\n',
            '    "sponsorSignature": "', vm.toString(sponsorSig), '"\n',
            '  },\n',
            '  "contractAddresses": {\n',
            '    "originChain": {\n',
            '      "chainId": "31337",\n',
            '      "theCompact": "0x5FbDB2315678afecb367f032d93F642f64180aa3",\n',
            '      "settlerCompact": "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",\n',
            '      "originToken": "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853",\n',
            '      "localOracle": "', vm.toString(order.localOracle), '"\n',
            '    },\n',
            '    "destinationChain": {\n',
            '      "chainId": "31338",\n',
            '      "coinFiller": "0x5FbDB2315678afecb367f032d93F642f64180aa3",\n',
            '      "remoteOracle": "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",\n',
            '      "destinationToken": "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"\n',
            '    }\n',
            '  },\n',
            '  "orderDetails": {\n',
            '    "nonce": ', vm.toString(order.nonce), ',\n',
            '    "originChainId": ', vm.toString(order.originChainId), ',\n',
            '    "expires": ', vm.toString(order.expires), ',\n',
            '    "fillDeadline": ', vm.toString(order.fillDeadline), ',\n',
            '    "inputs": [\n',
            '      [', vm.toString(order.inputs[0][0]), ', ', vm.toString(order.inputs[0][1]), ']\n',
            '    ],\n',
            '    "outputs": [\n',
            '      {\n',
            '        "remoteOracle": "', vm.toString(order.outputs[0].remoteOracle), '",\n',
            '        "remoteFiller": "', vm.toString(order.outputs[0].remoteFiller), '",\n',
            '        "chainId": ', vm.toString(order.outputs[0].chainId), ',\n',
            '        "token": "', vm.toString(order.outputs[0].token), '",\n',
            '        "amount": ', vm.toString(order.outputs[0].amount), ',\n',
            '        "recipient": "', vm.toString(order.outputs[0].recipient), '",\n',
            '        "remoteCall": "', vm.toString(order.outputs[0].remoteCall), '",\n',
            '        "fulfillmentContext": "', vm.toString(order.outputs[0].fulfillmentContext), '"\n',
            '      }\n',
            '    ]\n',
            '  }\n',
            '}'
        ));
        
        // Write to file
        vm.writeFile("order_data.json", json);
        console.log("Order data saved to: order_data.json");
    }
} 