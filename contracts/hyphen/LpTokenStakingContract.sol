// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "abdk-libraries-solidity/ABDKMathQuad.sol";

import "./interfaces/ILPToken.sol";

contract LpTokenStakingContract is
    Initializable,
    ERC2771ContextUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    IERC721ReceiverUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ABDKMathQuad for bytes16;

    event LpTokenStaked(address lp, uint256 tokenId, uint256 totalSharesAdded, uint256 periodAdded);
    event LpTokenUnstaked(address lp, uint256 tokenId, uint256 totalSharesRemoved, uint256 periodRemoved);
    event RewardAdded(address baseToken, uint256 amountInBico, uint256 periodAdded);
    event RewardExtracted(address lp, address baseToken, uint256 amountInBico, uint256 periodRemoved);

    ILPToken public lpToken;
    IERC20Upgradeable public bicoToken;

    // Rewards Distribution
    mapping(IERC20Upgradeable => uint256) public currentPeriodIndex;
    mapping(uint256 => mapping(IERC20Upgradeable => uint256)) public rewardAccuredByPeriod;
    mapping(address => mapping(IERC20Upgradeable => uint256)) public sharesAddedForTokenByLp;
    mapping(address => mapping(IERC20Upgradeable => uint256)) public lastRewardExtractionPeriodByLp;
    mapping(IERC20Upgradeable => bytes16[]) public rewardToLiquidityRatioPrefix;
    mapping(IERC20Upgradeable => uint256) public totalSharesAddedByToken;
    mapping(address => mapping(IERC20Upgradeable => uint256)) public savedLpRewards;
    mapping(address => uint256[]) public lpTokenStakedByUser;

    /**
     * @dev initalizes the contract, acts as constructor
     * @param _trustedForwarder address of trusted forwarder
     */
    function initialize(
        address _trustedForwarder,
        address _lpToken,
        address _bicoToken
    ) public initializer {
        __ERC2771Context_init(_trustedForwarder);
        __Ownable_init();
        __Pausable_init();
        lpToken = ILPToken(_lpToken);
        bicoToken = IERC20Upgradeable(_bicoToken);
    }

    /**
     * @dev Adds Fee to current fee-period
     * @param _token Base token (in which liquidity is supplied) for which rewards are to be added
     * @param _amountInBico bico rewards to add
     */
    function addBicoReward(IERC20Upgradeable _token, uint256 _amountInBico) external whenNotPaused onlyOwner {
        require(bicoToken.allowance(_msgSender(), address(this)) >= _amountInBico, "ERR__INSUFFICIENT_ALLOWANCE");
        bicoToken.safeTransferFrom(_msgSender(), address(this), _amountInBico);
        rewardAccuredByPeriod[currentPeriodIndex[_token]][_token] += _amountInBico;
        emit RewardAdded(address(_token), _amountInBico, currentPeriodIndex[_token]);
    }

    /**
     * @dev External Function to allow LPs to stake liquidity token
     * @param _nftId Id of NFT to be staked.
     */
    function stakeLpToken(uint256 _nftId) external whenNotPaused {
        require(
            lpToken.getApproved(_nftId) == address(this) || lpToken.isApprovedForAll(_msgSender(), address(this)),
            "ERR__ALLOWANCE_NOT_GIVEN"
        );

        lpToken.safeTransferFrom(_msgSender(), address(this), _nftId);
        (address baseTokenAddress, , uint256 totalShares) = lpToken.tokenMetadata(_nftId);
        IERC20Upgradeable token = IERC20Upgradeable(baseTokenAddress);
        _preapareForStakeModification(_msgSender(), token);
        lpTokenStakedByUser[_msgSender()].push(_nftId);
        sharesAddedForTokenByLp[_msgSender()][token] += totalShares;
        totalSharesAddedByToken[token] += totalShares;

        emit LpTokenStaked(_msgSender(), _nftId, totalShares, currentPeriodIndex[token]);
    }

    /**
     * @dev External Function to allow LPs to remove liquidity
     * @param _nftId NFT to unstake
     */
    function unstakeLpToken(uint256 _nftId) external whenNotPaused {
        require(_checkIfStakedByLp(_msgSender(), _nftId), "ERR__INVALID_NFT_ID");

        (address baseTokenAddress, , uint256 totalShares) = lpToken.tokenMetadata(_nftId);
        IERC20Upgradeable token = IERC20Upgradeable(baseTokenAddress);
        _preapareForStakeModification(_msgSender(), token);
        _deleteStakedTokenFromRecords(_msgSender(), _nftId);
        sharesAddedForTokenByLp[_msgSender()][token] -= totalShares;
        totalSharesAddedByToken[token] -= totalShares;

        lpToken.safeTransferFrom(address(this), _msgSender(), _nftId);
        emit LpTokenUnstaked(_msgSender(), _nftId, totalShares, currentPeriodIndex[token]);
    }

    /**
     * @dev External Function to allow extraction of LP Fee
     * @param _token Token for which Fee is to be extracted
     */
    function extractReward(IERC20Upgradeable _token) external whenNotPaused {
        _updatePeriod(_token);

        uint256 reward = calculateReward(_msgSender(), _token);
        require(reward > 0, "ERR_NO_REWARD_FOUND");
        lastRewardExtractionPeriodByLp[_msgSender()][_token] = currentPeriodIndex[_token] - 1;
        savedLpRewards[_msgSender()][_token] = 0;

        bicoToken.safeTransfer(_msgSender(), reward);

        emit RewardExtracted(_msgSender(), address(_token), reward, currentPeriodIndex[_token] - 1);
    }

    /**
     * @dev Public function to get NFTIds of all LPTokens staked by user
     * @param _lp adress of lp
     * @return array of ids
     */
    function getAllNftIdsStakedByUser(address _lp) public view returns (uint256[] memory) {
        return lpTokenStakedByUser[_lp];
    }

    /**
     * @dev Public function to calculate an LP's claimable fee for a given token.
     * @param _lp Address of LP
     * @param _token Token for which fee is to be calculated
     * @return Claimable Fee amount
     */
    function calculateReward(address _lp, IERC20Upgradeable _token) public view returns (uint256) {
        uint256 lastExtractionPeriod = lastRewardExtractionPeriodByLp[_lp][_token];
        bytes16 rewardToLiquiditySum = rewardToLiquidityRatioPrefix[_token][currentPeriodIndex[_token] - 1].sub(
            rewardToLiquidityRatioPrefix[_token][lastExtractionPeriod]
        );
        // If being called by externally before current period's ratio is added, we need to account for current rewards as well
        // If this is called just after _updatePeriod then it's 0
        rewardToLiquiditySum = rewardToLiquiditySum.add(_calculateCurrentRewardToLiquidityRatio(_token));

        bytes16 reward = rewardToLiquiditySum.mul(ABDKMathQuad.fromUInt(sharesAddedForTokenByLp[_lp][_token]));

        // Add saved rewards
        return reward.toUInt() + savedLpRewards[_lp][_token];
    }

    /**
     * @dev Checks if LP has staked NFT with _nftId or not
     * @param _lp address of lp
     * @param _nftId NFT to check
     * @return bool Boolean specifying if LP has staked NFT
     */
    function _checkIfStakedByLp(address _lp, uint256 _nftId) internal view returns (bool) {
        for (uint256 i = 0; i < lpTokenStakedByUser[_lp].length; ++i) {
            if (lpTokenStakedByUser[_lp][i] == _nftId) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Removes staked token from records for LP
     * @param _lp Address of LP
     * @param _nftId NFT to remove
     */
    function _deleteStakedTokenFromRecords(address _lp, uint256 _nftId) internal whenNotPaused {
        uint256 index = lpTokenStakedByUser[_lp].length;
        for (uint256 i = 0; i < lpTokenStakedByUser[_lp].length; ++i) {
            if (lpTokenStakedByUser[_lp][i] == _nftId) {
                index = i;
            }
        }
        require(index != lpTokenStakedByUser[_lp].length, "ERR__LP_TOKEN_NOT_FOUND");
        lpTokenStakedByUser[_lp][index] = lpTokenStakedByUser[_lp][lpTokenStakedByUser[_lp].length - 1];
        lpTokenStakedByUser[_lp].pop();
    }

    /**
     * @dev Updates Token Perid and saves Claimable LP fee to savedLpRewards
            Called before adding or removing liquidity.
     * @param _lp Address of LP
     * @param _token for which LP is to be updated
     */
    function _preapareForStakeModification(address _lp, IERC20Upgradeable _token) internal whenNotPaused {
        _updatePeriod(_token);
        uint256 reward = calculateReward(_lp, _token);
        savedLpRewards[_lp][_token] += reward;
        lastRewardExtractionPeriodByLp[_msgSender()][_token] = currentPeriodIndex[_token] - 1;
    }

    /**
     * @dev Calculates Period Fee / Total Liquidity Ratio
     * @param _token Token for which ratio is to be calculated
     * @return Calculated Ratio in IEEE754 Floating Point Representation
     */
    function _calculateCurrentRewardToLiquidityRatio(IERC20Upgradeable _token) internal view returns (bytes16) {
        if (totalSharesAddedByToken[_token] > 0 && rewardAccuredByPeriod[currentPeriodIndex[_token]][_token] > 0) {
            bytes16 currentReward = ABDKMathQuad.fromUInt(rewardAccuredByPeriod[currentPeriodIndex[_token]][_token]);
            bytes16 currentLiquidity = ABDKMathQuad.fromUInt(totalSharesAddedByToken[_token]);
            return currentReward.div(currentLiquidity);
        } else {
            return 0;
        }
    }

    /**
     * @dev Updates the Fee/(Total Liquidity) Prefix Sum Array and starts a new period
     * @param _token Token for which period is to be updated
     */
    function _updatePeriod(IERC20Upgradeable _token) internal whenNotPaused {
        bytes16 previousRewardToLiquidityRatioPrefix;
        if (currentPeriodIndex[_token] > 0) {
            previousRewardToLiquidityRatioPrefix = rewardToLiquidityRatioPrefix[_token][currentPeriodIndex[_token] - 1];
        } else {
            previousRewardToLiquidityRatioPrefix = ABDKMathQuad.fromUInt(0);
        }

        rewardToLiquidityRatioPrefix[_token].push(
            previousRewardToLiquidityRatioPrefix.add(_calculateCurrentRewardToLiquidityRatio(_token))
        );

        currentPeriodIndex[_token] += 1;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure virtual override returns (bytes4) {
        return this.onERC721Received.selector;
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
}
