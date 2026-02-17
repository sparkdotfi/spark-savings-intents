// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { Test } from "../lib/forge-std/src/Test.sol";

import { Ethereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { IERC20Like }   from "./interfaces/IERC20Like.sol";
import { IERC4626Like } from "./interfaces/IERC4626Like.sol";
import { IVaultLike }   from "./interfaces/IVaultLike.sol";

import { ISavingsVaultIntents } from "../src/interfaces/ISavingsVaultIntents.sol";
import { SavingsVaultIntents }  from "../src/SavingsVaultIntents.sol";

contract TestBase is Test {

    uint256 internal constant DEPOSIT_AMOUNT    = 1_000_000e6;
    uint256 internal constant MIN_INTENT_SHARES = 10e6;
    uint256 internal constant MAX_INTENT_SHARES = 100_000_000e6;

    IERC4626Like internal vault;
    IERC20Like   internal underlyingAsset;
    uint256      internal vaultInitialTotalSupply;

    bytes32 internal defaultAdminRole;
    bytes32 internal relayerRole;

    address internal admin;
    address internal relayer;
    address internal unauthorized;

    address internal user;
    uint256 internal userShares;

    SavingsVaultIntents internal savingsVaultIntents;

    function setUp() public virtual {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        vault           = IERC4626Like(Ethereum.SPARK_VAULT_V2_SPUSDC);
        underlyingAsset = IERC20Like(vault.asset());

        admin        = makeAddr("admin");
        relayer      = makeAddr("relayer");
        user         = makeAddr("user");
        unauthorized = makeAddr("unauthorized");

        savingsVaultIntents = new SavingsVaultIntents(admin, relayer, 1 days, MAX_INTENT_SHARES);

        // Initial setup of savingsVaultIntents by admin

        vm.startPrank(admin);

        savingsVaultIntents.updateWhitelist(address(vault), true);

        savingsVaultIntents.setMinIntentShares(MIN_INTENT_SHARES);

        vm.stopPrank();

        // User deposits assets into vault
        userShares = _depositToVault(user, DEPOSIT_AMOUNT);

        // Vault totalSupply at _getBlock() + above user deposit
        vaultInitialTotalSupply = vault.totalSupply();
    }

    function _getBlock() internal virtual pure returns (uint256) {
        return 24319071; //  January 26, 2026
    }

    function _drainVaultBalance() internal virtual {
        uint256 vaultBalance = underlyingAsset.balanceOf(address(vault));

        vm.prank(Ethereum.ALM_PROXY);
        IVaultLike(address(vault)).take(vaultBalance);
    }

    function _fundVaultBalance(uint256 amount_) internal {
        deal(address(underlyingAsset), address(vault), amount_);
    }

    function _depositToVault(address account, uint256 assets) internal returns (uint256 shares) {
        deal(address(underlyingAsset), account, assets);

        vm.prank(account);
        underlyingAsset.approve(address(vault), assets);

        vm.prank(account);
        shares = vault.deposit(assets, account);
    }

    function _assertRequest(
        address account,
        uint256 expectedRequestId,
        address expectedVault,
        uint256 expectedShares,
        address expectedRecipient,
        uint256 expectedDeadline
    )
        internal view
    {
        ( 
            uint256 requestId_,
            address vault_,
            uint256 shares_,
            address recipient_,
            uint256 deadline_
        ) = savingsVaultIntents.withdrawRequests(account);

        assertEq(requestId_, expectedRequestId);
        assertEq(vault_,     expectedVault);
        assertEq(shares_,    expectedShares);
        assertEq(recipient_, expectedRecipient);
        assertEq(deadline_,  expectedDeadline);
    }

    function _assertEmptyRequest(address account) internal view {
        _assertRequest({
            account           : account,
            expectedRequestId : 0,
            expectedVault     : address(0),
            expectedShares    : 0,
            expectedRecipient : address(0),
            expectedDeadline  : 0
        });
    }

}
