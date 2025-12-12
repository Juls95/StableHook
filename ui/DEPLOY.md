# Deploying to Vercel

This guide will help you deploy the StableYield Hook UI to Vercel.

## Prerequisites

- A Vercel account (sign up at [vercel.com](https://vercel.com))
- Git repository (GitHub, GitLab, or Bitbucket)

## Option 1: Deploy via Vercel CLI (Recommended)

### 1. Install Vercel CLI

```bash
npm install -g vercel
```

### 2. Navigate to UI directory

```bash
cd ui
```

### 3. Login to Vercel

```bash
vercel login
```

### 4. Deploy

```bash
vercel
```

Follow the prompts:
- Set up and deploy? **Yes**
- Which scope? (Select your account)
- Link to existing project? **No** (for first deployment)
- Project name? (Press Enter for default or enter a custom name)
- Directory? **./** (current directory)
- Override settings? **No**

### 5. Deploy to Production

After the first deployment, you can deploy to production:

```bash
vercel --prod
```

## Option 2: Deploy via Vercel Dashboard

### 1. Push to Git Repository

Make sure your code is pushed to GitHub, GitLab, or Bitbucket.

### 2. Import Project

1. Go to [vercel.com/dashboard](https://vercel.com/dashboard)
2. Click **"Add New..."** → **"Project"**
3. Import your Git repository
4. Configure the project:
   - **Framework Preset**: Vite
   - **Root Directory**: `ui` (if your repo root is the parent directory)
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`
   - **Install Command**: `npm install`

### 3. Deploy

Click **"Deploy"** and wait for the build to complete.

## Configuration

The UI is configured to run in **simulation mode** by default, which means:
- No real wallet connection required
- All interactions are simulated
- Works perfectly for testing without blockchain connection

### Environment Variables (Optional)

If you want to configure the UI for production/testnet later, you can add environment variables in Vercel:

1. Go to your project settings in Vercel
2. Navigate to **Environment Variables**
3. Add variables if needed (currently not required for simulation mode)

## Testing the Deployment

After deployment:

1. Visit your Vercel URL (provided after deployment)
2. You should see the StableYield Hook UI
3. The UI will be in simulation mode by default
4. Try performing a swap to see the simulation logs

## Updating the Deployment

### Via CLI

```bash
cd ui
vercel --prod
```

### Via Git

Simply push to your main branch, and Vercel will automatically redeploy if you have auto-deployment enabled.

## Troubleshooting

### Build Fails

- Check that all dependencies are in `package.json`
- Ensure Node.js version is compatible (Vercel uses Node 18.x by default)
- Check build logs in Vercel dashboard

### UI Not Loading

- Verify the `vercel.json` configuration
- Check that the build output directory is `dist`
- Ensure all routes are properly configured

### Simulation Mode Not Working

- Check browser console for errors
- Verify that `SIMULATION_MODE = true` in `App.jsx` and `SwapDemo.jsx`
- Clear browser cache and reload

## Notes

- The UI runs in simulation mode, so no real blockchain connection is needed
- All contract interactions are simulated in the browser
- Check the browser console for detailed simulation logs
- The UI is fully functional for testing without deploying contracts
