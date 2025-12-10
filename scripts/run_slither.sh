#!/bin/bash
# Slither Security Audit Script for StableYieldHook

set -e

echo "🔍 Running Slither security audit on StableYieldHook..."

# Check if slither is installed
if ! command -v slither &> /dev/null; then
    echo "❌ Slither is not installed. Installing..."
    pip3 install slither-analyzer --break-system-packages || pip3 install slither-analyzer --user
fi

# Run Slither on main contract
echo "📋 Analyzing StableYieldHook.sol..."
slither src/StableYieldHook.sol \
    --solc-version 0.8.26 \
    --solc-settings "{optimizer: {enabled: true, runs: 200}}" \
    --exclude-dependencies \
    --print human-summary \
    --print inheritance-graph \
    --print function-summary \
    --detect reentrancy-eth,reentrancy-no-eth,reentrancy-unlimited-gas \
    --detect unchecked-transfer \
    --detect unchecked-send \
    --detect unchecked-lowlevel \
    --detect arbitrary-send \
    --detect controlled-array-length \
    --detect tx-origin \
    --detect uninitialized-state \
    --detect uninitialized-storage \
    --detect unused-return \
    --detect shadowing-state \
    --detect suicidal \
    --detect uninitialized-local \
    --detect calls-loop \
    --detect timestamp \
    --detect assembly \
    --detect low-level-calls \
    --detect boolean-equal \
    --detect constant-function-asm \
    --detect constant-function-state \
    --detect immutable-states \
    --detect pragma \
    --detect solc-version \
    --detect naming-convention \
    --exclude-informational \
    --exclude-optimization \
    --exclude-low \
    --filter-paths "lib/" \
    > slither-report.txt 2>&1 || true

echo "✅ Slither analysis complete. Report saved to slither-report.txt"
echo ""
echo "📊 Summary:"
grep -E "(High|Medium|Low|Info)" slither-report.txt | head -20 || echo "No issues found or report format different"

