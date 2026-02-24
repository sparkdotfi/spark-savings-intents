// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

interface IERC4626Like {

    function redeem(uint256 shares, address receiver, address owner)
        external 
        returns (uint256 assets);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256 assets);

}
