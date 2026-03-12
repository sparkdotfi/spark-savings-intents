// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { AdminHandler } from "./handlers/AdminHandler.sol";
import { UserHandler }  from "./handlers/UserHandler.sol";

import { IERC4626Like } from "../interfaces/IERC4626Like.sol";
import { IERC20Like }   from "../interfaces/IERC20Like.sol";

import { SavingsVaultIntents } from "../../src/SavingsVaultIntents.sol";

contract InvariantsBase is Test {

    AdminHandler adminHandler;
    UserHandler  userHandler;

    IERC4626Like vault;
    IERC20Like   underlyingAsset;

    SavingsVaultIntents savingsVaultIntents;

    address admin   = makeAddr("admin");
    address relayer = makeAddr("relayer");

    function setUp() public virtual {
        vm.createSelectFork(getChain("mainnet").rpcUrl);

        vault           = IERC4626Like(Ethereum.SPARK_VAULT_V2_SPUSDC);
        underlyingAsset = IERC20Like(vault.asset());

        savingsVaultIntents = new SavingsVaultIntents(admin, relayer, 1 days);

        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(
            address(vault),
            true,
            0,
            type(uint256).max
        );
    }

}
