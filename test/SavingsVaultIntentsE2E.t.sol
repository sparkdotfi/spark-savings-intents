// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { Vm } from "../lib/forge-std/src/Test.sol";

import { TestBase } from "./Base.t.sol";

import { ISavingsVaultIntents } from "../src/interfaces/ISavingsVaultIntents.sol";

contract SavingsVaultIntentsE2ETests is TestBase {
    
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

    function test_e2e_fulfillMultipleRequestsSameUser() external {
        // - Step 1: User creates request for 1/3 shares
        // - Step 2: User creates another request for 1/3 shares
        // - Step 3: Relayer fulfills both
        // - Step 4: Verify user has remaining 1/3 shares + received assets
    }

    function test_e2e_fulfillMultipleRequestsOutofOrder() external {
        // - Step 1: User creates multiple requests
        // - Step 2: Relayer fulfills requests in a random order
    }

    function test_e2e_fulfillAfterTimePassesButBeforeDeadline() external {
        // - Step 1: User creates request with 100s deadline
        // - Step 2: Warp 99 seconds forward
        // - Step 3: Relayer fulfills successfully
    }

    function test_e2e_fulfillAfterDeadlineReverts() external {
        // - Step 1: User creates request with 100s deadline
        // - Step 2: Warp 101 seconds forward
        // - Step 3: Relayer fulfill reverts with DeadlineExceeded
        // - Step 4: User cancels the stale request to clean up
    }

    function test_e2e_requestCancelAndRequestAgain() external {
        // Step 1: User creates request


        // Step 2: User cancels
        // Step 3: User creates a new request (new signature, new requestId)
        // Step 4: Relayer fulfills the new request
    }

    function test_e2e_partialWithdrawal() external {
        // - Step 1: User creates request for half of shares
        // - Step 2: Relayer fulfills
        // - Step 3: Verify user still has remaining shares + received assets
    }

    function test_e2e_cancelAfterDeadline() external {
        // - Step 1: User creates request
        // - Step 2: Deadline passes
        // - Step 3: User cancels successfully (cancel has no deadline check)
        // - Step 4: Verify request cleared, user still holds shares
    }

    function test_e2e_withdrawToDifferentRecipient() external {
        // - Step 1: User creates request with a different recipient
        // - Step 2: Relayer fulfills
        // - Step 3: Verify recipient received assets, not the user
    }

    function test_e2e_fulfillWithPreApproval() external {
        // - Step 1: User approves savingsVaultIntents directly (no permit needed)
        // - Step 2: User creates request (with dummy/invalid signature)
        // - Step 3: Relayer fulfills — low-level permit call fails silently, transferFrom uses existing approval
        // - Step 4: Verify assets received
    }

    function test_e2e_adminUpdatesParametersMidFlight() external {
        // - Step 1: User creates request
        // - Step 2: Admin updates maxDeadline and minIntentShares
        // - Step 3: Relayer still fulfills existing request (it was valid at creation)
        // - Step 4: New request must follow updated parameters
    }

}
