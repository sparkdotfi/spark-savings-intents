// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { AccessControlEnumerable } from "../lib/openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";

import { IERC4626Like }         from "./interfaces/IERC4626Like.sol";
import { ISavingsVaultIntents } from "./interfaces/ISavingsVaultIntents.sol";

contract SavingsVaultIntents is ISavingsVaultIntents, AccessControlEnumerable {

    /**********************************************************************************************/
    /*** Declarations and constructor                                                           ***/
    /**********************************************************************************************/

    bytes32 public constant RELAYER = keccak256("RELAYER");

    uint256 public maxDeadline;

    mapping(address vault => VaultConfig) public vaultConfig;
    mapping(address vault => uint256)     public vaultRequestCount;

    mapping(address account => mapping(address vault => WithdrawRequest)) public withdrawRequests;

    constructor(address admin, address relayer, uint256 maxDeadline_) {
        require(admin   != address(0), InvalidAdminAddress());
        require(relayer != address(0), InvalidRelayerAddress());

        require(maxDeadline_ > 0, InvalidMaxDeadline());

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RELAYER,            relayer);

        maxDeadline = maxDeadline_;
    }

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setMaxDeadline(uint256 maxDeadline_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(maxDeadline_ > 0, InvalidMaxDeadline());

        maxDeadline = maxDeadline_;

        emit MaxDeadlineUpdated(maxDeadline_);
    }

    function updateVaultConfig(
        address vault,
        bool    whitelisted_,
        uint256 minIntentAssets_,
        uint256 maxIntentAssets_
    )
        external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(vault != address(0), InvalidVaultAddress());

        require(
            minIntentAssets_ < maxIntentAssets_,
            InvalidIntentAmountBounds(minIntentAssets_, maxIntentAssets_)
        );

        vaultConfig[vault] = VaultConfig({
            whitelisted     : whitelisted_,
            minIntentAssets : minIntentAssets_,
            maxIntentAssets : maxIntentAssets_
        });

        emit VaultConfigUpdated(vault, whitelisted_, minIntentAssets_, maxIntentAssets_);
    }

    /**********************************************************************************************/
    /*** External functions                                                                     ***/
    /**********************************************************************************************/

    function request(
        address vault,
        uint256 shares,
        address recipient,
        uint256 deadline
    )
        external returns (uint256 requestId)
    {
        VaultConfig memory vaultConfig_ = vaultConfig[vault];

        require(vaultConfig_.whitelisted, VaultNotWhitelisted());
        require(recipient != address(0),  InvalidRecipientAddress());

        uint256 assets = IERC4626Like(vault).convertToAssets(shares);

        require(
            assets >= vaultConfig_.minIntentAssets,
            IntentAssetsBelowMin(vaultConfig_.minIntentAssets, assets)
        );

        require(
            assets <= vaultConfig_.maxIntentAssets,
            IntentAssetsAboveMax(vaultConfig_.maxIntentAssets, assets)
        );

        uint256 userShares = IERC4626Like(vault).balanceOf(msg.sender);

        require(shares <= userShares, InsufficientShares(shares, userShares));

        require(
            deadline > block.timestamp && deadline <= block.timestamp + maxDeadline,
            InvalidDeadline(maxDeadline, deadline)
        );

        requestId = ++vaultRequestCount[vault];

        withdrawRequests[msg.sender][vault] = WithdrawRequest({
            requestId : requestId,
            shares    : shares,
            recipient : recipient,
            deadline  : deadline
        });

        emit RequestCreated(msg.sender, vault, requestId, shares, recipient, deadline);
    }

    function cancel(address vault) external {
        WithdrawRequest memory request_ = withdrawRequests[msg.sender][vault];

        require(request_.requestId != 0, RequestNotFound(msg.sender, vault));

        delete withdrawRequests[msg.sender][vault];

        emit RequestCancelled(msg.sender, vault, request_.requestId);
    }

    function fulfill(
        address account,
        address vault,
        uint256 requestId_
    )
        external
        onlyRole(RELAYER)
    {
        WithdrawRequest memory request_ = withdrawRequests[account][vault];

        require(
            requestId_ != 0 && request_.requestId == requestId_,
            RequestNotFound(account, vault)
        );

        require(
            block.timestamp <= request_.deadline,
            DeadlineExceeded(account, vault, request_.requestId, request_.deadline)
        );

        delete withdrawRequests[account][vault];

        emit RequestFulfilled(account, vault, request_.requestId);

        IERC4626Like(vault).transferFrom(account, address(this), request_.shares);

        IERC4626Like(vault).redeem(request_.shares, request_.recipient, address(this));
    }

}
