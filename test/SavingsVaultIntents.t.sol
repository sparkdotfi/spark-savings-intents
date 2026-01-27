// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20Like, BaseTest } from "./Base.t.sol";

import { SavingsVaultIntents } from "../src/SavingsVaultIntents.sol";

contract SavingsVaultIntentsRequestSuccessTest is BaseTest {

    event Request(
        address indexed account,
        uint256 indexed requestId,
        address indexed vault,
        uint256 shares,
        uint256 deadline,
        uint8   v,
        bytes32 r,
        bytes32 s
    );

    function test_request() public {
        _removeAllBalanceFromVault();

        (uint8 v, bytes32 r, bytes32 s) = _generateSignature();

        vm.expectEmit(address(savingsVaultIntents));
        emit Request(address(user), 1, address(vault), userShares, block.timestamp + 100, v, r, s);

        vm.prank(user);
        savingsVaultIntents.request({
            vault:     address(vault),
            shares:    userShares,
            recipient: user,
            deadline:  block.timestamp + 100,
            v:         v,
            r:         r,
            s:         s
        });
    }

}

contract SavingsVaultIntentsCancelFailureTest is BaseTest {

    function test_cancel_failure_requestNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(SavingsVaultIntents.RequestNotFound.selector, address(this), 1));
        savingsVaultIntents.cancel(1);
    }

}

contract SavingsVaultIntentsCancelSuccessTest is BaseTest {

    event Cancel(address indexed account, uint256 indexed requestId);

    function test_cancel() public {
        _removeAllBalanceFromVault();

        (uint8 v, bytes32 r, bytes32 s) = _generateSignature();

        vm.prank(user);
        savingsVaultIntents.request({
            vault:     address(vault),
            shares:    userShares,
            recipient: user,
            deadline:  block.timestamp + 100,
            v:         v,
            r:         r,
            s:         s
        });

        vm.startPrank(user);

        vm.expectEmit(true, true, true, true);
        emit Cancel(address(user), 1);
        savingsVaultIntents.cancel(1);

        vm.stopPrank();
    }

}

contract SavingsVaultIntentsFulfillFailureTest is BaseTest {

    function test_fulfill_failure_requestNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(SavingsVaultIntents.RequestNotFound.selector, address(this), 1));
        savingsVaultIntents.fulfill(address(this), 1);
    }

    function test_fulfill_failure_deadlineExceeded() public {
        _removeAllBalanceFromVault();

        (uint8 v, bytes32 r, bytes32 s) = _generateSignature();

        vm.prank(user);
        savingsVaultIntents.request({
            vault:     address(vault),
            shares:    userShares,
            recipient: user,
            deadline:  block.timestamp + 1,
            v:         v,
            r:         r,
            s:         s
        });

        vm.warp(block.timestamp + 2);

        vm.expectRevert(abi.encodeWithSelector(SavingsVaultIntents.DeadlineExceeded.selector, address(user), 1, block.timestamp -1));
        savingsVaultIntents.fulfill(address(user), 1);
    }

}

contract SavingsVaultIntentsFulfillSuccessTest is BaseTest {

    event Fulfill(address indexed account, uint256 indexed requestId);

    function test_fulfill() public {
        _removeAllBalanceFromVault();

        (uint8 v, bytes32 r, bytes32 s) = _generateSignature();

        vm.prank(user);
        savingsVaultIntents.request({
            vault:     address(vault),
            shares:    userShares,
            recipient: user,
            deadline:  block.timestamp + 100,
            v:         v,
            r:         r,
            s:         s
        });

        // Deal vault some assets.

        address asset = vault.asset();

        deal(asset, address(vault), DEPOSIT_AMOUNT);

        // Fulfill the request.

        assertEq(IERC20Like(asset).balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(IERC20Like(asset).balanceOf(address(user)),  0);

        vm.startPrank(user);

        vault.approve(address(savingsVaultIntents), userShares);

        vm.expectEmit(true, true, true, true);
        emit Fulfill(address(user), 1);
        savingsVaultIntents.fulfill(address(user), 1);

        vm.stopPrank();

        assertEq(IERC20Like(asset).balanceOf(address(vault)), 1);
        assertEq(IERC20Like(asset).balanceOf(address(user)),  DEPOSIT_AMOUNT - 1);
    }

}
