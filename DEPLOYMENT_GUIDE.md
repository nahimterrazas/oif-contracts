# Catalyst Intent Cross-Chain Deployment Guide

This guide will help you deploy and test the Catalyst Intent cross-chain swap system using Anvil with two chains.

## Overview

Catalyst Intent enables cross-chain swaps through an intent-based system where:
- **Users** sign intents on the origin chain specifying what they want
- **Solvers** fulfill these intents by providing outputs on destination chains
- **Oracles** verify that outputs have been filled before releasing inputs

## Architecture

### Origin Chain Contracts
- **TheCompact**: Resource lock mechanism for input assets
- **AlwaysOKAllocator**: Simple allocator for TheCompact
- **SimpleAllocator**: More advanced allocator for TheCompact
- **SettlerCompact**: Main settler contract that handles orders
- **AlwaysYesOracle**: Custom oracle that always returns true (for testing)
- **MockERC20 tokens**: Test tokens for swapping

### Destination Chain Contracts
- **CoinFiller**: Filler contract that allows solvers to fulfill outputs
- **AlwaysYesOracle**: Same oracle for verification
- **MockERC20 tokens**: Test tokens for receiving swaps

## Prerequisites

1. **Environment Setup**:
   ```bash
   # Install Foundry if not already installed
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   
   # Clone and setup the project
   git clone <repository>
   cd oif-contracts
   forge install
   ```

2. **Environment Variables**:
   Create a `.env` file:
   ```bash
   # Deployment private key (use a test key, not real funds)
   PRIVATE_KEY=0x1234567890abcdef...
   
   # User and solver keys for testing
   USER_PRIVATE_KEY=0xabcdef1234567890...
   SOLVER_PRIVATE_KEY=0x9876543210fedcba...
   
   # RPC URLs (will be localhost for Anvil)
   ORIGIN_RPC_URL=http://127.0.0.1:8545
   DESTINATION_RPC_URL=http://127.0.0.1:8546
   ```

## Step 1: Start Anvil Chains

Open three terminal windows:

### Terminal 1 - Origin Chain (Chain ID: 31337)
```bash
anvil --port 8545 --chain-id 31337
```

### Terminal 2 - Destination Chain (Chain ID: 31338)
```bash
anvil --port 8546 --chain-id 31338
```

Keep these running throughout the testing process.

## Step 2: Deploy Contracts

### Terminal 3 - Deploy to Origin Chain
```bash
# Deploy to origin chain
forge script script/DeployOriginChain.s.sol --rpc-url $ORIGIN_RPC_URL --broadcast

# Save the output addresses for later use
```

Expected output:
```
=== ORIGIN CHAIN DEPLOYMENT SUMMARY ===
Chain ID: 31337
TheCompact: 0x...
AlwaysOKAllocator: 0x...
AlwaysOKAllocator ID: 1
SimpleAllocator: 0x...
SimpleAllocator ID: 2
SettlerCompact: 0x...
AlwaysYesOracle: 0x...
TokenA: 0x...
TokenB: 0x...
```

### Deploy to Destination Chain
```bash
# Deploy to destination chain
forge script script/DeployDestinationChain.s.sol --rpc-url $DESTINATION_RPC_URL --broadcast
```

Expected output:
```
=== DESTINATION CHAIN DEPLOYMENT SUMMARY ===
Chain ID: 31338
CoinFiller: 0x...
AlwaysYesOracle: 0x...
TokenA: 0x...
TokenB: 0x...
```

## Step 3: Test the Cross-Chain Swap

### Option A: Using the Test Script

You can use the `TestCrossChainSwap.s.sol` script to simulate a cross-chain swap:

```bash
# Create a test script that calls demonstrateSwap with your deployed addresses
# See TestCrossChainSwap.s.sol for the required DeploymentAddresses structure
```

### Option B: Manual Testing

1. **Prepare addresses**: Update the `TestCrossChainSwap.s.sol` with your deployed addresses.

2. **Execute swap simulation**:
   ```bash
   # Create a script that uses TestCrossChainSwap
   forge script script/TestCrossChainSwap.s.sol --rpc-url $ORIGIN_RPC_URL
   ```

## Step 4: Understanding the Flow

### 1. User Creates Intent (Origin Chain)
```solidity
// User deposits 100 TokenA on origin chain
// Wants to receive 99 TokenB on destination chain
StandardOrder memory order = StandardOrder({
    user: userAddress,
    nonce: 0,
    originChainId: 31337,
    expires: type(uint32).max,
    fillDeadline: type(uint32).max,
    localOracle: originOracleAddress,
    inputs: inputs,    // [tokenId, amount]
    outputs: outputs   // Desired outputs on destination chain
});
```

### 2. Solver Fills Output (Destination Chain)
```solidity
// Solver provides 99 TokenB to user on destination chain
coinFiller.fill(
    type(uint32).max,      // fillDeadline
    orderId,               // Order identifier
    outputDescription,     // What to fill
    solverIdentifier       // Solver's identifier
);
```

### 3. Finalization (Origin Chain)
```solidity
// After oracle confirms the fill, solver gets input tokens
settlerCompact.finaliseSelf(
    order,
    signatures,
    timestamps,
    solverIdentifier
);
```

## Step 5: Advanced Testing

### Testing Different Scenarios

