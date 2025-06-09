# Catalyst Intent Cross-Chain Automation Guide

This guide explains how to run the automated cross-chain order execution system for Catalyst Intent contracts.

## Overview

The automation system consists of:
- **Manual Scripts**: Individual step-by-step execution
- **Automated Script**: Single command execution of the entire flow
- **Cross-chain order lifecycle**: Create → Fill → Finalize

## Prerequisites

### Required Tools
1. **Foundry** (with Forge and Anvil)
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Node.js** (for JSON processing)
   ```bash
   # Install via homebrew (macOS)
   brew install node
   
   # Or download from nodejs.org
   ```

3. **jq** (JSON processor)
   ```bash
   # macOS
   brew install jq
   
   # Ubuntu/Debian
   sudo apt-get install jq
   ```

### Environment Setup
Create a `.env` file in the project root:
```bash
# Private keys for testing (DO NOT USE IN PRODUCTION)
USER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
SOLVER_PRIVATE_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

## File Structure

```
script/
├── run_full_deployment.sh        # Automated full workflow
├── Step1_CreateOrder.s.sol       # Creates order on origin chain
├── Step2_FillOrder.s.sol         # Fills order on destination chain
├── Step3_FinalizeOrder.s.sol     # Finalizes order on origin chain
└── order_data.json              # Generated order data (auto-created)
```

## Execution Methods

### Method 1: Automated Execution (Recommended)

**Single Command Execution:**
```bash
./script/run_full_deployment.sh
```

**What it does:**
1. ✅ Starts two Anvil instances (Origin: 8545, Destination: 8546)
2. ✅ Deploys contracts to both chains
3. ✅ Creates an order on the origin chain
4. ✅ Fills the order on the destination chain
5. ✅ Finalizes the order on the origin chain
6. ✅ Provides cleanup instructions

**Features:**
- 🔍 Error handling and validation
- ⏱️ Automatic timing and sequencing
- 📊 Progress reporting with colored output
- 🛡️ Port conflict detection
- 🧹 Cleanup instructions

### Method 2: Manual Step-by-Step Execution

**Requirements:** 6 separate terminal windows

**Terminal 1 - Origin Chain:**
```bash
anvil --port 8545 --chain-id 31337
```

**Terminal 2 - Destination Chain:**
```bash
anvil --port 8546 --chain-id 31338
```

**Terminal 3 - Deploy Origin:**
```bash
forge script script/DeployLocal.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

**Terminal 4 - Deploy Destination:**
```bash
forge script script/DeployLocal.s.sol --rpc-url http://127.0.0.1:8546 --broadcast
```

**Terminal 5 - Execute Orders:**
```bash
# Step 1: Create Order
forge script script/Step1_CreateOrder.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

# Step 2: Fill Order
forge script script/Step2_FillOrder.s.sol --rpc-url http://127.0.0.1:8546 --broadcast

# Step 3: Finalize Order
forge script script/Step3_FinalizeOrder.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

**Terminal 6 - Monitoring:**
```bash
# Check order data
cat script/order_data.json

# Check logs in other terminals
```

## Chain Configuration

### Origin Chain (Anvil Instance 1)
- **RPC URL:** `http://127.0.0.1:8545`
- **Chain ID:** `31337`
- **Purpose:** Order creation and finalization

### Destination Chain (Anvil Instance 2)
- **RPC URL:** `http://127.0.0.1:8546` 
- **Chain ID:** `31338`
- **Purpose:** Order filling and execution

## Contract Addresses

After deployment, contracts are deployed at deterministic addresses:

### Origin Chain (31337)
- **TheCompact:** `0x5FbDB2315678afecb367f032d93F642f64180aa3`
- **SettlerCompact:** `0x5FC8d32690cc91D4c39d9d3abcBD16989F875707`
- **MockERC20:** `0xa513E6E4b8f2a923D98304ec87F64353C4D5C853`
- **Local Oracle:** `0x0165878A594ca255338adfa4d48449f69242Eb8F`

### Destination Chain (31338)
- **CoinFiller:** `0x5FbDB2315678afecb367f032d93F642f64180aa3`
- **RemoteOracle:** `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`
- **MockERC20:** `0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9`

## Workflow Explanation

### Step 1: Create Order (Origin Chain)
- User creates a cross-chain order
- Specifies input token and amount on origin chain
- Defines output token and amount on destination chain
- Order data is saved to `script/order_data.json`

### Step 2: Fill Order (Destination Chain)
- Solver reads the order data
- Executes the fill on destination chain
- Transfers tokens to the specified recipient
- Generates proof for finalization

### Step 3: Finalize Order (Origin Chain)
- Finalizes the original order
- Confirms the cross-chain execution
- Completes the order lifecycle

## Troubleshooting

### Common Issues

**1. Port Already in Use**
```bash
# Kill existing Anvil processes
pkill -f anvil
# Or specifically:
lsof -ti:8545 | xargs kill -9
lsof -ti:8546 | xargs kill -9
```

**2. Chain ID Mismatch**
- Ensure Anvil is running with correct chain IDs
- Check that scripts use `31337` and `31338` (not `1337`/`1338`)

**3. Contract Not Deployed**
- Run deployment scripts first
- Check if Anvil is running on correct ports

**4. Insufficient Balance**
- Anvil provides 10,000 ETH to test accounts by default
- Check private keys in `.env` file

**5. JSON File Not Found**
- Ensure Step1 completed successfully
- Check if `script/order_data.json` exists

### Debug Commands

```bash
# Check if Anvil is running
lsof -i :8545
lsof -i :8546

# Test RPC connections
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://127.0.0.1:8545

# Check order data
cat script/order_data.json | jq '.'

# View contract addresses
forge script script/DeployLocal.s.sol --rpc-url http://127.0.0.1:8545
```

## Cleanup

After testing, clean up resources:

```bash
# Stop Anvil instances
pkill -f anvil

# Remove generated files
rm -f script/order_data.json
rm -rf broadcast/
rm -rf cache/
rm -rf out/
```

## Security Notes

⚠️ **WARNING:** The private keys in this guide are for testing purposes only. Never use these keys in production or with real funds.

- Private keys are publicly known test keys
- Only use on local test networks
- Anvil provides isolated test environment

## Support

If you encounter issues:
1. Check the troubleshooting section
2. Verify all prerequisites are installed
3. Ensure ports 8545 and 8546 are available
4. Review the automated script logs for detailed error messages

---

**Quick Start:**
```bash
# Make script executable (first time only)
chmod +x script/run_full_deployment.sh

# Run everything
./script/run_full_deployment.sh
``` 