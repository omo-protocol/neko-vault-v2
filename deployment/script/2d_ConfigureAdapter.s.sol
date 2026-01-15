// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../../src/UniversalAdapterEscrow.sol";

/**
 * @title ConfigureAdapter
 * @notice Adapter strategy configuration (Step 2d)
 * @dev Run AFTER 2c_ConfigureFees.s.sol
 *
 * Required Environment Variables:
 *   - PRIVATE_KEY: Deployer/owner private key
 *   - ADAPTER_ADDRESS: Address of deployed UniversalAdapterEscrow
 *   - ALLOCATOR_ADDRESS: Address to set as strategy agent
 *
 * Optional Environment Variables:
 *   - STRATEGY_NAME: Strategy identifier (default: "default-strategy")
 *   - DAILY_LIMIT: Daily limit for strategy (default: 10000e18)
 *
 * Usage:
 *   source .env && forge script deployment/script/2d_ConfigureAdapter.s.sol \
 *     --rpc-url $RPC_URL --broadcast -v
 *
 * Transactions: 1 (adapter.setStrategy)
 */
contract ConfigureAdapter is Script {
    uint256 constant DEFAULT_DAILY_LIMIT = 10000e18; // 10,000 tokens - this param already ignored in adapter

    function run() public {
        // Load private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load required addresses from environment
        address adapterAddress = vm.envAddress("ADAPTER_ADDRESS");
        address allocatorAddress = vm.envAddress("ALLOCATOR_ADDRESS");

        // Load optional configuration
        string memory strategyName = vm.envOr("STRATEGY_NAME", string("default-strategy"));
        bytes32 STRATEGY_ID = keccak256(bytes(strategyName));
        uint256 dailyLimit = vm.envOr("DAILY_LIMIT", DEFAULT_DAILY_LIMIT);

        UniversalAdapterEscrow adapter = UniversalAdapterEscrow(payable(adapterAddress));

        console.log("\n=================================================");
        console.log("    ADAPTER CONFIGURATION (Step 2d)");
        console.log("=================================================");
        console.log("Deployer:", deployer);
        console.log("Adapter:", adapterAddress);
        console.log("Allocator:", allocatorAddress);
        console.log("Strategy Name:", strategyName);
        console.log("Daily Limit:", dailyLimit / 1e18, "tokens");
        console.log("Transactions: 1");

        vm.startBroadcast(deployerPrivateKey);

        // Configure adapter strategy
        console.log("\n[Step 1/1] Configuring adapter strategy...");
        adapter.setStrategy(
            STRATEGY_ID,
            allocatorAddress, // strategyAgent
            "", // No pre-configured data
            dailyLimit // Daily limit
        );
        console.log("  Strategy configured:");
        console.log("    Strategy ID:", vm.toString(STRATEGY_ID));
        console.log("    Strategy Agent:", allocatorAddress);
        console.log("    Daily Limit:", dailyLimit / 1e18, "tokens");

        vm.stopBroadcast();

        console.log("\n=================================================");
        console.log("    STEP 2d COMPLETE!");
        console.log("=================================================");
        console.log("Configuration:");
        console.log("  Strategy ID:", vm.toString(STRATEGY_ID));
        console.log("  Strategy Agent:", allocatorAddress);

        console.log("\n[SUCCESS] All vault configuration complete!");
        console.log("\nNext Steps:");
        console.log("  1. Test deposit/withdraw flows");
        console.log("  2. Test allocation/deallocation");
        console.log("  3. Configure whitelists if using Mantle (2f_ConfigureMantleSupplyOptimizerWhitelist.s.sol)");
    }
}
