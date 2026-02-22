// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

interface ISavingsVaultIntents {

    /**********************************************************************************************/
    /*** Types                                                                                  ***/
    /**********************************************************************************************/

    struct VaultConfig {
        bool    whitelisted;
        uint256 minIntentAssets;
        uint256 maxIntentAssets;
    }

    struct WithdrawRequest {
        uint256 requestId;
        address vault;
        uint256 shares;
        address recipient;
        uint256 deadline;
    }

    /**********************************************************************************************/
    /*** Errors                                                                                 ***/
    /**********************************************************************************************/

    error DeadlineExceeded(address account, uint256 requestId, uint256 deadline);
    error InsufficientShares(uint256 sharesRequested, uint256 sharesPresent);
    error IntentAssetsAboveMax(uint256 maxAssets, uint256 assets);
    error IntentAssetsBelowMin(uint256 minAssets, uint256 assets);
    error InvalidAdminAddress();
    error InvalidDeadline(uint256 maxDeadline, uint256 deadline);
    error InvalidMaxDeadline();
    error InvalidRecipientAddress();
    error InvalidRelayerAddress();
    error InvalidVaultAddress();
    error InvalidIntentAmountBounds(uint256 minIntentAssets, uint256 maxIntentAssets);
    error RequestNotFound(address account);
    error VaultNotWhitelisted();

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event MaxDeadlineUpdated(uint256 indexed maxDeadline);
    event RequestCancelled(address indexed account, uint256 indexed requestId);

    event RequestCreated(
        address indexed account,
        uint256 indexed requestId,
        address indexed vault,
        uint256         shares,
        address         recipient,
        uint256         deadline
    );

    event RequestFulfilled(address indexed account, uint256 indexed requestId);

    event VaultConfigUpdated(
        address indexed vault,
        bool    indexed whitelisted,
        uint256         minIntentAssets,
        uint256         maxIntentAssets
    );

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setMaxDeadline(uint256 maxDeadline_) external;

    function updateVaultConfig(
        address vault,
        bool    whitelisted_,
        uint256 minIntentAssets_,
        uint256 maxIntentAssets_
    ) external;

    /**********************************************************************************************/
    /*** External functions                                                                     ***/
    /**********************************************************************************************/

    function cancel() external;

    function fulfill(address account, uint256 requestId) external;

    function request(
        address vault,
        uint256 shares,
        address recipient,
        uint256 deadline
    ) external returns (uint256 requestId);

}
