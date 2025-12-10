import { WagmiProvider, createConfig, http } from 'wagmi'
import { mainnet, sepolia } from 'wagmi/chains'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { injected, metaMask, walletConnect } from 'wagmi/connectors'
import SwapDemo from './components/SwapDemo'

// Wagmi configuration
const config = createConfig({
  chains: [sepolia, mainnet],
  connectors: [
    injected(),
    metaMask(),
    walletConnect({ projectId: 'your-project-id' }),
  ],
  transports: {
    [sepolia.id]: http(),
    [mainnet.id]: http(),
  },
})

const queryClient = new QueryClient()

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <div style={{ maxWidth: '600px', margin: '0 auto' }}>
          <h1 style={{ textAlign: 'center', marginBottom: '30px' }}>
            StableYield Hook - Swap Interface
          </h1>
          <SwapDemo />
        </div>
      </QueryClientProvider>
    </WagmiProvider>
  )
}

export default App

