// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RiskManager} from "../RiskManager.sol";
import {InterestRateModel} from "../InterestRateModel.sol";
import {ArcadiaFactory} from "../ArcadiaFactory.sol";
import {ArcadiaVault} from "../ArcadiaVault.sol";

/// @notice Operator deployment script for Arc Testnet. Not run by Arc Studio.
/// @dev Usage (key from a keystore, never a literal):
///   forge script contracts/script/DeployArcadia.s.sol --rpc-url $ARC_TESTNET_RPC_URL --account <keystore> --broadcast
/// Environment: ADMIN_ADDRESS (required), USDC_ADDRESS (required, verify against Arc docs).
contract DeployArcadia is Script {
    function run() external {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");

        vm.startBroadcast();
        RiskManager risk = new RiskManager(admin, 1_000_000e6, 100_000e6, 1e6, 0);
        InterestRateModel model = new InterestRateModel(admin, 0.02e18, 0.8e18, 0.04e18, 0.75e18);
        ArcadiaFactory factory = new ArcadiaFactory(admin, address(risk), address(model), usdc, 0.1e18);
        ArcadiaVault vault = new ArcadiaVault(usdc, address(risk), admin, "Arcadia USDC Vault", "aUSDC");
        vm.stopBroadcast();

        console.log("RiskManager", address(risk));
        console.log("InterestRateModel", address(model));
        console.log("ArcadiaFactory", address(factory));
        console.log("USDC market", factory.marketFor(usdc));
        console.log("ArcadiaVault", address(vault));
    }
}
