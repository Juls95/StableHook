# End-to-End Testing Guide

This guide covers running comprehensive E2E tests for StableYieldHook, including fork testing on Sepolia.

## Test File

- `SYHookE2E.t.sol`: Complete end-to-end test suite simulating real swap/yield scenarios

## Running Tests

### Local Tests (Mock Environment)

Run all E2E tests locally:
```bash
forge test --match-path test/SYHookE2E.t.sol
```

Run with verbose output:
```bash
forge test --match-path test/SYHookE2E.t.sol -vvv
```

### Fork Tests (Sepolia)

To run tests on a Sepolia fork, you need a Sepolia RPC URL:

1. **Set up environment variable** (optional, or use inline):
```bash
export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_API_KEY"
```

2. **Run tests on fork**:
```bash
forge test --match-path test/SYHookE2E.t.sol --fork-url $SEPOLIA_RPC_URL
```

Or inline:
```bash
forge test --match-path test/SYHookE2E.t.sol --fork-url https://sepolia.infura.io/v3/YOUR_API_KEY
```

3. **Run with gas reporting on fork**:
```bash
forge test --match-path test/SYHookE2E.t.sol --fork-url $SEPOLIA_RPC_URL --gas-report
```

## Test Coverage

The E2E test suite covers:

### ✅ Core Functionality

1. **Dynamic Fee Application** (`testDynamicYield_HighAPY_LowVolume_AppliesDynamicFee`)
   - APY > 4% and volume < 2%
   - Verifies dynamic fee tier is applied
   - Verifies fees are routed to Morpho

2. **Base Fee Usage** (`testDynamicYield_LowAPY_UsesBaseFee`)
   - APY < 4%
   - Verifies base fee tier is used
   - Verifies no fee routing occurs

3. **High Volume Handling** (`testDynamicYield_HighVolume_UsesBaseFee`)
   - Volume > 2% even with APY > 4%
   - Verifies base fee is used to prevent excessive routing

### ✅ Yield Optimization

4. **Yield Compounding** (`testYieldCompounding_AccruesAndCompounds`)
   - Deposits fees to Morpho
   - Waits 30 days for yield accrual
   - Verifies yield is compounded back to pool

5. **Multiple Swaps** (`testMultipleSwaps_AccumulateFees`)
   - Tests fee accumulation across multiple swaps
   - Verifies routing works consistently

### ✅ Edge Cases

6. **Volume Tracking Reset** (`testVolumeTracking_ResetsAfter24Hours`)
   - Verifies 24-hour volume window resets correctly
   - Ensures routing resumes after reset

7. **APY at Threshold** (`testEdgeCase_APYAtThreshold`)
   - Tests behavior at exactly 4% APY
   - Verifies threshold logic (must be > 4%)

8. **Volume at Threshold** (`testEdgeCase_VolumeAtThreshold`)
   - Tests behavior at exactly 2% volume
   - Verifies threshold logic (must be < 2%)

### ✅ Failure Scenarios

9. **Oracle Failure Fallback** (`testOracleFailureFallback_UsesBaseFee`)
   - Simulates oracle returning 0 APY
   - Verifies fallback to base fee
   - Ensures system remains functional

10. **Constants Validation** (`testConstants_AreCorrectlySet`)
    - Verifies all hook constants are correctly configured

## Test Scenarios Explained

### Scenario 1: Optimal Yield Routing
```
APY: 5% (> 4% threshold) ✅
Volume: 1% (< 2% threshold) ✅
Result: Dynamic fee (0.5%) applied, 50% of fees routed to Morpho
```

### Scenario 2: Low APY (No Routing)
```
APY: 3% (< 4% threshold) ❌
Result: Base fee (0.3%) used, no fee routing
```

### Scenario 3: High Volume (No Routing)
```
APY: 5% (> 4% threshold) ✅
Volume: 3% (> 2% threshold) ❌
Result: Base fee (0.3%) used, no fee routing (prevents excessive routing)
```

### Scenario 4: Oracle Failure
```
APY: 0 (oracle failure)
Result: Base fee (0.3%) used, system remains functional
```

## Running Specific Tests

Run a specific test:
```bash
forge test --match-test testDynamicYield_HighAPY_LowVolume_AppliesDynamicFee -vv
```

Run all edge case tests:
```bash
forge test --match-test "testEdgeCase" -vv
```

Run all yield-related tests:
```bash
forge test --match-test "testYield" -vv
```

## Debugging

### View detailed traces:
```bash
forge test --match-path test/SYHookE2E.t.sol -vvvv
```

### Debug specific test:
```bash
forge test --debug testDynamicYield_HighAPY_LowVolume_AppliesDynamicFee
```

### Check gas usage:
```bash
forge test --match-path test/SYHookE2E.t.sol --gas-report
```

## Fork Testing Best Practices

1. **Use a reliable RPC provider**: Infura, Alchemy, or QuickNode
2. **Set appropriate fork block**: Use a recent block for accurate state
   ```bash
   forge test --fork-url $SEPOLIA_RPC_URL --fork-block-number 5000000
   ```
3. **Monitor rate limits**: Fork tests make many RPC calls
4. **Use caching**: Foundry caches fork state for faster subsequent runs

## Expected Test Results

All 10 tests should pass:
```
✓ testConstants_AreCorrectlySet
✓ testDynamicYield_HighAPY_LowVolume_AppliesDynamicFee
✓ testDynamicYield_HighVolume_UsesBaseFee
✓ testDynamicYield_LowAPY_UsesBaseFee
✓ testEdgeCase_APYAtThreshold
✓ testEdgeCase_VolumeAtThreshold
✓ testMultipleSwaps_AccumulateFees
✓ testOracleFailureFallback_UsesBaseFee
✓ testVolumeTracking_ResetsAfter24Hours
✓ testYieldCompounding_AccruesAndCompounds
```

## Integration with CI/CD

Example GitHub Actions workflow:
```yaml
- name: Run E2E Tests
  run: |
    forge test --match-path test/SYHookE2E.t.sol --fork-url ${{ secrets.SEPOLIA_RPC_URL }}
```

## Next Steps

After E2E tests pass:
1. ✅ Deploy to Sepolia testnet
2. ✅ Run integration tests on testnet
3. ✅ Monitor gas costs and optimize if needed
4. ✅ Prepare for mainnet deployment

