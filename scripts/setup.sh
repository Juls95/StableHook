#!/bin/bash
# Setup script for StableYield Hook project

set -e

echo "🚀 Setting up StableYield Hook project..."

# Check if foundry is installed
if ! command -v forge &> /dev/null; then
    echo "❌ Foundry is not installed. Please install it first:"
    echo "   curl -L https://foundry.paradigm.xyz | bash"
    exit 1
fi

echo "✅ Foundry is installed"

# Install dependencies
echo "📦 Installing Uniswap V4 dependencies..."

forge install Uniswap/v4-core --no-commit || echo "⚠️  v4-core may already be installed"
forge install Uniswap/v4-periphery --no-commit || echo "⚠️  v4-periphery may already be installed"
forge install foundry-rs/forge-std --no-commit || echo "⚠️  forge-std may already be installed"

echo "✅ Dependencies installed"

# Build contracts
echo "🔨 Building contracts..."
forge build

echo "✅ Build complete"

# Run tests
echo "🧪 Running tests..."
forge test

echo "✅ Setup complete! You can now:"
echo "   - Run tests: forge test"
echo "   - Build: forge build"
echo "   - Run specific test: forge test --match-test <test_name>"

