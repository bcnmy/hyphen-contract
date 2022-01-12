// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "hardhat/console.sol";
import "./interface/ILPToken.sol";
import "./metatx/ERC2771ContextUpgradeable.sol";

contract LiquidityProviders is Initializable, ERC2771ContextUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant BASE_DIVISOR = 10000000000;

    event LiquidityAdded(address lp, address token, uint256 amount);
    event LiquidityRemoved(address lp, address token, uint256 amount);
    event LPFeeAdded(address token, uint256 amount);
    event LPTokensBurnt(address claimer, address lpToken, uint256 lpTokenAmount, uint256 baseAmount);

    // LP Fee Distribution
    mapping(IERC20Upgradeable => uint256) public totalReserve;
    mapping(IERC20Upgradeable => ILPToken) public baseTokenToLpToken;
    mapping(ILPToken => IERC20Upgradeable) public lpTokenToBaseToken;

    /**
     * @dev initalizes the contract, acts as constructor
     * @param _trustedForwarder address of trusted forwarder
     */
    function __LiquidityProviders_init(address _trustedForwarder) public initializer {
        __ERC2771Context_init(_trustedForwarder);
        __Ownable_init();
    }

    /**
     * @dev Meta-Transaction Helper, returns msgSender
     */
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /**
     * @dev Meta-Transaction Helper, returns msgData
     */
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function setLpToken(IERC20Upgradeable _baseToken, ILPToken _lpToken) external onlyOwner {
        baseTokenToLpToken[_baseToken] = _lpToken;
        lpTokenToBaseToken[_lpToken] = _baseToken;
    }

    /**
     * @dev Returns current price of lp token in terms of base token.
     * @return Price multiplied by BASE
     */
    function getLpTokenPriceInTermsOfBaseToken(IERC20Upgradeable _baseToken) public view returns (uint256) {
        IERC20Upgradeable lpToken = baseTokenToLpToken[_baseToken];
        require(lpToken != IERC20Upgradeable(address(0)), "ERR_TOKEN_NOT_SUPPORTED");
        return (totalReserve[_baseToken] * BASE_DIVISOR) / lpToken.totalSupply();
    }

    /**
     * @dev Records fee being added to total reserve
     */
    function _addLPFee(address _token, uint256 _amount) internal {
        totalReserve[IERC20Upgradeable(_token)] += _amount;
        emit LPFeeAdded(_token, _amount);
    }

    /**
     * @dev Internal Function to allow LPs to add ERC20 token liquidity
     * @param _token ERC20 Token for which liquidity is to be added
     * @param _amount Token amount to be added
     */
    function _addTokenLiquidity(address _token, uint256 _amount) internal {
        require(
            IERC20Upgradeable(_token).allowance(_msgSender(), address(this)) >= _amount,
            "ERR__INSUFFICIENT_ALLOWANCE"
        );

        IERC20Upgradeable token = IERC20Upgradeable(_token);
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(_token), _msgSender(), address(this), _amount);
        totalReserve[token] += _amount;

        uint256 lpTokenPrice = getLpTokenPriceInTermsOfBaseToken(token);
        uint256 mintedLpTokenAmount = (_amount * BASE_DIVISOR) / lpTokenPrice;
        ILPToken lpToken = baseTokenToLpToken[token];
        lpToken.mint(_msgSender(), mintedLpTokenAmount);

        emit LiquidityAdded(_msgSender(), _token, _amount);
    }

    /**
     * @dev Internal Function to allow LPs to add native token liquidity
     * @param _token ERC20 Token for which liquidity is to be added
     */
    function _addNativeLiquidity(address _token) internal {
        require(
            IERC20Upgradeable(_token).allowance(_msgSender(), address(this)) >= msg.value,
            "ERR__INSUFFICIENT_ALLOWANCE"
        );

        IERC20Upgradeable token = IERC20Upgradeable(_token);

        uint256 amount = msg.value;
        totalReserve[token] += amount;
        uint256 lpTokenPrice = getLpTokenPriceInTermsOfBaseToken(token);
        uint256 mintedLpTokenAmount = (amount * BASE_DIVISOR) / lpTokenPrice;
        ILPToken lpToken = baseTokenToLpToken[token];
        lpToken.mint(_msgSender(), mintedLpTokenAmount);

        emit LiquidityAdded(_msgSender(), _token, msg.value);
    }

    /**
     * @dev Internal Function to burn LP tokens
     * @param _lpToken Token to be burnt
     * @param _amount Token amount to be burnt
     */
    function _burnLpTokens(address _lpToken, uint256 _amount) internal {
        require(ILPToken(_lpToken).allowance(_msgSender(), address(this)) >= _amount, "ERR__INSUFFICIENT_ALLOWANCE");
        IERC20Upgradeable baseToken = lpTokenToBaseToken[ILPToken(_lpToken)];
        require(address(baseToken) != address(0), "ERR_INVALID_LP_TOKEN");

        uint256 lpTokenPrice = getLpTokenPriceInTermsOfBaseToken(lpTokenToBaseToken[ILPToken(_lpToken)]);
        uint256 baseTokenAmount = (_amount * lpTokenPrice) / BASE_DIVISOR;
        totalReserve[baseToken] -= baseTokenAmount;

        ILPToken(_lpToken).burnFrom(_msgSender(), _amount);

        if (address(baseToken) == NATIVE) {
            require(address(this).balance >= baseTokenAmount, "INSUFFICIENT_LIQUIDITY");
            bool success = payable(_msgSender()).send(baseTokenAmount);
            require(success, "ERR_NATIVE_TRANSFER_FAILED");
        } else {
            require(baseToken.balanceOf(address(this)) >= baseTokenAmount, "INSUFFICIENT_LIQUIDITY");
            SafeERC20Upgradeable.safeTransfer(baseToken, _msgSender(), baseTokenAmount);
        }

        emit LPTokensBurnt(_msgSender(), _lpToken, _amount, baseTokenAmount);
    }
}
