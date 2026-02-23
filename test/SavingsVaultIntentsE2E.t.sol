// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { Vm } from "../lib/forge-std/src/Test.sol";

import { Ethereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { TestBase } from "./Base.t.sol";

import { IERC20Like }   from "./interfaces/IERC20Like.sol";
import { IERC4626Like } from "./interfaces/IERC4626Like.sol";
import { IVaultLike }   from "./interfaces/IVaultLike.sol";

import { ISavingsVaultIntents } from "../src/interfaces/ISavingsVaultIntents.sol";
import { SavingsVaultIntents }  from "../src/SavingsVaultIntents.sol";

contract USDCVaultIntentsE2ETests is TestBase {

    function test_e2e_vanilla() external {
        // Step 0: Setup.
        _drainVaultBalance();
        _fundVaultBalance(DEPOSIT_AMOUNT);

        // Step 1: User creates request
        _assertEmptyRequest(user);

        assertEq(savingsVaultIntents.requestCount(), 0);

        // Approve the transfer.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares);

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

        // Step 2: Relayer fulfills the request.
        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(underlyingAsset.balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(user),                     userShares);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply);

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

    function test_e2e_MultipleRequestsOverriden() external {
        // Step 0: Setup.
        _drainVaultBalance();
        _fundVaultBalance(DEPOSIT_AMOUNT);

        // - Step 1: User creates request for 1/3 shares.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares / 3);

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares / 3,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        assertEq(requestId, 1);

        assertEq(savingsVaultIntents.requestCount(), 1);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(vault),
            expectedShares    : userShares / 3,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        // - Step 2: User creates another request for 2/3 shares and the previous request get overriden.
        uint256 withdrawShares = 2 * userShares / 3;

        vm.prank(user);
        vault.approve(address(savingsVaultIntents), withdrawShares);

        vm.prank(user);
        requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : withdrawShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        assertEq(requestId, 2);

        assertEq(savingsVaultIntents.requestCount(), 2);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(vault),
            expectedShares    : withdrawShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        // - Step 3: Relayer fulfills the last made request for the user.
        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(underlyingAsset.balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(user),                     userShares);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), withdrawShares);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestFulfilled(address(user), requestId);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), requestId);

        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT / 3 + 2);  // Rounding
        assertEq(underlyingAsset.balanceOf(address(user)),  2 * DEPOSIT_AMOUNT / 3 - 1);  // Rounding
        assertEq(vault.balanceOf(address(user)),            userShares / 3 + 1);  // Rounding
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply - withdrawShares);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), 0);

        _assertEmptyRequest(user);
    }

    function test_e2e_fulfillAfterTimePassesButBeforeDeadline() external {
        // Step 0: Setup.
        _drainVaultBalance();
        _fundVaultBalance(DEPOSIT_AMOUNT);

        // Step 1: User creates request
        _assertEmptyRequest(user);

        assertEq(savingsVaultIntents.requestCount(), 0);

        // Approve the transfer.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares);

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

        // Step 2: Warp 99s

        vm.warp(block.timestamp + 99);

        _fundVaultBalance(DEPOSIT_AMOUNT + 1_000e6);  // Deal interest earned by the vault.

        // Step 3: Relayer fulfills the request.
        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT + 1_000e6);
        assertEq(underlyingAsset.balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(user),                     userShares);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), userShares);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestFulfilled(address(user), requestId);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), requestId);

        assertEq(underlyingAsset.balanceOf(address(vault)), 999.876877e6);  // Remaining interest.
        assertEq(underlyingAsset.balanceOf(address(user)),  DEPOSIT_AMOUNT + 0.123123e6);  // Interest earned by the user.
        assertEq(vault.balanceOf(address(user)),            0);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply - userShares);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), 0);

        _assertEmptyRequest(user);
    }

    function test_e2e_fulfillAfterDeadlineReverts() external {
        // Step 0: Setup.
        _drainVaultBalance();
        _fundVaultBalance(DEPOSIT_AMOUNT);

        // Step 1: User creates request with 100s deadline
        _assertEmptyRequest(user);

        assertEq(savingsVaultIntents.requestCount(), 0);

        // Approve the transfer.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares);

        uint256 deadline = block.timestamp + 100;

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            requestId : 1,
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : deadline
        });

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : deadline
        });

        assertEq(requestId, 1);

        assertEq(savingsVaultIntents.requestCount(), 1);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(vault),
            expectedShares    : userShares,
            expectedRecipient : user,
            expectedDeadline  : deadline
        });

        // Step 2: Warp 101 seconds forward
        vm.warp(block.timestamp + 101);

        // Step 3: Relayer tries to fulfill the request but it reverts because the deadline has passed.
        vm.expectRevert(abi.encodeWithSelector(ISavingsVaultIntents.DeadlineExceeded.selector, address(user), requestId, deadline));
        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), requestId);

        // Step 4: User cancels the stale request to clean up
        vm.prank(user);
        savingsVaultIntents.cancel();

        _assertEmptyRequest(user);
    }

    function test_e2e_adminUpdatesParametersMidFlight() external {
        // Step 0: Setup.
        _drainVaultBalance();
        _fundVaultBalance(DEPOSIT_AMOUNT);

        // Step 1: User creates request
        _assertEmptyRequest(user);

        assertEq(savingsVaultIntents.requestCount(), 0);

        // Approve the transfer.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares);

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

        // Step 2: Admin updates maxDeadline and minIntentShares
        vm.prank(admin);
        savingsVaultIntents.setMaxDeadline(block.timestamp + 50);

        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(address(vault), true, MIN_INTENT_ASSETS - 1, MAX_INTENT_ASSETS + 1);

        // Step 3: Relayer still fulfills existing request (it was valid at creation)
        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(underlyingAsset.balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(user),                     userShares);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply);

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

}

