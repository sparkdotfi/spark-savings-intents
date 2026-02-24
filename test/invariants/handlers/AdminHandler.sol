// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { HandlerBase } from "./HandlerBase.sol";

contract AdminHandler is HandlerBase {

    address public admin;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    constructor(address vault_, address savingsVaultIntents_) HandlerBase(vault_, savingsVaultIntents_) {
        admin = savingsVaultIntents.getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }

    function setMaxDeadline(
        uint256 maxDeadline
    ) public {
        vm.prank(admin);
        savingsVaultIntents.setMaxDeadline(maxDeadline);
    }

    function updateVaultConfig(
        bool    whitelisted,
        uint256 minIntentAssets,
        uint256 maxIntentAssets
    ) public {
        minIntentAssets = _bound(minIntentAssets, 0,                 MIN_INTENT_ASSETS);
        maxIntentAssets = _bound(maxIntentAssets, minIntentAssets, MAX_INTENT_ASSETS);

        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(vault, whitelisted, minIntentAssets, maxIntentAssets);
    }

}
