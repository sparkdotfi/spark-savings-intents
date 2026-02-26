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
        maxDeadline = _bound(maxDeadline, 1, 1 days);

        vm.startPrank(admin);
        savingsVaultIntents.setMaxDeadline(maxDeadline);
        vm.stopPrank();
    }

    function updateVaultConfig(
        bool    whitelisted,
        uint256 minIntentAssets,
        uint256 maxIntentAssets
    ) public {
        minIntentAssets = _bound(minIntentAssets, 0,                       10e6);
        maxIntentAssets = _bound(maxIntentAssets, minIntentAssets + 1e6, 10_000e6);

        vm.startPrank(admin);
        savingsVaultIntents.updateVaultConfig(vault, whitelisted, minIntentAssets, maxIntentAssets);
        vm.stopPrank();
    }

}
