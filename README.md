# StableYield Hook (SYHook)

An innovative Uniswap V4 hook that transforms standard stablecoin liquidity pools (e.g., USDC/USDT) into intelligent, yield-optimizing engines by integrating with EigenLayer's Actively Validated Services (AVS).
┌─────────────────────┐          ┌──────────────────────┐           ┌────────────────────┐
│     Trader / dApp   │  Swap    │   Uniswap V4 Core     │          │   EigenLayer AVS   │
│  (wagmi / Frontend) │ ──────►  │   PoolManager.sol     │◄───────► │   YieldOracle AVS  │
└─────────────────────┘          │  ↳ Calls SYHook.sol  │   (1)     │ (Off-chain Operators│
                                 └─────────▲────────────┘           │  compute live APY) │
                                            │                       └─────────▲──────────┘
                                            │                                 │
                                  ┌─────────┴────────────┐                    │ Signed & Aggregated
                                  │   SYHook.sol         │                    │   APY Data
                                  │ (beforeSwap / afterSwap)                  │
                                  │   • Fetches APY from AVS                  │
                                  │   • Decides allocation %                  │
                                  │   • Routes fees → Morpho/Aave mock        │
                                  └─────────▲────────────┘                    │   
                                            │                                 │
                                  ┌─────────┴────────────┐    ┌───────────────┴──────┐
                                  │   MockLendingVault   │    │   YieldOracle.sol    │
                                  │   (simulates Morpho) │    │   (AVS Consumer)     │
                                  │   • deposit()        │    │   • verifyQuorum()   │
                                  │   • accrueInterest() │    │   • latestAPY()      │
                                  └──────────────────────┘    └──────────────────────┘

After swap → Fees auto-compounded back to LP positions via PoolManager
## Overview

SYHook dynamically routes a portion of swap fees to high-yield lending protocols like Morpho Blue or Aave during favorable market conditions, while ensuring security through restaked ETH-backed oracle data. This enables LPs to earn 15-30% higher effective APY without manual intervention.

## Key Features

- **Dynamic Yield Routing**: Routes 50-80% of fees to lending protocols when APY > 4% threshold
- **AVS-Secured Oracle**: EigenLayer operators aggregate data from Morpho/Aave
- **Auto-Compounding**: Accrues interest proportionally to LPs, minimizing IL
- **Fallback Mechanisms**: Stale data → fixed 4% APY; no quorum → base 0.3% fee

## Architecture

### Core Contracts

- `StableYieldHook.sol`: Main hook contract extending BaseHook
- `MockAVSOracle.sol`: Mock AVS oracle for PoC (uses storage variable)
- `MockMorphoDeposit.sol`: Mock Morpho Blue deposit contract

### Hook Logic

1. **beforeSwap**: 
   - Fetches APY from AVS oracle
   - Checks if APY > 4% and volume < 2%
   - Returns dynamic fee tier if conditions are met

2. **afterSwap**:
   - Routes 50% of accumulated fees to Morpho if conditions met
   - Compounds accrued yield back to pool
   - Updates volume tracking

## Setup

### Prerequisites

- Foundry
- Node.js (for linting)

### Installation

```bash
# Install Foundry dependencies
forge install

# Install Node dependencies
pnpm install
```

### Compilation

```bash
forge build
```

### Testing

### Quick Start

Run all tests:
```bash
forge test
```

Run E2E tests specifically:
```bash
forge test --match-path test/SYHookE2E.t.sol
```

Run on Sepolia fork:
```bash
forge test --match-path test/SYHookE2E.t.sol --fork-url $SEPOLIA_RPC_URL
```

See [test/E2E_TESTING.md](test/E2E_TESTING.md) for detailed E2E testing guide.

### Unit & Integration Tests

First, install the required dependencies:

```bash
# Install Uniswap V4 core
forge install Uniswap/v4-core --no-commit

# Install Uniswap V4 periphery  
forge install Uniswap/v4-periphery --no-commit

# Install forge-std for testing utilities
forge install foundry-rs/forge-std --no-commit
```

Then run the tests:

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test file
forge test --match-path test/StableYieldHook.t.sol

# Run with gas reporting
forge test --gas-report
```

See `test/README.md` for detailed testing documentation.

## Configuration

### Constants

- `MIN_APY_THRESHOLD`: 4% (0.04e18)
- `MAX_VOLUME_THRESHOLD`: 2% (0.02e18)
- `FEE_ROUTING_PERCENTAGE`: 50% (0.5e18)
- `BASE_FEE_TIER`: 0.3% (3000)
- `DYNAMIC_FEE_TIER`: 0.5% (5000)

## Development Status

This is a Proof of Concept (PoC) implementation. Production deployment would require:

- Integration with real EigenLayer AVS oracle
- Integration with real Morpho Blue/Aave contracts
- Proper fee collection mechanism from PoolManager
- LP yield distribution logic
- Comprehensive testing and auditing

## License

MIT

