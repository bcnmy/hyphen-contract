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
    uint256 private constant BASE_DIVISOR = 10**27;

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

    /**
     * @dev Modifier for checking to validate a NFTId and it's ownership
     * @param _tokenId token id to validate
     * @param _transactor typically msgSender(), passed to verify against owner of _tokenId
     */
    modifier onlyValidLpToken(uint256 _tokenId, address _transactor) {
        (address token, , , , ) = lpToken.tokenMetadata(_tokenId);
        require(lpToken.exists(_tokenId), "ERR__TOKEN_DOES_NOT_EXIST");
        require(lpToken.ownerOf(_tokenId) == _transactor, "ERR__TRANSACTOR_DOES_NOT_OWN_NFT");
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
     * @dev To be called post initialization, used to set address of NFT Contract
     * @param _lpToken address of lpToken
     */
    function setLpToken(address _lpToken) external onlyOwner {
        lpToken = ILPToken(_lpToken);
        emit LpTokenUpdated(_lpToken);
    }

    /**
     * @dev Returns current price of lp token in terms of base token.
     * @param _baseToken address of baseToken whose current share price is to be calculated
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
     * @dev Returns the fee accumulated on a given NFT
     * @param _nftId Id of NFT
     * @return accumulated fee
     */
    function getFeeAccumulatedOnNft(uint256 _nftId) public view returns (uint256) {
        require(lpToken.exists(_nftId), "ERR__INVALID_NFT");
        (address token, , uint256 totalShares, uint256 savedRewards, uint256 priceWhenSavedRewards) = lpToken
            .tokenMetadata(_nftId);
        uint256 price = getLpSharePriceInTermsOfBaseToken(token) - priceWhenSavedRewards;
        return savedRewards + (totalShares * price) / BASE_DIVISOR;
    }

    /**
     * @dev Records fee being added to total reserve
     * @param _token Address of Token for which LP fee is being added
     * @param _amount Amount being added
     */
    function _addLPFee(address _token, uint256 _amount) internal {
        tokenToTotalReserve[_token] += _amount;
        emit LPFeeAdded(_token, _amount);
    }

    /**
     * @dev Private function to add liquidity to a new NFT
     */
    function _addLiquidity(address _token, uint256 _amount) private {
        require(_amount > 0, "ERR__AMOUNT_IS_0");
        uint256 nftId = lpToken.mint(_msgSender());
        LpTokenMetadata memory data = LpTokenMetadata(_token, 0, 0, 0, getLpSharePriceInTermsOfBaseToken(_token));
        lpToken.updateTokenMetadata(nftId, data);
        _increaseLiquidity(nftId, _amount);
        emit LPTokenMinted(_msgSender(), nftId);
    }

    /**
     * @dev Internal Function to mint a new NFT for a user, add native liquidity and store the
     *      record in the newly minted NFT
     */
    function _addNativeLiquidity() internal {
        _addLiquidity(NATIVE, msg.value);
    }

    /**
     * @dev Internal Function to mint a new NFT for a user, add token liquidity and store the
     *      record in the newly minted NFT
     * @param _token Address of token for which liquidity is to be added
     * @param _amount Amount of liquidity added
     */
    function _addTokenLiquidity(address _token, uint256 _amount) internal {
        require(_token != NATIVE, "ERR__WRONG_FUNCTION");
        require(
            IERC20Upgradeable(_token).allowance(_msgSender(), address(this)) >= _amount,
            "ERR__INSUFFICIENT_ALLOWANCE"
        );
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(_token), _msgSender(), address(this), _amount);
        _addLiquidity(_token, _amount);
    }

    /**
     * @dev Private helper function to increase liquidity in a given NFT
     */
    function _increaseLiquidity(uint256 _nftId, uint256 _amount) private onlyValidLpToken(_nftId, _msgSender()) {
        (
            address token,
            uint256 totalSuppliedLiquidity,
            uint256 totalShares,
            uint256 savedRewards,
            uint256 priceWhenSavedRewards
        ) = lpToken.tokenMetadata(_nftId);

        require(_amount > 0, "ERR__AMOUNT_IS_0");
        (savedRewards, priceWhenSavedRewards) = _getUpdatedSavedRewardsAndPrice(_nftId);

        uint256 lpSharePrice = getLpSharePriceInTermsOfBaseToken(token);
        uint256 mintedSharesAmount = (_amount * BASE_DIVISOR) / lpSharePrice;
        tokenToTotalReserve[token] += _amount;
        tokenToTotalSharesMinted[token] += mintedSharesAmount;

        LpTokenMetadata memory data = LpTokenMetadata(
            token,
            totalSuppliedLiquidity + _amount,
            totalShares + mintedSharesAmount,
            savedRewards,
            priceWhenSavedRewards
        );
        lpToken.updateTokenMetadata(_nftId, data);

        emit LiquidityAdded(_msgSender(), token, _amount);
    }

    /**
     * @dev Internal Function to allow LPs to add ERC20 token liquidity to existing NFT
     * @param _nftId ID of NFT for updating the balances
     * @param _amount Token amount to be added
     */
    function _increaseTokenLiquidity(uint256 _nftId, uint256 _amount) internal {
        (address token, , , , ) = lpToken.tokenMetadata(_nftId);
        require(token != NATIVE, "ERR__WRONG_FUNCTION");
        require(
            IERC20Upgradeable(token).allowance(_msgSender(), address(this)) >= _amount,
            "ERR__INSUFFICIENT_ALLOWANCE"
        );
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(token), _msgSender(), address(this), _amount);
        _increaseLiquidity(_nftId, _amount);
    }

    /**
     * @dev Internal Function to allow LPs to add native token liquidity to existing NFT
     */
    function _increaseNativeLiquidity(uint256 _nftId) internal {
        (address token, , , , ) = lpToken.tokenMetadata(_nftId);
        require(token == NATIVE, "ERR__WRONG_FUNCTION");
        _increaseLiquidity(_nftId, msg.value);
    }

    /**
     * @dev Private Function to burn LP shares and remove liquidity from existing NFT
     */
    function _burnSharesFromNft(
        uint256 _nftId,
        uint256 _shares,
        bool _onlyFeePool
    ) private onlyValidLpToken(_nftId, _msgSender()) {
        (
            address baseTokenAddress,
            uint256 totalSuppliedLiquidity,
            uint256 totalShares,
            uint256 savedRewards,
            uint256 priceWhenSavedRewards
        ) = lpToken.tokenMetadata(_nftId);
        require(totalShares >= _shares && _shares > 0, "ERR__INVALID_SHARES_AMOUNT");
        (savedRewards, priceWhenSavedRewards) = _getUpdatedSavedRewardsAndPrice(_nftId);

        uint256 baseTokenAmount = (_shares * priceWhenSavedRewards) / BASE_DIVISOR;
        tokenToTotalReserve[baseTokenAddress] -= baseTokenAmount;
        tokenToTotalSharesMinted[baseTokenAddress] -= _shares;
        totalShares -= _shares;

        if (_onlyFeePool) {
            // Only Burn from accumulated Fee, don't touch SL
            require(savedRewards >= baseTokenAmount, "ERR__INSUFFICIENT_REWARDS");
            savedRewards -= baseTokenAmount;
        } else {
            // First burn SL, then burn from accumulated fee if required
            if (baseTokenAmount > totalSuppliedLiquidity) {
                savedRewards -= (baseTokenAmount - totalSuppliedLiquidity);
                totalSuppliedLiquidity = 0;
            } else {
                totalSuppliedLiquidity -= baseTokenAmount;
            }
        }

        lpToken.updateTokenMetadata(
            _nftId,
            LpTokenMetadata(baseTokenAddress, totalSuppliedLiquidity, totalShares, savedRewards, priceWhenSavedRewards)
        );

        if (baseTokenAddress == NATIVE) {
            require(address(this).balance >= baseTokenAmount, "ERR__INSUFFICIENT_BALANCE");
            bool success = payable(_msgSender()).send(baseTokenAmount);
            require(success, "ERR__NATIVE_TRANSFER_FAILED");
        } else {
            IERC20Upgradeable baseToken = IERC20Upgradeable(baseTokenAddress);
            require(baseToken.balanceOf(address(this)) >= baseTokenAmount, "ERR__INSUFFICIENT_BALANCE");
            SafeERC20Upgradeable.safeTransfer(baseToken, _msgSender(), baseTokenAmount);
        }

        emit LPSharesBurnt(_msgSender(), baseTokenAddress, _shares, baseTokenAmount);
    }

    /**
     * @dev Internal Function to burn LP shares and remove liquidity from existing NFT
     * @param _nftId ID of NFT where liquidity is recorded
     * @param _shares Amount of shares to burn
     */
    function _decreaseLiquidity(uint256 _nftId, uint256 _shares) internal {
        _burnSharesFromNft(_nftId, _shares, false);
    }

    /**
     * @dev Function to allow LPs to burn a part of their shares that represent their reward
     * @param _nftId ID of NFT where liquidity is recorded
     */
    function _extractFee(uint256 _nftId, uint256 _shares) internal {
        _burnSharesFromNft(_nftId, _shares, true);
    }

    function _getSuppliedLiquidity(uint256 _nftId) internal view returns (uint256) {
        (, uint256 totalSuppliedLiquidity, , , ) = lpToken.tokenMetadata(_nftId);
        return totalSuppliedLiquidity;
    }

    function _getUpdatedSavedRewardsAndPrice(uint256 _nftId) internal view returns (uint256, uint256) {
        (address token, , , uint256 savedRewards, uint256 priceWhenSavedRewards) = lpToken.tokenMetadata(_nftId);
        priceWhenSavedRewards = getLpSharePriceInTermsOfBaseToken(token);
        savedRewards = getFeeAccumulatedOnNft(_nftId);
        return (savedRewards, priceWhenSavedRewards);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function isTokenSupported(address _token) public view virtual returns (bool);
}