1. **Dutch Auction Orders**:
   ```solidity
   // Set fulfillmentContext for declining price over time
   fulfillmentContext: abi.encodePacked(
       bytes1(0x01),              // Dutch auction flag
       bytes4(uint32(startTime)), // Auction start
       bytes4(uint32(stopTime)),  // Auction end
       bytes32(uint256(slope))    // Price decline rate
   )
   ```

2. **Exclusive Orders**:
   ```solidity
   // Set fulfillmentContext for solver exclusivity
   fulfillmentContext: abi.encodePacked(
       bytes1(0xe0),                    // Exclusive flag
       bytes32(uint256(uint160(solver))), // Exclusive solver
       bytes4(uint32(startTime))        // Exclusivity period
   )
   ```

3. **Multi-Output Orders**:
   ```solidity
   // Create orders with multiple outputs across different chains
   MandateOutput[] memory outputs = new MandateOutput[](2);
   // Fill outputs[0] and outputs[1] separately
   ```

## Step 6: Monitoring and Debugging

### View Contract State
```bash
# Check user's token balance
cast call $TOKEN_ADDRESS "balanceOf(address)" $USER_ADDRESS --rpc-url $ORIGIN_RPC_URL

# Check if order is filled
cast call $COIN_FILLER_ADDRESS "filled(bytes32)" $ORDER_ID --rpc-url $DESTINATION_RPC_URL

# Check oracle proof status
cast call $ORACLE_ADDRESS "isProven(uint256,bytes32,bytes32,bytes32)" \
    $CHAIN_ID $REMOTE_ORACLE $APPLICATION $DATA_HASH --rpc-url $ORIGIN_RPC_URL
```

### Common Issues and Solutions

1. **"WrongChain" Error**:
   - Ensure order.originChainId matches the chain you're deploying on
   - Verify output.chainId matches the destination chain

2. **"NotProven" Error**:
   - Check that the oracle correctly verifies the fill
   - Ensure timestamps are properly set

3. **"FilledTooLate" Error**:
   - Verify fillDeadline is in the future
   - Check timestamp parameters in finalization

4. **Token Transfer Failures**:
   - Ensure sufficient token balances
   - Verify approvals are set correctly

5. **"NotOrderOwner" Error**:
   - Ensure the correct solver is calling finalization functions
   - Verify the order owner matches the expected address

## Step 7: Production Considerations

When moving beyond testing:

1. **Replace AlwaysYesOracle**: Use proper oracles like Wormhole, LayerZero, etc.
2. **Security**: Implement proper access controls and validation
3. **Gas Optimization**: Review gas costs and optimize for production use
4. **Error Handling**: Add comprehensive error handling and recovery mechanisms
5. **Monitoring**: Implement proper logging and monitoring systems

## Key Contract APIs

### SettlerCompact
```solidity
// Create order identifier
function orderIdentifier(StandardOrder calldata order) external view returns (bytes32);

// Finalize order (self)
function finaliseSelf(
    StandardOrder calldata order,
    bytes calldata signatures,
    uint32[] calldata timestamps,
    bytes32 solver
) external;

// Finalize order (to specific destination)
function finaliseTo(
    StandardOrder calldata order,
    bytes calldata signatures,
    uint32[] calldata timestamps,
    bytes32 solver,
    bytes32 destination,
    bytes calldata call
) external;
```

### CoinFiller
```solidity
// Fill an order output
function fill(
    uint32 fillDeadline,
    bytes32 orderId,
    MandateOutput calldata output,
    bytes32 solverIdentifier
) external;
```

### TheCompact
```solidity
// Deposit ERC20 tokens
function depositERC20(
    address token,
    bytes12 allocatorTag,
    uint256 amount,
    address recipient
) external returns (uint256 tokenId);
```

## Useful Commands

```bash
# Build contracts
forge build

# Run all tests
forge test

# Run specific test with verbose output
forge test --match-test test_name -vvv

# Check contract sizes
forge build --sizes

# Generate gas report
forge test --gas-report

# Clean build artifacts
forge clean
```

## Architecture Diagram

```
Origin Chain (31337)              Destination Chain (31338)
┌─────────────────────┐          ┌─────────────────────┐
│  User               │          │  User               │
│  ├─ TokenA (input)  │          │  ├─ TokenB (output) │
│  └─ Create Intent   │          │  └─ Receive Output  │
└─────────────────────┘          └─────────────────────┘
           │                                │
           ▼                                ▲
┌─────────────────────┐          ┌─────────────────────┐
│  TheCompact         │          │  CoinFiller         │
│  ├─ Lock Assets     │          │  ├─ Fill Outputs    │
│  └─ Resource Mgmt   │          │  └─ Record Fills    │
└─────────────────────┘          └─────────────────────┘
           │                                │
           ▼                                ▲
┌─────────────────────┐          ┌─────────────────────┐
│  SettlerCompact     │          │  Solver             │
│  ├─ Order Mgmt      │◄────────►│  ├─ Monitor Orders  │
│  ├─ Validation      │          │  ├─ Fill Orders     │
│  └─ Finalization    │          │  └─ Claim Rewards   │
└─────────────────────┘          └─────────────────────┘
           │                                
           ▼                                
┌─────────────────────┐          
│  AlwaysYesOracle    │          
│  ├─ Proof Verify    │          
│  └─ Always True     │          
└─────────────────────┘          
```

This guide provides a complete setup for testing the Catalyst Intent system with two Anvil chains. The AlwaysYesOracle simplifies testing by removing the need for complex cross-chain messaging during development. 