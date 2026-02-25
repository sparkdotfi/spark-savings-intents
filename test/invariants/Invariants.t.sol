// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { InvariantsBase } from "./InvariantsBase.t.sol";

import { AdminHandler }    from "./handlers/AdminHandler.sol";
import { UserHandler }     from "./handlers/UserHandler.sol";

contract Invariants is InvariantsBase {

    function setUp() public override {
        super.setUp();

        adminHandler = new AdminHandler(address(vault), address(savingsVaultIntents));
        userHandler  = new UserHandler(address(vault),  address(savingsVaultIntents), 25);

        // Foundry will call only the functions of the target contracts
        targetContract(address(adminHandler));
        targetContract(address(userHandler));
    }

    function invariant_savingsVaultIntentsInvariants() public view {
        this.savingsVaultIntentsInvariant_savingsVaultIntentsBalanceIsZero();
    }

    /**********************************************************************************************/
    /*** SavingsVaultIntents invariant helper functions                                         ***/
    /**********************************************************************************************/

    function savingsVaultIntentsInvariant_savingsVaultIntentsBalanceIsZero() public view {
        assertEq(
            vault.balanceOf(address(savingsVaultIntents)),
            0,
            string(abi.encodePacked("savingsVaultIntents balance is not zero"))
        );
    }

}
