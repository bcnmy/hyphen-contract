// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interfaces/ILPToken.sol";
import "./metatx/ERC2771ContextUpgradeable.sol";

abstract contract LiquidityProviders is Initializable, ERC2771ContextUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant BASE_DIVISOR = 10000000000;

    event LiquidityAdded(address lp, address token, uint256 amount);
    event LiquidityRemoved(address lp, address token, uint256 amount);
    event LPTokenMinted(address lp, uint256 tokenId);
    event LPFeeAdded(address token, uint256 amount);
    event LPSharesBurnt(address claimer, address token, uint256 sharesAmount, uint256 baseAmount);
    event LpTokenUpdated(address lpToken);

    ILPToken public lpToken;

    // LP Fee Distribution
    mapping(address => uint256) public tokenToTotalReserve;
    mapping(address => uint256) public tokenToTotalSharesMinted;

    modifier onlyValidLpToken(uint256 _tokenId, address transactor) {
        (address token, , ) = lpToken.tokenMetadata(_tokenId);
        require(lpToken.exists(_tokenId), "ERR__TOKEN_DOES_NOT_EXIST");
        require(lpToken.ownerOf(_tokenId) == _msgSender(), "ERR__TRANSACTOR_DOES_NOT_OWN_NFT");
        _;
    }

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

    function setLpToken(address _lpToken) external onlyOwner {
        lpToken = ILPToken(_lpToken);
        emit LpTokenUpdated(_lpToken);
    }

    /**
     * @dev Returns current price of lp token in terms of base token.
     * @return Price multiplied by BASE
     */
    function getLpSharePriceInTermsOfBaseToken(address _baseToken) public view returns (uint256) {
        require(isTokenSupported(_baseToken), "ERR__TOKEN_NOT_SUPPORTED");
        uint256 supply = tokenToTotalSharesMinted[_baseToken];
        if (supply > 0) {
            return (tokenToTotalReserve[_baseToken] * BASE_DIVISOR) / supply;
        }
        return 1 * BASE_DIVISOR;
    }

    /**
     * @dev Records fee being added to total reserve
     */
    function _addLPFee(address _token, uint256 _amount) internal {
        tokenToTotalReserve[_token] += _amount;
        emit LPFeeAdded(_token, _amount);
    }

    function _addNativeLiquidityToNewNft() internal {
        uint256 nftId = lpToken.mint(_msgSender());
        LpTokenMetadata memory data = LpTokenMetadata(NATIVE, 0, 0);
        lpToken.updateTokenMetadata(nftId, data);
        _addNativeLiquidity(nftId);
        emit LPTokenMinted(_msgSender(), nftId);
    }

    function _addTokenLiquidityToNewNft(address _token, uint256 _amount) internal {
        require(_token != NATIVE, "ERR__WRONG_FUNCTION");
        uint256 nftId = lpToken.mint(_msgSender());
        LpTokenMetadata memory data = LpTokenMetadata(_token, 0, 0);
        lpToken.updateTokenMetadata(nftId, data);
        _addTokenLiquidity(nftId, _amount);
        emit LPTokenMinted(_msgSender(), nftId);
    }

    /**
     * @dev Internal Function to allow LPs to add ERC20 token liquidity
     * @param _nftId ID of NFT for updating the balances
     * @param _amount Token amount to be added
     */
    function _addTokenLiquidity(uint256 _nftId, uint256 _amount) internal onlyValidLpToken(_nftId, _msgSender()) {
        (address token, uint256 totalSuppliedLiquidity, uint256 totalShares) = lpToken.tokenMetadata(_nftId);

        require(
            IERC20Upgradeable(token).allowance(_msgSender(), address(this)) >= _amount,
            "ERR__INSUFFICIENT_ALLOWANCE"
        );
        require(token != NATIVE, "ERR__WRONG_FUNCTION");
        require(_amount > 0, "ERR_AMOUNT_IS_0");

        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(token), _msgSender(), address(this), _amount);
        uint256 lpSharePrice = getLpSharePriceInTermsOfBaseToken(token);
        uint256 mintedSharesAmount = (_amount * BASE_DIVISOR) / lpSharePrice;
        tokenToTotalReserve[token] += _amount;
        tokenToTotalSharesMinted[token] += mintedSharesAmount;

        LpTokenMetadata memory data = LpTokenMetadata(
            token,
            totalSuppliedLiquidity + _amount,
            totalShares + mintedSharesAmount
        );
        lpToken.updateTokenMetadata(_nftId, data);

        emit LiquidityAdded(_msgSender(), token, _amount);
    }

    /**
     * @dev Internal Function to allow LPs to add native token liquidity
     */
    function _addNativeLiquidity(uint256 _nftId) internal onlyValidLpToken(_nftId, _msgSender()) {
        (address token, uint256 totalSuppliedLiquidity, uint256 totalShares) = lpToken.tokenMetadata(_nftId);
        require(token == NATIVE, "ERR__WRONG_FUNCTION");

        uint256 amount = msg.value;
        require(amount > 0, "ERR__AMOUNT_IS_0");

        uint256 lpSharePrice = getLpSharePriceInTermsOfBaseToken(NATIVE);
        uint256 mintedSharesAmount = (amount * BASE_DIVISOR) / lpSharePrice;
        tokenToTotalReserve[NATIVE] += amount;
        tokenToTotalSharesMinted[NATIVE] += mintedSharesAmount;

        LpTokenMetadata memory data = LpTokenMetadata(
            NATIVE,
            totalSuppliedLiquidity + amount,
            totalShares + mintedSharesAmount
        );
        lpToken.updateTokenMetadata(_nftId, data);

        emit LiquidityAdded(_msgSender(), NATIVE, msg.value);
    }

    /**
     * @dev Internal Function to burn LP shares
     */
    function _burnLpShares(uint256 _nftId, uint256 _amount) internal onlyValidLpToken(_nftId, _msgSender()) {
        (address baseTokenAddress, uint256 totalSuppliedLiquidity, uint256 totalShares) = lpToken.tokenMetadata(_nftId);
        require(totalShares >= _amount, "ERR__INSUFFICIENT_SHARES");

        uint256 lpSharePrice = getLpSharePriceInTermsOfBaseToken(baseTokenAddress);
        uint256 baseTokenAmount = (_amount * lpSharePrice) / BASE_DIVISOR;
        tokenToTotalReserve[baseTokenAddress] -= baseTokenAmount;
        tokenToTotalSharesMinted[baseTokenAddress] -= _amount;

        totalShares -= _amount;
        totalSuppliedLiquidity = totalShares * getLpSharePriceInTermsOfBaseToken(baseTokenAddress);

        lpToken.updateTokenMetadata(_nftId, LpTokenMetadata(baseTokenAddress, totalSuppliedLiquidity, totalShares));

        if (baseTokenAddress == NATIVE) {
            require(address(this).balance >= baseTokenAmount, "ERR__INSUFFICIENT_BALANCE");
            bool success = payable(_msgSender()).send(baseTokenAmount);
            require(success, "ERR__NATIVE_TRANSFER_FAILED");
        } else {
            IERC20Upgradeable baseToken = IERC20Upgradeable(baseTokenAddress);
            require(baseToken.balanceOf(address(this)) >= baseTokenAmount, "ERR__INSUFFICIENT_BALANCE");
            SafeERC20Upgradeable.safeTransfer(baseToken, _msgSender(), baseTokenAmount);
        }

        emit LPSharesBurnt(_msgSender(), baseTokenAddress, _amount, baseTokenAmount);
    }

    function isTokenSupported(address _token) public view virtual returns (bool);
}
