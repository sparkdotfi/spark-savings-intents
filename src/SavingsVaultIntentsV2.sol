// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IATokenLike }            from "./interfaces/IATokenLike.sol";
import { IERC4626Like }           from "./interfaces/IERC4626Like.sol";
import { IMainnetControllerLike } from "./interfaces/IMainnetControllerLike.sol";
import { ISavingsVaultIntentsV2 } from "./interfaces/ISavingsVaultIntentsV2.sol";

import { SavingsVaultIntents } from "./SavingsVaultIntents.sol";

contract SavingsVaultIntentsV2 is ISavingsVaultIntentsV2, SavingsVaultIntents, ReentrancyGuard {

    /**********************************************************************************************/
    /*** Declarations and constructor                                                           ***/
    /**********************************************************************************************/

    IMainnetControllerLike public immutable mainnetController;

    mapping(address vault => address aToken) public vaultToAToken;

    constructor(
        address admin,
        address relayer,
        uint256 maxDeadlineDuration_,
        address mainnetController_
    )
        SavingsVaultIntents(admin, relayer, maxDeadlineDuration_)
    {
        require(mainnetController_ != address(0), InvalidMainnetControllerAddress());

        mainnetController = IMainnetControllerLike(mainnetController_);
    }

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setVaultToAToken(address vault, address aToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(vault  != address(0), InvalidVaultAddress());
        require(aToken != address(0), InvalidATokenAddress());

        require(
            IATokenLike(aToken).UNDERLYING_ASSET_ADDRESS() == IERC4626Like(vault).asset(),
            InvalidATokenUnderlying()
        );

        vaultToAToken[vault] = aToken;

        emit VaultToATokenSet(vault, aToken);
    }

    /**********************************************************************************************/
    /*** External functions                                                                     ***/
    /**********************************************************************************************/

    function permissionlessFulfill(address vault, uint256 requestId) external nonReentrant {
        // TODO : Consider adding a relayer grace period, and allow permissionless fulfillment after the grace period has expired.

        // Allowing only self-fulfillment for permissionless requests
        WithdrawRequest memory request_ = withdrawRequests[msg.sender][vault];

        require(
            requestId != 0 && request_.requestId == requestId,
            RequestNotFound(msg.sender, vault)
        );

        require(
            block.timestamp <= request_.deadline,
            DeadlineExceeded(msg.sender, vault, request_.requestId, request_.deadline)
        );

        // Step 1: Withdraw underlying from Aave

        address aToken = vaultToAToken[vault];

        require(aToken != address(0), VaultToATokenNotSet(vault));

        uint256 assetsRequired = IERC4626Like(vault).convertToAssets(request_.shares);

        uint256 amountWithdrawn = mainnetController.withdrawAave(aToken, assetsRequired);

        require(
            amountWithdrawn >= assetsRequired,
            InsufficientATokenLiquidity(assetsRequired, amountWithdrawn)
        );

        address underlying = IERC4626Like(vault).asset();

        // Step 2: Transfer assets to the vault 
        mainnetController.transferAsset(underlying, vault, amountWithdrawn);

        // Step 3: Delete the request and redeem shares for the user
        delete withdrawRequests[msg.sender][vault];

        emit RequestPermissionlessFulfilled(msg.sender, vault, request_.requestId);

        IERC4626Like(vault).redeem(request_.shares, request_.recipient, msg.sender);
    }

}
