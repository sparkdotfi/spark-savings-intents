// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

interface ISavingsVaultIntents {

    /**********************************************************************************************/
    /*** Types                                                                                  ***/
    /**********************************************************************************************/

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

    error InvalidAdminAddress();

    error InvalidMaxDeadline();

    error InvalidRelayerAddress();

    error InvalidVaultAddress();

    error VaultNotWhitelisted();

    error InvalidRecipientAddress();

    error InvalidMaxIntentAssets();

    error MinIntentAssetsAboveMax(uint256 minIntentAssets, uint256 maxIntentAssets);

    error MaxIntentAssetsBelowMin(uint256 maxIntentAssets, uint256 minIntentAssets);

    error InvalidDeadline(uint256 maxDeadline, uint256 deadline);

    error IntentAssetsBelowMin(uint256 minAssets, uint256 assets);

    error IntentAssetsAboveMax(uint256 maxAssets, uint256 assets);

    error InsufficientShares(uint256 sharesRequested, uint256 sharesPresent);

    error DeadlineExceeded(address account, uint256 requestId, uint256 deadline);

    error RequestNotFound(address account);

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event RequestCreated(
        address indexed account,
        uint256 indexed requestId,
        address indexed vault,
        uint256         shares,
        address         recipient,
        uint256         deadline
    );

    event RequestCancelled(address indexed account, uint256 indexed requestId);

    event RequestFulfilled(address indexed account, uint256 indexed requestId);

    event MaxDeadlineUpdated(uint256 indexed maxDeadline);

    event MinIntentAssetsUpdated(uint256 indexed minIntentAssets);
    
    event MaxIntentAssetsUpdated(uint256 indexed maxIntentAssets);

    event WhitelistUpdated(address indexed vault, bool indexed enabled);

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setMaxDeadline(uint256 maxDeadline_) external;

    function setMinIntentAssets(uint256 minIntentAssets_) external;

    function setMaxIntentAssets(uint256 maxIntentAssets_) external;

    function updateWhitelist(address vault, bool enabled) external;

    /**********************************************************************************************/
    /*** External functions                                                                     ***/
    /**********************************************************************************************/

    function request(
        address vault,
        uint256 shares,
        address recipient,
        uint256 deadline
    ) external returns (uint256 requestId);

    function cancel() external;

    function fulfill(address account, uint256 requestId) external;

}
