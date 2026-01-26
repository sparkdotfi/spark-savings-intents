// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { Ethereum } from "spark-address-registry/Ethereum.sol";

import { IERC4626Like, SavingsVaultIntents } from "../src/SavingsVaultIntents.sol";

interface IVaultLike {
    function take(uint256 amount) external;
}

contract BaseTest is Test {

    SavingsVaultIntents public savingsVaultIntents;

    IERC4626Like public constant vault = IERC4626Like(Ethereum.SPARK_VAULT_V2_SPUSDC);

    address user;
    uint256 userPrivateKey;

    uint256 public constant DEPOSIT_AMOUNT = 1_000_000e6;

    uint256 userShares;

    function setUp() public virtual {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        savingsVaultIntents = new SavingsVaultIntents();

        // Derive a key for the user from the standard test mnemonic
        string memory mnemonic = "test test test test test test test test test test test junk";
        userPrivateKey = vm.deriveKey(mnemonic, 1);
        user = vm.addr(userPrivateKey);

        // Deal some assets to the user and deposit

        deal(vault.asset(), user, DEPOSIT_AMOUNT);

        vm.startPrank(user);

        IERC20(vault.asset()).approve(address(vault), DEPOSIT_AMOUNT);

        userShares = vault.deposit(DEPOSIT_AMOUNT, user);

        vm.stopPrank();
    }

    function _getBlock() internal virtual pure returns (uint256) {
        return 24319071; //  January 26, 2026
    }

    function _generateSignature() internal virtual returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 digest = keccak256(abi.encode(user, block.timestamp));

        (v, r, s) = vm.sign(userPrivateKey, digest);
    }

    function _removeAllBalanceFromVault() internal virtual {
        address asset = vault.asset();

        vm.startPrank(Ethereum.ALM_PROXY);
        IVaultLike(address(vault)).take(IERC20(asset).balanceOf(address(vault)));
        vm.stopPrank();
    }

}
