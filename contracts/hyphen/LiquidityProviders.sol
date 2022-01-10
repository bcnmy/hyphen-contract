// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "abdk-libraries-solidity/ABDKMathQuad.sol";
import "hardhat/console.sol";
import "./metatx/ERC2771ContextUpgradeable.sol";

contract LiquidityProviders is Initializable, ERC2771ContextUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ABDKMathQuad for bytes16;

    event LiquidityAdded(address lp, address token, uint256 amount, uint256 periodAdded);
    event LiquidityRemoved(address lp, address token, uint256 amount, uint256 periodRemoved);
    event LPFeeAdded(address token, uint256 amount, uint256 periodAdded);
    event RewardExtracted(address lp, address token, uint256 amount, uint256 periodRemoved);
    event GasFeeAdded(address token, address executor, uint256 amount);
    event GasFeeRemoved(address token, address executor, uint256 amount, address to);

    // Rewards Distribution
    mapping(address => uint256) public currentPeriodIndex;
    mapping(uint256 => mapping(address => uint256)) public lpFeeAccruedByPeriod;
    mapping(address => uint256) public lpFeeAccruedByToken;

    mapping(address => mapping(address => uint256)) public liquidityAddedAmount;
    mapping(address => mapping(address => uint256)) public lastRewardExtractionPeriodByLp;
    mapping(address => bytes16[]) public rewardToLiquidityRatioPrefix;
    mapping(address => uint256) public totalLiquidityByToken;
    mapping(address => mapping(address => uint256)) public savedLpRewards;

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

    /**
     * @dev Adds Fee to current fee-period
     */
    function _addLPFee(address _token, uint256 _amount) internal {
        lpFeeAccruedByPeriod[currentPeriodIndex[_token]][_token] += _amount;
        lpFeeAccruedByToken[_token] += _amount;
        emit LPFeeAdded(_token, _amount, currentPeriodIndex[_token]);
    }

    /**
     * Returns total lp fee accrued by token address.
     */
    function getLPFeeAccruedByToken(address _token) public view returns (uint256 fee) {
        fee = lpFeeAccruedByToken[_token];
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

        _prepareForLiquidityModificationByLP(_msgSender(), _token);

        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(_token), _msgSender(), address(this), _amount);

        liquidityAddedAmount[_msgSender()][_token] += _amount;
        totalLiquidityByToken[_token] += _amount;

        emit LiquidityAdded(_msgSender(), _token, _amount, currentPeriodIndex[_token]);
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

        _prepareForLiquidityModificationByLP(_msgSender(), _token);

        liquidityAddedAmount[_msgSender()][_token] += msg.value;
        totalLiquidityByToken[_token] += msg.value;

        emit LiquidityAdded(_msgSender(), _token, msg.value, currentPeriodIndex[_token]);
    }

    /**
     * @dev Internal Function to allow LPs to remove liquidity
     * @param _token ERC20 Token for which liquidity is to be removed
     * @param _amount Token amount to removed
     */
    function _removeTokenLiquidity(address _token, uint256 _amount) internal {
        require(liquidityAddedAmount[_msgSender()][_token] >= _amount, "ERR_INSUFFICIENT_LIQUIDITY");

        _prepareForLiquidityModificationByLP(_msgSender(), _token);

        liquidityAddedAmount[_msgSender()][_token] -= _amount;
        totalLiquidityByToken[_token] -= _amount;

        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), _msgSender(), _amount);

        emit LiquidityRemoved(_msgSender(), _token, _amount, currentPeriodIndex[_token]);
    }

    /**
     * @dev Internal Function to allow LPs to remove liquidity
     * @param _token ERC20 Token for which liquidity is to be removed
     * @param _amount Token amount to removed
     */
    function _removeNativeLiquidity(address _token, uint256 _amount) internal {
        require(liquidityAddedAmount[_msgSender()][_token] >= _amount, "ERR_INSUFFICIENT_LIQUIDITY");

        _prepareForLiquidityModificationByLP(_msgSender(), _token);

        liquidityAddedAmount[_msgSender()][_token] -= _amount;
        totalLiquidityByToken[_token] -= _amount;

        bool success = payable(_msgSender()).send(_amount);
        require(success, "ERR_NATIVE_TRANSFER_FAILED");
        emit LiquidityRemoved(_msgSender(), _token, _amount, currentPeriodIndex[_token]);
    }

    /**
     * @dev External Function to allow extraction of LP Fee
     * @param _token Token for which Fee is to be extracted
     */
    function extractReward(address _token) external {
        _updatePeriod(_token);

        uint256 reward = calculateReward(_msgSender(), _token);
        require(reward > 0, "ERR_NO_REWARD_FOUND");
        lastRewardExtractionPeriodByLp[_msgSender()][_token] = currentPeriodIndex[_token] - 1;
        savedLpRewards[_msgSender()][_token] = 0;

        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), _msgSender(), reward);

        emit RewardExtracted(_msgSender(), _token, reward, currentPeriodIndex[_token] - 1);
    }

    /**
     * @dev External Function to allow extraction of LP Fee
     * @param _token Token for which Liquidity and Fee is to be extracted
     */
    function extractAllLiquidityAndReward(address _token) external {
        address lp = _msgSender();
        _prepareForLiquidityModificationByLP(lp, _token);

        uint256 currentLiquidity = liquidityAddedAmount[lp][_token];
        uint256 reward = calculateReward(_msgSender(), _token);
        require(currentLiquidity + reward >= 0, "ERR_NO_CLAIMABLE_AMOUNT");

        // Update Liquidity
        liquidityAddedAmount[lp][_token] -= currentLiquidity;
        totalLiquidityByToken[_token] -= currentLiquidity;

        // Update Rewards
        lastRewardExtractionPeriodByLp[lp][_token] = currentPeriodIndex[_token] - 1;
        savedLpRewards[lp][_token] = 0;

        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), lp, currentLiquidity + reward);

        emit LiquidityRemoved(lp, _token, currentLiquidity, currentPeriodIndex[_token]);
        emit RewardExtracted(lp, _token, reward, currentPeriodIndex[_token] - 1);
    }

    /**
     * @dev Public function to calculate an LP's claimable fee for a given token.
     * @param _lp Address of LP
     * @param _token Token for which fee is to be calculated
     * @return Claimable Fee amount
     */
    function calculateReward(address _lp, address _token) public view returns (uint256) {
        uint256 lastExtractionPeriod = lastRewardExtractionPeriodByLp[_lp][_token];
        bytes16 rewardToLiquiditySum = rewardToLiquidityRatioPrefix[_token][currentPeriodIndex[_token] - 1].sub(
            rewardToLiquidityRatioPrefix[_token][lastExtractionPeriod]
        );
        // If being called by externally before current period's ratio is added, we need to account for current rewards as well
        // If this is called just after _updatePeriod then it's 0
        rewardToLiquiditySum = rewardToLiquiditySum.add(_calculateCurrentRewardToLiquidityRatio(_token));

        bytes16 reward = rewardToLiquiditySum.mul(ABDKMathQuad.fromUInt(liquidityAddedAmount[_lp][_token]));

        // Add saved rewards
        return reward.toUInt() + savedLpRewards[_lp][_token];
    }

    /**
     * @dev Updates Token Perid and saves Claimable LP fee to savedLpRewards
            Called before adding or removing liquidity.
     * @param _lp Address of LP
     * @param _token for which LP is to be updated
     */
    function _prepareForLiquidityModificationByLP(address _lp, address _token) internal {
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
    function _calculateCurrentRewardToLiquidityRatio(address _token) internal view returns (bytes16) {
        if (totalLiquidityByToken[_token] > 0 && lpFeeAccruedByPeriod[currentPeriodIndex[_token]][_token] > 0) {
            bytes16 currentReward = ABDKMathQuad.fromUInt(lpFeeAccruedByPeriod[currentPeriodIndex[_token]][_token]);
            bytes16 currentLiquidity = ABDKMathQuad.fromUInt(totalLiquidityByToken[_token]);
            return currentReward.div(currentLiquidity);
        } else {
            return 0;
        }
    }

    /**
     * @dev Updates the Fee/(Total Liquidity) Prefix Sum Array and starts a new period
     * @param _token Token for which period is to be updated
     */
    function _updatePeriod(address _token) internal {
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
}
