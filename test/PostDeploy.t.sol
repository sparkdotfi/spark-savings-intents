// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { Test } from "../lib/forge-std/src/Test.sol";

import { Ethereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { SavingsVaultIntents } from "../src/SavingsVaultIntents.sol";

contract PostDeployMainnetProductionTests is Test {

    address internal constant SAVINGS_VAULT_INTENTS = 0x592B7DB9906E6f8924C4D74c2A0aB86CE44fDDDf;

    address internal constant ADMIN   = Ethereum.SPARK_PROXY;
    address internal constant RELAYER = Ethereum.ALM_RELAYER_MULTISIG;

    uint256 internal constant MAX_DEADLINE_DURATION = 7 days;

    SavingsVaultIntents internal savingsVaultIntents;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl);

        savingsVaultIntents = SavingsVaultIntents(SAVINGS_VAULT_INTENTS);
    }

    function test_postDeploy_mainnetProduction() external view {
        assertEq(savingsVaultIntents.hasRole(savingsVaultIntents.DEFAULT_ADMIN_ROLE(), ADMIN),   true);
        assertEq(savingsVaultIntents.hasRole(savingsVaultIntents.RELAYER(),            RELAYER), true);

        assertEq(savingsVaultIntents.getRoleMemberCount(savingsVaultIntents.DEFAULT_ADMIN_ROLE()), 1);
        assertEq(savingsVaultIntents.getRoleMemberCount(savingsVaultIntents.RELAYER()),            1);

        assertEq(savingsVaultIntents.maxDeadlineDuration(), MAX_DEADLINE_DURATION);

        // Vault configs

        bool    whitelisted;
        uint256 minIntentAssets;
        uint256 maxIntentAssets;

        // spUSDC
        ( whitelisted, minIntentAssets, maxIntentAssets ) =
            savingsVaultIntents.vaultConfig(Ethereum.SPARK_VAULT_V2_SPUSDC);

        assertEq(whitelisted,     true);
        assertEq(minIntentAssets, 5_000_000e6);
        assertEq(maxIntentAssets, 500_000_000e6);

        // spETH
        ( whitelisted, minIntentAssets, maxIntentAssets ) =
            savingsVaultIntents.vaultConfig(Ethereum.SPARK_VAULT_V2_SPETH);

        assertEq(whitelisted,     true);
        assertEq(minIntentAssets, 1_250e18);
        assertEq(maxIntentAssets, 250_000e18);

        // spPYUSD
        ( whitelisted, minIntentAssets, maxIntentAssets ) =
            savingsVaultIntents.vaultConfig(Ethereum.SPARK_VAULT_V2_SPPYUSD);

        assertEq(whitelisted,     true);
        assertEq(minIntentAssets, 5_000_000e6);
        assertEq(maxIntentAssets, 500_000_000e6);

        // spUSDT
        ( whitelisted, minIntentAssets, maxIntentAssets ) =
            savingsVaultIntents.vaultConfig(Ethereum.SPARK_VAULT_V2_SPUSDT);

        assertEq(whitelisted,     true);
        assertEq(minIntentAssets, 5_000_000e6);
        assertEq(maxIntentAssets, 500_000_000e6);
    }

}
