# VaultV2 Architecture - Technical Specification

> ERC-4626 vault with adapter allocation
> Location: `src/VaultV2.sol`

## Table of Contents

- [Overview](#overview)
- [Core Architecture](#core-architecture)
- [Access Control](#access-control)
- [Deposit/Withdraw Flows](#depositwithdraw-flows)
- [Allocation System](#allocation-system)
- [Fee Mechanisms](#fee-mechanisms)
- [Timelock Governance](#timelock-governance)
- [Security Properties](#security-properties)

---

## Overview

VaultV2 is an advanced ERC-4626 compliant vault that:
- Manages multi-adapter asset allocations
- Implements timelocked governance for security
- Supports cross-chain operations via LayerZero
- Enforces caps (absolute and relative) on allocations
- Provides gate-based access control

### Key Characteristics

- **Standard**: ERC-4626 + ERC-2612 (Permit)
- **Decimals**: Asset decimals + offset (configurable)
- **Virtual Shares**: Inflation attack protection
- **Non-conventional max functions**: Always return 0 (gate unpredictability)

---

## Core Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              USER LAYER                                  │
├─────────────────────────────────────────────────────────────────────────┤
│  deposit() / withdraw() / redeem() / mint()                             │
│  transfer() / transferFrom() (gated)                                    │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────────────┐
│                             VaultV2                                      │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   GATES     │  │   ROLES     │  │   CAPS      │  │   FEES      │    │
│  ├─────────────┤  ├─────────────┤  ├─────────────┤  ├─────────────┤    │
│  │receiveShares│  │ Owner       │  │ Absolute    │  │ Performance │    │
│  │sendShares   │  │ Curator     │  │ Relative    │  │ Management  │    │
│  │receiveAssets│  │ Allocator   │  │ (per ID)    │  │ (accrued)   │    │
│  │sendAssets   │  │ Sentinel    │  │             │  │             │    │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │                    ADAPTER MANAGEMENT                           │     │
│  │  allocate() / deallocate() / forceDeallocate()                  │     │
│  │  isAdapter[] / adapters[] / liquidityAdapter                    │     │
│  └──────────────────────────────┬─────────────────────────────────┘     │
└─────────────────────────────────┼───────────────────────────────────────┘
                                  │
                                  |
                                  ▼
                        ┌───────────────┐ 
                        |     Adapter   |
                        |    (Escrow)   |
                        └───────────────┘     
```

### State Variables

#### Immutables

```solidity
address public immutable asset;           // Underlying token
uint8 public immutable decimals;          // Share decimals
uint256 public immutable virtualShares;   // Inflation protection
```

#### Roles

```solidity
address public owner;                      // Highest privilege
address public curator;                    // Timelocked operations
mapping(address => bool) public isAllocator;  // Allocation management
mapping(address => bool) public isSentinel;   // Emergency access
```

#### Gates

```solidity
address public receiveSharesGate;    // Who can receive shares
address public sendSharesGate;       // Who can send shares
address public receiveAssetsGate;    // Who can receive assets
address public sendAssetsGate;       // Who can deposit assets
address public adapterRegistry;      // Optional adapter whitelist
```

#### Allocation State

```solidity
mapping(address => bool) public isAdapter;
address[] public adapters;
address public liquidityAdapter;
bytes public liquidityData;
mapping(bytes32 => Caps) public caps;

struct Caps {
    uint256 allocation;      // Current allocation
    uint128 absoluteCap;     // Hard ceiling
    uint128 relativeCap;     // % of firstTotalAssets (WAD)
}
```

#### Fee State

```solidity
uint96 public performanceFee;            // Max 50%
address public performanceFeeRecipient;
uint96 public managementFee;             // Max 5% annually
address public managementFeeRecipient;
mapping(address => uint256) public forceDeallocatePenalty;  // Per adapter
```

#### Interest State

```solidity
uint256 private firstTotalAssets;  // Transient, flashloan protection
uint128 public _totalAssets;       // Last recorded value
uint64 public lastUpdate;          // Last accrual timestamp
uint64 public maxRate;             // Max interest rate/sec
```

---

## Access Control

### Role Hierarchy

```
Owner (Highest)
│
├── setCurator(address)
├── setIsSentinel(address, bool)
├── setOwner(address)
├── setName(string), setSymbol(string)
│
▼
Curator
│
├── submit(bytes) - Queue timelocked operations
├── revoke(bytes) - Cancel pending operations
├── [Timelocked] setIsAllocator, addAdapter, removeAdapter
├── [Timelocked] setGates, setFees, increaseCaps, setTimelock
├── [Immediate] decreaseCaps (security-sensitive)
│
▼
Allocator
│
├── allocate(adapter, data, assets)
├── deallocate(adapter, data, assets)
├── setLiquidityAdapterAndData(adapter, data)
├── setMaxRate(rate)
│
▼
Sentinel
│
├── revoke(bytes) - Cancel curator's pending ops
├── deallocate(adapter, data, assets) - Emergency
├── decreaseAbsoluteCap, decreaseRelativeCap - Emergency
```

### Gate System

Four independent gates control user permissions:

| Gate | Controls | Checked On |
|------|----------|------------|
| `receiveSharesGate` | Who receives shares | deposit, mint, transfer |
| `sendSharesGate` | Who sends shares | withdraw, redeem, transfer |
| `receiveAssetsGate` | Who receives assets | withdraw, redeem |
| `sendAssetsGate` | Who deposits assets | deposit, mint |

**Gate Interface**:
```solidity
interface IGate {
    function canReceiveShares(address account) external view returns (bool);
    function canSendShares(address account) external view returns (bool);
    function canReceiveAssets(address account) external view returns (bool);
    function canSendAssets(address account) external view returns (bool);
}
```

**Special Cases**:
- `address(0)` gate = no restriction
- `address(this)` always passes receiveAssetsGate

---

## Deposit/Withdraw Flows

### Deposit Flow

```
User calls: deposit(assets, onBehalf)
    │
    ├── 1. accrueInterest()
    │       └── Updates _totalAssets, mints fee shares
    │
    ├── 2. Gate Checks
    │       ├── canReceiveShares(onBehalf) ✓
    │       └── canSendAssets(msg.sender) ✓
    │
    ├── 3. Transfer assets from user
    │       └── asset.transferFrom(msg.sender, address(this), assets)
    │
    ├── 4. Calculate shares
    │       └── shares = previewDeposit(assets)
    │
    ├── 5. Mint shares to onBehalf
    │       └── balanceOf[onBehalf] += shares
    │       └── totalSupply += shares
    │
    ├── 6. Update _totalAssets
    │       └── _totalAssets += assets
    │
    └── 7. Optional: Allocate to liquidity adapter
            └── allocateInternal(liquidityAdapter, liquidityData, assets)
```

### Withdraw Flow

```
User calls: withdraw(assets, receiver, onBehalf)
    │
    ├── 1. accrueInterest()
    │
    ├── 2. Calculate shares
    │       └── shares = previewWithdraw(assets)
    │
    ├── 3. Check idle balance
    │       └── idle = asset.balanceOf(address(this))
    │
    ├── 4. If assets > idle:
    │       └── deallocateInternal(liquidityAdapter, assets - idle)
    │
    ├── 5. Gate Checks
    │       ├── canSendShares(onBehalf) ✓
    │       └── canReceiveAssets(receiver) ✓
    │
    ├── 6. Check allowance (if msg.sender != onBehalf)
    │
    ├── 7. Burn shares from onBehalf
    │       └── balanceOf[onBehalf] -= shares
    │       └── totalSupply -= shares
    │
    ├── 8. Update _totalAssets
    │       └── _totalAssets -= assets
    │
    └── 9. Transfer assets to receiver
            └── asset.transfer(receiver, assets)
```

### Force Deallocate (Emergency)

```
User calls: forceDeallocate(adapter, data, assets, onBehalf)
    │
    ├── 1. deallocateInternal(adapter, data, assets)
    │       └── Moves assets from adapter to vault
    │
    ├── 2. Calculate penalty
    │       └── penaltyAssets = assets × forceDeallocatePenalty[adapter] / WAD
    │
    └── 3. Burn penalty shares from onBehalf
            └── withdraw(penaltyAssets, address(this), onBehalf)
```

**Purpose**: Allows users to exit even if strategy is illiquid, at cost of penalty (0-2%).

---

## Allocation System

### Allocate Flow

```
Allocator calls: allocate(adapter, data, assets)
    │
    ├── 1. Verify isAllocator[msg.sender]
    │
    ├── 2. accrueInterest() → Sets firstTotalAssets
    │
    ├── 3. Transfer assets to adapter
    │       └── asset.transfer(adapter, assets)
    │
    ├── 4. Call adapter.allocate(data, assets, selector, sender)
    │       └── Returns: ids[], change
    │
    └── 5. For each id in ids[]:
            │
            ├── Update: caps[id].allocation += change
            │
            ├── Verify: absoluteCap > 0 (must be set)
            │
            ├── Verify: allocation <= absoluteCap
            │
            └── Verify: allocation <= firstTotalAssets × relativeCap / WAD
```

### Cap System

**Absolute Cap**: Hard ceiling on allocation per ID.
```
allocation[id] ≤ absoluteCap[id]
```

**Relative Cap**: Soft limit as % of vault value.
```
allocation[id] ≤ firstTotalAssets × relativeCap[id] / WAD
```

**Why firstTotalAssets?**
- Prevents flashloan manipulation
- Set at first interaction in transaction
- Subsequent operations in same tx use same base

### Deallocate Flow

```
Allocator/Sentinel calls: deallocate(adapter, data, assets)
    │
    ├── 1. Verify isAllocator[msg.sender] || isSentinel[msg.sender]
    │
    ├── 2. Call adapter.deallocate(data, assets, selector, sender)
    │       └── Returns: ids[], change (typically negative)
    │
    ├── 3. For each id in ids[]:
    │       │
    │       ├── Verify: allocation > 0
    │       │
    │       └── Update: caps[id].allocation += change
    │
    └── 4. Transfer assets from adapter to vault
```

---

## Fee Mechanisms

### Performance Fee

**Parameters**:
- Max: 50% (0.5e18)
- Applied on: Positive interest only
- Recipient: `performanceFeeRecipient`

**Calculation**:
```
interest = max(realAssets, _totalAssets + maxRate×elapsed) - _totalAssets
performanceFeeAssets = interest × performanceFee / WAD
performanceFeeShares = performanceFeeAssets × (totalSupply + virtualShares) / newTotalAssets
```

### Management Fee

**Parameters**:
- Max: 5% annually (0.05e18 / 365 days)
- Applied on: Total assets continuously
- Recipient: `managementFeeRecipient`

**Calculation**:
```
managementFeeAssets = (newTotalAssets × elapsed) × managementFee / WAD
managementFeeShares = managementFeeAssets × (totalSupply + virtualShares) / newTotalAssets
```

### Interest Accrual

```solidity
function accrueInterest() public {
    if (firstTotalAssets != 0) return; // Already accrued this tx

    uint256 newTotalAssets = _totalAssets + realAssets();
    uint256 elapsed = block.timestamp - lastUpdate;

    // Cap interest at maxRate
    uint256 maxInterest = _totalAssets * elapsed * maxRate / WAD;
    newTotalAssets = min(newTotalAssets, _totalAssets + maxInterest);

    // Calculate and mint fee shares
    // ...

    firstTotalAssets = newTotalAssets;
    _totalAssets = newTotalAssets;
    lastUpdate = block.timestamp;
}
```

---

## Timelock Governance

### Mechanism

1. Curator submits operation: `submit(bytes data)`
2. System calculates: `executableAt = block.timestamp + timelock[selector]`
3. After delay: Anyone can execute the pending operation
4. Cancel: Curator or sentinel calls `revoke(bytes data)`

### Timelocked Operations

| Function | Who Can Submit | Who Can Revoke |
|----------|----------------|----------------|
| `setIsAllocator` | Curator | Curator, Sentinel |
| `addAdapter` | Curator | Curator, Sentinel |
| `removeAdapter` | Curator | Curator, Sentinel |
| `setReceiveSharesGate` | Curator | Curator, Sentinel |
| `increaseAbsoluteCap` | Curator | Curator, Sentinel |
| `increaseRelativeCap` | Curator | Curator, Sentinel |
| `setPerformanceFee` | Curator | Curator, Sentinel |
| `increaseTimelock` | Curator | Curator, Sentinel |

### Immediate Operations

| Function | Who Can Execute |
|----------|-----------------|
| `decreaseAbsoluteCap` | Curator, Sentinel |
| `decreaseRelativeCap` | Curator, Sentinel |
| `deallocate` | Allocator, Sentinel |

### Abdication

```solidity
function abdicate(bytes4 selector) external onlyTimelocked {
    abdicated[selector] = true;
}
```

Once abdicated, a function can never be called again (even with timelock).

---

## Security Properties

### Critical Invariants

1. **Share Price Consistency**
   ```
   totalAssets() / totalSupply() is monotonically non-decreasing
   (except for realized losses in adapters)
   ```

2. **Cap Enforcement**
   ```
   ∀ id: allocation[id] ≤ absoluteCap[id]
   ∀ id: allocation[id] ≤ firstTotalAssets × relativeCap[id] / WAD
   ```

3. **Cross-Chain Supply Integrity**
   ```
   VaultV2.totalSupply() = ShareOFTAdapter.locked + circulating on hub
   Sum of all ShareOFT across spokes = ShareOFTAdapter.locked
   ```

4. **Interest Accrual Once**
   ```
   firstTotalAssets set at first interaction per transaction
   Prevents flashloan-based share price manipulation
   ```

### Virtual Shares Protection

```solidity
virtualShares = 10 ** max(0, 18 - assetDecimals)
```

Protects against ERC-4626 inflation attacks on first deposit.

### Token Requirements

**Supported**:
- Standard ERC-20 (return values optional)
- Decrease balance exactly by transfer amount
- No reentrancy on transfer

**Not Supported**:
- Fee-on-transfer tokens
- Rebasing tokens
- Tokens with callbacks
