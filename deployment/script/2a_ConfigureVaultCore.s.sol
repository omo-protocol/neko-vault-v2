// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../../src/VaultV2.sol";
import "../../src/UniversalAdapterEscrow.sol";
import {IVaultV2} from "../../src/interfaces/IVaultV2.sol";

/**
 * @title ConfigureVaultCore
 * @notice Core vault configuration - adapter and allocator (Step 2a)
 * @dev Run AFTER 1_DeployVault_Adapter.s.sol
 *      Run 2b_ConfigureCaps.s.sol next
 *
 * Required Environment Variables:
 *   - PRIVATE_KEY: Deployer/curator private key
 *   - VAULT_ADDRESS: Address of deployed VaultV2
 *   - ADAPTER_ADDRESS: Address of deployed UniversalAdapterEscrow
 *   - ALLOCATOR_ADDRESS: Address to grant allocator role
 *
 * Usage:
 *   source .env && forge script deployment/script/2a_ConfigureVaultCore.s.sol \
 *     --rpc-url $RPC_URL --broadcast -v
 *
 * Transactions: 4 (submit + execute for adapter, submit + execute for allocator)
 */
contract ConfigureVaultCore is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load required addresses from environment
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address adapterAddress = vm.envAddress("ADAPTER_ADDRESS");
        address allocator = vm.envAddress("ALLOCATOR_ADDRESS");

        VaultV2 vault = VaultV2(vaultAddress);
        UniversalAdapterEscrow adapter = UniversalAdapterEscrow(payable(adapterAddress));

        console.log("\n=================================================");
        console.log("    VAULT CORE CONFIGURATION (Step 2a)");
        console.log("=================================================");
        console.log("Deployer:", deployer);
        console.log("VaultV2:", vaultAddress);
        console.log("Adapter:", adapterAddress);
        console.log("Allocator:", allocator);
        console.log("Transactions: 4");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Add adapter (2 transactions)
        console.log("\n[Step 1/2] Adding adapter...");
        vault.submit(abi.encodeCall(IVaultV2.addAdapter, (address(adapter))));
        vault.addAdapter(address(adapter));
        console.log("  Adapter added successfully");

        // Step 2: Set allocator (2 transactions)
        console.log("\n[Step 2/2] Setting allocator...");
        vault.submit(abi.encodeCall(IVaultV2.setIsAllocator, (allocator, true)));
        vault.setIsAllocator(allocator, true);
        console.log("  Allocator set:", allocator);

        vm.stopBroadcast();

        console.log("\n=================================================");
        console.log("    STEP 2a COMPLETE!");
        console.log("=================================================");
        console.log("Configuration:");
        console.log("  Adapter:", address(adapter));
        console.log("  Allocator:", allocator);
        console.log("\nNext Step:");
        console.log("  Run: forge script deployment/script/2b_ConfigureCaps.s.sol --rpc-url $RPC_URL --broadcast -v");
    }
}
