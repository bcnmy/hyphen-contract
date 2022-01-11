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
    mapping(address => uint256) public suppliedLiquidityPool;
    mapping(address => uint256) public feePool;
    mapping(address => address) public baseTokenToLpToken;
    mapping(address => address) public lpTokenToBaseToken;

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

    function setLpToken(address _baseToken, address _lpToken) external onlyOwner {
        baseTokenToLpToken[_baseToken] = _lpToken;
        lpTokenToBaseToken[_lpToken] = _baseToken;
    }

    /**
     * @dev Returns current price of lp token in terms of base token.
     * @return Price multiplied by BASE
     */
    function getLpTokenPriceInTermsOfBaseToken(address _baseToken) public view returns (uint256) {
        IERC20Upgradeable lpToken = IERC20Upgradeable(baseTokenToLpToken[_baseToken]);
        require(lpToken != IERC20Upgradeable(address(0)), "ERR_TOKEN_NOT_SUPPORTED");
        return ((feePool[_baseToken] + suppliedLiquidityPool[_baseToken]) * BASE_DIVISOR) / lpToken.totalSupply();
    }

    /**
     * @dev Calculates the SL share given an LP token amount
     */
    function _calculateSuppliedLiquidityPoolShare(address _lpToken, uint256 _amount) internal view returns (uint256) {
        ILPToken lpToken = ILPToken(_lpToken);
        address baseTokenAddress = lpTokenToBaseToken[_lpToken];
        require(baseTokenAddress != address(0), "ERR_TOKEN_NOT_SUPPORTED");
        if (lpToken.totalSupply() != 0) {
            return (_amount * suppliedLiquidityPool[baseTokenAddress]) / lpToken.totalSupply();
        }
        return 0;
    }

    /**
     * @dev Calculates the Fee pool share given an LP token amount
     */
    function _calculateFeePoolShare(address _lpToken, uint256 _amount) internal view returns (uint256) {
        ILPToken lpToken = ILPToken(_lpToken);
        address baseTokenAddress = lpTokenToBaseToken[_lpToken];
        require(baseTokenAddress != address(0), "ERR_TOKEN_NOT_SUPPORTED");
        if (lpToken.totalSupply() != 0) {
            return (_amount * feePool[baseTokenAddress]) / lpToken.totalSupply();
        }
        return 0;
    }

    /**
     * @dev Calculates and returns an LP's current Supplied Liquidity and Rewards share
     * @param _lp Address of LP
     * @param _lpToken address of lp token
     * @return Supplied Liquidity Share and Rewards Share
     */
    function getLpPosition(address _lp, address _lpToken) public view returns (uint256, uint256) {
        ILPToken lpToken = ILPToken(_lpToken);
        uint256 balance = lpToken.balanceOf(_lp);
        uint256 suppliedLiquidityAmount = _calculateSuppliedLiquidityPoolShare(_lpToken, balance);
        uint256 feeAmount = _calculateFeePoolShare(_lpToken, balance);
        return (suppliedLiquidityAmount, feeAmount);
    }

    /**
     * @dev Records fee being added to total reserve
     */
    function _addLPFee(address _token, uint256 _amount) internal {
        feePool[_token] += _amount;
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
        SafeERC20Upgradeable.safeTransferFrom(token, _msgSender(), address(this), _amount);
        feePool[_token] += _amount;

        uint256 lpTokenPrice = getLpTokenPriceInTermsOfBaseToken(_token);
        uint256 mintedLpTokenAmount = (_amount * BASE_DIVISOR) / lpTokenPrice;
        ILPToken lpToken = ILPToken(baseTokenToLpToken[_token]);
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

        uint256 amount = msg.value;
        feePool[_token] += amount;
        uint256 lpTokenPrice = getLpTokenPriceInTermsOfBaseToken(_token);
        uint256 mintedLpTokenAmount = (amount * BASE_DIVISOR) / lpTokenPrice;
        ILPToken lpToken = ILPToken(baseTokenToLpToken[_token]);
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

        ILPToken lpToken = ILPToken(_lpToken);
        address baseTokenAddress = lpTokenToBaseToken[_lpToken];
        IERC20Upgradeable baseToken = IERC20Upgradeable(baseTokenAddress);
        require(address(baseToken) != address(0), "ERR_INVALID_LP_TOKEN");

        uint256 suppliedLiquidityAmount = _calculateSuppliedLiquidityPoolShare(_lpToken, _amount);
        uint256 feeAmount = _calculateFeePoolShare(_lpToken, _amount);
        uint256 totalAmount = suppliedLiquidityAmount + feeAmount;
        suppliedLiquidityPool[baseTokenAddress] -= suppliedLiquidityAmount;
        feePool[baseTokenAddress] -= feeAmount;

        lpToken.burnFrom(_msgSender(), _amount);

        if (address(baseToken) == NATIVE) {
            require(address(this).balance >= totalAmount, "INSUFFICIENT_BALANCE");
            bool success = payable(_msgSender()).send(totalAmount);
            require(success, "ERR_NATIVE_TRANSFER_FAILED");
        } else {
            require(baseToken.balanceOf(address(this)) >= totalAmount, "INSUFFICIENT_BALANCE");
            SafeERC20Upgradeable.safeTransfer(baseToken, _msgSender(), totalAmount);
        }

        emit LPTokensBurnt(_msgSender(), _lpToken, _amount, totalAmount);
    }
}
