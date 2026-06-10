// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import { ISavingsVaultIntents } from "./ISavingsVaultIntents.sol";

interface ISavingsVaultIntentsV2 is ISavingsVaultIntents {

    /**********************************************************************************************/
    /*** Errors                                                                                 ***/
    /**********************************************************************************************/

    error InsufficientATokenLiquidity(uint256 required, uint256 available);
    error InvalidATokenAddress();
    error InvalidATokenUnderlying();
    error InvalidMainnetControllerAddress();
    error VaultToATokenNotSet(address vault);

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event RequestPermissionlessFulfilled(
        address indexed account,
        address indexed vault,
        uint256 indexed requestId
    );

    event VaultToATokenSet(address indexed vault, address indexed aToken);

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setVaultToAToken(address vault, address aToken) external;

    /**********************************************************************************************/
    /*** External functions                                                                     ***/
    /**********************************************************************************************/

    function permissionlessFulfill(address vault, uint256 requestId) external;

}
