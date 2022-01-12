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

    function addTokenLiquidity(address _token, uint256 _amount) external {
        _addTokenLiquidity(_token, _amount);
    }

    function addNativeLiquidity() external payable {
        _addNativeLiquidity();
    }

    function burnLpTokens(address _lpToken, uint256 _amount) external {
        _burnLpTokens(_lpToken, _amount);
    }
}
