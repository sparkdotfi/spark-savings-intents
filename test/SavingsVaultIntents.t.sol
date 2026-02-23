// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { IAccessControl } from "../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IERC20Like, IERC4626Like, TestBase } from "./Base.t.sol";

import { ISavingsVaultIntents } from "../src/interfaces/ISavingsVaultIntents.sol";
import { SavingsVaultIntents }  from "../src/SavingsVaultIntents.sol";

contract ConstructorTests is TestBase {

    // Failure tests

    function test_constructor_invalidAdmin() external {
        vm.expectRevert(ISavingsVaultIntents.InvalidAdminAddress.selector);
        new SavingsVaultIntents(address(0), relayer, 1 days);
    }

    function test_constructor_invalidRelayer() external {
        vm.expectRevert(ISavingsVaultIntents.InvalidRelayerAddress.selector);
        new SavingsVaultIntents(admin, address(0), 1 days);
    }

    function test_constructor_invalidMaxDeadline() external {
        vm.expectRevert(ISavingsVaultIntents.InvalidMaxDeadline.selector);
        new SavingsVaultIntents(admin, relayer, 0);
    }

    // Success tests

    function test_constructor() external {
        address admin_   = makeAddr("admin");
        address relayer_ = makeAddr("relayer");

        SavingsVaultIntents intentInstance = new SavingsVaultIntents({
            admin        : admin_,
            relayer      : relayer_,
            maxDeadline_ : 1 days
        });

        assertEq(intentInstance.hasRole(intentInstance.DEFAULT_ADMIN_ROLE(), admin_),   true);
        assertEq(intentInstance.hasRole(intentInstance.RELAYER(),            relayer_), true);

        assertEq(intentInstance.maxDeadline(), 1 days);
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

contract UpdateVaultConfigTests is TestBase {

    // Failure tests

    function test_updateVaultConfig_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                savingsVaultIntents.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(unauthorized);
        savingsVaultIntents.updateVaultConfig(
            makeAddr("vault"),
            true,
            MIN_INTENT_ASSETS_USDC,
            MAX_INTENT_ASSETS_USDC
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                savingsVaultIntents.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(unauthorized);
        savingsVaultIntents.updateVaultConfig(
            address(sparkVaultUSDC),
            true,
            MIN_INTENT_ASSETS_USDC,
            MAX_INTENT_ASSETS_USDC
        );
    }

    function test_updateVaultConfig_invalidVaultAddress() external {
        vm.expectRevert(ISavingsVaultIntents.InvalidVaultAddress.selector);
        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(
            address(0),
            true,
            MIN_INTENT_ASSETS_USDC,
            MAX_INTENT_ASSETS_USDC
        );

        vm.expectRevert(ISavingsVaultIntents.InvalidVaultAddress.selector);
        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(
            address(0),
            true,
            MIN_INTENT_ASSETS_USDC,
            MAX_INTENT_ASSETS_USDC
        );
    }

    function test_updateVaultConfig_invalidIntentAmountBoundsBoundary() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.InvalidIntentAmountBounds.selector,
                1,
                0
            )
        );

        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(
            address(sparkVaultUSDC),
            true,
            1,
            0
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.InvalidIntentAmountBounds.selector,
                0,
                0
            )
        );

        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(
            address(sparkVaultUSDC),
            true,
            0,
            0
        );

        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(
            address(sparkVaultUSDC),
            true,
            0,
            1
        );

        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(
            address(sparkVaultUSDC),
            false,
            0,
            1
        );
    }

    // Success tests

    function test_updateVaultConfig() external {
        (
            bool    whitelisted,
            uint256 minIntentAssets,
            uint256 maxIntentAssets
        ) = savingsVaultIntents.vaultConfig(address(sparkVaultUSDC));

        assertEq(whitelisted,     true);
        assertEq(minIntentAssets, MIN_INTENT_ASSETS_USDC);
        assertEq(maxIntentAssets, MAX_INTENT_ASSETS_USDC);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.VaultConfigUpdated(
            address(sparkVaultUSDC),
            false,
            0,
            1
        );

        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(
            address(sparkVaultUSDC),
            false,
            0,
            1
        );

        (
            whitelisted,
            minIntentAssets,
            maxIntentAssets
        ) = savingsVaultIntents.vaultConfig(address(sparkVaultUSDC));

        assertEq(whitelisted,     false);
        assertEq(minIntentAssets, 0);
        assertEq(maxIntentAssets, 1);
    }

    function test_updateVaultConfig_newVault() external {
        (
            bool    whitelisted,
            uint256 minIntentAssets,
            uint256 maxIntentAssets
        ) = savingsVaultIntents.vaultConfig(makeAddr("newVault"));

        assertEq(whitelisted,     false);
        assertEq(minIntentAssets, 0);
        assertEq(maxIntentAssets, 0);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.VaultConfigUpdated(
            makeAddr("newVault"),
            true,
            MIN_INTENT_ASSETS_USDC,
            MAX_INTENT_ASSETS_USDC
        );

        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(
            makeAddr("newVault"),
            true,
            MIN_INTENT_ASSETS_USDC,
            MAX_INTENT_ASSETS_USDC
        );

        (
            whitelisted,
            minIntentAssets,
            maxIntentAssets
        ) = savingsVaultIntents.vaultConfig(makeAddr("newVault"));

        assertEq(whitelisted,     true);
        assertEq(minIntentAssets, MIN_INTENT_ASSETS_USDC);
        assertEq(maxIntentAssets, MAX_INTENT_ASSETS_USDC);
    }

}

