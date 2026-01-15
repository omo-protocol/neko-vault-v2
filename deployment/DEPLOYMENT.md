# Neko Vault V2 - Deployment Guide

This guide covers the complete deployment process for Neko Vault V2 on HyperEVM and Mantle networks.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Network Configuration](#network-configuration)
3. [Environment Setup](#environment-setup)
4. [Deployment Flow](#deployment-flow)
5. [Script Reference](#script-reference)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- **Foundry** installed (`curl -L https://foundry.paradigm.xyz | bash && foundryup`)
- **Private key** with sufficient native tokens for gas
- **Node.js** (optional, for off-chain keeper)

## Network Configuration

Pre-configured networks in `foundry.toml`:

| Network | Chain ID | RPC URL | Explorer |
|---------|----------|---------|----------|
| HyperEVM | 999 | `https://rpc.hyperliquid.xyz/evm` | `https://api.hyperliquid.xyz/evm/explorer` |
| Mantle | 5000 | `https://rpc.mantle.xyz` | `https://api.mantlescan.xyz` |

### HyperEVM Special Requirements

HyperEVM requires enabling "Big Block" feature for contracts >2M gas:
1. Visit https://hyperevm-block-toggle.vercel.app/
2. Connect wallet and enable Big Block for your deployer address

---

## Environment Setup

### 1. Copy environment template

```bash
cp deployment/.env.example .env
```

### 2. Edit `.env` with your values

```bash
# Required for all deployments
PRIVATE_KEY=0x...
ASSET_ADDRESS=0x...           # ERC20 asset (e.g., WMNT, USDT)
KEEPER_ADDRESS=0x...          # Keeper for automated valuation
ALLOCATOR_ADDRESS=0x...       # Address to grant allocator role

# Optional configuration
STRATEGY_NAME=my-strategy     # Unique identifier for your strategy
```

### 3. Load environment

```bash
source .env
```

---

## Deployment Flow

### Overview

```
Step 0a: Deploy Factories (once per network)
    └── VaultV2Factory
    └── UniversalAdapterEscrowFactory

Step 0b: Deploy Valuer
    └── UniversalValuerOffchain

Step 1: Deploy Vault & Adapter
    └── VaultV2
    └── UniversalAdapterEscrow

Step 2a: Configure Vault Core
    └── Add adapter to vault
    └── Set allocator

Step 2b: Configure Caps
    └── Set absolute cap (MAX)
    └── Set relative cap (100%)

Step 2c: Configure Fees (optional)
    └── Set fee recipient
    └── Set performance fee

Step 2d: Configure Adapter
    └── Set strategy

Step 2f: Configure Whitelists (Mantle only)
    └── Whitelist protocol functions
```

---

### Step 0a: Deploy Factories

**Only needed once per network.** If factories already exist, skip to Step 0b.

```bash
forge script deployment/script/0a_DeployFactory.s.sol \
  --rpc-url hyperevm \
  --broadcast \
  -v
```

**Output:** Save the deployed addresses:
- `VAULT_FACTORY_ADDRESS`
- `ADAPTER_FACTORY_ADDRESS`

---

### Step 0b: Deploy Valuer

```bash
# Set required env vars
export ASSET_ADDRESS=0x...
export KEEPER_ADDRESS=0x...
export STRATEGY_NAME=my-strategy

forge script deployment/script/0b_DeployValuer.s.sol \
  --rpc-url hyperevm \
  --broadcast \
  -v
```

**Output:** Save `VALUER_ADDRESS`

---

### Step 1: Deploy Vault & Adapter

```bash
# Set required env vars (from Step 0a and 0b)
export VAULT_FACTORY_ADDRESS=0x...
export ADAPTER_FACTORY_ADDRESS=0x...
export VALUER_ADDRESS=0x...
export ASSET_ADDRESS=0x...
export STRATEGY_NAME=my-strategy

forge script deployment/script/1_DeployVault_Adapter.s.sol \
  --rpc-url hyperevm \
  --broadcast \
  -v
```

**Output:** Save:
- `VAULT_ADDRESS`
- `ADAPTER_ADDRESS`

---

### Step 2a: Configure Vault Core

```bash
# Set required env vars (from Step 1)
export VAULT_ADDRESS=0x...
export ADAPTER_ADDRESS=0x...
export ALLOCATOR_ADDRESS=0x...

forge script deployment/script/2a_ConfigureVaultCore.s.sol \
  --rpc-url hyperevm \
  --broadcast \
  -v
```

---

### Step 2b: Configure Caps

```bash
# Set required env vars
export VAULT_ADDRESS=0x...
export STRATEGY_NAME=my-strategy
export RELATIVE_CAP=1000000000000000000  # Optional: 1e18 = 100%

forge script deployment/script/2b_ConfigureCaps.s.sol \
  --rpc-url hyperevm \
  --broadcast \
  -v
```

---

### Step 2c: Configure Fees (Optional)

Skip this step if you don't want to configure fees.

```bash
# Set required env vars
export VAULT_ADDRESS=0x...
export PERFORMANCE_FEE_RECIPIENT=0x...
export PERFORMANCE_FEE=200000000000000000  # Optional: 0.2e18 = 20%

forge script deployment/script/2c_ConfigureFees.s.sol \
  --rpc-url hyperevm \
  --broadcast \
  -v
```

---

### Step 2d: Configure Adapter

```bash
# Set required env vars
export ADAPTER_ADDRESS=0x...
export ALLOCATOR_ADDRESS=0x...
export STRATEGY_NAME=my-strategy

forge script deployment/script/2d_ConfigureAdapter.s.sol \
  --rpc-url hyperevm \
  --broadcast \
  -v
```

---

### Step 2f: Configure Mantle Whitelists (Mantle Only)

**Only for Mantle network deployments.**

```bash
# Set required env vars
export ADAPTER_ADDRESS=0x...
export COMPOUND_COMET_USDE=0x...  # Optional: if Compound V3 is available

forge script deployment/script/2f_ConfigureMantleSupplyOptimizerWhitelist.s.sol \
  --rpc-url mantle \
  --broadcast \
  -v
```

---

## Script Reference

| Script | Purpose | Required Env Vars |
|--------|---------|-------------------|
| `0a_DeployFactory.s.sol` | Deploy factories | `PRIVATE_KEY` |
| `0b_DeployValuer.s.sol` | Deploy valuer | `ASSET_ADDRESS`, `KEEPER_ADDRESS` |
| `1_DeployVault_Adapter.s.sol` | Deploy vault & adapter | `VAULT_FACTORY_ADDRESS`, `ADAPTER_FACTORY_ADDRESS`, `VALUER_ADDRESS`, `ASSET_ADDRESS` |
| `2a_ConfigureVaultCore.s.sol` | Add adapter, set allocator | `VAULT_ADDRESS`, `ADAPTER_ADDRESS`, `ALLOCATOR_ADDRESS` |
| `2b_ConfigureCaps.s.sol` | Configure caps | `VAULT_ADDRESS` |
| `2c_ConfigureFees.s.sol` | Configure fees | `VAULT_ADDRESS`, `PERFORMANCE_FEE_RECIPIENT` (optional) |
| `2d_ConfigureAdapter.s.sol` | Configure strategy | `ADAPTER_ADDRESS`, `ALLOCATOR_ADDRESS` |
| `2f_...Whitelist.s.sol` | Whitelist Mantle protocols | `ADAPTER_ADDRESS` |

---

## Verification

### Verify Contracts on Explorer

```bash
# Verify VaultV2
forge verify-contract <VAULT_ADDRESS> \
  src/VaultV2.sol:VaultV2 \
  --chain-id 999 \
  --num-of-optimizations 100000 \
  --constructor-args $(cast abi-encode 'constructor(address,address)' <OWNER> <ASSET>) \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version 0.8.28

# Verify UniversalAdapterEscrow
forge verify-contract <ADAPTER_ADDRESS> \
  src/UniversalAdapterEscrow.sol:UniversalAdapterEscrow \
  --chain-id 999 \
  --num-of-optimizations 100000 \
  --constructor-args $(cast abi-encode 'constructor(address,address,bool)' <VAULT> <VALUER> false) \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version 0.8.28
```

### Verify Configuration

```bash
# Check vault adapter
cast call $VAULT_ADDRESS "adapters(address)(bool)" $ADAPTER_ADDRESS --rpc-url hyperevm

# Check allocator
cast call $VAULT_ADDRESS "isAllocator(address)(bool)" $ALLOCATOR_ADDRESS --rpc-url hyperevm

# Check caps
STRATEGY_HASH=$(cast keccak "my-strategy")
cast call $VAULT_ADDRESS "caps(bytes32)(uint256,uint256)" $STRATEGY_HASH --rpc-url hyperevm
```

---

## Troubleshooting

### Common Issues

**"PRIVATE_KEY must be set"**
- Ensure `.env` is loaded: `source .env`
- Check variable is exported: `echo $PRIVATE_KEY`

**"Out of gas" on HyperEVM**
- Enable Big Block at https://hyperevm-block-toggle.vercel.app/

**"Adapter not in vault"**
- Run Step 2a before Steps 2b-2d
- Verify adapter address matches

**Transaction reverts with no error**
- Check timelock: configuration changes may require `submit()` + wait + `execute()`
- Verify you have curator role for vault configuration

### Dry Run (No Broadcast)

Test scripts without sending transactions:

```bash
forge script deployment/script/1_DeployVault_Adapter.s.sol \
  --rpc-url hyperevm \
  -vvvv
# Note: no --broadcast flag
```

### Debug Mode

Add verbosity for detailed traces:

```bash
forge script deployment/script/1_DeployVault_Adapter.s.sol \
  --rpc-url hyperevm \
  --broadcast \
  -vvvv
```

---

## Quick Start Example

Complete deployment on HyperEVM:

```bash
# 1. Setup
cp deployment/.env.example .env
# Edit .env with your values
source .env

# 2. Deploy factories (if not already deployed)
forge script deployment/script/0a_DeployFactory.s.sol --rpc-url hyperevm --broadcast -v

# 3. Deploy valuer
export ASSET_ADDRESS=0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111  # WMNT
export KEEPER_ADDRESS=0x...
export STRATEGY_NAME=my-vault-strategy
forge script deployment/script/0b_DeployValuer.s.sol --rpc-url hyperevm --broadcast -v

# 4. Deploy vault & adapter (update env vars with outputs from previous steps)
export VAULT_FACTORY_ADDRESS=0x...
export ADAPTER_FACTORY_ADDRESS=0x...
export VALUER_ADDRESS=0x...
forge script deployment/script/1_DeployVault_Adapter.s.sol --rpc-url hyperevm --broadcast -v

# 5. Configure vault (update env vars with outputs)
export VAULT_ADDRESS=0x...
export ADAPTER_ADDRESS=0x...
export ALLOCATOR_ADDRESS=0x...
forge script deployment/script/2a_ConfigureVaultCore.s.sol --rpc-url hyperevm --broadcast -v
forge script deployment/script/2b_ConfigureCaps.s.sol --rpc-url hyperevm --broadcast -v
forge script deployment/script/2d_ConfigureAdapter.s.sol --rpc-url hyperevm --broadcast -v

# Done! Vault is ready for deposits and allocations.
```
