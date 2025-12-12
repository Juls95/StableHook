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

## Deployment to Vercel

### Quick Deploy (Recommended)

```bash
# Option 1: Use the deployment script
./deploy.sh

# Option 2: Use Vercel CLI directly
npm install -g vercel
vercel --prod
```

### Step-by-Step Deployment

1. **Install Vercel CLI** (if not already installed):
   ```bash
   npm install -g vercel
   ```

2. **Login to Vercel**:
   ```bash
   vercel login
   ```

3. **Deploy**:
   ```bash
   # First deployment (preview)
   vercel
   
   # Production deployment
   vercel --prod
   ```

### Deploy via Vercel Dashboard

1. Push your code to GitHub/GitLab/Bitbucket
2. Go to [vercel.com/dashboard](https://vercel.com/dashboard)
3. Click **"Add New..."** → **"Project"**
4. Import your repository
5. Configure:
   - **Framework Preset**: Vite
   - **Root Directory**: `ui` (if repo root is parent directory)
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`
6. Click **"Deploy"**

### Configuration

The UI is pre-configured with `vercel.json` for optimal deployment. The app runs in **simulation mode** by default, so no blockchain connection is required.

For detailed deployment instructions, see [DEPLOY.md](./DEPLOY.md).

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

