// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { ISavingsVaultIntents } from "./ISavingsVaultIntents.sol";

interface ISavingsVaultIntentsV2 is ISavingsVaultIntents {

    /**********************************************************************************************/
    /*** Types                                                                                  ***/
    /**********************************************************************************************/

    enum VenueType { ERC4626, AAVE, PSM }

    struct VenueConfig {
        bool      whitelisted;
        VenueType venueType;
    }

    /**********************************************************************************************/
    /*** Errors                                                                                 ***/
    /**********************************************************************************************/

    error EmptyVenueOrder();
    error InsufficientVenueLiquidity(uint256 required, uint256 available);
    error InvalidAssetAddress();
    error InvalidMainnetControllerAddress();
    error InvalidVenueAddress();
    error VenueNotWhitelisted(address venue);

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event DefaultVenueOrderUpdated(address indexed vault, address[] venues);

    event RequestPermissionlessFulfilled(
        address indexed account,
        address indexed vault,
        uint256 indexed requestId
    );

    event VenueConfigUpdated(
        address indexed asset,
        address indexed venue,
        bool            whitelisted,
        uint8           venueType
    );

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/
    function setDefaultVenueOrder(address vault, address[] calldata venues) external;
    
    function updateVenueConfig(
        address   asset,
        address   venue,
        bool      whitelisted_,
        VenueType venueType_
    ) external;

    /**********************************************************************************************/
    /*** External functions                                                                     ***/
    /**********************************************************************************************/

    function permissionlessFulfill(
        address account,
        address vault,
        uint256 requestId
    ) external;

    function permissionlessFulfill(
        address   account,
        address   vault,
        uint256   requestId,
        address[] calldata venues
    ) external;

    /**********************************************************************************************/
    /*** View functions                                                                         ***/
    /**********************************************************************************************/

    function defaultVenueOrder(address vault, uint256 index) external view returns (address venue);

    function venueConfig(
        address asset,
        address venue
    )
        external
        view
        returns (bool whitelisted, VenueType venueType);

}
