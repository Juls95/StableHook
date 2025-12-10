import { useState, useEffect } from 'react'
import { useAccount, useWriteContract, useReadContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther, formatEther } from 'viem'

// Contract addresses (update these with your deployed addresses)
const POOL_MANAGER_ADDRESS = '0x0000000000000000000000000000000000000000' // Update with actual address
const HOOK_ADDRESS = '0x0000000000000000000000000000000000000000' // Update with actual address
const AVS_ORACLE_ADDRESS = '0x0000000000000000000000000000000000000000' // Update with actual address

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
]

function SwapDemo() {
  const { address, isConnected, connector } = useAccount()
  const [amount, setAmount] = useState('')
  const [zeroForOne, setZeroForOne] = useState(true) // true = token0 -> token1
  const [mockAPY, setMockAPY] = useState(5.0) // Mock APY in percentage

  // Read current APY from oracle (if available)
  const { data: apyData } = useReadContract({
    address: AVS_ORACLE_ADDRESS !== '0x0000000000000000000000000000000000000000' ? AVS_ORACLE_ADDRESS : undefined,
    abi: AVS_ORACLE_ABI,
    functionName: 'getAPY',
    query: {
      enabled: AVS_ORACLE_ADDRESS !== '0x0000000000000000000000000000000000000000',
    },
  })

  // Update mock APY if oracle data is available
  useEffect(() => {
    if (apyData) {
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

  const handleSwap = async () => {
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

  return (
    <div style={{ 
      border: '1px solid #ddd', 
      borderRadius: '8px', 
      padding: '20px',
      backgroundColor: 'white',
      boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
    }}>
      {/* Connection Status */}
      <div style={{ marginBottom: '20px', padding: '10px', backgroundColor: '#f0f0f0', borderRadius: '4px' }}>
        <p><strong>Wallet:</strong> {isConnected ? address : 'Not Connected'}</p>
        {isConnected && connector && (
          <p><strong>Connector:</strong> {connector.name}</p>
        )}
      </div>

      {/* APY Display */}
      <div style={{ marginBottom: '20px', padding: '15px', backgroundColor: '#e8f5e9', borderRadius: '4px' }}>
        <h3 style={{ marginBottom: '10px' }}>Current APY Status</h3>
        <p style={{ fontSize: '24px', fontWeight: 'bold', color: mockAPY > 4 ? '#4caf50' : '#ff9800' }}>
          Mock APY: {formatAPY(mockAPY)}%
        </p>
        <p><strong>Fee Tier:</strong> {getFeeTier()}</p>
        <p><strong>Yield Routing:</strong> {getYieldRoutingStatus()}</p>
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
            disabled={!isConnected}
          />
        </div>

        {/* Swap Button */}
        <button
          onClick={handleSwap}
          disabled={!isConnected || !amount || isPending || isConfirming}
          style={{
            width: '100%',
            padding: '12px',
            fontSize: '16px',
            fontWeight: 'bold',
            backgroundColor: isConnected && amount && !isPending && !isConfirming ? '#4caf50' : '#ccc',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: isConnected && amount && !isPending && !isConfirming ? 'pointer' : 'not-allowed',
          }}
        >
          {isPending ? 'Confirming...' : isConfirming ? 'Processing...' : 'Swap & Route Yield'}
        </button>

        {/* Transaction Status */}
        {hash && (
          <div style={{ marginTop: '15px', padding: '10px', backgroundColor: '#e3f2fd', borderRadius: '4px' }}>
            <p><strong>Transaction Hash:</strong></p>
            <p style={{ fontSize: '12px', wordBreak: 'break-all' }}>{hash}</p>
            {isConfirmed && (
              <p style={{ color: '#4caf50', marginTop: '5px' }}>✓ Transaction confirmed!</p>
            )}
          </div>
        )}

        {/* Error Display */}
        {writeError && (
          <div style={{ marginTop: '15px', padding: '10px', backgroundColor: '#ffebee', borderRadius: '4px', color: '#c62828' }}>
            <p><strong>Error:</strong> {writeError.message}</p>
          </div>
        )}
      </div>

      {/* Info Section */}
      <div style={{ marginTop: '20px', padding: '15px', backgroundColor: '#f5f5f5', borderRadius: '4px', fontSize: '14px' }}>
        <h4 style={{ marginBottom: '10px' }}>How it works:</h4>
        <ul style={{ paddingLeft: '20px' }}>
          <li>When APY &gt; 4% and volume &lt; 2%, 50% of swap fees are routed to Morpho</li>
          <li>Dynamic fee tier (0.5%) is applied when yield routing is active</li>
          <li>Base fee tier (0.3%) is used when conditions are not met</li>
          <li>Yield is automatically compounded back to the pool</li>
        </ul>
      </div>
    </div>
  )
}

export default SwapDemo

