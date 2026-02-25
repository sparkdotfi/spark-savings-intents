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
        maxDeadline = _bound(maxDeadline, 1, type(uint256).max);

        vm.prank(admin);
        savingsVaultIntents.setMaxDeadline(maxDeadline);
    }

    function updateVaultConfig(
        bool whitelisted
    ) public {
        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(vault, whitelisted, 0, type(uint256).max);
    }

}
