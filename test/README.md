# Testing Guide

This directory contains comprehensive tests for the StableYield Hook.

## Test Files

- `StableYieldHook.t.sol`: Unit tests for individual hook functions
- `Integration.t.sol`: Integration tests simulating full swap flows

## Running Tests

### Run all tests
```bash
forge test
```

### Run with verbose output
```bash
forge test -vvv
```

### Run specific test file
```bash
forge test --match-path test/StableYieldHook.t.sol
```

### Run specific test function
```bash
forge test --match-test test_BeforeSwap_HighAPY_LowVolume_ReturnsDynamicFee
```

### Run with gas reporting
```bash
forge test --gas-report
```

## Test Coverage

### Unit Tests (`StableYieldHook.t.sol`)

1. **Hook Permissions**: Verifies correct hook permissions are set
2. **beforeSwap Logic**:
   - Returns base fee when APY is below threshold
   - Returns dynamic fee when APY is above threshold and volume is low
   - Returns base fee when volume is too high
3. **afterSwap Logic**:
   - Routes fees when conditions are met
   - Does not route fees when conditions are not met
   - Compounds yield correctly
4. **Volume Tracking**: Verifies volume resets after 24 hours
5. **Fee Calculation**: Verifies fees are calculated correctly
6. **Constants**: Verifies all constants are set correctly
7. **Access Control**: Verifies only pool manager can update liquidity and accumulate fees

### Integration Tests (`Integration.t.sol`)

1. **Complete Flow**: Tests full swap flow with fee routing
2. **Multiple Swaps**: Tests compounding across multiple swaps
3. **Edge Cases**: Tests APY and volume threshold edge cases

## Setting Up Dependencies

Before running tests, you need to install Uniswap V4 dependencies:

```bash
# Install Uniswap V4 core
forge install Uniswap/v4-core --no-commit

# Install Uniswap V4 periphery
forge install Uniswap/v4-periphery --no-commit

# Install forge-std for testing utilities
forge install foundry-rs/forge-std --no-commit
```

## Mock Contracts

The tests use mock contracts for:
- **MockPoolManager**: Simulates Uniswap V4 PoolManager
- **MockAVSOracle**: Provides configurable APY values
- **MockMorphoDeposit**: Simulates lending protocol deposits

## Test Scenarios

### Scenario 1: High APY, Low Volume
- APY: 5% (> 4% threshold)
- Volume: 1% (< 2% threshold)
- Expected: Dynamic fee tier, fees routed to Morpho

### Scenario 2: Low APY
- APY: 3% (< 4% threshold)
- Expected: Base fee tier, no fee routing

### Scenario 3: High Volume
- APY: 5% (> 4% threshold)
- Volume: 3% (> 2% threshold)
- Expected: Base fee tier, no fee routing

### Scenario 4: Yield Compounding
- Deposit funds to Morpho
- Wait 30 days
- Expected: Yield compounded back to pool

## Debugging Tests

### View console logs
```bash
forge test -vvv
```

### Debug specific test
```bash
forge test --debug test_BeforeSwap_HighAPY_LowVolume_ReturnsDynamicFee
```

### Trace gas usage
```bash
forge test --gas-report --match-test test_AfterSwap_RoutesFees_WhenConditionsMet
```

## Notes

- Tests use `vm.prank` to simulate pool manager calls
- Time manipulation uses `vm.warp` for yield accrual testing
- Mock contracts are simplified versions for testing purposes
- In production, real Uniswap V4 contracts would be used

