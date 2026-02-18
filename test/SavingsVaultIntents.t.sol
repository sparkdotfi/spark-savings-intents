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

    function test_constructor_invalidMaxIntentAssets() external {
        vm.expectRevert(ISavingsVaultIntents.InvalidMaxIntentAssets.selector);
        new SavingsVaultIntents(admin, relayer, 1 days, 0);
    }

    // Success tests

    function test_constructor() external {
        address admin_   = makeAddr("admin");
        address relayer_ = makeAddr("relayer");

        SavingsVaultIntents intentInstance = new SavingsVaultIntents({
            admin            : admin_,
            relayer          : relayer_,
            maxDeadline_     : 1 days,
            maxIntentAssets_ : 100_000_000e6
        });

        assertEq(intentInstance.hasRole(intentInstance.DEFAULT_ADMIN_ROLE(), admin_),   true);
        assertEq(intentInstance.hasRole(intentInstance.RELAYER(),            relayer_), true);

        assertEq(intentInstance.maxDeadline(),     1 days);
        assertEq(intentInstance.maxIntentAssets(), 100_000_000e6);
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

contract SetMinIntentAssetsTests is TestBase {

    // Failure tests

    function test_setMinIntentAssets_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                savingsVaultIntents.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(unauthorized);
        savingsVaultIntents.setMinIntentAssets(1e6);
    }

    function test_setMinIntentAssets_minIntentAssetsAboveMaxBoundary() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.MinIntentAssetsAboveMax.selector,
                MAX_INTENT_ASSETS,
                MAX_INTENT_ASSETS
            )
        );

        vm.prank(admin);
        savingsVaultIntents.setMinIntentAssets(MAX_INTENT_ASSETS);

        vm.prank(admin);
        savingsVaultIntents.setMinIntentAssets(MAX_INTENT_ASSETS - 1);
    }

    // Success tests

    function test_setMinIntentAssets() external {
        assertEq(savingsVaultIntents.minIntentAssets(), MIN_INTENT_ASSETS);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.MinIntentAssetsUpdated(0);

        vm.prank(admin);
        savingsVaultIntents.setMinIntentAssets(0);

        assertEq(savingsVaultIntents.minIntentAssets(), 0);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.MinIntentAssetsUpdated(10_000_000e6);

        vm.prank(admin);
        savingsVaultIntents.setMinIntentAssets(10_000_000e6);

        assertEq(savingsVaultIntents.minIntentAssets(), 10_000_000e6);
    }

}

contract SetMaxIntentAssetsTests is TestBase {

    // Failure tests

    function test_setMaxIntentAssets_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                savingsVaultIntents.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(unauthorized);
        savingsVaultIntents.setMaxIntentAssets(1e6);
    }

    function test_setMaxIntentAssets_invalidMaxIntentAssetsBoundary() external {
        // Setting maxIntentAssets zero when minIntentAssets > 0 should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.MaxIntentAssetsBelowMin.selector,
                0,
                MIN_INTENT_ASSETS
            )
        );

        vm.prank(admin);
        savingsVaultIntents.setMaxIntentAssets(0);

        // Setting maxIntentAssets zero when minIntentAssets == 0 (0 > 0), should revert
        vm.prank(admin);
        savingsVaultIntents.setMinIntentAssets(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.MaxIntentAssetsBelowMin.selector,
                0,
                0
            )
        );

        vm.prank(admin);
        savingsVaultIntents.setMaxIntentAssets(0);

        // Setting maxIntentAssets to 1 passes when minIntentAssets == 0 (1 > 0)
        vm.prank(admin);
        savingsVaultIntents.setMaxIntentAssets(1);
    }

    function test_setMaxIntentAssets_maxIntentAssetsBelowMinBoundary() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.MaxIntentAssetsBelowMin.selector,
                MIN_INTENT_ASSETS,
                MIN_INTENT_ASSETS
            )
        );

        vm.prank(admin);
        savingsVaultIntents.setMaxIntentAssets(MIN_INTENT_ASSETS);

        vm.prank(admin);
        savingsVaultIntents.setMaxIntentAssets(MIN_INTENT_ASSETS + 1);
    }

    // Success tests

    function test_setMaxIntentAssets() external {
        assertEq(savingsVaultIntents.maxIntentAssets(), MAX_INTENT_ASSETS);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.MaxIntentAssetsUpdated(100_000e6);

        vm.prank(admin);
        savingsVaultIntents.setMaxIntentAssets(100_000e6);

        assertEq(savingsVaultIntents.maxIntentAssets(), 100_000e6);
    }

}

