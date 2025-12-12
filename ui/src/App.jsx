import { WagmiProvider, createConfig, http } from 'wagmi'
import { mainnet, sepolia } from 'wagmi/chains'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { injected, metaMask, walletConnect } from 'wagmi/connectors'
import SwapDemo from './components/SwapDemo'

// Simulation mode - set to true to run without real wallet connection
const SIMULATION_MODE = true

// Wagmi configuration (only used if not in simulation mode)
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
    <WagmiProvider config={config} reconnectOnMount={!SIMULATION_MODE}>
      <QueryClientProvider client={queryClient}>
        <div style={{ maxWidth: '800px', margin: '0 auto', padding: '20px' }}>
          <h1 style={{ textAlign: 'center', marginBottom: '10px' }}>
            StableYield Hook - Swap Interface
          </h1>
          {SIMULATION_MODE && (
            <p style={{ textAlign: 'center', color: '#666', fontSize: '14px', marginBottom: '30px' }}>
              🧪 Running in Simulation Mode - All interactions are simulated
            </p>
          )}
          <SwapDemo />
        </div>
      </QueryClientProvider>
    </WagmiProvider>
  )
}

export default App

