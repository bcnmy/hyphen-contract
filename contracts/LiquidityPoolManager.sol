// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "abdk-libraries-solidity/ABDKMathQuad.sol";
import "hardhat/console.sol";

contract LiquidityPool is Initializable, ERC2771ContextUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ABDKMathQuad for bytes16;

    event LiquidityAdded(address lp, IERC20Upgradeable token, uint256 amount, uint256 periodAdded);
    event LiquidityRemoved(address lp, IERC20Upgradeable token, uint256 amount, uint256 periodRemoved);
    event RewardAdded(IERC20Upgradeable token, uint256 amount, uint256 periodAdded);
    event RewardExtracted(address lp, IERC20Upgradeable token, uint256 amount, uint256 periodRemoved);
    event GasFeeAdded(IERC20Upgradeable token, address executor, uint256 amount);
    event GasFeeRemoved(IERC20Upgradeable token, address executor, uint256 amount, address to);

    // Rewards Distribution
    mapping(IERC20Upgradeable => uint256) public currentPeriodIndex;
    mapping(uint256 => mapping(IERC20Upgradeable => uint256)) public rewardAccuredByPeriod;
    mapping(address => mapping(IERC20Upgradeable => uint256)) public liquidityAddedAmount;
    mapping(address => mapping(IERC20Upgradeable => uint256)) public lastRewardExtractionPeriodByLp;
    mapping(IERC20Upgradeable => bytes16[]) public rewardToLiquidityRatioPrefix;
    mapping(IERC20Upgradeable => uint256) public totalLiquidityByToken;
    mapping(address => mapping(IERC20Upgradeable => uint256)) public savedLpRewards;

    //Gas Fee
    mapping(IERC20Upgradeable => mapping(address => uint256)) public gasFeeAccumulated;

    /**
     * @dev initalizes the contract, acts as constructor
     * @param _trustedForwarder address of trusted forwarder
     */
    function initialize(address _trustedForwarder) public initializer {
        __ERC2771Context_init(_trustedForwarder);
        __Ownable_init();
    }

    /**
     * @dev Meta-Transaction Helper, returns msgSender
     */
    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /**
     * @dev Meta-Transaction Helper, returns msgData
     */
    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }

    /**
     * @dev Adds Fee to current fee-period
     */
    function _addReward(IERC20Upgradeable _token, uint256 _amount) internal {
        rewardAccuredByPeriod[currentPeriodIndex[_token]][_token] += _amount;
        emit RewardAdded(_token, _amount, currentPeriodIndex[_token]);
    }

    /**
     * @dev Adds Gas Fee for an executor
     * @param _token ERC20 Token for which gas fee is saved
     * @param _executor Executor address
     * @param _amount Gas Fee amount to be stored
     */
    function _addGasFee(
        IERC20Upgradeable _token,
        address _executor,
        uint256 _amount
    ) internal {
        require(_token.allowance(_msgSender(), address(this)) >= _amount, "ERR__INSUFFICIENT_ALLOWANCE");
        _token.safeTransferFrom(_msgSender(), address(this), _amount);
        gasFeeAccumulated[_token][_executor] += _amount;

        emit GasFeeAdded(_token, _executor, _amount);
    }

    /**
     * @dev Function to allow extraction of saved gas fee by executors
     * @param _token ERC20 Token for which gas fee is saved
     * @param _to Account to which gas fee is to be credited
     */
    function extractGasFee(IERC20Upgradeable _token, address _to) external {
        address executor = _msgSender();
        uint256 amount = gasFeeAccumulated[_token][executor];
        require(amount > 0, "ERR_NO_GAS_FEE_ACCUMULATED");
        gasFeeAccumulated[_token][executor] = 0;
        _token.safeTransfer(_to, amount);

        emit GasFeeRemoved(_token, executor, amount, _to);
    }

    /**
     * @dev External Function to allow LPs to add liquidity
     * @param _token ERC20 Token for which liquidity is to be added
     * @param _amount Token amount to be added
     */
    function addLiquidity(IERC20Upgradeable _token, uint256 _amount) external {
        require(_token.allowance(_msgSender(), address(this)) >= _amount, "ERR__INSUFFICIENT_ALLOWANCE");

        _prepareForLiquidityModificationByLP(_msgSender(), _token);

        _token.safeTransferFrom(_msgSender(), address(this), _amount);

        liquidityAddedAmount[_msgSender()][_token] += _amount;
        totalLiquidityByToken[_token] += _amount;

        emit LiquidityAdded(_msgSender(), _token, _amount, currentPeriodIndex[_token]);
    }

    /**
     * @dev External Function to allow LPs to remove liquidity
     * @param _token ERC20 Token for which liquidity is to be removed
     * @param _amount Token amount to removed
     */
    function removeLiquidity(IERC20Upgradeable _token, uint256 _amount) external {
        require(liquidityAddedAmount[_msgSender()][_token] >= _amount, "ERR_INSUFFICIENT_LIQUIDITY");

        _prepareForLiquidityModificationByLP(_msgSender(), _token);

        liquidityAddedAmount[_msgSender()][_token] -= _amount;
        totalLiquidityByToken[_token] -= _amount;

        _token.safeTransfer(_msgSender(), _amount);

        emit LiquidityRemoved(_msgSender(), _token, _amount, currentPeriodIndex[_token]);
    }

    /**
     * @dev External Function to allow extraction of LP Fee
     * @param _token Token for which Fee is to be extracted
     */
    function extractReward(IERC20Upgradeable _token) external {
        _updatePeriod(_token);

        uint256 reward = calculateReward(_msgSender(), _token);
        require(reward > 0, "ERR_NO_REWARD_FOUND");
        lastRewardExtractionPeriodByLp[_msgSender()][_token] = currentPeriodIndex[_token] - 1;
        savedLpRewards[_msgSender()][_token] = 0;

        _token.safeTransfer(_msgSender(), reward);

        emit RewardExtracted(_msgSender(), _token, reward, currentPeriodIndex[_token] - 1);
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
    function _prepareForLiquidityModificationByLP(address _lp, IERC20Upgradeable _token) internal {
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
        if (totalLiquidityByToken[_token] > 0 && rewardAccuredByPeriod[currentPeriodIndex[_token]][_token] > 0) {
            bytes16 currentReward = ABDKMathQuad.fromUInt(rewardAccuredByPeriod[currentPeriodIndex[_token]][_token]);
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
    function _updatePeriod(IERC20Upgradeable _token) internal {
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
