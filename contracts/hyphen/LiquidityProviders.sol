// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interfaces/ILPToken.sol";
import "./interfaces/IWhiteListPeriodManager.sol";
import "./metatx/ERC2771ContextUpgradeable.sol";
import "hardhat/console.sol";

abstract contract LiquidityProviders is Initializable, ERC2771ContextUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant BASE_DIVISOR = 10**36;

    ILPToken public lpToken;
    IWhiteListPeriodManager public whiteListPeriodManager;

    event LiquidityRemoved(address indexed tokenAddress, uint256 indexed amount, address indexed lp);
    event FeeClaimed(address indexed tokenAddress, uint256 indexed fee, address indexed lp, uint256 sharesBurnt);
    
    // LP Fee Distribution
    mapping(address => uint256) public totalReserve; // Include Liquidity + Fee accumulated
    mapping(address => uint256) public totalLiquidity; // Include Liquidity only
    mapping(address => uint256) public totalLPFees;
    mapping(address => uint256) public totalSharesMinted;

    /**
     * @dev Modifier for checking to validate a NFTId and it's ownership
     * @param _tokenId token id to validate
     * @param _transactor typically msgSender(), passed to verify against owner of _tokenId
     */
    modifier onlyValidLpToken(uint256 _tokenId, address _transactor) {
        (address token, ,) = lpToken.tokenMetadata(_tokenId);
        require(lpToken.exists(_tokenId), "ERR__TOKEN_DOES_NOT_EXIST");
        require(lpToken.ownerOf(_tokenId) == _transactor, "ERR__TRANSACTOR_DOES_NOT_OWN_NFT");
        _;
    }

    /**
     * @dev initalizes the contract, acts as constructor
     * @param _trustedForwarder address of trusted forwarder
     */
    function __LiquidityProviders_init(address _trustedForwarder, address _lpToken) public initializer {
        __ERC2771Context_init(_trustedForwarder);
        __Ownable_init();
        _setLPToken(_lpToken);
    }

    function getTotalReserveByToken(address tokenAddress) public view returns(uint256) {
        return totalReserve[tokenAddress];
    }

    function getSuppliedLiquidityByToken(address tokenAddress) public view returns(uint256) {
        return totalLiquidity[tokenAddress];
    }

    function getTotalLPFeeByToken(address tokenAddress) public view returns(uint256) {
        return totalLPFees[tokenAddress];
    }

    /**
     * @dev To be called post initialization, used to set address of NFT Contract
     * @param _lpToken address of lpToken
     */
    function setLpToken(address _lpToken) external onlyOwner {
        lpToken = ILPToken(_lpToken);
    }

    /**
     * Internal method to set LP token contract.
     */
    function _setLPToken(address _lpToken) internal {
        lpToken = ILPToken(_lpToken);
    }

    /**
     * @dev To be called post initialization, used to set address of WhiteListPeriodManager Contract
     * @param _whiteListPeriodManager address of WhiteListPeriodManager
     */
    function setWhiteListPeriodManager(address _whiteListPeriodManager) external onlyOwner {
        whiteListPeriodManager = IWhiteListPeriodManager(_whiteListPeriodManager);
    }

    /**
     * @dev Returns price of Base token in terms of LP Shares
     * @param _baseToken address of baseToken
     * @return Price of Base token in terms of LP Shares
     */
    function getTokenPriceInLPShares(address _baseToken) public view returns (uint256) {
        require(isTokenSupported(_baseToken), "ERR__TOKEN_NOT_SUPPORTED");
        uint256 supply = totalSharesMinted[_baseToken];
        if (supply > 0) {
            return totalSharesMinted[_baseToken] / totalReserve[_baseToken];
        }
        return BASE_DIVISOR;
    }

    /**
     * @dev Returns the fee accumulated on a given NFT
     * @param _nftId Id of NFT
     * @return accumulated fee
     */
    function getFeeAccumulatedOnNft(uint256 _nftId) public view returns (uint256) {
        require(lpToken.exists(_nftId), "ERR__INVALID_NFT");

        (address _tokenAddress, uint256 nftSuppliedLiquidity, uint256 totalNFTShares) = lpToken.tokenMetadata(_nftId);

        if(totalNFTShares == 0) {
            return 0;
        }
        // Calculate rewards accumulated
        uint256 eligibleLiquidity = sharesToTokenAmount(totalNFTShares, _tokenAddress);
        uint256 lpFeeAccumulated = eligibleLiquidity - nftSuppliedLiquidity;

        return lpFeeAccumulated;
    }

    /**
     * @dev Records fee being added to total reserve
     * @param _token Address of Token for which LP fee is being added
     * @param _amount Amount being added
     */
    function _addLPFee(address _token, uint256 _amount) internal {
        totalReserve[_token] += _amount;
        totalLPFees[_token] += _amount;
    }

    /**
     * @dev Private function to add liquidity to a new NFT
     */
    function _addLiquidity(address _token, uint256 _amount) private {
        require(_amount > 0, "ERR__AMOUNT_IS_0");
        uint256 nftId = lpToken.mint(_msgSender());
        LpTokenMetadata memory data = LpTokenMetadata(_token, 0, 0);
        lpToken.updateTokenMetadata(nftId, data);
        _increaseLiquidity(nftId, _amount);
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
            uint256 totalShares
        ) = lpToken.tokenMetadata(_nftId);

        require(_amount > 0, "ERR__AMOUNT_IS_0");
        whiteListPeriodManager.beforeLiquidityAddition(_msgSender(), token, _amount);

        uint256 mintedSharesAmount;
        // Adding liquidity in the pool for the first time
        if(totalReserve[token] == 0) {
            mintedSharesAmount = BASE_DIVISOR * _amount;
        } else {
            mintedSharesAmount = (_amount * totalSharesMinted[token]) / totalReserve[token];
        }

        require(mintedSharesAmount >= BASE_DIVISOR, "ERR__AMOUNT_BELOW_MIN_LIQUIDITY");

        totalLiquidity[token] += _amount;
        totalReserve[token] += _amount;
        totalSharesMinted[token] += mintedSharesAmount;

        LpTokenMetadata memory data = LpTokenMetadata(
            token,
            totalSuppliedLiquidity + _amount,
            totalShares + mintedSharesAmount
        );
        lpToken.updateTokenMetadata(_nftId, data);
    }

    /**
     * @dev Internal Function to allow LPs to add ERC20 token liquidity to existing NFT
     * @param _nftId ID of NFT for updating the balances
     * @param _amount Token amount to be added
     */
    function _increaseTokenLiquidity(uint256 _nftId, uint256 _amount) internal {
        (address token, , ) = lpToken.tokenMetadata(_nftId);
        require(token != NATIVE, "ERR__WRONG_FUNCTION");
        require(
            IERC20Upgradeable(token).allowance(_msgSender(), address(this)) >= _amount,
            "ERR__INSUFFICIENT_ALLOWANCE"
        );
        _increaseLiquidity(_nftId, _amount);
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(token), _msgSender(), address(this), _amount);
    }

    /**
     * @dev Internal Function to allow LPs to add native token liquidity to existing NFT
     */
    function _increaseNativeLiquidity(uint256 _nftId) internal {
        (address token, ,) = lpToken.tokenMetadata(_nftId);
        require(token == NATIVE, "ERR__WRONG_FUNCTION");
        _increaseLiquidity(_nftId, msg.value);
    }


    function _removeLiquidity(uint256 _nftId, uint256 amount) internal onlyValidLpToken(_nftId, _msgSender()) {
        (address _tokenAddress, uint256 nftSuppliedLiquidity, uint256 totalNFTShares) = lpToken.tokenMetadata(_nftId);

        require(amount != 0, "ERR__INVALID_AMOUNT");
        require(nftSuppliedLiquidity >= amount, "ERR__INSUFFICIENT_LIQUIDITY");
        whiteListPeriodManager.beforeLiquidityRemoval(_msgSender(), _tokenAddress, amount);
        // Claculate how much shares represent input amount
        uint256 lpSharesForInputAmount = amount * getTokenPriceInLPShares(_tokenAddress);

        // Calculate rewards accumulated
        uint256 eligibleLiquidity = sharesToTokenAmount(totalNFTShares, _tokenAddress);
        uint256 lpFeeAccumulated = eligibleLiquidity - nftSuppliedLiquidity;
        // Calculate amount of lp shares that represent accumulated Fee
        uint256 lpSharesRepresentingFee = lpFeeAccumulated * getTokenPriceInLPShares(_tokenAddress);

        totalLPFees[_tokenAddress] -= lpFeeAccumulated;
        uint256 amountToWithdraw = amount + lpFeeAccumulated;
        uint256 lpSharesToBurn = lpSharesForInputAmount + lpSharesRepresentingFee;

        // Handle round off errors to avoid dust lp token in contract
        if(totalNFTShares - lpSharesToBurn < BASE_DIVISOR) {
            lpSharesToBurn = totalNFTShares;
        }
        totalReserve[_tokenAddress] -= amountToWithdraw;
        totalLiquidity[_tokenAddress] -= amount;
        totalSharesMinted[_tokenAddress] -= lpSharesToBurn;

        _burnSharesFromNft(_nftId, lpSharesToBurn, amount, _tokenAddress);
        
        _transfer(_tokenAddress, _msgSender(), amountToWithdraw);

        emit LiquidityRemoved(_tokenAddress, amountToWithdraw, _msgSender());
    }

    /**
     * @dev Function to allow LPs to burn a part of their shares that represent their reward
     * @param _nftId ID of NFT where liquidity is recorded
     */
    function _claimFee(uint256 _nftId) internal onlyValidLpToken(_nftId, _msgSender()) {
        (address _tokenAddress, uint256 nftSuppliedLiquidity, uint256 totalNFTShares) = lpToken.tokenMetadata(_nftId);

        uint256 lpSharesForSuppliedLiquidity = nftSuppliedLiquidity * getTokenPriceInLPShares(_tokenAddress);

        // Calculate rewards accumulated
        uint256 eligibleLiquidity = sharesToTokenAmount(totalNFTShares, _tokenAddress);
        uint256 lpFeeAccumulated = eligibleLiquidity - nftSuppliedLiquidity;
        require(lpFeeAccumulated > 0, "ERR__NO_REWARDS_TO_CLAIM");
        // Calculate amount of lp shares that represent accumulated Fee
        uint256 lpSharesRepresentingFee = totalNFTShares - lpSharesForSuppliedLiquidity;

        totalReserve[_tokenAddress] -= lpFeeAccumulated;
        totalSharesMinted[_tokenAddress] -= lpSharesRepresentingFee;
        totalLPFees[_tokenAddress] -= lpFeeAccumulated;

        _burnSharesFromNft(_nftId, lpSharesRepresentingFee, 0, _tokenAddress);
        _transfer(_tokenAddress, _msgSender(), lpFeeAccumulated);
        emit FeeClaimed(_tokenAddress, lpFeeAccumulated, _msgSender(), lpSharesRepresentingFee);
    }

    /**
     * @dev Private Function to burn LP shares and remove liquidity from existing NFT
     */
    function _burnSharesFromNft(
        uint256 _nftId,
        uint256 _shares,
        uint256 _tokenAmount,
        address _tokenAddress
    ) private {
        (
            ,
            uint256 nftSuppliedLiquidity,
            uint256 nftShares
        ) = lpToken.tokenMetadata(_nftId);
        nftShares -= _shares;
        nftSuppliedLiquidity -= _tokenAmount;
        
        lpToken.updateTokenMetadata(
            _nftId,
            LpTokenMetadata(_tokenAddress, nftSuppliedLiquidity, nftShares)
        );
    }

    function _transfer(address _tokenAddress, address _receiver, uint256 _tokenAmount) private {
        if (_tokenAddress == NATIVE) {
            require(address(this).balance >= _tokenAmount, "ERR__INSUFFICIENT_BALANCE");
            bool success = payable(_receiver).send(_tokenAmount);
            require(success, "ERR__NATIVE_TRANSFER_FAILED");
        } else {
            IERC20Upgradeable baseToken = IERC20Upgradeable(_tokenAddress);
            require(baseToken.balanceOf(address(this)) >= _tokenAmount, "ERR__INSUFFICIENT_BALANCE");
            SafeERC20Upgradeable.safeTransfer(baseToken, _receiver, _tokenAmount);
        }
    }

    function sharesToTokenAmount(uint256 _shares, address _tokenAddress) public view returns(uint256) {
        return _shares * totalReserve[_tokenAddress] / totalSharesMinted[_tokenAddress];
    }

    function _getSuppliedLiquidity(uint256 _nftId) internal view returns (uint256) {
        (, uint256 totalSuppliedLiquidity,) = lpToken.tokenMetadata(_nftId);
        return totalSuppliedLiquidity;
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
