// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "../structures/LpTokenMetadata.sol";
import "hardhat/console.sol";

interface ILPToken is IERC721Upgradeable {
    function mint(address _to) external returns (uint256);

    function updateTokenMetadata(uint256 _tokenId, LpTokenMetadata memory _lpTokenMetadata) external;

    function exists(uint256 _tokenId) external returns (bool);

    function tokenMetadata(uint256 _tokenId) external returns (address ,uint256,uint256);
}
