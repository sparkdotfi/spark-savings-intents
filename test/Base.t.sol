// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { Test } from "../lib/forge-std/src/Test.sol";

import { Ethereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { SavingsVaultIntents } from "../src/SavingsVaultIntents.sol";

interface IVaultLike {
    function take(uint256 amount) external;
}

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC712Like {
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external view returns (bytes32);
}

interface IERC4626Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function asset() external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TestBase is Test {

    SavingsVaultIntents internal savingsVaultIntents;

    IERC4626Like internal constant vault = IERC4626Like(Ethereum.SPARK_VAULT_V2_SPUSDC);

    uint256 internal constant DEPOSIT_AMOUNT = 1_000_000e6;

    address internal user;

    uint256 internal userPrivateKey;
    uint256 internal userShares;

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

        IERC20Like(vault.asset()).approve(address(vault), DEPOSIT_AMOUNT);

        userShares = vault.deposit(DEPOSIT_AMOUNT, user);

        vm.stopPrank();
    }

    function _getBlock() internal virtual pure returns (uint256) {
        return 24319071; //  January 26, 2026
    }

    function _generateSignature(
        uint256 amount_,
        uint256 deadline_
    )
        internal virtual returns (uint8 v, bytes32 r, bytes32 s)
    {
        uint256 nonce        = IERC712Like(address(vault)).nonces(user);
        bytes32 permitDigest = keccak256(abi.encode(IERC712Like(address(vault)).PERMIT_TYPEHASH(), user, address(savingsVaultIntents), amount_, nonce, deadline_));
        bytes32 digest       = keccak256(abi.encodePacked("\x19\x01", IERC712Like(address(vault)).DOMAIN_SEPARATOR(), permitDigest));

        ( v, r, s ) = vm.sign(userPrivateKey, digest);
    }

    function _removeAllBalanceFromVault() internal virtual {
        address asset = vault.asset();

        vm.startPrank(Ethereum.ALM_PROXY);
        IVaultLike(address(vault)).take(IERC20Like(asset).balanceOf(address(vault)));
        vm.stopPrank();
    }

}
