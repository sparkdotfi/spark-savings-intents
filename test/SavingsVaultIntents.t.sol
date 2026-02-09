// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20Like, TestBase } from "./Base.t.sol";

import { SavingsVaultIntents } from "../src/SavingsVaultIntents.sol";

contract SavingsVaultIntentsRequestTests is TestBase {

    function test_request() public {
        ( uint8 v, bytes32 r, bytes32 s ) = _generateSignature(userShares, block.timestamp + 100);

        vm.expectEmit(address(savingsVaultIntents));
        emit SavingsVaultIntents.Request(user, 1, address(vault), userShares, block.timestamp + 100, v, r, s);

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault:     address(vault),
            shares:    userShares,
            recipient: user,
            deadline:  block.timestamp + 100,
            v:         v,
            r:         r,
            s:         s
        });

        assertEq(requestId, 1);

        ( 
            address vault_,
            uint256 shares_,
            address recipient_,
            uint256 deadline_,
            uint8   v_,
            bytes32 r_,
            bytes32 s_ 
        ) = savingsVaultIntents.requests(user, 1);
        
        assertEq(vault_,     address(vault));
        assertEq(shares_,    userShares);
        assertEq(recipient_, user);
        assertEq(deadline_,  block.timestamp + 100);
        assertEq(v_,         v);
        assertEq(r_,         r);
        assertEq(s_,         s);
    }

}

contract SavingsVaultIntentsCancelTest is TestBase {

    function test_cancel_requestNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(SavingsVaultIntents.RequestNotFound.selector, address(this), 1));
        savingsVaultIntents.cancel(1);
    }

    function test_cancel() public {
        ( uint8 v, bytes32 r, bytes32 s ) = _generateSignature(userShares, block.timestamp + 100);

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


        vm.expectEmit(true, true, true, true);
        emit SavingsVaultIntents.Cancel(address(user), 1);

        vm.prank(user);
        savingsVaultIntents.cancel(1);
    }

}

contract SavingsVaultIntentsFulfillTest is TestBase {

    function test_fulfill_requestNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(SavingsVaultIntents.RequestNotFound.selector, address(this), 1));
        savingsVaultIntents.fulfill(address(this), 1);
    }

    function test_fulfill_deadlineExceededBoundary() public {
        _removeAllBalanceFromVault();

        (uint8 v, bytes32 r, bytes32 s) = _generateSignature(userShares, block.timestamp + 100);

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

        vm.expectRevert(abi.encodeWithSelector(SavingsVaultIntents.DeadlineExceeded.selector, user, 1, block.timestamp - 1));
        savingsVaultIntents.fulfill(user, 1);
    }

    function test_fulfill() public {
        _removeAllBalanceFromVault();

        (uint8 v, bytes32 r, bytes32 s) = _generateSignature(userShares, block.timestamp + 100);

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
        assertEq(vault.balanceOf(address(user)),              userShares);

        vm.expectEmit(address(savingsVaultIntents));
        emit SavingsVaultIntents.Fulfill(address(user), 1);

        vm.prank(user);
        savingsVaultIntents.fulfill(address(user), 1);

        assertEq(IERC20Like(asset).balanceOf(address(vault)), 1);
        assertEq(IERC20Like(asset).balanceOf(address(user)),  DEPOSIT_AMOUNT - 1);
        assertEq(vault.balanceOf(address(user)),              0);
    }

}
