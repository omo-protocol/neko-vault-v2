# Universal Adapter System - Comprehensive Documentation

## Table of Contents
1. [System Architecture Overview](#system-architecture-overview)
2. [Core Components](#core-components)

## System Architecture Overview

The Universal Adapter System is a sophisticated multi-strategy integration framework for Morpho Vault V2 that enables secure and flexible allocation to various DeFi strategies through a unified interface.

```
┌─────────────────┐
│   VaultV2       │ <── User deposits/withdrawals
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ UniversalAdapter│ <── Unified adapter + escrow
│    Escrow       │ ←─┐ (Combined functionality)
│                 │   │ realAssets() via getValue(ESCROW_TOTAL_ID)
│ • O(1) Gas Opt  │   │
│ • Smart Balance │   │
│ • Security Audit│   │
│ • Whitelist Ctrl│   │
└────┬───────┬────┘   │
     │       │         │
     ▼       ▼         │
┌────────┐ ┌────────┐  │
│Strategy│ │Strategy│  │
│   A    │ │   B    │  │ <── Individual DeFi strategies
└────────┘ └────────┘  │     (PT-kHYPE, vNeko, etc.)
                        │
      ┌─────────────────┘
      │
      ▼
┌──────────────────────┐
│ UniversalValuer      │ <── Off-chain valuation system
│    Offchain          │     with signature verification
│                      │ ←── Off-Chain Keeper Service
└──────────────────────┘     (Python/Node.js)
```

## Core Components

### 1. UniversalAdapterEscrow (`src/adapters/UniversalAdapterEscrow.sol`)

**Purpose**: Unified adapter that merges UniversalEscrowAdapter and StrategyEscrow functionality into a single contract, simplifying architecture and improving security.

**Key Features**:
- Implements IAdapter interface for vault compatibility
- **Unified Architecture**: Combines adapter and escrow logic in single contract
- **Gas Optimizations**: O(1) totalAllocations tracking instead of O(n) loops
- **Smart Balance Management**: Efficient three-scenario deallocate logic
- **Security Audited**: Implements auditor-recommended deallocate patterns
- **Whitelist-Based Execution**: Secure multicall with function whitelisting
- **Emergency Controls**: Pause functionality and owner-based access control
- **Standard Token Support**: Optimized for standard ERC20 tokens only

**Core Functions**:
```solidity
// Allocate funds to a strategy with optional immediate execution
function allocate(bytes memory data, uint256 assets, bytes4, address)
    returns (bytes32[] memory ids, int256 change)

// Deallocate funds with smart three-scenario balance handling
function deallocate(bytes memory data, uint256 assets, bytes4, address)
    returns (bytes32[] memory ids, int256 change)

// Get total value via getValue(ESCROW_TOTAL_ID) - pre-computed total from keeper
function realAssets() returns (uint256)

// Strategy management
function setStrategy(bytes32 strategyId, address agent, bytes calldata preConfiguredData, uint256 dailyLimit)
function removeStrategy(bytes32 strategyId)

// Multicall execution with whitelist validation
function executeStrategy(bytes32 strategyId, Call[] calldata calls)
function executePreConfigured(bytes32 strategyId)

// Whitelist and access control
function updateWhitelist(address target, bytes4 selector, bool allowed, uint256 limit)
function setPaused(bool _paused)
function transferOwnership(address newOwner)
```

**Data Format for Allocation/Deallocation**:
```solidity
(bytes32 strategyId, uint256 amount, bool executeNow, Call[] memory calls) = abi.decode(
    data,
    (bytes32, uint256, bool, Call[])
);

struct Call {
    address target;    // Contract to call
    bytes data;       // Function calldata
    uint256 value;    // ETH to send (if any)
}
```

### 🧮 Yield Accounting Model

**Solution**: Valuer-Based Synchronization with exact balance tracking.

**Why This Solution**:
- **Protocol Agnostic**: No protocol-specific integration needed in adapter
- **Future Proof**: Adding new protocols only requires keeper configuration
- **Leverages Existing**: Uses existing `UniversalValuerOffchain` infrastructure
- **Exact Tracking**: Keeper uses `balanceOf()` and `convertToAssets()` for precise values

**Accounting Model**:

`externalDeposits[strategyId]` now represents **total value** (principal + yield), not just principal.

The synchronization happens after every withdrawal via `_syncExternalDepositsWithValuer()`:

**Architecture**:
```
┌─────────────────────────┐
│   Off-Chain Keeper      │
│  (Python Service)       │
├─────────────────────────┤
│ • Calculate values      │
│ • Monitor thresholds    │
│ • Sign reports          │
└───────────┬─────────────┘
            │ Signed Reports
            ▼
┌─────────────────────────┐
│ UniversalValuerOffchain │
├─────────────────────────┤
│ • Verify signatures     │
│ • Store values          │
│ • Manage staleness      │
│ • Emergency fallbacks   │
└─────────────────────────┘
```

**Key Features**:
- **Hybrid Push/Pull Model**: Updates on-demand or when thresholds exceeded
- **Multi-Signature Support**: Configurable signer weights for security
- **Confidence Scoring**: Each value has confidence score (0-100)
- **Emergency Mode**: Owner can force updates in emergencies
- **Fallback Values**: Backup values if oracle fails

**Value Report Structure**:
```solidity
struct ValueReport {
    uint256 value;        // Strategy value in base asset
    uint256 timestamp;    // When calculated
    uint256 confidence;   // 0-100 confidence score
    uint256 nonce;        // Replay protection
    bool isPush;          // Push vs pull update
    address lastUpdater;  // Who submitted
}
```

**Update Mechanisms**:
1. **Pull Model**: Anyone can request update via `requestUpdate(strategyId)`
2. **Push Model**: Keeper pushes when value change exceeds threshold
3. **Scheduled**: Automatic updates before staleness limit

**Off-Chain Keeper Service**
- Monitors on-chain events for update requests
- Calculates strategy values using DeFi protocol APIs
- Signs values with authorized private key
- Submits signed reports to chain
- Handles batch updates for gas efficiency

**Deployment Steps**:
1. Deploy `UniversalValuerOffchain`
2. Configure authorized signers with appropriate weights
3. Start off-chain keeper service
4. Deploy adapter with `useOffchainValuer = true`
5. Configure strategy parameters and update thresholds

**Benefits**:
- Significantly reduced audit costs (~$20K one-time vs ~$50K per strategy)
- Minimal gas costs for valuation updates
- Flexible off-chain computation for complex strategies
- Cryptographic security through signature verification
