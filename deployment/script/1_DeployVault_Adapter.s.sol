// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../../src/VaultV2.sol";
import "../../src/VaultV2Factory.sol";
import "../../src/UniversalAdapterEscrow.sol";
import "../../src/UniversalAdapterEscrowFactory.sol";
import "../../src/UniversalValuerOffchain.sol";
import {IVaultV2} from "../../src/interfaces/IVaultV2.sol";
import {IUniversalAdapterEscrow} from "../../src/interfaces/IUniversalAdapterEscrow.sol";

/**
 * @title DeployVaultAdapter
 * @notice Production deployment script for VaultV2 with UniversalAdapterEscrow
 * @dev Deploys vault and adapter using pre-deployed factories
 *
 * Required Environment Variables:
 *   - PRIVATE_KEY: Deployer private key
 *   - ASSET_ADDRESS: ERC20 asset address for the vault
 *   - VAULT_FACTORY_ADDRESS: Address of deployed VaultV2Factory
 *   - ADAPTER_FACTORY_ADDRESS: Address of deployed UniversalAdapterEscrowFactory
 *   - VALUER_ADDRESS: Address of deployed UniversalValuerOffchain
 *
 * Optional Environment Variables:
 *   - STRATEGY_NAME: Strategy identifier for salt generation (default: "default-strategy")
 *
 * Usage:
 *   source .env && forge script deployment/script/1_DeployVault_Adapter.s.sol \
 *     --rpc-url $RPC_URL --broadcast -v
 */
contract DeployPTLoopVault is Script {
    function run() public {
        // Load private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load required addresses from environment
        address asset = vm.envAddress("ASSET_ADDRESS");
        address vaultFactoryAddress = vm.envAddress("VAULT_FACTORY_ADDRESS");
        address adapterFactoryAddress = vm.envAddress("ADAPTER_FACTORY_ADDRESS");
        address valuerAddress = vm.envAddress("VALUER_ADDRESS");

        // Load optional strategy name (default: "default-strategy")
        string memory strategyName = vm.envOr("STRATEGY_NAME", string("default-strategy"));
        bytes32 STRATEGY_ID = keccak256(bytes(strategyName));

        console.log("\n=================================================");
        console.log("    VAULT & ADAPTER DEPLOYMENT");
        console.log("=================================================");
        console.log("Deployer:", deployer);
        console.log("Asset:", asset);
        console.log("Vault Factory:", vaultFactoryAddress);
        console.log("Adapter Factory:", adapterFactoryAddress);
        console.log("Valuer:", valuerAddress);
        console.log("Strategy Name:", strategyName);

        // Create deterministic salt
        bytes32 salt = keccak256(abi.encodePacked(
            "vault-v2",
            STRATEGY_ID,
            deployer,
            asset
        ));

        vm.startBroadcast(deployerPrivateKey);

        // Load infrastructure contracts
        VaultV2Factory vaultFactory = VaultV2Factory(vaultFactoryAddress);
        UniversalAdapterEscrowFactory adapterFactory = UniversalAdapterEscrowFactory(adapterFactoryAddress);

        // Step 1: Deploy VaultV2
        console.log("\n[Step 1] Deploying VaultV2...");
        address vaultAddress = vaultFactory.createVaultV2(deployer, asset, salt);
        VaultV2 vault = VaultV2(vaultAddress);
        console.log("  VaultV2:", vaultAddress);

        // Step 2: Deploy UniversalAdapterEscrow
        console.log("\n[Step 2] Deploying UniversalAdapterEscrow...");
        address adapterAddress = adapterFactory.deployAdapter(
            address(vault),
            valuerAddress,
            false, // useOffchainValuer
            salt
        );
        UniversalAdapterEscrow adapter = UniversalAdapterEscrow(payable(adapterAddress));
        console.log("  Adapter:", adapterAddress);

        // Step 3: Set curator (required for configuration)
        console.log("\n[Step 3] Setting curator...");
        vault.setCurator(deployer);
        console.log("  Curator set:", deployer);

        vm.stopBroadcast();

        // Final status
        console.log("\n=================================================");
        console.log("    VAULT DEPLOYMENT COMPLETE!");
        console.log("=================================================");
        console.log("\nDeployed Contracts:");
        console.log("  VaultV2:", address(vault));
        console.log("  UniversalAdapterEscrow:", address(adapter));
    }
}