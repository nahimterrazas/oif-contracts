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
        uint256 userPrivateKey = vm.envUint("USER_PRIVATE_KEY");
        uint256 solverPrivateKey = vm.envUint("SOLVER_PRIVATE_KEY");
        address user = vm.addr(userPrivateKey);
        address solver = vm.addr(solverPrivateKey);
        
        console.log("=== STEP 3: FINALIZE ORDER ON ORIGIN CHAIN ===");
        console.log("User:", user);
        console.log("Solver:", solver);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(solverPrivateKey);  // Solver broadcasts the finalization
        
        // Deploy a fresh AlwaysYesOracle for testing
        AlwaysYesOracle testOracle = new AlwaysYesOracle();
        console.log("Deployed fresh AlwaysYesOracle at:", address(testOracle));
        
        // Origin chain contract addresses
        SettlerCompact settlerCompact = SettlerCompact(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);
        MockERC20 originToken = MockERC20(0xa513E6E4b8f2a923D98304ec87F64353C4D5C853);
        TheCompact theCompact = TheCompact(0x5FbDB2315678afecb367f032d93F642f64180aa3);
        
        uint256 inputAmount = 100 * 10**18; // 100 tokens
        uint256 outputAmount = 99 * 10**18;  // 99 tokens
        
        // Recreate the order structure (same as in Step 1)
        uint256[2][] memory inputs = new uint256[2][](1);
        inputs[0] = [232173931049414487598928205764542517475099722052565410375093941968804628563, inputAmount];
        
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
            localOracle: address(testOracle),
            inputs: inputs,
            outputs: outputs
        });
        
        bytes32 orderId = settlerCompact.orderIdentifier(order);
        bytes32 destination = bytes32(uint256(uint160(solver))); // Send tokens to solver
        
        // Create signature for the user to allow the solver to finalize on their behalf
        bytes32 domainSeparator = settlerCompact.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                this._hashAllowOpenHelper(orderId, destination, hex"")
            )
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(solverPrivateKey, digest);  // Use solver's key, not user's key
        bytes memory orderOwnerSignature = bytes.concat(r, s, bytes1(v));
        
        // Create signature for finalization (simplified for AlwaysYesOracle)
        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = uint32(block.timestamp);
        
        // Create proper Compact signatures for resource lock resolution
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
        bytes memory allocatorSig = hex""; // Empty for AlwaysOKAllocator
        
        bytes memory signatures = abi.encode(sponsorSig, allocatorSig);
        bytes32 solverIdentifier = bytes32(uint256(uint160(solver)));
        
        // Check solver's balance before finalization
        uint256 solverBalanceBefore = originToken.balanceOf(solver);
        console.log("Solver's balance before finalization:", solverBalanceBefore / 10**18);
        
        // Use finaliseFor - allows solver to finalize on behalf of user with signature
        settlerCompact.finaliseFor(
            order,
            signatures,
            timestamps,
            solverIdentifier,
            destination,
            hex"", // Empty call data
            orderOwnerSignature
        );
        console.log("Order finalized successfully using finaliseFor!");
        
        // Check solver's balance after finalization
        uint256 solverBalanceAfter = originToken.balanceOf(solver);
        console.log("Solver's balance after finalization:", solverBalanceAfter / 10**18);
        
        vm.stopBroadcast();
        
        console.log("\n=== CROSS-CHAIN SWAP COMPLETED SUCCESSFULLY! ===");
        console.log("User swapped 100 TokenA on origin chain for 99 TokenB on destination chain");
        console.log("Solver received 100 TokenA on origin chain");
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