contract ETHVaultIntentsE2ETests is TestBase {

    function setUp() public virtual override {
        DEPOSIT_AMOUNT    = 1_000e18;
        MIN_INTENT_ASSETS = 10e18;
        MAX_INTENT_ASSETS = 10_000e18;

        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        vault           = IERC4626Like(Ethereum.SPARK_VAULT_V2_SPETH);
        underlyingAsset = IERC20Like(vault.asset());

        admin        = makeAddr("admin");
        relayer      = makeAddr("relayer");
        user         = makeAddr("user");
        unauthorized = makeAddr("unauthorized");

        savingsVaultIntents = new SavingsVaultIntents(admin, relayer, 1 days);

        // Initial setup of savingsVaultIntents by admin

        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(
            address(vault),
            true,
            MIN_INTENT_ASSETS,
            MAX_INTENT_ASSETS
        );

        // User deposits assets into vault
        userShares = _depositToVault(user, DEPOSIT_AMOUNT);

        // Vault totalSupply at _getBlock() + above user deposit
        vaultInitialTotalSupply = vault.totalSupply();
    }

    function test_e2e_vanilla() external {
        // Step 0: Setup.
        _drainVaultBalance();
        _fundVaultBalance(DEPOSIT_AMOUNT);

        // Step 1: User creates request
        _assertEmptyRequest(user);

        assertEq(savingsVaultIntents.requestCount(), 0);

        // Approve the transfer.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares);

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

        // Step 2: Relayer fulfills the request.
        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(underlyingAsset.balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(user),                     userShares);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply);

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

    function test_e2e_MultipleRequestsOverriden() external {
        // Step 0: Setup.
        _drainVaultBalance();
        _fundVaultBalance(DEPOSIT_AMOUNT);

        // - Step 1: User creates request for 1/3 shares.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares / 3);

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares / 3,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        assertEq(requestId, 1);

        assertEq(savingsVaultIntents.requestCount(), 1);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(vault),
            expectedShares    : userShares / 3,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        // - Step 2: User creates another request for 2/3 shares and the previous request get overriden.
        uint256 withdrawShares = 2 * userShares / 3;

        vm.prank(user);
        vault.approve(address(savingsVaultIntents), withdrawShares);

        vm.prank(user);
        requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : withdrawShares,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        assertEq(requestId, 2);

        assertEq(savingsVaultIntents.requestCount(), 2);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(vault),
            expectedShares    : withdrawShares,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        // - Step 3: Relayer fulfills the last made request for the user.
        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(underlyingAsset.balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(user),                     userShares);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), withdrawShares);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestFulfilled(address(user), requestId);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), requestId);

        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT / 3 + 1);  // Rounding
        assertEq(underlyingAsset.balanceOf(address(user)),  2 * DEPOSIT_AMOUNT / 3);  // Rounding
        assertEq(vault.balanceOf(address(user)),            userShares / 3 + 1);  // Rounding
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply - withdrawShares);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), 0);

        _assertEmptyRequest(user);
    }

    function test_e2e_fulfillAfterTimePassesButBeforeDeadline() external {
        // Step 0: Setup.
        _drainVaultBalance();
        _fundVaultBalance(DEPOSIT_AMOUNT);

        // Step 1: User creates request
        _assertEmptyRequest(user);

        assertEq(savingsVaultIntents.requestCount(), 0);

        // Approve the transfer.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares);

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

        // Step 2: Warp 99s

        vm.warp(block.timestamp + 99);

        _fundVaultBalance(DEPOSIT_AMOUNT + 1_000e18);  // Deal interest earned by the vault.

        // Step 3: Relayer fulfills the request.
        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT + 1_000e18);
        assertEq(underlyingAsset.balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(user),                     userShares);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), userShares);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestFulfilled(address(user), requestId);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), requestId);

        assertEq(underlyingAsset.balanceOf(address(vault)), 999.999951714575768813e18);  // Remaining interest.
        assertEq(underlyingAsset.balanceOf(address(user)),  DEPOSIT_AMOUNT + 0.000048285424231187e18);  // Interest earned by the user.
        assertEq(vault.balanceOf(address(user)),            0);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply - userShares);

        assertEq(vault.allowance(user, address(savingsVaultIntents)), 0);

        _assertEmptyRequest(user);
    }

    function test_e2e_fulfillAfterDeadlineReverts() external {
        // Step 0: Setup.
        _drainVaultBalance();
        _fundVaultBalance(DEPOSIT_AMOUNT);

        // Step 1: User creates request with 100s deadline
        _assertEmptyRequest(user);

        assertEq(savingsVaultIntents.requestCount(), 0);

        // Approve the transfer.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares);

        uint256 deadline = block.timestamp + 100;

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            requestId : 1,
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : deadline
        });

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : address(vault),
            shares    : userShares,
            recipient : user,
            deadline  : deadline
        });

        assertEq(requestId, 1);

        assertEq(savingsVaultIntents.requestCount(), 1);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(vault),
            expectedShares    : userShares,
            expectedRecipient : user,
            expectedDeadline  : deadline
        });

        // Step 2: Warp 101 seconds forward
        vm.warp(block.timestamp + 101);

        // Step 3: Relayer tries to fulfill the request but it reverts because the deadline has passed.
        vm.expectRevert(abi.encodeWithSelector(ISavingsVaultIntents.DeadlineExceeded.selector, address(user), requestId, deadline));
        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), requestId);

        // Step 4: User cancels the stale request to clean up
        vm.prank(user);
        savingsVaultIntents.cancel();

        _assertEmptyRequest(user);
    }

    function test_e2e_adminUpdatesParametersMidFlight() external {
        // Step 0: Setup.
        _drainVaultBalance();
        _fundVaultBalance(DEPOSIT_AMOUNT);

        // Step 1: User creates request
        _assertEmptyRequest(user);

        assertEq(savingsVaultIntents.requestCount(), 0);

        // Approve the transfer.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares);

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

        // Step 2: Admin updates maxDeadline and minIntentShares
        vm.prank(admin);
        savingsVaultIntents.setMaxDeadline(block.timestamp + 50);

        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(address(vault), true, MIN_INTENT_ASSETS - 1, MAX_INTENT_ASSETS + 1);

        // Step 3: Relayer still fulfills existing request (it was valid at creation)
        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(underlyingAsset.balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(user),                     userShares);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply);

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

}

