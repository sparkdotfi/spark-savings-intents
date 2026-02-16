// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { IAccessControl } from "../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IERC20Like, TestBase } from "./Base.t.sol";

import { ISavingsVaultIntents } from "../src/interfaces/ISavingsVaultIntents.sol";
import { SavingsVaultIntents }  from "../src/SavingsVaultIntents.sol";

contract ConstructorTests is TestBase {

    // Failure tests

    function test_constructor_invalidAdmin() external {
        vm.expectRevert(ISavingsVaultIntents.InvalidAdminAddress.selector);
        new SavingsVaultIntents(address(0), relayer, 1 days, 1e6);
    }

    function test_constructor_invalidRelayer() external {
        vm.expectRevert(ISavingsVaultIntents.InvalidRelayerAddress.selector);
        new SavingsVaultIntents(admin, address(0), 1 days, 1e6);
    }

    function test_constructor_invalidMaxDeadline() external {
        vm.expectRevert(ISavingsVaultIntents.InvalidMaxDeadline.selector);
        new SavingsVaultIntents(admin, relayer, 0, 1e6);
    }

    function test_constructor_invalidMinIntentShares() external {
        vm.expectRevert(ISavingsVaultIntents.InvalidMinIntentShares.selector);
        new SavingsVaultIntents(admin, relayer, 1 days, 0);
    }

    // Success tests

    function test_constructor() external {
        SavingsVaultIntents intentInstance = new SavingsVaultIntents({
            admin            : makeAddr("admin"),
            relayer          : makeAddr("relayer"),
            maxDeadline_     : 1 days,
            minIntentShares_ : 1e6
        });

        assertEq(intentInstance.hasRole(defaultAdminRole, makeAddr("admin")),   true);
        assertEq(intentInstance.hasRole(relayerRole,      makeAddr("relayer")), true);

        assertEq(intentInstance.maxDeadline(),     1 days);
        assertEq(intentInstance.minIntentShares(), 1e6);
    }
}

contract SetMaxDeadlineTests is TestBase {

    // Failure tests

    function test_setMaxDeadline_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                savingsVaultIntents.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(unauthorized);
        savingsVaultIntents.setMaxDeadline(2 days);
    }

    function test_setMaxDeadline_invalidMaxDeadlineBoundary() external {
        vm.expectRevert(ISavingsVaultIntents.InvalidMaxDeadline.selector);
        vm.prank(admin);
        savingsVaultIntents.setMaxDeadline(0);

        vm.prank(admin);
        savingsVaultIntents.setMaxDeadline(1);
    }

    // Success tests

    function test_setMaxDeadline() external {
        assertEq(savingsVaultIntents.maxDeadline(), 1 days);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.MaxDeadlineUpdated(2 days);

        vm.prank(admin);
        savingsVaultIntents.setMaxDeadline(2 days);

        assertEq(savingsVaultIntents.maxDeadline(), 2 days);
    }

}

contract SetMinIntentSharesTests is TestBase {

    // Failure tests

    function test_setMinIntentShares_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                savingsVaultIntents.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(unauthorized);
        savingsVaultIntents.setMinIntentShares(1e6);
    }

    function test_setMinIntentShares_invalidMinIntentSharesBoundary() external {
        vm.expectRevert(ISavingsVaultIntents.InvalidMinIntentShares.selector);
        vm.prank(admin);
        savingsVaultIntents.setMinIntentShares(0);

        vm.prank(admin);
        savingsVaultIntents.setMinIntentShares(1);
    }

    // Success tests

    function test_setMinIntentShares() external {
        assertEq(savingsVaultIntents.minIntentShares(), 1e6);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.MinIntentSharesUpdated(2e6);

        vm.prank(admin);
        savingsVaultIntents.setMinIntentShares(2e6);

        assertEq(savingsVaultIntents.minIntentShares(), 2e6);
    }

}

