// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

interface ISavingsVaultIntents {

    /**********************************************************************************************/
    /*** Types                                                                                  ***/
    /**********************************************************************************************/

    struct WithdrawRequest {
        address vault;
        uint256 shares;
        address recipient;
        uint256 deadline;
        uint8   v;
        bytes32 r;
        bytes32 s;
    }

    /**********************************************************************************************/
    /*** Errors                                                                                 ***/
    /**********************************************************************************************/

    error InvalidAdminAddress();

    error InvalidMaxDeadline();

    error InvalidRelayerAddress();

    error InvalidVaultAddress();

    error InvalidRecipientAddress();

    error InvalidMinIntentShares();

    error InvalidDeadline(uint256 maxDeadline, uint256 deadline);

    error InvalidIntentShares(uint256 minShares, uint256 shares);

    error DeadlineExceeded(address account, uint256 requestId, uint256 deadline);

    error RequestNotFound(address account, uint256 requestId);

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event RequestCreated(
        address indexed account,
        uint256 indexed requestId,
        address indexed vault,
        uint256         shares,
        uint256         deadline,
        uint8           v,
        bytes32         r,
        bytes32         s
    );

    event RequestCancelled(address indexed account, uint256 indexed requestId);

    event RequestFulfilled(address indexed account, uint256 indexed requestId);

    event MaxDeadlineUpdated(uint256 indexed maxDeadline);

    event MinIntentSharesUpdated(uint256 indexed minIntentShares);

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setMaxDeadline(uint256 maxDeadline_) external;

    function setMinIntentShares(uint256 minIntentShares_) external;

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
    ) external returns (uint256 requestId);

    function cancel(uint256 requestId) external;

    function fulfill(address account, uint256 requestId) external;

    /**********************************************************************************************/
    /*** View functions                                                                         ***/
    /**********************************************************************************************/

    function getRequest(address account, uint256 requestId) 
        external
        view 
        returns (WithdrawRequest memory);

}
