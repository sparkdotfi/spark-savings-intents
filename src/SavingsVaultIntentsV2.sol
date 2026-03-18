// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { IERC4626Like }           from "./interfaces/IERC4626Like.sol";
import { IMainnetControllerLike } from "./interfaces/IMainnetControllerLike.sol";
import { ISavingsVaultIntentsV2 } from "./interfaces/ISavingsVaultIntentsV2.sol";

import { SavingsVaultIntents } from "./SavingsVaultIntents.sol";

contract SavingsVaultIntentsV2 is ISavingsVaultIntentsV2, SavingsVaultIntents {

    /**********************************************************************************************/
    /*** Declarations and constructor                                                           ***/
    /**********************************************************************************************/

    IMainnetControllerLike public immutable mainnetController;

    mapping(address asset => mapping(address venue => VenueConfig config)) public venueConfig;

    mapping(address vault => address[] venues) public defaultVenueOrder;

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

    function updateVenueConfig(
        address   asset,
        address   venue,
        bool      whitelisted_,
        VenueType venueType_
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(asset != address(0), InvalidAssetAddress());
        require(venue != address(0), InvalidVenueAddress());

        // NOTE: Find a way to check that venue is actually related the asset (underlying)

        venueConfig[asset][venue] = VenueConfig({
            whitelisted : whitelisted_,
            venueType   : venueType_
        });

        emit VenueConfigUpdated(asset, venue, whitelisted_, uint8(venueType_));
    }

    function setDefaultVenueOrder(address vault, address[] calldata venues)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(vault != address(0), InvalidVaultAddress());

        // TODO : Do non-zero checks on venues

        defaultVenueOrder[vault] = venues;

        emit DefaultVenueOrderUpdated(vault, venues);
    }

    /**********************************************************************************************/
    /*** External functions                                                                     ***/
    /**********************************************************************************************/

    function permissionlessFulfill(
        address account,
        address vault,
        uint256 requestId
    )
        external
    {
        address[] memory venues = defaultVenueOrder[vault];

        require(venues.length > 0, EmptyVenueOrder());

        _permissionlessFulfill(account, vault, requestId, venues);
    }

    function permissionlessFulfill(
        address   account,
        address   vault,
        uint256   requestId,
        address[] calldata venues
    )
        external
    {
        require(venues.length > 0, EmptyVenueOrder());

        _permissionlessFulfill(account, vault, requestId, venues);
    }

    /**********************************************************************************************/
    /*** Internal functions                                                                     ***/
    /**********************************************************************************************/

    function _permissionlessFulfill(
        address          account,
        address          vault,
        uint256          requestId,
        address[] memory venues
    )
        internal
    {
        WithdrawRequest memory request_ = withdrawRequests[account][vault];

        require(
            requestId != 0 && request_.requestId == requestId,
            RequestNotFound(account, vault)
        );

        require(
            block.timestamp <= request_.deadline,
            DeadlineExceeded(account, vault, request_.requestId, request_.deadline)
        );

        uint256 assetsRequired = IERC4626Like(vault).convertToAssets(request_.shares);

        address underlying = IERC4626Like(vault).asset();

        // Step 1: Withdraw underlying from venues
        uint256 totalWithdrawn = _withdrawFromVenues(underlying, venues, assetsRequired);

        require(
            totalWithdrawn >= assetsRequired,
            InsufficientVenueLiquidity(assetsRequired, totalWithdrawn)
        );

        // Step 2: Transfer assets to the vault 
        mainnetController.transferAsset(underlying, vault, totalWithdrawn);

        // Step 3: Delete the request and redeem shares for the user
        delete withdrawRequests[account][vault];

        emit RequestPermissionlessFulfilled(account, vault, request_.requestId);

        IERC4626Like(vault).redeem(request_.shares, request_.recipient, account);
    }

    function _withdrawFromVenues(
        address          underlying,
        address[] memory venues,
        uint256          assetsRequired
    )
        internal returns (uint256 totalWithdrawn)
    {
        for (uint256 i = 0; i < venues.length; ++i) {
            if (totalWithdrawn >= assetsRequired) break;

            VenueConfig memory venue = venueConfig[underlying][venues[i]];

            require(venue.whitelisted, VenueNotWhitelisted(venues[i]));

            uint256 remaining = assetsRequired - totalWithdrawn;

            uint256 withdrawn;

            if (venue.venueType == VenueType.ERC4626) {
                withdrawn = mainnetController.withdrawERC4626(
                    venues[i],
                    remaining,
                    type(uint256).max  // maxSharesIn: no limit
                );
            } else if (venue.venueType == VenueType.AAVE) {
                withdrawn = mainnetController.withdrawAave(
                    venues[i],
                    remaining
                );
            } else if (venue.venueType == VenueType.PSM) {
                mainnetController.swapUSDSToUSDC(remaining);
                withdrawn = remaining;
            }

            totalWithdrawn += withdrawn;
        }
    }

}
