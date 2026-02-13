// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20Like, IERC712Like, TestBase } from "./Base.t.sol";

import { SavingsVaultIntents } from "../src/SavingsVaultIntents.sol";

contract SavingsVaultIntentsE2ETests is TestBase {

    function test_e2e_vanilla() external {
        _removeAllBalanceFromVault();

        // Step 1: User requests a withdrawal.

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

        // Step 2: Relayer fulfills the request.
        
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

    function test_e2e_multipleRequests() external {
        // Step 0: Setup.

        ( address user1, uint256 userPrivateKey1 ) = _createUser("test test test test test test test test test test test junk");
        ( address user2, uint256 userPrivateKey2 ) = _createUser("abandon zoo abandon zoo abandon zoo abandon zoo abandon zoo abandon wrestle");
        ( address user3, uint256 userPrivateKey3 ) = _createUser("candy maple cake sugar pudding cream honey rich smooth crumble sweet treat");

        uint256 userShares1 = _depositToUser(user1, DEPOSIT_AMOUNT);
        uint256 userShares2 = _depositToUser(user2, DEPOSIT_AMOUNT);
        uint256 userShares3 = _depositToUser(user3, DEPOSIT_AMOUNT);

        _removeAllBalanceFromVault();

        // Step 1: Multiple users request a withdrawal.
        
        uint256 requestId1 = _createRequest(user1, userPrivateKey1, userShares1, block.timestamp + 100);
        uint256 requestId2 = _createRequest(user2, userPrivateKey2, userShares2, block.timestamp + 100);
        uint256 requestId3 = _createRequest(user3, userPrivateKey3, userShares3, block.timestamp + 100);

        // Step 2: Relayer fulfills the requests.

        address asset = vault.asset();

        deal(asset, address(vault), DEPOSIT_AMOUNT * 3);

        assertEq(IERC20Like(asset).balanceOf(address(vault)), DEPOSIT_AMOUNT * 3);
        assertEq(IERC20Like(asset).balanceOf(user1),          0);
        assertEq(IERC20Like(asset).balanceOf(user2),          0);
        assertEq(IERC20Like(asset).balanceOf(user3),          0);

        vm.startPrank(relayer);

        savingsVaultIntents.fulfill(user1, requestId1);
        savingsVaultIntents.fulfill(user2, requestId2);
        savingsVaultIntents.fulfill(user3, requestId3);

        vm.stopPrank();

        assertEq(IERC20Like(asset).balanceOf(address(vault)), 3);
        assertEq(IERC20Like(asset).balanceOf(user1),          DEPOSIT_AMOUNT - 1);
        assertEq(IERC20Like(asset).balanceOf(user2),          DEPOSIT_AMOUNT - 1);
        assertEq(IERC20Like(asset).balanceOf(user3),          DEPOSIT_AMOUNT - 1);
    }

    function _createUser(string memory mnemonic_) internal returns (address user, uint256 userPrivateKey) {
        userPrivateKey = vm.deriveKey(mnemonic_, 1);
        user           = vm.addr(userPrivateKey);
    }

    function _depositToUser(address user_, uint256 amount_) internal returns (uint256 userShares) {
        deal(vault.asset(), user_, amount_);

        vm.startPrank(user_);

        IERC20Like(vault.asset()).approve(address(vault), amount_);

        userShares = vault.deposit(amount_, user_);

        vm.stopPrank();
    }

    function _createRequest(address user_, uint256 userPrivateKey_, uint256 shares_, uint256 deadline_) internal returns (uint256 requestId) {
        ( uint8 v, bytes32 r, bytes32 s ) = _generateUserSignature(user_, userPrivateKey_, shares_, deadline_);
            
        vm.prank(user_);
        requestId = savingsVaultIntents.request({
            vault:     address(vault),
            shares:    shares_,
            recipient: user_,
            deadline:  deadline_,
            v:         v,
            r:         r,
            s:         s
        });
    }

    function _generateUserSignature(
        address user_,
        uint256 userPrivateKey_,
        uint256 amount_,
        uint256 deadline_
    )
        internal virtual returns (uint8 v, bytes32 r, bytes32 s)
    {
        uint256 nonce        = IERC712Like(address(vault)).nonces(user_);
        bytes32 permitDigest = keccak256(abi.encode(IERC712Like(address(vault)).PERMIT_TYPEHASH(), user_, address(savingsVaultIntents), amount_, nonce, deadline_));
        bytes32 digest       = keccak256(abi.encodePacked("\x19\x01", IERC712Like(address(vault)).DOMAIN_SEPARATOR(), permitDigest));

        ( v, r, s ) = vm.sign(userPrivateKey_, digest);
    }

}
