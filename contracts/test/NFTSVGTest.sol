// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../hyphen/svg/NFTSVG.sol";

contract NFTSVGTest is NFTSVG {
    using StringsUpgradeable for uint256;

    function initialize(uint256 _decimals, string memory _backgroundUrl) public initializer {
        __NFTSVG_init(_decimals, _backgroundUrl);
    }

    function getDigitsCount(uint256 _number) external pure returns (uint256) {
        return _getDigitsCount(_number);
    }

    function getZeroString(uint256 _length) public pure returns (string memory) {
        return _getZeroString(_length);
    }

    function truncateDigitsFromRight(uint256 _number, uint256 _digitsCount) public pure returns (uint256) {
        return _truncateDigitsFromRight(_number, _digitsCount);
    }

    function divideByPowerOf10(
        uint256 _value,
        uint256 _power,
        uint256 _maxDigitsAfterDecimal
    ) public pure returns (string memory) {
        return _divideByPowerOf10(_value, _power, _maxDigitsAfterDecimal);
    }

    function calculatePercentage(uint256 _num, uint256 _denom) public pure returns (string memory) {
        return _calculatePercentage(_num, _denom);
    }

    function getTokenSvg(
        uint256,
        uint256,
        uint256
    ) public view virtual override returns (string memory) {
        return "";
    }
}
