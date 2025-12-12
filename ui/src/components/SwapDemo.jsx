import { useState, useEffect } from 'react'
import { useAccount, useWriteContract, useReadContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther, formatEther } from 'viem'

// Simulation mode - set to true to run without real wallet connection
const SIMULATION_MODE = true

// Contract addresses (will be loaded from simulation.json if available)
let POOL_MANAGER_ADDRESS = '0x0000000000000000000000000000000000000000'
let HOOK_ADDRESS = '0x0000000000000000000000000000000000000000'
let AVS_ORACLE_ADDRESS = '0x0000000000000000000000000000000000000000'

// Try to load addresses from simulation.json
if (typeof window !== 'undefined') {
  try {
    // In production, this would be fetched from an API or env vars
    // For simulation, we'll use mock addresses
    if (SIMULATION_MODE) {
      POOL_MANAGER_ADDRESS = '0x000000000004444c5dc75cB358380D2e3dE08A90'
      HOOK_ADDRESS = '0x4444000000000000000000000000000000000000'
      AVS_ORACLE_ADDRESS = '0x4444000000000000000000000000000000000001'
    }
  } catch (e) {
    console.log('Using default addresses for simulation')
  }
}

// Mock token addresses (USDC/USDT on Sepolia)
const USDC_ADDRESS = '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238' // Sepolia USDC
const USDT_ADDRESS = '0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0' // Sepolia USDT

// PoolManager ABI (simplified for swap)
const POOL_MANAGER_ABI = [
  {
    name: 'swap',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      {
        name: 'key',
        type: 'tuple',
        components: [
          { name: 'currency0', type: 'address' },
          { name: 'currency1', type: 'address' },
          { name: 'fee', type: 'uint24' },
          { name: 'tickSpacing', type: 'int24' },
          { name: 'hooks', type: 'address' },
        ],
      },
      {
        name: 'params',
        type: 'tuple',
        components: [
          { name: 'zeroForOne', type: 'bool' },
          { name: 'amountSpecified', type: 'int256' },
          { name: 'sqrtPriceLimitX96', type: 'uint160' },
        ],
      },
      { name: 'hookData', type: 'bytes' },
    ],
    outputs: [{ name: 'delta', type: 'int256' }],
  },
]

// Hook ABI for reading APY-related data
const HOOK_ABI = [
  {
    name: 'MIN_APY_THRESHOLD',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'BASE_FEE_TIER',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint24' }],
  },
  {
    name: 'DYNAMIC_FEE_TIER',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint24' }],
  },
]

// AVS Oracle ABI
const AVS_ORACLE_ABI = [
  {
    name: 'getAPY',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'setAPY',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'apy', type: 'uint256' }],
    outputs: [],
  },
]