contract MultipleVaultsIntentsE2ETests is TestBase {

    uint256 internal DEPOSIT_AMOUNT_ETH    = 1_000e18;
    uint256 internal MIN_INTENT_ASSETS_ETH = 10e18;
    uint256 internal MAX_INTENT_ASSETS_ETH = 10_000e18;

    IERC4626Like internal ethVault;
    IERC20Like   internal underlyingAsset_eth;
    uint256      internal vaultInitialTotalSupply_eth;

    uint256 internal userShares_eth;
    
    function setUp() public virtual override {
        super.setUp();

        ethVault            = IERC4626Like(Ethereum.SPARK_VAULT_V2_SPETH);
        underlyingAsset_eth = IERC20Like(ethVault.asset());

        // Initial setup of savingsVaultIntents by admin

        vm.prank(admin);
        savingsVaultIntents.updateVaultConfig(
            address(ethVault),
            true,
            MIN_INTENT_ASSETS_ETH,
            MAX_INTENT_ASSETS_ETH
        );

        // User deposits assets into vault
        deal(address(underlyingAsset_eth), user, DEPOSIT_AMOUNT_ETH);

        vm.prank(user);
        underlyingAsset_eth.approve(address(ethVault), DEPOSIT_AMOUNT_ETH);

        vm.prank(user);
        userShares_eth = ethVault.deposit(DEPOSIT_AMOUNT_ETH, user);

        // Vault totalSupply at _getBlock() + above user deposit
        vaultInitialTotalSupply_eth = ethVault.totalSupply();
    }

    function test_e2e_multipleVaults() external {
        // Step 0: Setup.
        vm.startPrank(Ethereum.ALM_PROXY);
        IVaultLike(address(vault)).take(underlyingAsset.balanceOf(address(vault)));
        IVaultLike(address(ethVault)).take(underlyingAsset_eth.balanceOf(address(ethVault)));
        vm.stopPrank();

        // Fund vault upto DEPOSIT_AMOUNT and DEPOSIT_AMOUNT_ETH
        deal(address(underlyingAsset),     address(vault),    DEPOSIT_AMOUNT);
        deal(address(underlyingAsset_eth), address(ethVault), DEPOSIT_AMOUNT_ETH);

        // Step 1: User creates request for USDC vault
        _assertEmptyRequest(user);

        assertEq(savingsVaultIntents.requestCount(), 0);

        // Approve the transfer.
        vm.prank(user);
        vault.approve(address(savingsVaultIntents), userShares);

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

        // Request gets fulfilled
        assertEq(underlyingAsset.balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(underlyingAsset.balanceOf(address(user)),  0);
        assertEq(vault.balanceOf(user),                     userShares);
        assertEq(vault.totalSupply(),                       vaultInitialTotalSupply);

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

        // Step 2: User creates request for ETH vault
        _assertEmptyRequest(user);

        assertEq(savingsVaultIntents.requestCount(), 1);

        // Approve the transfer.
        vm.prank(user);
        ethVault.approve(address(savingsVaultIntents), userShares_eth);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestCreated({
            account   : user,
            requestId : 2,
            vault     : address(ethVault),
            shares    : userShares_eth,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        vm.prank(user);
        requestId = savingsVaultIntents.request({
            vault     : address(ethVault),
            shares    : userShares_eth,
            recipient : user,
            deadline  : block.timestamp + 100
        });

        assertEq(requestId, 2);

        assertEq(savingsVaultIntents.requestCount(), 2);

        _assertRequest({
            account           : user,
            expectedRequestId : requestId,
            expectedVault     : address(ethVault),
            expectedShares    : userShares_eth,
            expectedRecipient : user,
            expectedDeadline  : block.timestamp + 100
        });

        // Request gets fulfilled
        assertEq(underlyingAsset_eth.balanceOf(address(ethVault)), DEPOSIT_AMOUNT_ETH);
        assertEq(underlyingAsset_eth.balanceOf(address(user)),     0);
        assertEq(ethVault.balanceOf(user),                         userShares_eth);
        assertEq(ethVault.totalSupply(),                           vaultInitialTotalSupply_eth);

        assertEq(ethVault.allowance(user, address(savingsVaultIntents)), userShares_eth);

        vm.expectEmit(address(savingsVaultIntents));
        emit ISavingsVaultIntents.RequestFulfilled(address(user), requestId);

        vm.prank(relayer);
        savingsVaultIntents.fulfill(address(user), requestId);

        assertEq(underlyingAsset_eth.balanceOf(address(ethVault)), 1);
        assertEq(underlyingAsset_eth.balanceOf(address(user)),     DEPOSIT_AMOUNT_ETH - 1); // Rounding
        assertEq(ethVault.balanceOf(address(user)),                0);
        assertEq(ethVault.totalSupply(),                           vaultInitialTotalSupply_eth - userShares_eth);

        assertEq(ethVault.allowance(user, address(savingsVaultIntents)), 0);

        _assertEmptyRequest(user);
    }

}
