// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { HandlerBase } from "./HandlerBase.sol";

import { console2 } from "forge-std/console2.sol";

interface IERC4626Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function asset() external view returns (address);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function depositCap() external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract UserHandler is HandlerBase {

    uint256 public numUsers;

    address[] public users;

    mapping (address user => bool status)       public requestStatus;
    mapping (address user => uint256 requestId) public requestIds;

    constructor(address vault_, address savingsVaultIntents_, uint256 numUsers_) HandlerBase(vault_, savingsVaultIntents_) {
        numUsers = numUsers_;

        for (uint256 i = 0; i < numUsers_; i++) {
            users.push(makeAddr(string(abi.encodePacked("user", i))));
        }
    }

    function _getRandomUser(uint256 userIndex) internal view returns (address) {
        return users[_bound(userIndex, 0, users.length - 1)];
    }

    function createRequest(uint256 assetAmount, uint32 userIndex, uint256 deadline) public {
        deadline = _bound(deadline, block.timestamp + 1, block.timestamp + savingsVaultIntents.maxDeadline());

        ( bool whitelisted, uint256 minIntentAssets, uint256 maxIntentAssets ) = savingsVaultIntents.vaultConfig(vault);

        if (!whitelisted) return;

        address user = _getRandomUser(userIndex);

        IERC20Like underlyingAsset = IERC20Like(IERC4626Like(vault).asset());

        // Deposit amount for user.
        assetAmount = _bound(assetAmount, minIntentAssets + 1, maxIntentAssets);

        deal(address(underlyingAsset), user, assetAmount);

        vm.startPrank(user);

        underlyingAsset.approve(address(vault), assetAmount);

        if (IERC4626Like(vault).depositCap() < IERC4626Like(vault).totalAssets() + assetAmount) return;
        
        uint256 shares = IERC4626Like(vault).deposit(assetAmount, address(user));

        vm.stopPrank();

        // Approve savingsVaultIntents to spend shares
        vm.prank(user);
        IERC4626Like(vault).approve(address(savingsVaultIntents), shares);

        vm.prank(user);
        uint256 requestId = savingsVaultIntents.request({
            vault     : vault,
            shares    : shares,
            recipient : user,
            deadline  : deadline
        });

        requestStatus[user] = true;
        requestIds[user]    = requestId;
    }

    function cancelRequest(uint32 userIndex) public {
        address user = _getRandomUser(userIndex);

        if (requestStatus[user]) {
            requestStatus[user] = false;

            delete requestIds[user];

            vm.prank(user);
            savingsVaultIntents.cancel(address(vault));
        }
    }

    function fulfillRequest(uint32 userIndex) public {
        address user = _getRandomUser(userIndex);

        if (requestStatus[user]) {
            requestStatus[user] = false;

            delete requestIds[user];

            ( uint256 requestId, uint256 shares,, ) = savingsVaultIntents.withdrawRequests(user, address(vault));

            uint256 userAmount = IERC4626Like(vault).convertToAssets(shares);

            address underlyingAsset = IERC4626Like(vault).asset();

            deal(underlyingAsset, address(vault), userAmount);

            vm.prank(relayer);
            savingsVaultIntents.fulfill(user, address(vault), requestId);
        }
    }

}
