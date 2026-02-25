// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";

import { SavingsVaultIntents } from "src/SavingsVaultIntents.sol";

contract HandlerBase is Test {

    SavingsVaultIntents savingsVaultIntents;

    uint256 public MIN_INTENT_ASSETS;
    uint256 public MAX_INTENT_ASSETS;

    address public relayer;

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER");

    address vault;

    constructor(address vault_, address savingsVaultIntents_) {
        vault = vault_;

        savingsVaultIntents = SavingsVaultIntents(savingsVaultIntents_);

        MIN_INTENT_ASSETS = 100e6;
        MAX_INTENT_ASSETS = 100_000_000e6;

        relayer = savingsVaultIntents.getRoleMember(RELAYER_ROLE, 0);
    }

}