contract SavingsVaultIntentsRequestTests is TestBase {

    // Failure tests

    function test_request_invalidVaultAddress() public {
        vm.expectRevert(ISavingsVaultIntents.InvalidVaultAddress.selector);
        savingsVaultIntents.request({
            vault     : address(0),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + 100,
            v         : 0,
            r         : 0,
            s         : 0
        });
    }

    function test_request_invalidRecipientAddress() public {
        vm.expectRevert(ISavingsVaultIntents.InvalidRecipientAddress.selector);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : address(0),
            deadline  : block.timestamp + 100,
            v         : 0,
            r         : 0,
            s         : 0
        });
    }

    function test_request_invalidIntentSharesBoundary() external {
        uint256 minIntentShares = savingsVaultIntents.minIntentShares();

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.InvalidIntentShares.selector,
                minIntentShares,
                minIntentShares - 1
            )
        );

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : minIntentShares - 1,
            recipient : user,
            deadline  : block.timestamp + 100,
            v         : 0,
            r         : 0,
            s         : 0
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : minIntentShares,
            recipient : user,
            deadline  : block.timestamp + 100,
            v         : 0,
            r         : 0,
            s         : 0
        });
    }

    function test_request_invalidDeadlineBoundary_deadlineTooLow() public {
        uint256 maxDeadline = savingsVaultIntents.maxDeadline();

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.InvalidDeadline.selector,
                maxDeadline,
                block.timestamp
            )
        );

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp,
            v         : 0,
            r         : 0,
            s         : 0
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + 1,
            v         : 0,
            r         : 0,
            s         : 0
        });
    }

    function test_request_invalidDeadlineBoundary_deadlineTooHigh() public {
        uint256 maxDeadline = savingsVaultIntents.maxDeadline();

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.InvalidDeadline.selector,
                maxDeadline,
                block.timestamp + maxDeadline + 1
            )
        );

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + maxDeadline + 1,
            v         : 0,
            r         : 0,
            s         : 0
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + maxDeadline,
            v         : 0,
            r         : 0,
            s         : 0
        });
    }

    // Success tests

    function test_request() public {
        _assertEmptyRequest(user, 1);

        ( uint8 v, bytes32 r, bytes32 s ) = _generateSignature(userShares, block.timestamp + 100);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            requestId : 1,
            vault     : address(vault),
            shares    : userShares,
            deadline  : block.timestamp + 100,
            v         : v,
            r         : r,
            s         : s
        });

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + 100,
            v         : v,
            r         : r,
            s         : s
        });

        assertEq(requestId, 1);

        _assertRequest({
            account           : user,
            requestId         : requestId,
            expectedVault     : address(vault),
            expectedShares    : userShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100,
            expectedV         : v,
            expectedR         : r,
            expectedS         : s
        });
    }

}

contract SavingsVaultIntentsCancelTest is TestBase {

    // Failure tests

    function test_cancel_requestNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.RequestNotFound.selector,
                user,
                1
            )
        );

        vm.prank(user);
        savingsVaultIntents.cancel(1);
    }

    // Success tests

    function test_cancel() public {
        ( uint8 v, bytes32 r, bytes32 s ) = _generateSignature(userShares, block.timestamp + 100);

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + 100,
            v         : v,
            r         : r,
            s         : s
        });
        assertEq(requestId, 1);

        _assertRequest({
            account           : user,
            requestId         : requestId,
            expectedVault     : address(vault),
            expectedShares    : userShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100,
            expectedV         : v,
            expectedR         : r,
            expectedS         : s
        });

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCancelled(user, requestId);

        vm.prank(user);
        savingsVaultIntents.cancel(requestId);

        _assertEmptyRequest(user, requestId);
    }

}

