// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

interface IATokenLike {

    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

}
