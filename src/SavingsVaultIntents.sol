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

    uint256 public requestCount;

    uint256 public maxDeadline;
    uint256 public minIntentShares;
    uint256 public maxIntentShares;

    mapping(address => WithdrawRequest) public withdrawRequests;
    mapping(address => bool)            public vaultWhitelist;

    constructor(
        address admin,
        address relayer,
        uint256 maxDeadline_,
        uint256 maxIntentShares_
    ) {
        require(admin   != address(0), InvalidAdminAddress());
        require(relayer != address(0), InvalidRelayerAddress());

        require(maxDeadline_     > 0, InvalidMaxDeadline());
        require(maxIntentShares_ > 0, InvalidMaxIntentShares());

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RELAYER,            relayer);

        maxDeadline     = maxDeadline_;
        maxIntentShares = maxIntentShares_;
    }

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setMaxDeadline(uint256 maxDeadline_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(maxDeadline_ > 0, InvalidMaxDeadline());

        maxDeadline = maxDeadline_;

        emit MaxDeadlineUpdated(maxDeadline_);
    }

    function setMinIntentShares(uint256 minIntentShares_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minIntentShares = minIntentShares_;

        emit MinIntentSharesUpdated(minIntentShares_);
    }

    function setMaxIntentShares(uint256 maxIntentShares_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(maxIntentShares_ > 0, InvalidMaxIntentShares());

        maxIntentShares = maxIntentShares_;

        emit MaxIntentSharesUpdated(maxIntentShares_);
    }

    function updateWhitelist(address vault, bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(vault != address(0), InvalidVaultAddress());

        vaultWhitelist[vault] = enabled;

        emit WhitelistUpdated(vault, enabled);
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
        require(vaultWhitelist[vault],     VaultNotWhitelisted());
        require(recipient != address(0),   InvalidRecipientAddress());
        require(shares >= minIntentShares, IntentSharesBelowMin(minIntentShares, shares));
        require(shares <= maxIntentShares, IntentSharesAboveMax(maxIntentShares, shares));

        uint256 userShares = IERC4626Like(vault).balanceOf(msg.sender);

        require(shares <= userShares, InsufficientShares(shares, userShares));

        require(
            deadline > block.timestamp && deadline <= block.timestamp + maxDeadline,
            InvalidDeadline(maxDeadline, deadline)
        );

        requestId = ++requestCount;

        withdrawRequests[msg.sender] = WithdrawRequest({
            requestId : requestId,
            vault     : vault,
            shares    : shares,
            recipient : recipient,
            deadline  : deadline
        });

        emit RequestCreated(msg.sender, requestId, vault, shares, recipient, deadline);
    }

    function cancel() external {
        WithdrawRequest memory request_ = withdrawRequests[msg.sender];

        require(request_.requestId != 0, RequestNotFound(msg.sender));

        delete withdrawRequests[msg.sender];

        emit RequestCancelled(msg.sender, request_.requestId);
    }

    function fulfill(address account, uint256 requestId_) external onlyRole(RELAYER) {
        WithdrawRequest memory request_ = withdrawRequests[account];

        require(requestId_ != 0 && request_.requestId == requestId_, RequestNotFound(account));

        require(
            block.timestamp <= request_.deadline,
            DeadlineExceeded(account, request_.requestId, request_.deadline)
        );

        delete withdrawRequests[account];

        emit RequestFulfilled(account, request_.requestId);

        IERC4626Like(request_.vault).transferFrom(account, address(this), request_.shares);

        IERC4626Like(request_.vault).redeem(request_.shares, request_.recipient, address(this));
    }

}
