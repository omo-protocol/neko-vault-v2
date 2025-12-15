# Neko Vault V2

A non-custodial, ERC-4626 compliant vault system for multi-protocol DeFi allocation.

---

## Overview

| Attribute | Details |
|-----------|---------|
| Standard | ERC-4626 + ERC-2612 |
| Architecture | Immutable (no upgrades) |
| Security | 5 independent audits, 121+ tests |
| Chain | HyperEVM (Chain ID: 999) |

---

## Contracts to Review

| Contract | Purpose | Priority |
|----------|---------|----------|
| [VaultV2.sol](./src/VaultV2.sol) | Main vault: deposits, withdrawals, roles, timelocks, fees | Critical |
| [UniversalAdapterEscrow.sol](./src/UniversalAdapterEscrow.sol) | Strategy execution: allocation, whitelist multicall | Critical |
| [UniversalValuerOffchain.sol](./src/UniversalValuerOffchain.sol) | Valuation oracle: multi-sig price updates | Critical |
| [VaultV2Factory.sol](./src/VaultV2Factory.sol) | Vault deployment | Low |

---

## Trust Model

### Roles

| Role | Capability | Risk Level |
|------|------------|------------|
| **Owner** | Sets curator and sentinels | High (centralized) |
| **Curator** | All configuration (timelocked) | High (mitigated by timelock) |
| **Allocator(s)** | Move funds within caps | Medium |
| **Sentinel(s)** | Emergency derisk only | Low |

### External Dependencies

| Component | Trust Assumption |
|-----------|------------------|
| Off-chain Keeper | Must provide accurate valuations |
| Signers | Must secure private keys (95% threshold) |
| Adapters | Must implement IAdapter correctly |

---

## Non-Custodial Guarantees

1. **In-kind redemptions** - `forceDeallocate()` enables exit regardless of allocator state (0-2% penalty)
2. **Timelocked configuration** - Users can exit before changes take effect
3. **Immutable contracts** - No upgrade risk

---

## Security Audits

| Module | Auditor | Location |
|--------|---------|----------|
| Vault V2 | Chainsecurity, Blackthorn, Zellic | [audits/morpho-vault-v2/](./audits/morpho-vault-v2/) |
| Universal Adapter | SBSecurity, Octane | [audits/universal-adapter/](./audits/universal-adapter/) |

---

## Documentation

| Document | Description |
|----------|-------------|
| [VAULT_V2_ARCHITECTURE.md](./docs/VAULT_V2_ARCHITECTURE.md) | Complete technical specification |
| [UNIVERSAL_ADAPTER.md](./docs/UNIVERSAL_ADAPTER.md) | Adapter system documentation |
| [UNIVERSAL_VALUER_OFFCHAIN.md](./docs/UNIVERSAL_VALUER_OFFCHAIN.md) | Valuation oracle specification |
| [PPS_CALCULATION.md](./docs/PPS_CALCULATION.md) | Price per share calculation |
