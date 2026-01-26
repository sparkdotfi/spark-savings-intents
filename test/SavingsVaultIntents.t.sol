// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { BaseTest } from "./Base.t.sol";

import { SavingsVaultIntents } from "../src/SavingsVaultIntents.sol";

contract SavingsVaultIntentsRequestFailureTest is BaseTest {

    function test_request_failure_insufficientBalance() public {
        vm.expectRevert("Insufficient balance");
        savingsVaultIntents.request({
            vault:     address(vault),
            shares:    100,
            recipient: address(this),
            deadline:  block.timestamp + 100,
            v:         0,
            r:         0,
            s:         0
        });
    }

    function test_request_failure_assetsAlreadyAvailable() public {
        vm.expectRevert("Assets already available in vault to redeem");
        vm.prank(user);
        savingsVaultIntents.request({
            vault:     address(vault),
            shares:    userShares,
            recipient: user,
            deadline:  block.timestamp + 100,
            v:         0,
            r:         0,
            s:         0
        });
    }

}

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

        vm.startPrank(user);

        vm.expectEmit(true, true, true, true);
        emit Request(address(user), 1, address(vault), userShares, block.timestamp + 100, v, r, s);
        savingsVaultIntents.request({
            vault:     address(vault),
            shares:    userShares,
            recipient: user,
            deadline:  block.timestamp + 100,
            v:         v,
            r:         r,
            s:         s
        });

        vm.stopPrank();
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

        // Deal vault some assets 

        address asset = vault.asset();

        deal(asset, address(vault), DEPOSIT_AMOUNT);

        // Fulfill the request

        assertEq(IERC20(asset).balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(IERC20(asset).balanceOf(address(user)),  0);

        vm.startPrank(user);

        vault.approve(address(savingsVaultIntents), userShares);

        vm.expectEmit(true, true, true, true);
        emit Fulfill(address(user), 1);
        savingsVaultIntents.fulfill(address(user), 1);

        vm.stopPrank();

        assertEq(IERC20(asset).balanceOf(address(vault)), 1);
        assertEq(IERC20(asset).balanceOf(address(user)),  DEPOSIT_AMOUNT - 1);
    }

}
