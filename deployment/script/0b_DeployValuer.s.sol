// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../../src/UniversalValuerOffchain.sol";

/**
 * @title DeployValuer
 * @notice Deploys and configures UniversalValuerOffchain
 *
 * Required Environment Variables:
 *   - PRIVATE_KEY: Deployer private key
 *   - ASSET_ADDRESS: ERC20 asset address for valuation
 *   - KEEPER_ADDRESS: Keeper address for automated operations
 *
 * Optional Environment Variables:
 *   - STRATEGY_NAME: Strategy identifier (default: "default-strategy")
 *
 * Usage:
 *   source .env && forge script deployment/script/0b_DeployValuer.s.sol \
 *     --rpc-url $RPC_URL --broadcast -v
 */
contract DeployValuer is Script {
    // Sensible defaults for valuer configuration
    uint256 constant MIN_UPDATE_INTERVAL = 300;    // 5 minutes
    uint256 constant MAX_STALENESS = 3600;         // 1 hour
    uint256 constant PUSH_THRESHOLD = 500;         // 5%
    uint256 constant MIN_CONFIDENCE = 90;          // 90%
    uint256 constant PRICE_CHANGE_BOUNDS = 5000;   // 50%
    uint256 constant REQUIRED_WEIGHT = 90;         // 90%
    uint256 constant SIGNER_WEIGHT = 100;          // 100 weight for initial signer

    function run() public {
        // Load private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load required addresses from environment
        address asset = vm.envAddress("ASSET_ADDRESS");
        address keeper = vm.envAddress("KEEPER_ADDRESS");

        // Load optional strategy name (default: "default-strategy")
        string memory strategyName = vm.envOr("STRATEGY_NAME", string("default-strategy"));
        bytes32 STRATEGY_ID = keccak256(bytes(strategyName));

        console.log("\n=================================================");
        console.log("    VALUER DEPLOYMENT");
        console.log("=================================================");
        console.log("Deployer:", deployer);
        console.log("Asset:", asset);
        console.log("Keeper:", keeper);
        console.log("Strategy Name:", strategyName);
        console.log("Strategy ID:");
        console.logBytes32(STRATEGY_ID);

        vm.startBroadcast(deployerPrivateKey);

        UniversalValuerOffchain valuer = new UniversalValuerOffchain(deployer, asset);
        console.log("\nValuer deployed:", address(valuer));

        // Configure valuer
        valuer.initiateSignerChange(deployer, true, SIGNER_WEIGHT);
        valuer.setRequiredWeight(REQUIRED_WEIGHT);

        valuer.configureStrategy(
            STRATEGY_ID,
            MIN_UPDATE_INTERVAL,
            MAX_STALENESS,
            PUSH_THRESHOLD,
            MIN_CONFIDENCE
        );

        // Set price change bounds
        valuer.setPriceChangeBounds(STRATEGY_ID, PRICE_CHANGE_BOUNDS);

        // Set keeper for automated operations
        valuer.setIsKeeper(keeper, true);

        vm.stopBroadcast();

        console.log("\n=================================================");
        console.log("    VALUER DEPLOYMENT COMPLETE!");
        console.log("=================================================");
        console.log("Valuer deployed:", address(valuer));
        console.log("Keeper set:", keeper);
        console.log("\n[SUCCESS] Valuer deployed!");
    }
}