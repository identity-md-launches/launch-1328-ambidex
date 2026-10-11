// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {AmbidexToken} from "../src/AmbidexToken.sol";

/// @title Deploy script for AMBIDEX (AMBI)
/// @notice Reviewable deployment helper. The IdentityMD launch deploys the token from its built
/// bytecode through the ProjectFactory, so this script is for local forks, staging and manual
/// deployments outside that flow. It reads nothing from the environment: the token takes no
/// constructor arguments, so there is nothing to configure.
/// @dev Tests call `deploy()` directly. `run()` only wraps it in a broadcast.
contract DeployAmbidexToken is Script {
    /// @notice Deploys a fresh AmbidexToken. Whoever is `msg.sender` of the creation receives the
    /// whole supply.
    /// @return token The deployed token.
    function deploy() public returns (AmbidexToken token) {
        token = new AmbidexToken();
    }

    /// @notice Broadcast entry point: `forge script script/DeployAmbidexToken.s.sol --broadcast`.
    /// The broadcasting account becomes the deployer and receives the whole supply.
    function run() external returns (AmbidexToken token) {
        vm.startBroadcast();
        token = deploy();
        vm.stopBroadcast();
    }
}
