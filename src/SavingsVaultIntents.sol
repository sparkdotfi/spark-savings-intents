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

    uint256 internal _requestCount;

    uint256 public maxDeadline;
    uint256 public minIntentShares;

    mapping(address => mapping(uint256 => WithdrawRequest)) internal _requests;

    constructor(
        address admin,
        address relayer,
        uint256 maxDeadline_,
        uint256 minIntentShares_
    ) {
        require(admin   != address(0), InvalidAdminAddress());
        require(relayer != address(0), InvalidRelayerAddress());

        require(maxDeadline_     > 0, InvalidMaxDeadline());
        require(minIntentShares_ > 0, InvalidMinIntentShares());

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RELAYER,            relayer);

        maxDeadline     = maxDeadline_;
        minIntentShares = minIntentShares_;
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
        require(minIntentShares_ > 0, InvalidMinIntentShares());

        minIntentShares = minIntentShares_;

        emit MinIntentSharesUpdated(minIntentShares_);
    }

    /**********************************************************************************************/
    /*** External functions                                                                     ***/
    /**********************************************************************************************/

    function request(
        address vault,
        uint256 shares,
        address recipient,
        uint256 deadline,
        uint8   v,
        bytes32 r,
        bytes32 s
    )
        external returns (uint256 requestId)
    {
        require(vault     != address(0), InvalidVaultAddress());
        require(recipient != address(0), InvalidRecipientAddress());

        require(shares >= minIntentShares, InvalidIntentShares(minIntentShares, shares));

        require(
            deadline > block.timestamp && deadline <= block.timestamp + maxDeadline,
            InvalidDeadline(maxDeadline, deadline)
        );

        _requests[msg.sender][requestId = ++_requestCount] = WithdrawRequest({
            vault     : vault,
            shares    : shares,
            recipient : recipient,
            deadline  : deadline,
            v         : v,
            r         : r,
            s         : s
        });

        emit RequestCreated(msg.sender, requestId, vault, shares, deadline, v, r, s);
    }

    function cancel(uint256 requestId) external {
        WithdrawRequest memory request_ = _requests[msg.sender][requestId];

        require(request_.vault != address(0), RequestNotFound(msg.sender, requestId));

        delete _requests[msg.sender][requestId];

        emit RequestCancelled(msg.sender, requestId);
    }

    function fulfill(address account, uint256 requestId) external onlyRole(RELAYER) {
        WithdrawRequest memory _request = _requests[account][requestId];

        require(_request.vault != address(0), RequestNotFound(account, requestId));

        require(
            block.timestamp <= _request.deadline,
            DeadlineExceeded(account, requestId, _request.deadline)
        );

        // Call permit to approve the transfer
        // Use low-level call to handle case where permit may have already been consumed.
        _request.vault.call(
            abi.encodeWithSelector(
                IERC4626Like.permit.selector,
                account,
                address(this),
                _request.shares,
                _request.deadline,
                _request.v,
                _request.r,
                _request.s
            )
        );

        delete _requests[account][requestId];

        emit RequestFulfilled(account, requestId);

        IERC4626Like(_request.vault).transferFrom(account, address(this), _request.shares);

        IERC4626Like(_request.vault).redeem(_request.shares, _request.recipient, address(this));
    }

    /**********************************************************************************************/
    /*** View functions                                                                         ***/
    /**********************************************************************************************/

    function getRequest(address account, uint256 requestId) 
        external
        view
        returns (WithdrawRequest memory)
    {
        return _requests[account][requestId];
    }

}
