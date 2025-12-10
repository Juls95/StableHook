# Quick Testing Guide

## Quick Start

1. **Install dependencies** (first time only):
```bash
./scripts/setup.sh
```

Or manually:
```bash
forge install Uniswap/v4-core --no-commit
forge install Uniswap/v4-periphery --no-commit
forge install foundry-rs/forge-std --no-commit
```

2. **Run all tests**:
```bash
forge test
```

3. **Run with detailed output**:
```bash
forge test -vvv
```

## Test Structure

### Unit Tests (`test/StableYieldHook.t.sol`)

Tests individual functions and logic:

- ✅ Hook permissions configuration
- ✅ `beforeSwap` with different APY/volume conditions
- ✅ `afterSwap` fee routing logic
- ✅ Yield compounding
- ✅ Volume tracking
- ✅ Access control

### Integration Tests (`test/Integration.t.sol`)

Tests complete swap flows:

- ✅ Full swap flow with fee routing
- ✅ Multiple swaps with compounding
- ✅ Edge cases (threshold boundaries)

## Common Test Commands

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/StableYieldHook.t.sol

# Run specific test function
forge test --match-test test_BeforeSwap_HighAPY_LowVolume_ReturnsDynamicFee

# Run with gas reporting
forge test --gas-report

# Run with trace (for debugging)
forge test -vvvv

# Run and show console.log output
forge test -vv
```

## Test Scenarios

### Scenario 1: Fee Routing (High APY, Low Volume)
```bash
forge test --match-test test_AfterSwap_RoutesFees_WhenConditionsMet -vv
```

**Expected behavior:**
- APY: 5% (> 4% threshold) ✅
- Volume: 1% (< 2% threshold) ✅
- Result: 50% of fees routed to Morpho

### Scenario 2: No Fee Routing (Low APY)
```bash
forge test --match-test test_AfterSwap_DoesNotRouteFees_WhenConditionsNotMet -vv
```

**Expected behavior:**
- APY: 3% (< 4% threshold) ❌
- Result: No fees routed, base fee tier used

### Scenario 3: Yield Compounding
```bash
forge test --match-test test_AfterSwap_CompoundsYield -vv
```

**Expected behavior:**
- Deposit to Morpho
- Wait 30 days
- Yield automatically compounded back to pool

## Debugging Failed Tests

1. **Get detailed output**:
```bash
forge test --match-test <test_name> -vvvv
```

2. **Use console.log** (already included in tests):
```bash
forge test -vv  # Shows console.log output
```

3. **Debug specific test**:
```bash
forge test --debug <test_name>
```

## Understanding Test Output

- `✓` = Test passed
- `✗` = Test failed
- `-vv` = Show logs
- `-vvv` = Show execution traces
- `-vvvv` = Show detailed traces

## Troubleshooting

### Error: "Cannot find module v4-core"
**Solution**: Run `forge install Uniswap/v4-core --no-commit`

### Error: "Cannot find module forge-std"
**Solution**: Run `forge install foundry-rs/forge-std --no-commit`

### Tests fail with "Only pool manager" error
**Solution**: Tests use `vm.prank` to simulate pool manager calls. This is expected behavior.

### Compilation errors
**Solution**: Make sure all dependencies are installed and remappings are correct in `remappings.txt`

## Next Steps

After running tests successfully:

1. Review test coverage: `forge coverage`
2. Check gas usage: `forge test --gas-report`
3. Run linting: `pnpm lint` (if configured)
4. Deploy to testnet (see deployment guide)

## Additional Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Uniswap V4 Documentation](https://docs.uniswap.org/)
- See `test/README.md` for detailed test documentation

