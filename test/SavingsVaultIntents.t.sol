// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IAccessControl } from "../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IERC20Like, TestBase } from "./Base.t.sol";

import { SavingsVaultIntents } from "../src/SavingsVaultIntents.sol";

contract ConstructorTests is TestBase {

    // Failure tests

    function test_constructor_invalidAdmin() external {
        vm.expectRevert(SavingsVaultIntents.InvalidAdminAddress.selector);
        new SavingsVaultIntents(address(0), relayer, 1 days);
    }

    function test_constructor_invalidRelayer() external {
        vm.expectRevert(SavingsVaultIntents.InvalidRelayerAddress.selector);
        new SavingsVaultIntents(admin, address(0), 1 days);
    }

    function test_constructor_invalidMaxDeadline() external {
        vm.expectRevert(SavingsVaultIntents.InvalidMaxDeadline.selector);
        new SavingsVaultIntents(admin, relayer, 0);
    }

    // Success tests

    function test_constructor() external {
        assertEq(savingsVaultIntents.hasRole(savingsVaultIntents.DEFAULT_ADMIN_ROLE(), admin),   true);
        assertEq(savingsVaultIntents.hasRole(savingsVaultIntents.RELAYER(),            relayer), true);

        assertEq(savingsVaultIntents.maxDeadline(), 1 days);
    }
}

contract SavingsVaultIntentsRequestTests is TestBase {

    function test_request_invalidVaultAddress() public {
        vm.expectRevert(SavingsVaultIntents.InvalidVaultAddress.selector);
        savingsVaultIntents.request(address(0), userShares, user, block.timestamp + 100, 0, 0, 0);
    }

    function test_request_invalidRecipientAddress() public {
        vm.expectRevert(SavingsVaultIntents.InvalidRecipientAddress.selector);
        savingsVaultIntents.request(address(vault), userShares, address(0), block.timestamp + 100, 0, 0, 0);
    }

    function test_request_invalidDeadline() public {
        vm.expectRevert(abi.encodeWithSelector(SavingsVaultIntents.InvalidDeadline.selector, 1 days, block.timestamp + 1 days + 1));
        savingsVaultIntents.request(address(vault), userShares, user, block.timestamp + 1 days + 1, 0, 0, 0);
    }

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

contract SetMaxDeadlineTests is TestBase {

    // Failure tests

    function test_setMaxDeadline_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                savingsVaultIntents.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(user);
        savingsVaultIntents.setMaxDeadline(2 days);
    }
    
    function test_setMaxDeadline_invalidMaxDeadline() external {
        vm.expectRevert(SavingsVaultIntents.InvalidMaxDeadline.selector);

        vm.prank(admin);
        savingsVaultIntents.setMaxDeadline(0);
    }

    // Success tests

    function test_setMaxDeadline() external {
        assertEq(savingsVaultIntents.maxDeadline(), 1 days);

        vm.expectEmit(address(savingsVaultIntents));
        emit SavingsVaultIntents.MaxDeadlineUpdated(2 days);

        vm.prank(admin);
        savingsVaultIntents.setMaxDeadline(2 days);

        assertEq(savingsVaultIntents.maxDeadline(), 2 days);
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


        vm.expectEmit(address(savingsVaultIntents));
        emit SavingsVaultIntents.Cancel(address(user), 1);

        vm.prank(user);
        savingsVaultIntents.cancel(1);
    }

}

contract SavingsVaultIntentsFulfillTest is TestBase {

    function test_fulfill_requestNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(SavingsVaultIntents.RequestNotFound.selector, user, 1));
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, 1);
    }

    function test_fulfill_insufficientUserFunds() public {
        _removeAllBalanceFromVault();

        _createRequest(userShares + 1, block.timestamp + 100);

        vm.expectRevert("SparkVault/insufficient-balance");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, 1);
    }

    function test_fulfill_insufficientVaultFunds() public {
        _removeAllBalanceFromVault();

        _createRequest(userShares, block.timestamp + 100);

        vm.expectRevert("SparkVault/insufficient-liquidity");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, 1);
    }

    function test_fulfill_deadlineExceededBoundary() public {
        _removeAllBalanceFromVault();

        uint256 deadline = block.timestamp + 1;

        _createRequest(userShares, deadline);

        vm.warp(deadline + 1);

        vm.expectRevert(abi.encodeWithSelector(SavingsVaultIntents.DeadlineExceeded.selector, user, 1, deadline));
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, 1);

        vm.warp(deadline - 1);

        address asset = vault.asset();

        deal(asset, address(vault), DEPOSIT_AMOUNT);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, 1);
    }

    function test_fulfill() public {
        _removeAllBalanceFromVault();

        _createRequest(userShares, block.timestamp + 100);

        // Deal vault some assets.

        address asset = vault.asset();

        deal(asset, address(vault), DEPOSIT_AMOUNT);

        // Fulfill the request.

        assertEq(IERC20Like(asset).balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(IERC20Like(asset).balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(address(user)),              userShares);

        vm.expectEmit(address(savingsVaultIntents));
        emit SavingsVaultIntents.Fulfill(address(user), 1);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), 1);

        assertEq(IERC20Like(asset).balanceOf(address(vault)), 1);
        assertEq(IERC20Like(asset).balanceOf(address(user)),  DEPOSIT_AMOUNT - 1);
        assertEq(vault.balanceOf(address(user)),              0);
    }

    function test_fulfill_worksWhenInvalidPermitButApprovalExists() public {
        _removeAllBalanceFromVault();

        _createRequest(userShares, block.timestamp + 100);

        // Deal vault some assets.

        address asset = vault.asset();

        deal(asset, address(vault), DEPOSIT_AMOUNT);

        // Fulfill the request.

        assertEq(IERC20Like(asset).balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(IERC20Like(asset).balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(address(user)),              userShares);

        // Approve the transfer.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares);

        vm.expectEmit(address(savingsVaultIntents));
        emit SavingsVaultIntents.Fulfill(address(user), 1);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), 1);

        assertEq(IERC20Like(asset).balanceOf(address(vault)), 1);
        assertEq(IERC20Like(asset).balanceOf(address(user)),  DEPOSIT_AMOUNT - 1);
        assertEq(vault.balanceOf(address(user)),              0);

        // Request should be deleted.

        ( 
            address vault_,
            uint256 shares_,
            address recipient_,
            uint256 deadline_,
            uint8   v_,
            bytes32 r_,
            bytes32 s_ 
        ) = savingsVaultIntents.requests(user, 1);

        assertEq(vault_,     address(0));
        assertEq(shares_,    0);
        assertEq(recipient_, address(0));
        assertEq(deadline_,  0);
        assertEq(v_,         0);
        assertEq(r_,         0);
        assertEq(s_,         0);
    }

    function _createRequest(uint256 shares_, uint256 deadline_) internal {
        ( uint8 v, bytes32 r, bytes32 s ) = _generateSignature(shares_, deadline_);

        vm.prank(user);
        savingsVaultIntents.request({
            vault:     address(vault),
            shares:    shares_,
            recipient: user,
            deadline:  deadline_,
            v:         v,
            r:         r,
            s:         s
        });
    }

}
