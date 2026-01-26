// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IERC4626Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function asset() external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract SavingsVaultIntents {

    struct WithdrawRequest {
        address vault;
        uint256 shares;
        address recipient;
        uint256 deadline;
        uint8   v;
        bytes32 r;
        bytes32 s;
    }

    error RequestNotFound(address account, uint256 requestId);

    error DeadlineExceeded(address account, uint256 requestId, uint256 deadline);

    error InsufficientAssets(address account, uint256 requestId, uint256 minAssets, uint256 assets);

    event Request(
        address indexed account,
        uint256 indexed requestId,
        address indexed vault,
        uint256 shares,
        uint256 deadline,
        uint8   v,
        bytes32 r,
        bytes32 s
    );

    event Cancel(address indexed account, uint256 indexed requestId);

    event Fulfill(address indexed account, uint256 indexed requestId);

    uint256 internal _requestCount;

    mapping(address => mapping(uint256 => WithdrawRequest)) public requests;

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
        require(IERC4626Like(vault).balanceOf(msg.sender) >= shares, "Insufficient balance");

        require(
            IERC20(IERC4626Like(vault).asset()).balanceOf(vault) < IERC4626Like(vault).convertToAssets(shares),
            "Assets already available in vault to redeem"
        );

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
        WithdrawRequest memory _request = requests[msg.sender][requestId];

        if (_request.vault == address(0)) revert RequestNotFound(msg.sender, requestId);

        delete requests[msg.sender][requestId];

        emit Cancel(msg.sender, requestId);
    }

    function fulfill(address account, uint256 requestId) external {
        WithdrawRequest memory _request = requests[account][requestId];

        if (_request.vault == address(0)) revert RequestNotFound(msg.sender, requestId);

        if (block.timestamp > _request.deadline) revert DeadlineExceeded(account, requestId, _request.deadline);

        // Call permit to approve the transfer
        // Use low-level call to handle case where permit may have already been consumed.
        (bool success, ) = _request.vault.call(
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
        // Ignore failure if permit was already consumed
        success;

        IERC4626Like(_request.vault).transferFrom(account, address(this), _request.shares);

        IERC4626Like(_request.vault).redeem(_request.shares, _request.recipient, address(this));

        delete requests[account][requestId];

        emit Fulfill(account, requestId);
    }

}
