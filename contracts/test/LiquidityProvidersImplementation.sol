// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../hyphen/LiquidityProviders.sol";
import "hardhat/console.sol";

contract LiquidityProvidersImplementation is LiquidityProviders {
    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize(address _trustedForwarder) public initializer {
        __LiquidityProviders_init(_trustedForwarder);
    }

    function addLPFee(address _token, uint256 _amount) external payable {
        if (_token == NATIVE) {
            require(msg.value == _amount, "INVALID_VALUE");
        } else {
            IERC20Upgradeable(_token).safeTransferFrom(_msgSender(), address(this), _amount);
        }
        _addLPFee(_token, _amount);
    }

    function addTokenLiquidity(uint256 _nftId, uint256 _amount) external {
        _addTokenLiquidity(_nftId, _amount);
    }

    function addNativeLiquidity(uint256 _nftId) external payable {
        _addNativeLiquidity(_nftId);
    }

    function addTokenLiquidityToNewNft(address _token, uint256 _amount) external {
        _addTokenLiquidityToNewNft(_token, _amount);
    }

    function addNativeLiquidityToNewNft() external payable {
        _addNativeLiquidityToNewNft();
    }

    function burnLpShares(uint256 _nftId, uint256 _amount) external {
        _burnLpShares(_nftId, _amount);
    }

    function isTokenSupported(address) public pure override returns (bool) {
        return true;
    }
}