function SwapDemo() {
  const { address, isConnected, connector } = useAccount()
  const [amount, setAmount] = useState('')
  const [zeroForOne, setZeroForOne] = useState(true) // true = token0 -> token1
  const [mockAPY, setMockAPY] = useState(5.0) // Mock APY in percentage
  const [simulationLogs, setSimulationLogs] = useState([])
  const [isSimulating, setIsSimulating] = useState(false)

  // In simulation mode, always show as connected
  const effectiveConnected = SIMULATION_MODE || isConnected
  const effectiveAddress = SIMULATION_MODE ? '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb' : address

  // Read current APY from oracle (if available and not in simulation mode)
  const { data: apyData } = useReadContract({
    address: !SIMULATION_MODE && AVS_ORACLE_ADDRESS !== '0x0000000000000000000000000000000000000000' ? AVS_ORACLE_ADDRESS : undefined,
    abi: AVS_ORACLE_ABI,
    functionName: 'getAPY',
    query: {
      enabled: !SIMULATION_MODE && AVS_ORACLE_ADDRESS !== '0x0000000000000000000000000000000000000000',
    },
  })

  // Update mock APY if oracle data is available
  useEffect(() => {
    if (!SIMULATION_MODE && apyData) {
      // Convert from 18 decimal format to percentage
      const apyPercentage = (Number(apyData) / 1e18) * 100
      setMockAPY(apyPercentage)
    }
  }, [apyData])

  // Write contract for swap
  const {
    data: hash,
    writeContract,
    isPending,
    error: writeError,
  } = useWriteContract()

  // Wait for transaction
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  })

  const addLog = (message, type = 'info') => {
    const timestamp = new Date().toLocaleTimeString()
    setSimulationLogs(prev => [...prev, { timestamp, message, type }])
    // Also log to console for terminal visibility
    console.log(`[${timestamp}] ${message}`)
  }

  const simulateSwap = async () => {
    if (!amount) {
      alert('Please enter amount')
      return
    }

    setIsSimulating(true)
    setSimulationLogs([])

    try {
      addLog('🔄 Starting swap simulation...', 'info')
      addLog(`📊 Swap amount: ${amount} tokens`, 'info')
      addLog(`🔄 Direction: ${zeroForOne ? 'USDC → USDT' : 'USDT → USDC'}`, 'info')

      // Simulate checking APY from EigenLayer AVS Oracle
      addLog('🔍 Querying EigenLayer AVS Oracle for current APY...', 'info')
      await new Promise(resolve => setTimeout(resolve, 500))
      addLog(`✅ AVS Oracle returned APY: ${mockAPY.toFixed(2)}%`, 'success')

      // Determine fee tier
      const shouldRoute = mockAPY > 4
      const feeTier = shouldRoute ? 0.5 : 0.3
      addLog(`💰 Fee tier: ${feeTier}% (${shouldRoute ? 'Dynamic - Yield routing active' : 'Base - Yield routing inactive'})`, 'info')

      // Simulate swap execution
      addLog('⚡ Executing swap on Uniswap V4 PoolManager...', 'info')
      await new Promise(resolve => setTimeout(resolve, 1000))
      addLog('✅ Swap executed successfully', 'success')

      // Calculate fees
      const swapAmount = parseFloat(amount)
      const feeAmount = (swapAmount * feeTier) / 100
      addLog(`💵 Swap fee: ${feeAmount.toFixed(4)} tokens (${feeTier}%)`, 'info')

      if (shouldRoute) {
        const routingAmount = feeAmount * 0.5
        addLog(`🚀 Routing 50% of fees to Morpho Blue: ${routingAmount.toFixed(4)} tokens`, 'info')
        await new Promise(resolve => setTimeout(resolve, 800))
        addLog('✅ Fees deposited to Morpho Blue lending protocol', 'success')
        addLog('📈 Yield will accrue and compound back to pool automatically', 'info')
      } else {
        addLog('ℹ️  Yield routing inactive (APY below 4% threshold)', 'info')
      }

      // Simulate yield compounding check
      addLog('🔍 Checking for accrued yield from previous deposits...', 'info')
      await new Promise(resolve => setTimeout(resolve, 500))
      addLog('✅ Yield compounding check complete', 'success')

      addLog('✨ Swap and yield routing complete!', 'success')

      // Generate mock transaction hash
      const mockHash = '0x' + Array.from({ length: 64 }, () => Math.floor(Math.random() * 16).toString(16)).join('')
      addLog(`📝 Transaction hash: ${mockHash}`, 'info')

    } catch (err) {
      addLog(`❌ Error: ${err.message}`, 'error')
      console.error('Simulation error:', err)
    } finally {
      setIsSimulating(false)
    }
  }

  const handleSwap = async () => {
    if (SIMULATION_MODE) {
      await simulateSwap()
    } else {
      // Real swap logic
      if (!amount || !isConnected) {
        alert('Please connect wallet and enter amount')
        return
      }

      try {
        const amountSpecified = parseEther(amount)
        const amountInt = zeroForOne ? -BigInt(amountSpecified) : BigInt(amountSpecified)

        // Pool key structure
        const poolKey = {
          currency0: zeroForOne ? USDC_ADDRESS : USDT_ADDRESS,
          currency1: zeroForOne ? USDT_ADDRESS : USDC_ADDRESS,
          fee: 3000, // 0.3% base fee
          tickSpacing: 60,
          hooks: HOOK_ADDRESS,
        }

        // Swap params
        const swapParams = {
          zeroForOne,
          amountSpecified: amountInt,
          sqrtPriceLimitX96: 0n, // No price limit
        }

        // Hook data (empty for now)
        const hookData = '0x'

        writeContract({
          address: POOL_MANAGER_ADDRESS,
          abi: POOL_MANAGER_ABI,
          functionName: 'swap',
          args: [poolKey, swapParams, hookData],
        })
      } catch (err) {
        console.error('Swap error:', err)
        alert(`Swap failed: ${err.message}`)
      }
    }
  }

  const formatAPY = (apy) => {
    return apy.toFixed(2)
  }

  const getFeeTier = () => {
    // Dynamic fee if APY > 4%
    return mockAPY > 4 ? '0.5% (Dynamic)' : '0.3% (Base)'
  }

  const getYieldRoutingStatus = () => {
    if (mockAPY > 4) {
      return 'Active - 50% fees routed to Morpho'
    }
    return 'Inactive - APY below 4% threshold'
  }

  const handleAPYChange = (newAPY) => {
    setMockAPY(newAPY)
    if (SIMULATION_MODE) {
      addLog(`🔧 APY updated to ${newAPY.toFixed(2)}% (simulating EigenLayer AVS Oracle update)`, 'info')
    }
  }

  return (
    <div style={{ 
      border: '1px solid #ddd', 
      borderRadius: '8px', 
      padding: '20px',
      backgroundColor: 'white',
      boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
    }}>
      {/* Simulation Mode Banner */}
      {SIMULATION_MODE && (
        <div style={{ 
          marginBottom: '20px', 
          padding: '10px', 
          backgroundColor: '#fff3cd', 
          borderRadius: '4px',
          border: '1px solid #ffc107'
        }}>
          <p style={{ margin: 0, fontWeight: 'bold', color: '#856404' }}>
            🧪 SIMULATION MODE - No real transactions
          </p>
          <p style={{ margin: '5px 0 0 0', fontSize: '12px', color: '#856404' }}>
            All interactions are simulated. Check browser console for detailed logs.
          </p>
        </div>
      )}

      {/* Connection Status */}
      <div style={{ marginBottom: '20px', padding: '10px', backgroundColor: '#f0f0f0', borderRadius: '4px' }}>
        <p><strong>Wallet:</strong> {effectiveConnected ? (effectiveAddress?.substring(0, 10) + '...') : 'Not Connected'}</p>
        {SIMULATION_MODE && (
          <p style={{ fontSize: '12px', color: '#666' }}>Simulated wallet address</p>
        )}
        {!SIMULATION_MODE && isConnected && connector && (
          <p><strong>Connector:</strong> {connector.name}</p>
        )}
      </div>

      {/* APY Display */}
      <div style={{ marginBottom: '20px', padding: '15px', backgroundColor: '#e8f5e9', borderRadius: '4px' }}>
        <h3 style={{ marginBottom: '10px' }}>Current APY Status</h3>
        <p style={{ fontSize: '24px', fontWeight: 'bold', color: mockAPY > 4 ? '#4caf50' : '#ff9800' }}>
          {SIMULATION_MODE ? 'Simulated' : ''} APY: {formatAPY(mockAPY)}%
        </p>
        <p><strong>Fee Tier:</strong> {getFeeTier()}</p>
        <p><strong>Yield Routing:</strong> {getYieldRoutingStatus()}</p>
        {SIMULATION_MODE && (
          <div style={{ marginTop: '10px' }}>
            <label style={{ fontSize: '12px' }}>
              Adjust APY (simulating EigenLayer):
              <input
                type="range"
                min="0"
                max="10"
                step="0.1"
                value={mockAPY}
                onChange={(e) => handleAPYChange(parseFloat(e.target.value))}
                style={{ width: '100%', marginTop: '5px' }}
              />
              <span style={{ fontSize: '12px', marginLeft: '10px' }}>{mockAPY.toFixed(2)}%</span>
            </label>
          </div>
        )}
      </div>

      {/* Swap Interface */}
      <div style={{ marginBottom: '20px' }}>
        <h3 style={{ marginBottom: '15px' }}>Swap Tokens</h3>
        
        {/* Token Selection */}
        <div style={{ marginBottom: '15px' }}>
          <label style={{ display: 'block', marginBottom: '5px' }}>
            <input
              type="radio"
              checked={zeroForOne}
              onChange={() => setZeroForOne(true)}
              style={{ marginRight: '5px' }}
            />
            USDC → USDT
          </label>
          <label style={{ display: 'block' }}>
            <input
              type="radio"
              checked={!zeroForOne}
              onChange={() => setZeroForOne(false)}
              style={{ marginRight: '5px' }}
            />
            USDT → USDC
          </label>
        </div>

        {/* Amount Input */}
        <div style={{ marginBottom: '15px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
            Amount:
          </label>
          <input
            type="number"
            placeholder="Enter amount"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            style={{
              width: '100%',
              padding: '10px',
              fontSize: '16px',
              border: '1px solid #ddd',
              borderRadius: '4px',
            }}
            disabled={!effectiveConnected || isSimulating}
          />
        </div>

        {/* Swap Button */}
        <button
          onClick={handleSwap}
          disabled={!effectiveConnected || !amount || isPending || isConfirming || isSimulating}
          style={{
            width: '100%',
            padding: '12px',
            fontSize: '16px',
            fontWeight: 'bold',
            backgroundColor: effectiveConnected && amount && !isPending && !isConfirming && !isSimulating ? '#4caf50' : '#ccc',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: effectiveConnected && amount && !isPending && !isConfirming && !isSimulating ? 'pointer' : 'not-allowed',
          }}
        >
          {isSimulating ? 'Simulating...' : isPending ? 'Confirming...' : isConfirming ? 'Processing...' : 'Swap & Route Yield'}
        </button>

        {/* Transaction Status */}
        {hash && !SIMULATION_MODE && (
          <div style={{ marginTop: '15px', padding: '10px', backgroundColor: '#e3f2fd', borderRadius: '4px' }}>
            <p><strong>Transaction Hash:</strong></p>
            <p style={{ fontSize: '12px', wordBreak: 'break-all' }}>{hash}</p>
            {isConfirmed && (
              <p style={{ color: '#4caf50', marginTop: '5px' }}>✓ Transaction confirmed!</p>
            )}
          </div>
        )}

        {/* Error Display */}
        {writeError && !SIMULATION_MODE && (
          <div style={{ marginTop: '15px', padding: '10px', backgroundColor: '#ffebee', borderRadius: '4px', color: '#c62828' }}>
            <p><strong>Error:</strong> {writeError.message}</p>
          </div>
        )}
      </div>

      {/* Simulation Logs */}
      {SIMULATION_MODE && simulationLogs.length > 0 && (
        <div style={{ marginTop: '20px', padding: '15px', backgroundColor: '#f5f5f5', borderRadius: '4px', maxHeight: '300px', overflowY: 'auto' }}>
          <h4 style={{ marginBottom: '10px' }}>Simulation Logs (also in browser console):</h4>
          <div style={{ fontSize: '12px', fontFamily: 'monospace' }}>
            {simulationLogs.map((log, idx) => (
              <div key={idx} style={{ 
                marginBottom: '5px',
                color: log.type === 'error' ? '#c62828' : log.type === 'success' ? '#4caf50' : '#333'
              }}>
                <span style={{ color: '#666' }}>[{log.timestamp}]</span> {log.message}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Info Section */}
      <div style={{ marginTop: '20px', padding: '15px', backgroundColor: '#f5f5f5', borderRadius: '4px', fontSize: '14px' }}>
        <h4 style={{ marginBottom: '10px' }}>How it works:</h4>
        <ul style={{ paddingLeft: '20px' }}>
          <li>When APY &gt; 4% and volume &lt; 2%, 50% of swap fees are routed to Morpho</li>
          <li>Dynamic fee tier (0.5%) is applied when yield routing is active</li>
          <li>Base fee tier (0.3%) is used when conditions are not met</li>
          <li>Yield is automatically compounded back to the pool</li>
          <li>EigenLayer AVS Oracle provides secure APY data</li>
        </ul>
      </div>
    </div>
  )
}

export default SwapDemo
