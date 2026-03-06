// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { Script, stdJson, console } from "../lib/forge-std/src/Script.sol";

import { ScriptTools } from "dss-test/ScriptTools.sol";

import { Ethereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { SavingsVaultIntentsDeploy } from "../deploy/SavingsVaultIntentsDeploy.sol";

contract DeployMainnetFull is Script {

    using stdJson     for string;
    using ScriptTools for string;

    function run() external {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             "1");
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        vm.createSelectFork(getChain("mainnet").rpcUrl);

        console.log("Deploying Mainnet SavingsVaultIntents..");

        string memory fileSlug = string(abi.encodePacked("mainnet-", vm.envString("ENV")));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        vm.startBroadcast();

        // Deploy the SavingsVaultIntents contract
        address savingsVaultIntents = SavingsVaultIntentsDeploy.deployFull({
            admin               : config.readAddress(".admin"),
            relayer             : config.readAddress(".relayer"),
            maxDeadlineDuration : config.readUint(".maxDeadlineDuration")
        });

        console.log("SavingsVaultIntents deployed at : ", savingsVaultIntents);

        ScriptTools.exportContract(fileSlug, "savingsVaultIntents", savingsVaultIntents);

        vm.stopBroadcast();
    }

}
