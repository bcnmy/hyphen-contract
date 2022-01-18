// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct LpTokenMetadata {
    address token;
    uint256 totalSuppliedLiquidity;
    uint256 totalShares;
    uint256 savedRewards;
    uint256 priceWhenSavedRewards;
}
