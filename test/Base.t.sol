// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { Test } from "../lib/forge-std/src/Test.sol";

import { Ethereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { IERC20Like }   from "./interfaces/IERC20Like.sol";
import { IERC712Like }  from "./interfaces/IERC712Like.sol";
import { IERC4626Like } from "./interfaces/IERC4626Like.sol";
import { IVaultLike }   from "./interfaces/IVaultLike.sol";

import { ISavingsVaultIntents } from "../src/interfaces/ISavingsVaultIntents.sol";
import { SavingsVaultIntents }  from "../src/SavingsVaultIntents.sol";

contract TestBase is Test {

    uint256 internal constant DEPOSIT_AMOUNT = 1_000_000e6;

    IERC4626Like internal vault;
    IERC20Like   internal underlyingAsset;
    uint256      internal vaultInitialTotalSupply;

    bytes32 internal defaultAdminRole;
    bytes32 internal relayerRole;

    address internal admin;
    address internal relayer;
    address internal unauthorized;

    address internal user;
    uint256 internal userPrivateKey;
    uint256 internal userShares;

    SavingsVaultIntents internal savingsVaultIntents;

    function setUp() public virtual {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        vault           = IERC4626Like(Ethereum.SPARK_VAULT_V2_SPUSDC);
        underlyingAsset = IERC20Like(vault.asset());

        admin        = makeAddr("admin");
        relayer      = makeAddr("relayer");
        unauthorized = makeAddr("unauthorized");

        savingsVaultIntents = new SavingsVaultIntents(admin, relayer, 1 days, 1e6);

        defaultAdminRole = savingsVaultIntents.DEFAULT_ADMIN_ROLE();
        relayerRole      = savingsVaultIntents.RELAYER();

        ( user, userPrivateKey ) = makeAddrAndKey("user");

        // Deal some assets to the user and deposit

        deal(address(underlyingAsset), user, DEPOSIT_AMOUNT);

        vm.startPrank(user);

        underlyingAsset.approve(address(vault), DEPOSIT_AMOUNT);

        userShares = vault.deposit(DEPOSIT_AMOUNT, user);

        vm.stopPrank();

        // Vault totalSupply at _getBlock() + above user deposit
        vaultInitialTotalSupply = vault.totalSupply();
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
        uint256 nonce      = IERC712Like(address(vault)).nonces(user);
        bytes32 permitHash = IERC712Like(address(vault)).PERMIT_TYPEHASH();
        bytes32 domainSep  = IERC712Like(address(vault)).DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSep,
                keccak256(
                    abi.encode(
                        permitHash,
                        user,
                        address(savingsVaultIntents),
                        amount_,
                        nonce,
                        deadline_
                    )
                )
            )
        );

        ( v, r, s ) = vm.sign(userPrivateKey, digest);
    }

    function _drainVaultBalance() internal virtual {
        uint256 vaultBalance = underlyingAsset.balanceOf(address(vault));

        vm.prank(Ethereum.ALM_PROXY);
        IVaultLike(address(vault)).take(vaultBalance);
    }

    function _fundVaultBalance(uint256 amount_) internal {
        deal(address(underlyingAsset), address(vault), amount_);
    }

    function _assertRequest(
        address account,
        uint256 requestId,
        address expectedVault,
        uint256 expectedShares,
        address expectedRecipient,
        uint256 expectedDeadline,
        uint8   expectedV,
        bytes32 expectedR,
        bytes32 expectedS
    )
        internal view
    {
        ISavingsVaultIntents.WithdrawRequest memory request_ = savingsVaultIntents.getRequest(
            account,
            requestId
        );

        assertEq(request_.vault,     expectedVault);
        assertEq(request_.shares,    expectedShares);
        assertEq(request_.recipient, expectedRecipient);
        assertEq(request_.deadline,  expectedDeadline);
        assertEq(request_.v,         expectedV);
        assertEq(request_.r,         expectedR);
        assertEq(request_.s,         expectedS);
    }

    function _assertEmptyRequest(address account, uint256 requestId) internal view {
        _assertRequest({
            account           : account,
            requestId         : requestId,
            expectedVault     : address(0),
            expectedShares    : 0,
            expectedRecipient : address(0),
            expectedDeadline  : 0,
            expectedV         : 0,
            expectedR         : 0,
            expectedS         : 0
        });
    }

}
