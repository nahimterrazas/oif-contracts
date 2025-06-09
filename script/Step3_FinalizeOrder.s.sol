// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { SettlerCompact } from "../src/settlers/compact/SettlerCompact.sol";
import { MockERC20 } from "../test/mocks/MockERC20.sol";
import { StandardOrder } from "../src/settlers/types/StandardOrderType.sol";
import { MandateOutput } from "../src/libs/MandateOutputEncodingLib.sol";
import { AllowOpenType } from "../src/settlers/types/AllowOpenType.sol";
import { AlwaysYesOracle } from "../test/mocks/AlwaysYesOracle.sol";
import { TheCompact } from "the-compact/src/TheCompact.sol";

contract Step3_FinalizeOrder is Script {
    function run() external {
        uint256 solverPrivateKey = vm.envUint("SOLVER_PRIVATE_KEY");
        address solver = vm.addr(solverPrivateKey);
        
        console.log("=== STEP 3: FINALIZE ORDER ON ORIGIN CHAIN ===");
        console.log("Solver:", solver);
        console.log("Chain ID:", block.chainid);
        
        // Read order data from Step1
        string memory jsonData = vm.readFile("order_data.json");
        
        // Parse key values from JSON
        bytes32 orderId = vm.parseJsonBytes32(jsonData, ".orderInfo.orderId");
        address user = vm.parseJsonAddress(jsonData, ".orderInfo.user");
        uint256 inputAmount = vm.parseJsonUint(jsonData, ".orderInfo.inputAmount");
        uint256 outputAmount = vm.parseJsonUint(jsonData, ".orderInfo.outputAmount");
        // uint256 tokenId = vm.parseJsonUint(jsonData, ".orderInfo.tokenId");
        bytes memory sponsorSig = vm.parseJsonBytes(jsonData, ".signatures.sponsorSignature");
        
        // Parse contract addresses
        address settlerCompactAddr = vm.parseJsonAddress(jsonData, ".contractAddresses.originChain.settlerCompact");
        address originTokenAddr = vm.parseJsonAddress(jsonData, ".contractAddresses.originChain.originToken");
        
        console.log("User:", user);
        console.log("Order ID:", vm.toString(orderId));
        console.log("Input Amount:", inputAmount / 10**18);
        
        vm.startBroadcast(solverPrivateKey);  // Solver broadcasts the finalization
        
        // Parse original oracle address from JSON instead of deploying fresh
        address originalOracle = vm.parseJsonAddress(jsonData, ".contractAddresses.originChain.localOracle");
        console.log("Using original oracle at:", originalOracle);
        
        // Origin chain contracts
        SettlerCompact settlerCompact = SettlerCompact(settlerCompactAddr);
        MockERC20 originToken = MockERC20(originTokenAddr);
        
        // Recreate the order from JSON data with original oracle
        StandardOrder memory order = _recreateOrderFromJson(jsonData, originalOracle);
        
        bytes32 destination = bytes32(uint256(uint160(solver))); // Send tokens to solver
        
        // Create timestamp for finalization
        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = uint32(block.timestamp);
        
        bytes memory allocatorSig = hex""; // Empty for AlwaysOKAllocator
        bytes memory signatures = abi.encode(sponsorSig, allocatorSig);
        bytes32 solverIdentifier = bytes32(uint256(uint160(solver)));
        
        // Check solver's balance before finalization
        uint256 solverBalanceBefore = originToken.balanceOf(solver);
        console.log("Solver's balance before finalization:", solverBalanceBefore / 10**18);
        
        // Use finalise - solver finalizes directly
        bytes32[] memory solvers = new bytes32[](1);
        solvers[0] = solverIdentifier;
        settlerCompact.finalise(
            order,
            signatures,
            timestamps,
            solvers,
            destination,
            hex"" // Empty call data
        );
        console.log("Order finalized successfully using finalise!");
        
        // Check solver's balance after finalization
        uint256 solverBalanceAfter = originToken.balanceOf(solver);
        console.log("Solver's balance after finalization:", solverBalanceAfter / 10**18);
        
        vm.stopBroadcast();
        
        console.log("\n=== CROSS-CHAIN SWAP COMPLETED SUCCESSFULLY! ===");
        console.log("User swapped", inputAmount / 10**18, "TokenA on origin chain");
        console.log("User received", outputAmount / 10**18, "TokenB on destination chain");
        console.log("Solver received", inputAmount / 10**18, "TokenA on origin chain");
    }
    
    // Helper function to recreate order from JSON data
    function _recreateOrderFromJson(
        string memory jsonData,
        address originalOracle
    ) internal pure returns (StandardOrder memory order) {
        // Parse order details from JSON
        uint256 nonce = vm.parseJsonUint(jsonData, ".orderDetails.nonce");
        uint256 originChainId = vm.parseJsonUint(jsonData, ".orderDetails.originChainId");
        uint256 expires = vm.parseJsonUint(jsonData, ".orderDetails.expires");
        uint256 fillDeadline = vm.parseJsonUint(jsonData, ".orderDetails.fillDeadline");
        
        address user = vm.parseJsonAddress(jsonData, ".orderInfo.user");
        uint256 tokenId = vm.parseJsonUint(jsonData, ".orderInfo.tokenId");
        uint256 inputAmount = vm.parseJsonUint(jsonData, ".orderInfo.inputAmount");
        uint256 outputAmount = vm.parseJsonUint(jsonData, ".orderInfo.outputAmount");
        
        // Recreate inputs array
        uint256[2][] memory inputs = new uint256[2][](1);
        inputs[0] = [tokenId, inputAmount];
        
        // Recreate outputs array
        MandateOutput[] memory outputs = new MandateOutput[](1);
        outputs[0] = MandateOutput({
            remoteOracle: vm.parseJsonBytes32(jsonData, ".orderDetails.outputs[0].remoteOracle"),
            remoteFiller: vm.parseJsonBytes32(jsonData, ".orderDetails.outputs[0].remoteFiller"),
            chainId: vm.parseJsonUint(jsonData, ".orderDetails.outputs[0].chainId"),
            token: vm.parseJsonBytes32(jsonData, ".orderDetails.outputs[0].token"),
            amount: outputAmount,
            recipient: vm.parseJsonBytes32(jsonData, ".orderDetails.outputs[0].recipient"),
            remoteCall: vm.parseJsonBytes(jsonData, ".orderDetails.outputs[0].remoteCall"),
            fulfillmentContext: vm.parseJsonBytes(jsonData, ".orderDetails.outputs[0].fulfillmentContext")
        });
        
        order = StandardOrder({
            user: user,
            nonce: nonce,
            originChainId: originChainId,
            expires: uint32(expires),
            fillDeadline: uint32(fillDeadline),
            localOracle: originalOracle,
            inputs: inputs,
            outputs: outputs
        });
    }
    
    function _hashAllowOpenHelper(bytes32 orderId, bytes32 destination, bytes calldata call) external pure returns (bytes32) {
        return AllowOpenType.hashAllowOpen(orderId, destination, call);
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
} 