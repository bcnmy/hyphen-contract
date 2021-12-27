// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "abdk-libraries-solidity/ABDKMathQuad.sol";

contract LiquidityPool is
  Initializable,
  ERC2771ContextUpgradeable,
  OwnableUpgradeable
{
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using ABDKMathQuad for bytes16;

  event LiquidityAdded(address, IERC20Upgradeable, uint256);
  event LiquidityRemoved(address, IERC20Upgradeable);

  mapping(IERC20Upgradeable => uint256) public currentPeriodIndex;
  mapping(uint256 => mapping(IERC20Upgradeable => uint256))
    public rewardAccuredByPeriod;
  mapping(address => mapping(IERC20Upgradeable => uint256))
    public liquidityAddedAmount;
  mapping(address => mapping(IERC20Upgradeable => uint256))
    public periodAtLiquidityAddition;
  mapping(IERC20Upgradeable => bytes16[]) public rewardToLiquidityRatioPrefix;
  mapping(IERC20Upgradeable => uint256) public totalLiquidityByToken;

  function initialize(address _trustedForwarder) public initializer {
    __ERC2771Context_init(_trustedForwarder);
    __Ownable_init();
  }

  function _msgSender()
    internal
    view
    override(ContextUpgradeable, ERC2771ContextUpgradeable)
    returns (address)
  {
    return ERC2771ContextUpgradeable._msgSender();
  }

  function _msgData()
    internal
    view
    override(ContextUpgradeable, ERC2771ContextUpgradeable)
    returns (bytes calldata)
  {
    return ERC2771ContextUpgradeable._msgData();
  }

  // Only used for testing, will be removed from production
  function addReward(IERC20Upgradeable _token, uint256 _amount) external {
    require(
      _token.allowance(_msgSender(), address(this)) >= _amount,
      "ERR__INSUFFICIENT_ALLOWANCE"
    );
    _token.safeTransferFrom(_msgSender(), address(this), _amount);
    rewardAccuredByPeriod[currentPeriodIndex[_token]][_token] += _amount;
  }

  function addLiquidity(IERC20Upgradeable _token, uint256 _amount) external {
    require(
      liquidityAddedAmount[_msgSender()][_token] == 0,
      "ERR_ALREADY_PROVIDED_LIQUIDITY"
    );
    require(
      _token.allowance(_msgSender(), address(this)) >= _amount,
      "ERR__INSUFFICIENT_ALLOWANCE"
    );

    _token.safeTransferFrom(_msgSender(), address(this), _amount);
    _updatePeriod(_token);

    liquidityAddedAmount[_msgSender()][_token] = _amount;
    totalLiquidityByToken[_token] += _amount;
    periodAtLiquidityAddition[_msgSender()][_token] = currentPeriodIndex[
      _token
    ];

    emit LiquidityAdded(_msgSender(), _token, _amount);
  }

  function removeLiquidity(IERC20Upgradeable _token) external {
    require(
      liquidityAddedAmount[_msgSender()][_token] > 0,
      "ERR_NO_LIQUIDITY_PROVIDED"
    );

    _updatePeriod(_token);

    uint256 amount = liquidityAddedAmount[_msgSender()][_token];
    uint256 reward = calculateReward(_msgSender(), _token);

    liquidityAddedAmount[_msgSender()][_token] = 0;
    totalLiquidityByToken[_token] -= amount;
    rewardAccuredByPeriod[currentPeriodIndex[_token]][_token] =
      rewardAccuredByPeriod[currentPeriodIndex[_token] - 1][_token] -
      reward;

    _token.safeTransfer(_msgSender(), amount + reward);

    emit LiquidityRemoved(_msgSender(), _token);
  }

  function calculateReward(address _lp, IERC20Upgradeable _token)
    public
    view
    returns (uint256)
  {
    uint256 periodLiquidityAddedAt = periodAtLiquidityAddition[_lp][_token];
    bytes16 rewardToLiquiditySum = rewardToLiquidityRatioPrefix[_token][
      currentPeriodIndex[_token] - 1
    ].sub(rewardToLiquidityRatioPrefix[_token][periodLiquidityAddedAt - 1]);

    bytes16 reward = rewardToLiquiditySum.mul(
      ABDKMathQuad.fromUInt(liquidityAddedAmount[_lp][_token])
    );

    return reward.toUInt();
  }

  function _calculateCurrentRewardToLiquidityRatio(IERC20Upgradeable _token)
    internal
    view
    returns (bytes16)
  {
    if (totalLiquidityByToken[_token] > 0) {
      bytes16 currentReward = ABDKMathQuad.fromUInt(
        rewardAccuredByPeriod[currentPeriodIndex[_token]][_token]
      );
      bytes16 currentLiquidity = ABDKMathQuad.fromUInt(
        totalLiquidityByToken[_token]
      );
      return currentReward.div(currentLiquidity);
    } else {
      return 0;
    }
  }

  function _updatePeriod(IERC20Upgradeable _token) internal {
    bytes16 previousRewardToLiquidityRatioPrefix;
    if (currentPeriodIndex[_token] > 0) {
      previousRewardToLiquidityRatioPrefix = rewardToLiquidityRatioPrefix[
        _token
      ][currentPeriodIndex[_token] - 1];
    } else {
      previousRewardToLiquidityRatioPrefix = ABDKMathQuad.fromUInt(0);
    }

    rewardToLiquidityRatioPrefix[_token][
      currentPeriodIndex[_token]
    ] = previousRewardToLiquidityRatioPrefix.add(
      _calculateCurrentRewardToLiquidityRatio(_token)
    );

    currentPeriodIndex[_token] += 1;
  }
}