contract UpdateWhitelistTests is TestBase {

    // Failure tests

    function test_updateWhitelist_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                savingsVaultIntents.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(unauthorized);
        savingsVaultIntents.updateWhitelist(makeAddr("vault"), true);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                savingsVaultIntents.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(unauthorized);
        savingsVaultIntents.updateWhitelist(address(vault), false);
    }

    function test_updateWhitelist_invalidVaultAddress() external {
        vm.expectRevert(ISavingsVaultIntents.InvalidVaultAddress.selector);
        vm.prank(admin);
        savingsVaultIntents.updateWhitelist(address(0), true);

        vm.expectRevert(ISavingsVaultIntents.InvalidVaultAddress.selector);
        vm.prank(admin);
        savingsVaultIntents.updateWhitelist(address(0), false);
    }

    // Success tests

    function test_updateWhitelist() external {
        assertEq(savingsVaultIntents.vaultWhitelist(address(vault)),       true);
        assertEq(savingsVaultIntents.vaultWhitelist(makeAddr("newVault")),   false);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.WhitelistUpdated(address(vault), false);

        vm.prank(admin);
        savingsVaultIntents.updateWhitelist(address(vault), false);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.WhitelistUpdated(makeAddr("newVault"), true);

        vm.prank(admin);
        savingsVaultIntents.updateWhitelist(makeAddr("newVault"), true);

        assertEq(savingsVaultIntents.vaultWhitelist(address(vault)),       false);
        assertEq(savingsVaultIntents.vaultWhitelist(makeAddr("newVault")), true);
    }

}

contract RequestTests is TestBase {

    // Failure tests

    function test_request_vaultNotWhitelisted() public {
        vm.expectRevert(ISavingsVaultIntents.VaultNotWhitelisted.selector);
        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(0),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });
    }

    function test_request_invalidRecipientAddress() public {
        vm.expectRevert(ISavingsVaultIntents.InvalidRecipientAddress.selector);
        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : address(0),
            deadline  : block.timestamp + 100
        });
    }

    function test_request_intentAssetsBelowMinBoundary() external {
        uint256 minIntentSharesAtBoundary    = vault.convertToShares(MIN_INTENT_ASSETS) + 1; // Rounding
        uint256 minIntentSharesUnderBoundary = minIntentSharesAtBoundary - 1;
        uint256 minIntentAssetsUnderBoundary = vault.convertToAssets(minIntentSharesUnderBoundary);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.IntentAssetsBelowMin.selector,
                MIN_INTENT_ASSETS,
                minIntentAssetsUnderBoundary
            )
        );

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : minIntentSharesUnderBoundary,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : minIntentSharesAtBoundary,
            recipient : user,
            deadline  : block.timestamp + 100
        });
    }

    function test_request_intentAssetsAboveMaxBoundary() external {
        uint256 maxIntentSharesAtBoundary    = vault.convertToShares(MAX_INTENT_ASSETS) + 1; // Rounding
        uint256 maxIntentSharesAboveBoundary = maxIntentSharesAtBoundary + 1;
        uint256 maxIntentAssetsAboveBoundary = vault.convertToAssets(maxIntentSharesAboveBoundary);

        _depositToVault(user, MAX_INTENT_ASSETS + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.IntentAssetsAboveMax.selector,
                MAX_INTENT_ASSETS,
                maxIntentAssetsAboveBoundary
            )
        );

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : maxIntentSharesAboveBoundary,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : maxIntentSharesAtBoundary,
            recipient : user,
            deadline  : block.timestamp + 100
        });
    }

    function test_request_insufficientSharesBoundary() external {
        uint256 requestedSharesAtBoundary   = userShares;
        uint256 requestedSharesOverBoundary = userShares + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.InsufficientShares.selector,
                requestedSharesOverBoundary,
                userShares
            )
        );

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : requestedSharesOverBoundary,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : requestedSharesAtBoundary,
            recipient : user,
            deadline  : block.timestamp + 100
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
            deadline  : block.timestamp
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + 1
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
            deadline  : block.timestamp + maxDeadline + 1
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + maxDeadline
        });
    }

    // Success tests

    function test_request() public {
        _assertEmptyRequest(user);

        assertEq(savingsVaultIntents.requestCount(), 0);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            requestId : 1,
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        assertEq(requestId, 1);

        assertEq(savingsVaultIntents.requestCount(), 1);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(vault),
            expectedShares    : userShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });
    }

    function test_request_overwriteRequest() public {
        _assertEmptyRequest(user);

        assertEq(savingsVaultIntents.requestCount(), 0);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            requestId : 1,
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        assertEq(requestId, 1);

        assertEq(savingsVaultIntents.requestCount(), 1);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(vault),
            expectedShares    : userShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        // Overwriting request 1 with userShares - 10

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            requestId : 2,
            vault     : address(vault),
            shares    : userShares - 10,
            recipient : user,
            deadline  : block.timestamp + 200
        });

        vm.prank(user);
        requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares - 10,
            recipient : user,
            deadline  : block.timestamp + 200
        });

        assertEq(requestId, 2);

        assertEq(savingsVaultIntents.requestCount(), 2);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(vault),
            expectedShares    : userShares - 10,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 200
        });
    }

}

