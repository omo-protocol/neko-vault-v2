// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../../src/VaultV2.sol";
import {IVaultV2} from "../../src/interfaces/IVaultV2.sol";

/**
 * @title ConfigureFees
 * @notice Performance fee configuration (Step 2c)
 * @dev Run AFTER 2b_ConfigureCaps.s.sol
 *      Run 2d_ConfigureAdapter.s.sol next
 *
 * Required Environment Variables:
 *   - PRIVATE_KEY: Deployer/curator private key
 *   - VAULT_ADDRESS: Address of deployed VaultV2
 *
 * Optional Environment Variables:
 *   - PERFORMANCE_FEE_RECIPIENT: Address to receive performance fees (skip if not set)
 *   - PERFORMANCE_FEE: Performance fee in WAD (default: 0.2e18 = 20%)
 *
 * Usage:
 *   source .env && forge script deployment/script/2c_ConfigureFees.s.sol \
 *     --rpc-url $RPC_URL --broadcast -v
 *
 * Transactions: 4 (submit + execute for recipient, submit + execute for fee)
 *               or 0 if recipient not configured
 */
contract ConfigureFees is Script {
    uint256 constant DEFAULT_PERFORMANCE_FEE = 0.2e18; // 20%

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load required addresses from environment
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        // Load optional configuration
        address feeRecipient = vm.envOr("PERFORMANCE_FEE_RECIPIENT", address(0));
        uint256 performanceFee = vm.envOr("PERFORMANCE_FEE", DEFAULT_PERFORMANCE_FEE);

        VaultV2 vault = VaultV2(vaultAddress);

        console.log("\n=================================================");
        console.log("    FEE CONFIGURATION (Step 2c)");
        console.log("=================================================");
        console.log("Deployer:", deployer);
        console.log("VaultV2:", vaultAddress);

        if (feeRecipient == address(0)) {
            console.log("\nSkipping: Performance fee recipient not configured");
            console.log("\nNext Step:");
            console.log("  Run: forge script deployment/script/2d_ConfigureAdapter.s.sol --rpc-url $RPC_URL --broadcast -v");
            return;
        }

        console.log("Fee Recipient:", feeRecipient);
        console.log("Performance Fee:", performanceFee / 1e16, "%");
        console.log("Transactions: 4");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Set performance fee recipient (2 transactions)
        console.log("\n[Step 1/2] Setting performance fee recipient...");
        vault.submit(abi.encodeCall(IVaultV2.setPerformanceFeeRecipient, (feeRecipient)));
        vault.setPerformanceFeeRecipient(feeRecipient);
        console.log("  Recipient set:", feeRecipient);

        // Step 2: Set performance fee (2 transactions)
        console.log("\n[Step 2/2] Setting performance fee...");
        vault.submit(abi.encodeCall(IVaultV2.setPerformanceFee, (performanceFee)));
        vault.setPerformanceFee(performanceFee);
        console.log("  Fee set to:", performanceFee / 1e16, "%");

        vm.stopBroadcast();

        console.log("\n=================================================");
        console.log("    STEP 2c COMPLETE!");
        console.log("=================================================");
        console.log("Configuration:");
        console.log("  Performance Fee Recipient:", feeRecipient);
        console.log("  Performance Fee:", performanceFee / 1e16, "%");
        console.log("\nNext Step:");
        console.log("  Run: forge script deployment/script/2d_ConfigureAdapter.s.sol --rpc-url $RPC_URL --broadcast -v");
    }
}
