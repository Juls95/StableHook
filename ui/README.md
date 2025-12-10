# StableYield Hook - React UI

Minimal React swap interface for StableYield Hook using wagmi and Vite.

## Features

- Wallet connection (MetaMask, WalletConnect, Injected)
- Token swap interface (USDC/USDT)
- Real-time APY display
- Dynamic fee tier indication
- Yield routing status
- Transaction status tracking

## Setup

1. Install dependencies:
```bash
cd ui
npm install
```

2. Update contract addresses in `src/components/SwapDemo.jsx`:
   - `POOL_MANAGER_ADDRESS`
   - `HOOK_ADDRESS`
   - `AVS_ORACLE_ADDRESS`

3. Update WalletConnect project ID in `src/App.jsx` (optional)

4. Run development server:
```bash
npm run dev
```

## Deployment

### Vercel

```bash
npm install -g vercel
vercel
```

### Netlify

```bash
npm run build
# Deploy the 'dist' folder to Netlify
```

## Environment Variables

Create `.env.local` for production:
```
VITE_POOL_MANAGER_ADDRESS=0x...
VITE_HOOK_ADDRESS=0x...
VITE_AVS_ORACLE_ADDRESS=0x...
```

## Notes

- This is a minimal UI for PoC demonstration
- No advanced styling or animations
- Focuses on core swap functionality
- Can be extended with additional features