contract CancelTests is TestBase {

    // Failure tests

    function test_cancel_requestNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.RequestNotFound.selector,
                user
            )
        );

        vm.prank(user);
        savingsVaultIntents.cancel();
    }

    // Success tests

    function test_cancel() public {
        assertEq(savingsVaultIntents.requestCount(), 0);

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        assertEq(requestId, 1);

        assertEq(savingsVaultIntents.requestCount(), 1);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(vault),
            expectedShares    : userShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCancelled(user, requestId);

        vm.prank(user);
        savingsVaultIntents.cancel();

        assertEq(savingsVaultIntents.requestCount(), 1);

        _assertEmptyRequest(user);
    }

    function test_cancel_afterRequestOverwrite() public {
        assertEq(savingsVaultIntents.requestCount(), 0);

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        assertEq(requestId, 1);

        assertEq(savingsVaultIntents.requestCount(), 1);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(vault),
            expectedShares    : userShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        // Overwriting request 1

        vm.prank(user);
        requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares/2,
            recipient : user,
            deadline  : block.timestamp + 200
        });
    
        assertEq(requestId, 2);

        assertEq(savingsVaultIntents.requestCount(), 2);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(vault),
            expectedShares    : userShares/2,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 200
        });
        
        // Cancel event will have overwritten requestId
        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCancelled(user, requestId);

        vm.prank(user);
        savingsVaultIntents.cancel();

        assertEq(savingsVaultIntents.requestCount(), 2);

        _assertEmptyRequest(user);
    }

}