contract SavingsVaultIntentsFulfillTest is TestBase {

    // Failure tests

    function test_fulfill_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                relayerRole
            )
        );

        vm.prank(unauthorized);
        savingsVaultIntents.fulfill(user, 1);
    }

    function test_fulfill_requestNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.RequestNotFound.selector,
                user,
                1
            )
        );
        
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, 1);
    }

    function test_fulfill_insufficientUserFundsBoundary() public {
        _drainVaultBalance();

        _fundVaultBalance(DEPOSIT_AMOUNT);
        
        uint256 requestId = _createRequest(userShares + 1, block.timestamp + 100);

        assertEq(requestId, 1);

        vm.expectRevert("SparkVault/insufficient-balance");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);

        requestId = _createRequest(userShares, block.timestamp + 100);

        assertEq(requestId, 2);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);
    }

    function test_fulfill_insufficientVaultFundsBoundary() public {
        uint256 assetsAtBoundary    = vault.convertToAssets(userShares); // 999_999_999999
        uint256 assetsUnderBoundary = vault.convertToAssets(userShares) - 1; // 999_999_999998

        _drainVaultBalance();

        uint256 requestId = _createRequest(userShares, block.timestamp + 100);
        
        // Vault have zero assets to redeem userShares
        vm.expectRevert("SparkVault/insufficient-liquidity");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);

        // Vault have one less than the amount of assets required to redeem userShares
        _fundVaultBalance(assetsUnderBoundary);
        
        vm.expectRevert("SparkVault/insufficient-liquidity");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);

        // Vault have exact amount of assets required to redeem
        _fundVaultBalance(assetsAtBoundary);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);
    }

    function test_fulfill_deadlineExceededBoundary() public {
        _drainVaultBalance();

        uint256 deadline = block.timestamp + 10;

        uint256 requestId = _createRequest(userShares, deadline);

        assertEq(requestId, 1);

        vm.warp(deadline + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.DeadlineExceeded.selector,
                user,
                requestId,
                deadline
            )
        );

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);

        vm.warp(deadline);

        _fundVaultBalance(vault.convertToAssets(userShares));

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);
    }

    // Success tests

    function test_fulfill() public {
        _drainVaultBalance();

        uint256 requestId = _createRequest(userShares, block.timestamp + 100);

        assertEq(requestId, 1);

        _fundVaultBalance(DEPOSIT_AMOUNT);

        // Fulfill the request.

        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(underlyingAsset.balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(address(user)),            userShares);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestFulfilled(address(user), requestId);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), requestId);

        assertEq(underlyingAsset.balanceOf(address(vault)), 1);
        assertEq(underlyingAsset.balanceOf(address(user)),  DEPOSIT_AMOUNT - 1); // Rounding
        assertEq(vault.balanceOf(address(user)),            0);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply - userShares);

        _assertEmptyRequest(user, requestId);
    }

    function test_fulfill_worksWhenInvalidPermitButApprovalExists() public {
        _drainVaultBalance();

        uint256 requestId = _createRequest(userShares, block.timestamp + 100);

        assertEq(requestId, 1);

        _fundVaultBalance(DEPOSIT_AMOUNT);

        // Fulfill the request.

        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(underlyingAsset.balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(address(user)),            userShares);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply);

        // Approve the transfer.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestFulfilled(address(user), requestId);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), requestId);

        assertEq(underlyingAsset.balanceOf(address(vault)), 1);
        assertEq(underlyingAsset.balanceOf(address(user)),  DEPOSIT_AMOUNT - 1); // Rounding
        assertEq(vault.balanceOf(address(user)),            0);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply - userShares);

        // Request should be deleted.
        _assertEmptyRequest(user, requestId);
    }

    // Helper functions

    function _createRequest(uint256 shares_, uint256 deadline_)
        internal 
        returns (uint256 requestId) 
    {
        ( uint8 v, bytes32 r, bytes32 s ) = _generateSignature(shares_, deadline_);

        vm.prank(user);
        requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : shares_,
            recipient : user,
            deadline  : deadline_,
            v         : v,
            r         : r,
            s         : s
        });
    }

}
