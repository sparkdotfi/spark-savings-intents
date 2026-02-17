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

    mapping(address => WithdrawRequest) internal _requests;
    mapping(address => bool)            internal _vaultWhitelist;

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

    function updateWhitelist(address vault, bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(vault != address(0), InvalidVaultAddress());

        _vaultWhitelist[vault] = enabled;

        emit WhitelistUpdated(vault, enabled);
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
        require(_vaultWhitelist[vault],    VaultNotWhitelisted());
        require(recipient != address(0),   InvalidRecipientAddress());
        require(shares >= minIntentShares, InvalidIntentShares(minIntentShares, shares));

        uint256 userShares = IERC4626Like(vault).balanceOf(msg.sender);

        require(shares <= userShares, InsufficientShares(shares, userShares));

        require(
            deadline > block.timestamp && deadline <= block.timestamp + maxDeadline,
            InvalidDeadline(maxDeadline, deadline)
        );
        
        require(_requests[msg.sender].requestId == 0, ActiveRequestExists());

        requestId = ++_requestCount;

        _requests[msg.sender] = WithdrawRequest({
            requestId : requestId,
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

    function cancel() external {
        WithdrawRequest memory request_ = _requests[msg.sender];

        require(request_.requestId != 0, RequestNotFound(msg.sender));

        delete _requests[msg.sender];

        emit RequestCancelled(msg.sender, request_.requestId);
    }

    function fulfill(address account, uint256 requestId_) external onlyRole(RELAYER) {
        WithdrawRequest memory request_ = _requests[account];

        require(requestId_ != 0 && request_.requestId == requestId_, RequestNotFound(account));

        require(
            block.timestamp <= request_.deadline,
            DeadlineExceeded(account, request_.requestId, request_.deadline)
        );

        // Call permit to approve the transfer
        // Use low-level call to handle case where permit may have already been consumed.
        request_.vault.call(
            abi.encodeWithSelector(
                IERC4626Like.permit.selector,
                account,
                address(this),
                request_.shares,
                request_.deadline,
                request_.v,
                request_.r,
                request_.s
            )
        );

        delete _requests[account];

        emit RequestFulfilled(account, request_.requestId);

        IERC4626Like(request_.vault).transferFrom(account, address(this), request_.shares);

        IERC4626Like(request_.vault).redeem(request_.shares, request_.recipient, address(this));
    }

    /**********************************************************************************************/
    /*** View functions                                                                         ***/
    /**********************************************************************************************/

    function getRequest(address account) 
        external
        view
        returns (WithdrawRequest memory)
    {
        return _requests[account];
    }

    function isRegistered(address vault) external view returns (bool) {
        return _vaultWhitelist[vault];
    }

}
