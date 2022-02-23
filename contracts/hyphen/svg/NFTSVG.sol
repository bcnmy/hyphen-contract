// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "base64-sol/base64.sol";
import "hardhat/console.sol";

abstract contract NFTSVG is OwnableUpgradeable {
    using StringsUpgradeable for uint256;

    string public backgroundUrl;
    uint256 public tokenDecimals;

    event BackgroundUrlUpdated(string newBackgroundUrl);
    event TokenDecimalsUpdated(uint256 newTokenDecimals);

    function __NFTSVG_init(uint256 _tokenDecimals, string memory _backgroundUrl) internal initializer {
        __Ownable_init();
        backgroundUrl = _backgroundUrl;
        tokenDecimals = _tokenDecimals;
    }

    function setBackgroundPngUrl(string memory _backgroundUrl) public onlyOwner {
        backgroundUrl = _backgroundUrl;
        emit BackgroundUrlUpdated(backgroundUrl);
    }

    function setTokenDecimals(uint256 _tokenDecimals) public onlyOwner {
        tokenDecimals = _tokenDecimals;
        emit TokenDecimalsUpdated(_tokenDecimals);
    }

    function getDigitsCount(uint256 _number) internal pure returns (uint256) {
        uint256 count = 0;
        while (_number > 0) {
            ++count;
            _number /= 10;
        }
        return count;
    }

    function getZeroString(uint256 _length) internal pure returns (string memory) {
        if (_length == 0) {
            return "";
        }
        string memory result;
        for (uint256 i = 0; i < _length; ++i) {
            result = string(abi.encodePacked(result, "0"));
        }
        return result;
    }

    function truncateDigitsFromRight(uint256 _number, uint256 _digitsCount) internal pure returns (uint256) {
        return _number /= (10**_digitsCount);
    }

    function divideByPowerOf10(
        uint256 _value,
        uint256 _power,
        uint256 _maxDigitsAfterDecimal
    ) public pure returns (string memory) {
        uint256 integerPart = _value / 10**_power;
        uint256 leadingZeroesToAddBeforeDecimal = 0;
        uint256 fractionalPartTemp = _value % (10**_power);

        uint256 powerRemaining = _power;
        if (fractionalPartTemp != 0) {
            // Remove Leading Zeroes
            while (fractionalPartTemp != 0 && fractionalPartTemp % 10 == 0) {
                fractionalPartTemp /= 10;
                if (powerRemaining > 0) {
                    powerRemaining--;
                }
            }

            uint256 expectedFractionalDigits = powerRemaining;
            if (getDigitsCount(fractionalPartTemp) < expectedFractionalDigits) {
                leadingZeroesToAddBeforeDecimal = expectedFractionalDigits - getDigitsCount(fractionalPartTemp);
            }
        }

        if (fractionalPartTemp == 0) {
            return integerPart.toString();
        }
        uint256 digitsToTruncateCount = getDigitsCount(fractionalPartTemp) > _maxDigitsAfterDecimal
            ? getDigitsCount(fractionalPartTemp) - _maxDigitsAfterDecimal
            : 0;
        return
            string(
                abi.encodePacked(
                    integerPart.toString(),
                    ".",
                    getZeroString(leadingZeroesToAddBeforeDecimal),
                    truncateDigitsFromRight(fractionalPartTemp, digitsToTruncateCount).toString()
                )
            );
    }

    function getTokenSvg(
        uint256 _tokenId,
        uint256 _suppliedLiquidity,
        uint256 _totalSuppliedLiquidity
    ) public view virtual returns (string memory);
}