contract FulfillTests is TestBase {

    // Failure tests

    function test_fulfill_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                savingsVaultIntents.RELAYER()
            )
        );

        vm.prank(unauthorized);
        savingsVaultIntents.fulfill(user, 1);
    }

    function test_fulfill_requestNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.RequestNotFound.selector,
                user
            )
        );
        
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.RequestNotFound.selector,
                address(0)
            )
        );
        
        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(0), 1);

        uint256 requestId = _approveAndCreateRequest(user, userShares, block.timestamp + 100);
        
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);
    }

    function test_fulfill_requestNotFoundRaceCondition() public {
        // User creates request A
        uint256 requestA = _approveAndCreateRequest(user, userShares, block.timestamp + 100);

        assertEq(requestA, 1);

        // User cancels request A
        vm.prank(user);
        savingsVaultIntents.cancel();

        // User creates request B with half of his shares. No approval is needed again.
        uint256 requestB = _createRequest(user, userShares/2, block.timestamp + 100);

        assertEq(requestB, 2);

        // Relayer captured the request A and trying to fulfill
        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.RequestNotFound.selector,
                user
            )
        );
        
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestA);

        // Relayer now trying to fulfill request B

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestB);
    }

    function test_fulfill_deadlineExceededBoundary() public {
        uint256 deadline = block.timestamp + 10;

        uint256 requestId = _approveAndCreateRequest(user, userShares, deadline);

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

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);
    }

    function test_fulfill_noSharesAllowance() public {
        // Creating intent request without approval of shares
        uint256 requestId = _createRequest(user, userShares, block.timestamp + 100);

        assertEq(requestId, 1);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), 0);

        // Fulfill the request will fail with insufficient allowances
        vm.expectRevert("SparkVault/insufficient-allowance");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), requestId);

        // Approve the transfer.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), userShares);

        // Same request can be fulfilled after approval
        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), requestId);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), 0);
    }


    function test_fulfill_insufficientUserFundsBoundary() external {
        assertEq(vault.balanceOf(address(user)), userShares);
        
        uint256 requestId = _approveAndCreateRequest(user, userShares, block.timestamp + 100);

        assertEq(requestId, 1);

        // User redeems all of his shares before fulfill
        vm.prank(user);
        vault.redeem(userShares, user, user);

        assertEq(vault.balanceOf(address(user)), 0);

        // Request fulfill will fail
        vm.expectRevert("SparkVault/insufficient-balance");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);

        // User deposits DEPOSIT_AMOUNT back to vault. So the existing request will be fulfilled.
        _depositToVault(user, DEPOSIT_AMOUNT);

        assertEq(vault.balanceOf(address(user)), userShares);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);
    }

    function test_fulfill_insufficientVaultFundsBoundary() external {
        _drainVaultBalance();

        uint256 assetsAtBoundary    = vault.convertToAssets(userShares); // 999_999_999999
        uint256 assetsUnderBoundary = vault.convertToAssets(userShares) - 1; // 999_999_999998

        uint256 requestId = _approveAndCreateRequest(user, userShares, block.timestamp + 100);
        
        // Vault have zero assets to redeem userShares, request fulfill fails
        vm.expectRevert("SparkVault/insufficient-liquidity");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);

        _fundVaultBalance(assetsUnderBoundary);
        
        // Vault have one less than the assets required to redeem userShares, request fulfill fails
        vm.expectRevert("SparkVault/insufficient-liquidity");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);

        // Vault have exact amount of assets required to redeem, request fulfilled
        _fundVaultBalance(assetsAtBoundary);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, requestId);
    }

    // Success tests

    function test_fulfill() external {
        // Drain all vault balance and fund exact user deposited amount

        _drainVaultBalance();
        _fundVaultBalance(DEPOSIT_AMOUNT);

        uint256 requestId = _approveAndCreateRequest(user, userShares, block.timestamp + 100);

        assertEq(requestId, 1);

        // Fulfill the request.

        assertEq(underlyingAsset.balanceOf(address(vault)),DEPOSIT_AMOUNT);
        assertEq(underlyingAsset.balanceOf(address(user)), 0);
        assertEq(vault.balanceOf(user),                    userShares);
        assertEq(vault.totalSupply(),                      vaultInitialTotalSupply);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), userShares);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestFulfilled(address(user), requestId);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), requestId);

        assertEq(underlyingAsset.balanceOf(address(vault)), 1);
        assertEq(underlyingAsset.balanceOf(address(user)),  DEPOSIT_AMOUNT - 1); // Rounding
        assertEq(vault.balanceOf(address(user)),            0);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply - userShares);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), 0);

        _assertEmptyRequest(user);
    }

    // Helper functions

    function _approveAndCreateRequest(
        address account,
        uint256 shares_,
        uint256 deadline_
    )
        internal 
        returns (uint256 requestId) 
    {
        // Approve the transfer.
        vm.prank(account);
        vault.approve(address(savingsVaultIntents), shares_);

        // Create request
        requestId = _createRequest(account, shares_, deadline_);
    }

    function _createRequest(
        address account,
        uint256 shares_,
        uint256 deadline_
    )
        internal 
        returns (uint256 requestId) 
    {
        // Create request
        vm.prank(account);
        requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : shares_,
            recipient : account,
            deadline  : deadline_
        });
    }

}
