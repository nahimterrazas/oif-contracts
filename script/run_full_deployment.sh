#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port is in use
    else
        return 0  # Port is available
    fi
}

# Function to wait for RPC to be ready
wait_for_rpc() {
    local url=$1
    local max_attempts=30
    local attempt=1
    
    print_step "Waiting for RPC at $url to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -X POST \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
            $url >/dev/null 2>&1; then
            print_success "RPC at $url is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 1
        ((attempt++))
    done
    
    print_error "RPC at $url failed to start after $max_attempts seconds"
    return 1
}

# Function to cleanup anvil processes
cleanup() {
    print_warning "Cleaning up anvil processes..."
    pkill -f "anvil.*8545" 2>/dev/null || true
    pkill -f "anvil.*8546" 2>/dev/null || true
    sleep 2
}

# Trap to cleanup on script exit
trap cleanup EXIT

print_step "Starting Catalyst Intent Cross-Chain Deployment Automation"

# Step 1: Check if ports are available
print_step "Checking if ports 8545 and 8546 are available..."
if ! check_port 8545; then
    print_error "Port 8545 is already in use. Please stop the process using this port."
    exit 1
fi

if ! check_port 8546; then
    print_error "Port 8546 is already in use. Please stop the process using this port."
    exit 1
fi

# Step 2: Start Anvil instances
print_step "Starting Anvil instances..."
print_step "Starting Origin Chain (Chain ID: 31337) on port 8545..."
anvil --port 8545 --chain-id 31337 --silent &
ANVIL_PID_1=$!

print_step "Starting Destination Chain (Chain ID: 31338) on port 8546..."
anvil --port 8546 --chain-id 31338 --silent &
ANVIL_PID_2=$!

# Wait for both RPC endpoints to be ready
wait_for_rpc "http://127.0.0.1:8545" || exit 1
wait_for_rpc "http://127.0.0.1:8546" || exit 1

print_success "Both Anvil instances are running!"

# Step 3: Deploy to Origin Chain
print_step "Deploying contracts to Origin Chain..."
if forge script script/DeployOriginChain.s.sol --rpc-url http://127.0.0.1:8545 --broadcast; then
    print_success "Origin chain deployment completed!"
else
    print_error "Origin chain deployment failed!"
    exit 1
fi

# Step 4: Deploy to Destination Chain
print_step "Deploying contracts to Destination Chain..."
if forge script script/DeployDestinationChain.s.sol --rpc-url http://127.0.0.1:8546 --broadcast; then
    print_success "Destination chain deployment completed!"
else
    print_error "Destination chain deployment failed!"
    exit 1
fi

# Step 5: Create Order on Origin Chain
print_step "Creating order on Origin Chain..."
if forge script script/Step1_CreateOrder.s.sol --rpc-url http://127.0.0.1:8545 --broadcast; then
    print_success "Order created successfully!"
else
    print_error "Order creation failed!"
    exit 1
fi

# Step 6: Fill Order on Destination Chain
print_step "Filling order on Destination Chain..."
if forge script script/Step2_FillOrder.s.sol --rpc-url http://127.0.0.1:8546 --broadcast; then
    print_success "Order filled successfully!"
else
    print_error "Order filling failed!"
    exit 1
fi

# Step 7: Finalize Order on Origin Chain
print_step "Finalizing order on Origin Chain..."
if forge script script/Step3_FinalizeOrder.s.sol --rpc-url http://127.0.0.1:8545 --broadcast; then
    print_success "Order finalized successfully!"
else
    print_error "Order finalization failed!"
    exit 1
fi

print_success "🎉 Full deployment and execution completed successfully!"
print_step "Origin Chain RPC: http://127.0.0.1:8545 (Chain ID: 31337)"
print_step "Destination Chain RPC: http://127.0.0.1:8546 (Chain ID: 31338)"
print_warning "Press Ctrl+C to stop the Anvil instances when you're done testing."

# Keep the script running so anvil instances stay alive
print_step "Keeping Anvil instances running... (Press Ctrl+C to stop)"
wait 