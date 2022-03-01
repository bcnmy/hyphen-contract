// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./metatx/ERC2771ContextUpgradeable.sol";

import "../security/Pausable.sol";
import "./interfaces/ILPToken.sol";
import "./interfaces/ILiquidityProviders.sol";

contract HyphenLiquidityFarming is
    Initializable,
    ERC2771ContextUpgradeable,
    OwnableUpgradeable,
    Pausable,
    ReentrancyGuardUpgradeable,
    IERC721ReceiverUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    ILPToken public lpToken;
    ILiquidityProviders public liquidityProviders;

    /// @notice Info of each Rewarder user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of Reward Token entitled to the user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 unpaidRewards;
    }

    /// @notice Info of the rewarder pool
    struct PoolInfo {
        uint256 accTokenPerShare;
        uint256 lastRewardTime;
    }

    /// @notice Mapping to track the rewarder pool.
    mapping(address => PoolInfo) public poolInfo;

    /// @notice Info of each user that stakes LP tokens.
    mapping(address => mapping(address => UserInfo)) public userInfo;

    /// @notice Reward rate per base token
    mapping(address => uint256) public rewardPerSecond;

    /// @notice Reward Token
    mapping(address => address) public rewardTokens;

    /// @notice Staker => NFTs staked
    mapping(address => uint256[]) public nftIdsStaked;

    /// @notice Token => Total Shares Staked
    mapping(address => uint256) public totalSharesStaked;

    uint256 private constant ACC_TOKEN_PRECISION = 1e12;
    uint256 private constant ACC_SUSHI_PRECISION = 1e12;
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event LogDeposit(address indexed user, address indexed baseToken, uint256 nftId, address indexed to);
    event LogWithdraw(address indexed user, address baseToken, uint256 nftId, address indexed to);
    event LogOnReward(address indexed user, address indexed baseToken, uint256 amount, address indexed to);
    event LogUpdatePool(address indexed baseToken, uint256 lastRewardTime, uint256 lpSupply, uint256 accToken1PerShare);
    event LogRewardPerSecond(address indexed baseToken, uint256 rewardPerSecond);
    event LogRewardPoolInitialized(address _baseToken, address _rewardToken, uint256 _rewardPerSecond);
    event LogNativeReceived(address indexed sender, uint256 value);

    function initialize(
        address _trustedForwarder,
        address _pauser,
        ILiquidityProviders _liquidityProviders,
        ILPToken _lpToken
    ) public initializer {
        __ERC2771Context_init(_trustedForwarder);
        __Ownable_init();
        __Pausable_init(_pauser);
        __ReentrancyGuard_init();
        liquidityProviders = _liquidityProviders;
        lpToken = _lpToken;
    }

    /// @notice Initialize the rewarder pool.
    /// @param _baseToken Base token to be used for the rewarder pool.
    /// @param _rewardToken Reward token to be used for the rewarder pool.
    /// @param _rewardPerSecond Reward rate per base token.
    function initalizeRewardPool(
        address _baseToken,
        address _rewardToken,
        uint256 _rewardPerSecond
    ) external onlyOwner {
        require(rewardTokens[_baseToken] == address(0), "ERR__POOL_ALREADY_INITIALIZED");
        require(rewardPerSecond[_baseToken] == 0, "ERR__POOL_ALREADY_INITIALIZED");
        rewardTokens[_baseToken] = _rewardToken;
        rewardPerSecond[_baseToken] = _rewardPerSecond;
        emit LogRewardPoolInitialized(_baseToken, _rewardToken, _rewardPerSecond);
    }

    /// @notice Update the reward state of a user, and if possible send reward funds to _to.
    /// @param _baseToken Base token to be used for the rewarder pool.
    /// @param _user User that is depositing LP tokens.
    /// @param _to Address to which rewards will be credited.
    /// @param _lpTokenAmount Amount LP tokens to be deposited.
    function _onReward(
        address _baseToken,
        address _user,
        address _to,
        uint256 _lpTokenAmount
    ) internal {
        PoolInfo memory pool = updatePool(_baseToken);
        UserInfo storage user = userInfo[_baseToken][_user];
        uint256 pending;
        if (user.amount > 0) {
            pending =
                ((user.amount * pool.accTokenPerShare) / ACC_TOKEN_PRECISION) -
                user.rewardDebt +
                user.unpaidRewards;
            if (rewardTokens[_baseToken] == NATIVE) {
                uint256 balance = address(this).balance;
                if (pending > balance) {
                    user.unpaidRewards = pending - balance;
                    (bool success, ) = payable(_to).call{value: balance}("");
                    require(success, "ERR__NATIVE_TRANSFER_FAILED");
                } else {
                    user.unpaidRewards = 0;
                    (bool success, ) = payable(_to).call{value: pending}("");
                    require(success, "ERR__NATIVE_TRANSFER_FAILED");
                }
            } else {
                IERC20Upgradeable rewardToken = IERC20Upgradeable(rewardTokens[_baseToken]);
                uint256 balance = rewardToken.balanceOf(address(this));
                if (pending > balance) {
                    rewardToken.safeTransfer(_to, balance);
                    user.unpaidRewards = pending - balance;
                } else {
                    rewardToken.safeTransfer(_to, pending);
                    user.unpaidRewards = 0;
                }
            }
        }
        user.amount = _lpTokenAmount;
        user.rewardDebt = (_lpTokenAmount * pool.accTokenPerShare) / ACC_TOKEN_PRECISION;
        emit LogOnReward(_user, _baseToken, pending - user.unpaidRewards, _to);
    }

    /// @notice Sets the sushi per second to be distributed. Can only be called by the owner.
    /// @param _rewardPerSecond The amount of Sushi to be distributed per second.
    function setRewardPerSecond(address _baseToken, uint256 _rewardPerSecond) public onlyOwner {
        rewardPerSecond[_baseToken] = _rewardPerSecond;
        emit LogRewardPerSecond(_baseToken, _rewardPerSecond);
    }

    /// @notice Allows owner to reclaim/withdraw any tokens (including reward tokens) held by this contract
    /// @param _token Token to reclaim, use 0x00 for Ethereum
    /// @param _amount Amount of tokens to reclaim
    /// @param _to Receiver of the tokens, first of his name, rightful heir to the lost tokens,
    /// reightful owner of the extra tokens, and ether, protector of mistaken transfers, mother of token reclaimers,
    /// the Khaleesi of the Great Token Sea, the Unburnt, the Breaker of blockchains.
    function reclaimTokens(
        address _token,
        uint256 _amount,
        address payable _to
    ) public nonReentrant onlyOwner {
        if (_token == NATIVE) {
            (bool success, ) = payable(_to).call{value: _amount}("");
            require(success, "ERR__NATIVE_TRANSFER_FAILED");
        } else {
            IERC20Upgradeable(_token).safeTransfer(_to, _amount);
        }
    }

    /// @notice Deposit LP tokens
    /// @param _nftId LP token nftId to deposit.
    /// @param _to The receiver of `amount` deposit benefit.
    function deposit(uint256 _nftId, address _to) public whenNotPaused nonReentrant {
        require(lpToken.isApprovedForAll(_msgSender(), address(this)), "ERR__NOT_APPROVED_FOR_ALL");

        (address baseToken, , uint256 amount) = lpToken.tokenMetadata(_nftId);
        require(rewardTokens[baseToken] != address(0), "ERR__POOL_NOT_INITIALIZED");
        require(rewardPerSecond[baseToken] != 0, "ERR__POOL_NOT_INITIALIZED");

        amount /= liquidityProviders.BASE_DIVISOR();
        updatePool(baseToken);
        UserInfo storage user = userInfo[baseToken][_to];

        _onReward(baseToken, _to, _to, user.amount + amount);

        nftIdsStaked[_msgSender()].push(_nftId);
        totalSharesStaked[baseToken] = totalSharesStaked[baseToken] + amount;
        lpToken.safeTransferFrom(_msgSender(), address(this), _nftId);

        emit LogDeposit(_msgSender(), baseToken, _nftId, _to);
    }

    /// @notice Withdraw LP tokens
    /// @param _nftId LP token nftId to withdraw.
    /// @param _to The receiver of `amount` withdraw benefit.
    function withdraw(uint256 _nftId, address _to) public whenNotPaused nonReentrant {
        uint256 index;
        for (index = 0; index < nftIdsStaked[_msgSender()].length; index++) {
            if (nftIdsStaked[_msgSender()][index] == _nftId) {
                break;
            }
        }
        if (index == nftIdsStaked[_msgSender()].length) {
            require(false, "ERR__NFT_NOT_STAKED");
        }
        nftIdsStaked[_msgSender()][index] = nftIdsStaked[_msgSender()][nftIdsStaked[_msgSender()].length - 1];
        nftIdsStaked[_msgSender()].pop();

        (address baseToken, , uint256 amount) = lpToken.tokenMetadata(_nftId);
        amount /= liquidityProviders.BASE_DIVISOR();

        updatePool(baseToken);
        UserInfo storage user = userInfo[baseToken][_msgSender()];

        _onReward(baseToken, _to, _to, user.amount - amount);
        totalSharesStaked[baseToken] = totalSharesStaked[baseToken] - amount;
        lpToken.safeTransferFrom(address(this), _to, _nftId);

        emit LogWithdraw(_msgSender(), baseToken, _nftId, _to);
    }

    /// @notice Extract all rewards without withdrawing LP tokens
    /// @param _baseToken Base token to be used for the rewarder pool.
    /// @param _to The receiver of withdraw benefit.
    function extractRewards(address _baseToken, address _to) external whenNotPaused nonReentrant {
        UserInfo memory user = userInfo[_baseToken][_msgSender()];
        _onReward(_baseToken, _msgSender(), _to, user.amount);
    }

    /// @notice View function to see pending Token
    /// @param _user Address of user.
    /// @return pending SUSHI reward for a given user.
    function pendingToken(address _baseToken, address _user) public view returns (uint256 pending) {
        PoolInfo memory pool = poolInfo[_baseToken];
        UserInfo storage user = userInfo[_baseToken][_user];
        uint256 accToken1PerShare = pool.accTokenPerShare;
        if (block.timestamp > pool.lastRewardTime && totalSharesStaked[_baseToken] != 0) {
            uint256 time = block.timestamp - pool.lastRewardTime;
            uint256 sushiReward = time * rewardPerSecond[_baseToken];
            accToken1PerShare = accToken1PerShare + (sushiReward * ACC_TOKEN_PRECISION) / totalSharesStaked[_baseToken];
        }
        pending = ((user.amount * accToken1PerShare) / ACC_TOKEN_PRECISION) - user.rewardDebt + user.unpaidRewards;
    }

    /// @notice Update reward variables of the given pool.
    /// @return pool Returns the pool that was updated.
    function updatePool(address _baseToken) public whenNotPaused returns (PoolInfo memory pool) {
        pool = poolInfo[_baseToken];
        if (block.timestamp > pool.lastRewardTime) {
            if (totalSharesStaked[_baseToken] > 0) {
                uint256 time = block.timestamp - pool.lastRewardTime;
                uint256 sushiReward = time * rewardPerSecond[_baseToken];
                pool.accTokenPerShare =
                    pool.accTokenPerShare +
                    ((sushiReward * (ACC_TOKEN_PRECISION)) / totalSharesStaked[_baseToken]);
            }
            pool.lastRewardTime = block.timestamp;
            poolInfo[_baseToken] = pool;
            emit LogUpdatePool(_baseToken, pool.lastRewardTime, totalSharesStaked[_baseToken], pool.accTokenPerShare);
        }
    }

    /// @notice View function to see the tokens staked by a given user.
    /// @param _user Address of user.
    function getNftIdsStaked(address _user) public view returns (uint256[] memory nftIds) {
        nftIds = nftIdsStaked[_user];
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override(IERC721ReceiverUpgradeable) returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
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

    receive() external payable {
        emit LogNativeReceived(_msgSender(), msg.value);
    }
}
