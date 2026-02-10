// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { AccessControlEnumerable } from "../lib/openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";

interface IERC4626Like {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8   v,
        bytes32 r,
        bytes32 s
    ) external;

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract SavingsVaultIntents is AccessControlEnumerable {

    struct WithdrawRequest {
        address vault;
        uint256 shares;
        address recipient;
        uint256 deadline;
        uint8   v;
        bytes32 r;
        bytes32 s;
    }

    error InvalidAdminAddress();

    error InvalidMaxDeadline();

    error InvalidRelayerAddress();

    error InvalidVaultAddress();

    error InvalidRecipientAddress();

    error InvalidDeadline(uint256 maxDeadline, uint256 deadline);

    error RequestNotFound(address account, uint256 requestId);

    error DeadlineExceeded(address account, uint256 requestId, uint256 deadline);

    error InsufficientAssets(address account, uint256 requestId, uint256 minAssets, uint256 assets);

    event Request(
        address indexed account,
        uint256 indexed requestId,
        address indexed vault,
        uint256         shares,
        uint256         deadline,
        uint8           v,
        bytes32         r,
        bytes32         s
    );

    event Cancel(address indexed account, uint256 indexed requestId);

    event Fulfill(address indexed account, uint256 indexed requestId);

    event MaxDeadlineUpdated(uint256 indexed maxDeadline);

    bytes32 public constant RELAYER = keccak256("RELAYER");

    uint256 internal _requestCount;

    uint256 public maxDeadline;

    mapping(address => mapping(uint256 => WithdrawRequest)) public requests;

    constructor(
        address admin,
        address relayer,
        uint256 maxDeadline_
    ) {
        if (admin        == address(0)) revert InvalidAdminAddress();
        if (relayer     == address(0))  revert InvalidRelayerAddress();
        if (maxDeadline_ == 0)          revert InvalidMaxDeadline();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RELAYER,            relayer);

        maxDeadline = maxDeadline_;
    }


    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setMaxDeadline(uint256 maxDeadline_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (maxDeadline_ == 0) revert InvalidMaxDeadline();

        maxDeadline = maxDeadline_;

        emit MaxDeadlineUpdated(maxDeadline_);
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
        if (vault     == address(0)) revert InvalidVaultAddress();
        if (recipient == address(0)) revert InvalidRecipientAddress();

        if (deadline < block.timestamp || deadline > block.timestamp + maxDeadline) {
            revert InvalidDeadline(maxDeadline, deadline);
        }

        requests[msg.sender][requestId = ++_requestCount] = WithdrawRequest({
            vault:     vault,
            shares:    shares,
            recipient: recipient,
            deadline:  deadline,
            v:         v,
            r:         r,
            s:         s
        });

        emit Request(msg.sender, requestId, vault, shares, deadline, v, r, s);
    }

    function cancel(uint256 requestId) external {
        WithdrawRequest memory request_ = requests[msg.sender][requestId];

        if (request_.vault == address(0)) revert RequestNotFound(msg.sender, requestId);

        delete requests[msg.sender][requestId];

        emit Cancel(msg.sender, requestId);
    }

    function fulfill(address account, uint256 requestId) external onlyRole(RELAYER) {
        WithdrawRequest memory _request = requests[account][requestId];

        if (_request.vault == address(0)) revert RequestNotFound(account, requestId);

        if (block.timestamp > _request.deadline) 
            revert DeadlineExceeded(account, requestId, _request.deadline);

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

        delete requests[account][requestId];

        emit Fulfill(account, requestId);

        IERC4626Like(_request.vault).transferFrom(account, address(this), _request.shares);

        IERC4626Like(_request.vault).redeem(_request.shares, _request.recipient, address(this));
    }

}
