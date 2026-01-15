// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../../src/VaultV2.sol";
import {IVaultV2} from "../../src/interfaces/IVaultV2.sol";

/**
 * @title ConfigureCaps
 * @notice Caps configuration - absolute and relative caps (Step 2b)
 * @dev Run AFTER 2a_ConfigureVaultCore.s.sol
 *      Run 2c_ConfigureFees.s.sol next
 *
 * Required Environment Variables:
 *   - PRIVATE_KEY: Deployer/curator private key
 *   - VAULT_ADDRESS: Address of deployed VaultV2
 *
 * Optional Environment Variables:
 *   - STRATEGY_NAME: Strategy identifier for caps (default: "default-strategy")
 *   - RELATIVE_CAP: Relative cap in WAD (default: 1e18 = 100%)
 *
 * Usage:
 *   source .env && forge script deployment/script/2b_ConfigureCaps.s.sol \
 *     --rpc-url $RPC_URL --broadcast -v
 *
 * Transactions: 4 (submit + execute for absolute cap, submit + execute for relative cap)
 */
contract ConfigureCaps is Script {
    uint256 constant DEFAULT_RELATIVE_CAP = 1e18; // 100%

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load required addresses from environment
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        // Load optional configuration
        string memory strategyName = vm.envOr("STRATEGY_NAME", string("default-strategy"));
        bytes memory idData = bytes(strategyName);
        uint256 relativeCap = vm.envOr("RELATIVE_CAP", DEFAULT_RELATIVE_CAP);

        VaultV2 vault = VaultV2(vaultAddress);

        console.log("\n=================================================");
        console.log("    CAPS CONFIGURATION (Step 2b)");
        console.log("=================================================");
        console.log("Deployer:", deployer);
        console.log("VaultV2:", vaultAddress);
        console.log("Strategy Name:", strategyName);
        console.log("Relative Cap:", relativeCap / 1e16, "%");

        // Calculate what the hash will be
        bytes32 expectedHash = keccak256(idData);
        console.log("Cap ID Hash:");
        console.logBytes32(expectedHash);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Set absolute cap (2 transactions)
        console.log("\n[Step 1/2] Setting absolute cap...");
        vault.submit(abi.encodeCall(IVaultV2.increaseAbsoluteCap, (idData, type(uint128).max)));
        vault.increaseAbsoluteCap(idData, type(uint128).max);
        console.log("  Absolute cap set to MAX");

        // Step 2: Set relative cap (2 transactions)
        console.log("\n[Step 2/2] Setting relative cap...");
        vault.submit(abi.encodeCall(IVaultV2.increaseRelativeCap, (idData, relativeCap)));
        vault.increaseRelativeCap(idData, relativeCap);
        console.log("  Relative cap set to:", relativeCap / 1e16, "%");

        vm.stopBroadcast();

        console.log("\n=================================================");
        console.log("    STEP 2b COMPLETE!");
        console.log("=================================================");
        console.log("Caps stored under:");
        console.logBytes32(expectedHash);
        console.log("\nNext Step:");
        console.log("  Run: forge script deployment/script/2c_ConfigureFees.s.sol --rpc-url $RPC_URL --broadcast -v");
    }
}
