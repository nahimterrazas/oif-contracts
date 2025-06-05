#!/bin/bash

# Test deployment script for Catalyst Intent Cross-Chain System
echo "🚀 Starting Catalyst Intent Deployment Test"

# Check if foundry is installed
if ! command -v forge &> /dev/null; then
    echo "❌ Foundry not found. Please install it first:"
    echo "curl -L https://foundry.paradigm.xyz | bash"
    echo "foundryup"
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found. Creating a sample .env file..."
    cat > .env << EOL
# Test private keys (DO NOT use these in production!)
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
USER_PRIVATE_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
SOLVER_PRIVATE_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

# RPC URLs for Anvil
ORIGIN_RPC_URL=http://127.0.0.1:8545
DESTINATION_RPC_URL=http://127.0.0.1:8546
EOL
    echo "✅ Sample .env file created. You can edit it if needed."
fi

# Source environment variables
source .env

echo "📋 Pre-deployment checks..."

# Build contracts
echo "🔨 Building contracts..."
forge build
if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

# Run tests to ensure everything works
echo "🧪 Running tests..."
forge test --match-test test_deposit_compact -q
if [ $? -ne 0 ]; then
    echo "❌ Basic tests failed"
    exit 1
fi

echo "✅ Pre-deployment checks passed!"

echo ""
echo "🔗 To test the full cross-chain deployment:"
echo "1. Start two Anvil instances in separate terminals:"
echo "   Terminal 1: anvil --port 8545 --chain-id 31337"
echo "   Terminal 2: anvil --port 8546 --chain-id 31338"
echo ""
echo "2. Deploy to origin chain:"
echo "   forge script script/DeployOriginChain.s.sol --rpc-url \$ORIGIN_RPC_URL --broadcast"
echo ""
echo "3. Deploy to destination chain:"
echo "   forge script script/DeployDestinationChain.s.sol --rpc-url \$DESTINATION_RPC_URL --broadcast"
echo ""
echo "4. Run the integration test:"
echo "   forge test --match-test test_entire_flow --gas-report -vvv"
echo ""

# Check if anvil processes are running
if pgrep -f "anvil.*8545" > /dev/null; then
    echo "✅ Anvil is running on port 8545 (origin chain)"
    ORIGIN_RUNNING=true
else
    echo "⚠️  Anvil not detected on port 8545 (origin chain)"
    ORIGIN_RUNNING=false
fi

if pgrep -f "anvil.*8546" > /dev/null; then
    echo "✅ Anvil is running on port 8546 (destination chain)"
    DESTINATION_RUNNING=true
else
    echo "⚠️  Anvil not detected on port 8546 (destination chain)"
    DESTINATION_RUNNING=false
fi

if [ "$ORIGIN_RUNNING" = true ] && [ "$DESTINATION_RUNNING" = true ]; then
    echo ""
    echo "🎯 Both Anvil chains detected! You can now run deployments."
    echo ""
    read -p "Do you want to run the deployments now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🚀 Deploying to origin chain..."
        forge script script/DeployOriginChain.s.sol --rpc-url $ORIGIN_RPC_URL --broadcast
        
        echo ""
        echo "🚀 Deploying to destination chain..."
        forge script script/DeployDestinationChain.s.sol --rpc-url $DESTINATION_RPC_URL --broadcast
        
        echo ""
        echo "✅ Deployments complete!"
        echo "📖 Check DEPLOYMENT_GUIDE.md for next steps."
    fi
else
    echo ""
    echo "📖 See DEPLOYMENT_GUIDE.md for detailed instructions."
fi

echo ""
echo "🎉 Setup complete! Happy testing!" 