contract RequestTests is TestBase {

    // Failure tests

    function test_request_vaultNotWhitelisted() public {
        vm.expectRevert(ISavingsVaultIntents.VaultNotWhitelisted.selector);
        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(0),
            shares    : userSpUSDCShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });
    }

    function test_request_invalidRecipientAddress() public {
        vm.expectRevert(ISavingsVaultIntents.InvalidRecipientAddress.selector);
        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : userSpUSDCShares,
            recipient : address(0),
            deadline  : block.timestamp + 100
        });
    }

    function test_request_intentAssetsBelowMinBoundary() external {
        uint256 minIntentSharesAtBoundary    = sparkVaultUSDC.convertToShares(MIN_INTENT_ASSETS_USDC) + 1; // Rounding
        uint256 minIntentSharesUnderBoundary = minIntentSharesAtBoundary - 1;
        uint256 minIntentAssetsUnderBoundary = sparkVaultUSDC.convertToAssets(minIntentSharesUnderBoundary);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.IntentAssetsBelowMin.selector,
                MIN_INTENT_ASSETS_USDC,
                minIntentAssetsUnderBoundary
            )
        );

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : minIntentSharesUnderBoundary,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : minIntentSharesAtBoundary,
            recipient : user,
            deadline  : block.timestamp + 100
        });
    }

    function test_request_intentAssetsAboveMaxBoundary() external {
        uint256 maxIntentSharesAtBoundary    = sparkVaultUSDC.convertToShares(MAX_INTENT_ASSETS_USDC) + 1; // Rounding
        uint256 maxIntentSharesAboveBoundary = maxIntentSharesAtBoundary + 1;
        uint256 maxIntentAssetsAboveBoundary = sparkVaultUSDC.convertToAssets(maxIntentSharesAboveBoundary);

        _depositToVault(user, sparkVaultUSDC, MAX_INTENT_ASSETS_USDC + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.IntentAssetsAboveMax.selector,
                MAX_INTENT_ASSETS_USDC,
                maxIntentAssetsAboveBoundary
            )
        );

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : maxIntentSharesAboveBoundary,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : maxIntentSharesAtBoundary,
            recipient : user,
            deadline  : block.timestamp + 100
        });
    }

    function test_request_insufficientSharesBoundary() external {
        uint256 requestedSharesAtBoundary   = userSpUSDCShares;
        uint256 requestedSharesOverBoundary = userSpUSDCShares + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.InsufficientShares.selector,
                requestedSharesOverBoundary,
                userSpUSDCShares
            )
        );

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : requestedSharesOverBoundary,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
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
            vault     : address(sparkVaultUSDC),
            shares    : userSpUSDCShares,
            recipient : user,
            deadline  : block.timestamp
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : userSpUSDCShares,
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
            vault     : address(sparkVaultUSDC),
            shares    : userSpUSDCShares,
            recipient : user,
            deadline  : block.timestamp + maxDeadline + 1
        });

        vm.prank(user);
        savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : userSpUSDCShares,
            recipient : user,
            deadline  : block.timestamp + maxDeadline
        });
    }

    // Success tests

    function test_request() public {
        _assertEmptyRequest(user, sparkVaultUSDC);

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 0);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            vault     : address(sparkVaultUSDC),
            requestId : 1,
            shares    : userSpUSDCShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : userSpUSDCShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        assertEq(requestId, 1);

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 1);

        _assertRequest({
            account           : user,
            vault             : sparkVaultUSDC,
            expectedRequestId : requestId,
            expectedShares    : userSpUSDCShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });
    }

    function test_request_overwriteRequest() public {
        _assertEmptyRequest(user, sparkVaultUSDC);

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 0);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            vault     : address(sparkVaultUSDC),
            requestId : 1,
            shares    : userSpUSDCShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : userSpUSDCShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        assertEq(requestId, 1);

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 1);

        _assertRequest({
            account           : user,
            vault             : sparkVaultUSDC,
            expectedRequestId : requestId,
            expectedShares    : userSpUSDCShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        // Overwriting request 1 with userShares - 10

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            vault     : address(sparkVaultUSDC),
            requestId : 2,
            shares    : userSpUSDCShares - 10,
            recipient : user,
            deadline  : block.timestamp + 200
        });

        vm.prank(user);
        requestId = savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : userSpUSDCShares - 10,
            recipient : user,
            deadline  : block.timestamp + 200
        });

        assertEq(requestId, 2);

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 2);

        _assertRequest({
            account           : user,
            vault             : sparkVaultUSDC,
            expectedRequestId : requestId,
            expectedShares    : userSpUSDCShares - 10,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 200
        });
    }

    function test_request_multipleVaults_perVaultRequestCountIsolation() public {
        _assertEmptyRequest(user, sparkVaultUSDC);
        _assertEmptyRequest(user, sparkVaultETH);

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 0);
        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultETH)),  0);

        // Create request for sparkVaultUSDC

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            vault     : address(sparkVaultUSDC),
            requestId : 1,
            shares    : userSpUSDCShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        vm.prank(user);
        uint256 requestIdVaultUSDC = savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : userSpUSDCShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        // Create request for sparkVaultETH

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            vault     : address(sparkVaultETH),
            requestId : 1,
            shares    : userSpETHShares,
            recipient : user,
            deadline  : block.timestamp + 200
        });

        vm.prank(user);
        uint256 requestIdVaultETH = savingsVaultIntents.request({
            vault     : address(sparkVaultETH),
            shares    : userSpETHShares,
            recipient : user,
            deadline  : block.timestamp + 200
        });

        assertEq(requestIdVaultUSDC, 1);
        assertEq(requestIdVaultETH,  1);

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 1);
        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultETH)),  1);

        _assertRequest({
            account           : user,
            vault             : sparkVaultUSDC,
            expectedRequestId : requestIdVaultUSDC,
            expectedShares    : userSpUSDCShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        _assertRequest({
            account           : user,
            vault             : sparkVaultETH,
            expectedRequestId : requestIdVaultETH,
            expectedShares    : userSpETHShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 200
        });

        // Overwriting request sparkVaultUSDC with userShares - 10

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            vault     : address(sparkVaultUSDC),
            requestId : 2,
            shares    : userSpUSDCShares - 10,
            recipient : user,
            deadline  : block.timestamp + 200
        });

        vm.prank(user);
        requestIdVaultUSDC = savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : userSpUSDCShares - 10,
            recipient : user,
            deadline  : block.timestamp + 200
        });

        assertEq(requestIdVaultUSDC, 2);

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 2);

        _assertRequest({
            account           : user,
            vault             : sparkVaultUSDC,
            expectedRequestId : requestIdVaultUSDC,
            expectedShares    : userSpUSDCShares - 10,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 200
        });

        // Request of sparkVaultETH will remain same.

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultETH)), 1);

        _assertRequest({
            account           : user,
            vault             : sparkVaultETH,
            expectedRequestId : requestIdVaultETH,
            expectedShares    : userSpETHShares,
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
                user,
                address(0)
            )
        );

        vm.prank(user);
        savingsVaultIntents.cancel(address(0));

        uint256 requestId = _createRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares,
            block.timestamp + 100
        );

        assertEq(requestId, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.RequestNotFound.selector,
                user,
                address(sparkVaultETH)
            )
        );

        vm.prank(user);
        savingsVaultIntents.cancel(address(sparkVaultETH));
    }

    // Success tests

    function test_cancel() public {
        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 0);

        uint256 requestId = _createRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares,
            block.timestamp + 100
        );

        assertEq(requestId, 1);

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 1);

        _assertRequest({
            account           : user,
            vault             : sparkVaultUSDC,
            expectedRequestId : requestId,
            expectedShares    : userSpUSDCShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCancelled(user, address(sparkVaultUSDC), requestId);

        vm.prank(user);
        savingsVaultIntents.cancel(address(sparkVaultUSDC));

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 1);

        _assertEmptyRequest(user, sparkVaultUSDC);
    }

    function test_cancel_multipleVaults_onlyAffectsTargetVault() public {
        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 0);
        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultETH)),  0);

        uint256 requestIdVaultUSDC = _createRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares,
            block.timestamp + 100
        );

        uint256 requestIdVaultETH = _createRequest(
            user,
            sparkVaultETH,
            userSpETHShares,
            block.timestamp + 200
        );

        assertEq(requestIdVaultUSDC, 1);
        assertEq(requestIdVaultETH,  1);

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 1);
        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultETH)),  1);

        _assertRequest({
            account           : user,
            vault             : sparkVaultUSDC,
            expectedRequestId : requestIdVaultUSDC,
            expectedShares    : userSpUSDCShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        _assertRequest({
            account           : user,
            vault             : sparkVaultETH,
            expectedRequestId : requestIdVaultETH,
            expectedShares    : userSpETHShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 200
        });

        // Cancelling sparkVaultUSDC request, Cancel event should have requestIdVaultUSDC
    
        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCancelled(
            user,
            address(sparkVaultUSDC),
            requestIdVaultUSDC
        );

        vm.prank(user);
        savingsVaultIntents.cancel(address(sparkVaultUSDC));

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 1);

        _assertEmptyRequest(user, sparkVaultUSDC);

        // Request sparkVaultETH will not be affected

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultETH)),  1);

        _assertRequest({
            account           : user,
            vault             : sparkVaultETH,
            expectedRequestId : requestIdVaultETH,
            expectedShares    : userSpETHShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 200
        });
    }

    function test_cancel_afterRequestOverwrite() public {
        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 0);

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : userSpUSDCShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        assertEq(requestId, 1);

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 1);

        _assertRequest({
            account           : user,
            vault             : sparkVaultUSDC,
            expectedRequestId : requestId,
            expectedShares    : userSpUSDCShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        // Overwriting request 1

        vm.prank(user);
        requestId = savingsVaultIntents.request({
            vault     : address(sparkVaultUSDC),
            shares    : userSpUSDCShares/2,
            recipient : user,
            deadline  : block.timestamp + 200
        });
    
        assertEq(requestId, 2);

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 2);

        _assertRequest({
            account           : user,
            vault             : sparkVaultUSDC,
            expectedRequestId : requestId,
            expectedShares    : userSpUSDCShares/2,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 200
        });
        
        // Cancel event will have overwritten requestId
        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCancelled(user, address(sparkVaultUSDC), requestId);

        vm.prank(user);
        savingsVaultIntents.cancel(address(sparkVaultUSDC));

        assertEq(savingsVaultIntents.vaultToRequestCount(address(sparkVaultUSDC)), 2);

        _assertEmptyRequest(user, sparkVaultUSDC);
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
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), 1);
    }

    function test_fulfill_requestNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.RequestNotFound.selector,
                user,
                address(sparkVaultUSDC)
            )
        );
        
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.RequestNotFound.selector,
                user,
                address(0)
            )
        );
        
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(0), 1);


        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.RequestNotFound.selector,
                address(0),
                address(sparkVaultUSDC)
            )
        );
        
        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(0), address(sparkVaultUSDC), 1);

        // User created request for sparkVaultUSDC

        uint256 requestId = _approveAndCreateRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares,
            block.timestamp + 100
        );

        // Fulfill of sparkVaultETH should fail
        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.RequestNotFound.selector,
                user,
                address(sparkVaultETH)
            )
        );
        
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultETH), requestId);

        // Fulfill of sparkVaultUSDC should succeed

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestId);
    }

    function test_fulfill_requestNotFoundRaceCondition() public {
        // User creates request A
        uint256 requestA = _approveAndCreateRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares,
            block.timestamp + 100
        );

        assertEq(requestA, 1);

        // User cancels request A
        vm.prank(user);
        savingsVaultIntents.cancel(address(sparkVaultUSDC));

        // User creates request B with half of his shares. No approval is needed again.
        uint256 requestB = _createRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares/2,
            block.timestamp + 100
        );

        assertEq(requestB, 2);

        // Relayer captured the request A and trying to fulfill
        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.RequestNotFound.selector,
                user,
                address(sparkVaultUSDC)
            )
        );
        
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestA);

        // Relayer now trying to fulfill request B

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestB);
    }

    function test_fulfill_deadlineExceededBoundary() public {
        uint256 deadline = block.timestamp + 10;

        uint256 requestId = _approveAndCreateRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares,
            deadline
        );

        assertEq(requestId, 1);

        vm.warp(deadline + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISavingsVaultIntents.DeadlineExceeded.selector,
                user,
                address(sparkVaultUSDC),
                requestId,
                deadline
            )
        );

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestId);

        vm.warp(deadline);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestId);
    }

    function test_fulfill_noSharesAllowance() public {
        // Creating intent request without approval of shares
        uint256 requestId = _createRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares,
            block.timestamp + 100
        );

        assertEq(requestId, 1);

        assertEq(sparkVaultUSDC.allowance(user, address(savingsVaultIntents)), 0);

        // Fulfill the request will fail with insufficient allowances
        vm.expectRevert("SparkVault/insufficient-allowance");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestId);

        // Approve the transfer.
        vm.prank(user);
        sparkVaultUSDC.approve(address(savingsVaultIntents), userSpUSDCShares);

        assertEq(sparkVaultUSDC.allowance(user, address(savingsVaultIntents)), userSpUSDCShares);

        // Same request can be fulfilled after approval
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestId);

        assertEq(sparkVaultUSDC.allowance(user, address(savingsVaultIntents)), 0);
    }


    function test_fulfill_insufficientUserFundsBoundary() external {
        assertEq(sparkVaultUSDC.balanceOf(user), userSpUSDCShares);
        
        uint256 requestId = _approveAndCreateRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares,
            block.timestamp + 100
        );

        assertEq(requestId, 1);

        // User redeems all of his shares before fulfill
        vm.prank(user);
        sparkVaultUSDC.redeem(userSpUSDCShares, user, user);

        assertEq(sparkVaultUSDC.balanceOf(user), 0);

        // Request fulfill will fail
        vm.expectRevert("SparkVault/insufficient-balance");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestId);

        // User deposits DEPOSIT_AMOUNT back to vault. So the existing request will be fulfilled.
        _depositToVault(user, sparkVaultUSDC, DEPOSIT_AMOUNT_USDC);

        assertEq(sparkVaultUSDC.balanceOf(user), userSpUSDCShares);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestId);
    }

    function test_fulfill_insufficientVaultFundsBoundary() external {
        _drainVaultBalance(sparkVaultUSDC);

        uint256 assetsAtBoundary    = sparkVaultUSDC.convertToAssets(userSpUSDCShares); // 999_999_999999
        uint256 assetsUnderBoundary = sparkVaultUSDC.convertToAssets(userSpUSDCShares) - 1; // 999_999_999998

        uint256 requestId = _approveAndCreateRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares,
            block.timestamp + 100
        );
        
        // Vault have zero assets to redeem userShares, request fulfill fails
        vm.expectRevert("SparkVault/insufficient-liquidity");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestId);

        _fundVaultBalance(sparkVaultUSDC, assetsUnderBoundary);
        
        // Vault have one less than the assets required to redeem userShares, request fulfill fails
        vm.expectRevert("SparkVault/insufficient-liquidity");
        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestId);

        // Vault have exact amount of assets required to redeem, request fulfilled
        _fundVaultBalance(sparkVaultUSDC, assetsAtBoundary);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestId);
    }

    // Success tests

    function test_fulfill() external {
        IERC20Like underlyingAsset = IERC20Like(sparkVaultUSDC.asset());

        // Drain all vault balance and fund exact user deposited amount

        _drainVaultBalance(sparkVaultUSDC);
        _fundVaultBalance(sparkVaultUSDC, DEPOSIT_AMOUNT_USDC);

        uint256 requestId = _approveAndCreateRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares,
            block.timestamp + 100
        );

        assertEq(requestId, 1);

        // Fulfill the request.

        assertEq(underlyingAsset.balanceOf(address(sparkVaultUSDC)), DEPOSIT_AMOUNT_USDC);
        assertEq(underlyingAsset.balanceOf(user),                    0);

        assertEq(sparkVaultUSDC.balanceOf(user), userSpUSDCShares);
        assertEq(sparkVaultUSDC.totalSupply(),   sparkVaultUSDCInitSupply);

        assertEq(sparkVaultUSDC.allowance(user, address(savingsVaultIntents)), userSpUSDCShares);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestFulfilled(user, address(sparkVaultUSDC), requestId);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestId);

        assertEq(underlyingAsset.balanceOf(address(sparkVaultUSDC)), 1);
        assertEq(underlyingAsset.balanceOf(user),                    DEPOSIT_AMOUNT_USDC - 1); // Rounding

        assertEq(sparkVaultUSDC.balanceOf(user), 0);
        assertEq(sparkVaultUSDC.totalSupply(),   sparkVaultUSDCInitSupply - userSpUSDCShares);

        assertEq(sparkVaultUSDC.allowance(user, address(savingsVaultIntents)), 0);

        _assertEmptyRequest(user, sparkVaultUSDC);
    }

    function test_fulfill_multipleVaults() external {
        IERC20Like underlyingAssetUSDC = IERC20Like(sparkVaultUSDC.asset());
        IERC20Like underlyingAssetETH  = IERC20Like(sparkVaultETH.asset());

        // Drain both vaults balance and fund exact user deposited amount

        _drainVaultBalance(sparkVaultUSDC);
        _drainVaultBalance(sparkVaultETH);

        _fundVaultBalance(sparkVaultUSDC, DEPOSIT_AMOUNT_USDC);
        _fundVaultBalance(sparkVaultETH,  DEPOSIT_AMOUNT_ETH);

        // User creates sparkVaultUSDC and sparkVaultETH requests

        uint256 requestIdVaultUSDC = _approveAndCreateRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares,
            block.timestamp + 100
        );

        uint256 requestIdVaultETH = _approveAndCreateRequest(
            user,
            sparkVaultETH,
            userSpETHShares,
            block.timestamp + 200
        );

        assertEq(requestIdVaultUSDC, 1);
        assertEq(requestIdVaultETH,  1);

        // Fulfill both sparkVaultUSDC and sparkVaultETH requests.

        assertEq(underlyingAssetUSDC.balanceOf(address(sparkVaultUSDC)), DEPOSIT_AMOUNT_USDC);
        assertEq(underlyingAssetETH.balanceOf(address(sparkVaultETH)),   DEPOSIT_AMOUNT_ETH);
        assertEq(underlyingAssetUSDC.balanceOf(user),                    0);
        assertEq(underlyingAssetETH.balanceOf(user),                     0);

        assertEq(sparkVaultUSDC.balanceOf(user), userSpUSDCShares);
        assertEq(sparkVaultETH.balanceOf(user),  userSpETHShares);
        assertEq(sparkVaultUSDC.totalSupply(),   sparkVaultUSDCInitSupply);
        assertEq(sparkVaultETH.totalSupply(),    sparkVaultETHInitSupply);

        assertEq(sparkVaultUSDC.allowance(user, address(savingsVaultIntents)), userSpUSDCShares);
        assertEq(sparkVaultETH.allowance(user,  address(savingsVaultIntents)), userSpETHShares);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestFulfilled(
            user,
            address(sparkVaultUSDC),
            requestIdVaultUSDC
        );

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestIdVaultUSDC);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestFulfilled(
            user,
            address(sparkVaultETH),
            requestIdVaultETH
        );

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultETH), requestIdVaultETH);

        assertEq(underlyingAssetUSDC.balanceOf(address(sparkVaultUSDC)), 1);
        assertEq(underlyingAssetETH.balanceOf(address(sparkVaultETH)),   1);
        assertEq(underlyingAssetUSDC.balanceOf(user),                    DEPOSIT_AMOUNT_USDC - 1); // Rounding
        assertEq(underlyingAssetETH.balanceOf(user),                     DEPOSIT_AMOUNT_ETH - 1);  // Rounding

        assertEq(sparkVaultUSDC.balanceOf(user), 0);
        assertEq(sparkVaultETH.balanceOf(user),  0);
        assertEq(sparkVaultUSDC.totalSupply(),   sparkVaultUSDCInitSupply - userSpUSDCShares);
        assertEq(sparkVaultETH.totalSupply(),    sparkVaultETHInitSupply - userSpETHShares);

        assertEq(sparkVaultUSDC.allowance(user, address(savingsVaultIntents)), 0);
        assertEq(sparkVaultETH.allowance(user,  address(savingsVaultIntents)), 0);

        _assertEmptyRequest(user, sparkVaultUSDC);
        _assertEmptyRequest(user, sparkVaultETH);
    }

    function test_fulfill_multipleVaults_onlyAffectsTargetVault() external {
        IERC20Like underlyingAssetUSDC = IERC20Like(sparkVaultUSDC.asset());
        IERC20Like underlyingAssetETH  = IERC20Like(sparkVaultETH.asset());

        // Drain both vaults balance and fund exact user deposited amount

        _drainVaultBalance(sparkVaultUSDC);
        _drainVaultBalance(sparkVaultETH);

        _fundVaultBalance(sparkVaultUSDC, DEPOSIT_AMOUNT_USDC);
        _fundVaultBalance(sparkVaultETH,  DEPOSIT_AMOUNT_ETH);

        // User creates sparkVaultUSDC and sparkVaultETH requests

        uint256 requestIdVaultUSDC = _approveAndCreateRequest(
            user,
            sparkVaultUSDC,
            userSpUSDCShares,
            block.timestamp + 100
        );

        uint256 requestIdVaultETH = _approveAndCreateRequest(
            user,
            sparkVaultETH,
            userSpETHShares,
            block.timestamp + 200
        );

        assertEq(requestIdVaultUSDC, 1);
        assertEq(requestIdVaultETH,  1);

        // Fulfill only the sparkVaultUSDC request.

        assertEq(underlyingAssetUSDC.balanceOf(address(sparkVaultUSDC)), DEPOSIT_AMOUNT_USDC);
        assertEq(underlyingAssetETH.balanceOf(address(sparkVaultETH)),   DEPOSIT_AMOUNT_ETH);
        assertEq(underlyingAssetUSDC.balanceOf(user),                    0);
        assertEq(underlyingAssetETH.balanceOf(user),                     0);

        assertEq(sparkVaultUSDC.balanceOf(user), userSpUSDCShares);
        assertEq(sparkVaultETH.balanceOf(user),  userSpETHShares);
        assertEq(sparkVaultUSDC.totalSupply(),   sparkVaultUSDCInitSupply);
        assertEq(sparkVaultETH.totalSupply(),    sparkVaultETHInitSupply);

        assertEq(sparkVaultUSDC.allowance(user, address(savingsVaultIntents)), userSpUSDCShares);
        assertEq(sparkVaultETH.allowance(user,  address(savingsVaultIntents)), userSpETHShares);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestFulfilled(
            user,
            address(sparkVaultUSDC),
            requestIdVaultUSDC
        );

        vm.prank(relayer);
        savingsVaultIntents.fulfill(user, address(sparkVaultUSDC), requestIdVaultUSDC);

        assertEq(underlyingAssetUSDC.balanceOf(address(sparkVaultUSDC)), 1);
        assertEq(underlyingAssetUSDC.balanceOf(user),                    DEPOSIT_AMOUNT_USDC - 1); // Rounding

        assertEq(sparkVaultUSDC.balanceOf(user), 0);
        assertEq(sparkVaultUSDC.totalSupply(),   sparkVaultUSDCInitSupply - userSpUSDCShares);

        assertEq(sparkVaultUSDC.allowance(user, address(savingsVaultIntents)), 0);

        _assertEmptyRequest(user, sparkVaultUSDC);

        // Request sparkVaultETH is not fulfilled

        assertEq(underlyingAssetETH.balanceOf(address(sparkVaultETH)), DEPOSIT_AMOUNT_ETH);
        assertEq(underlyingAssetETH.balanceOf(user),                   0);

        assertEq(sparkVaultETH.balanceOf(user), userSpETHShares);
        assertEq(sparkVaultETH.totalSupply(),   sparkVaultETHInitSupply);

        assertEq(sparkVaultETH.allowance(user, address(savingsVaultIntents)), userSpETHShares);

        _assertRequest({
            account           : user,
            vault             : sparkVaultETH,
            expectedRequestId : requestIdVaultETH,
            expectedShares    : userSpETHShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 200
        });
    }

}
