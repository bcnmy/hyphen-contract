// File @boringcrypto/boring-solidity/contracts/interfaces/IERC20.sol@v1.0.4

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// File @boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol@v1.0.4
pragma solidity ^0.8.0;

library BoringERC20 {
    function safeSymbol(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(0x95d89b41));
        return success && data.length > 0 ? abi.decode(data, (string)) : "???";
    }

    function safeName(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(0x06fdde03));
        return success && data.length > 0 ? abi.decode(data, (string)) : "???";
    }

    function safeDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(0x313ce567));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: Transfer failed");
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x23b872dd, from, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: TransferFrom failed");
    }
}

// File @boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol@v1.0.4

pragma solidity ^0.8.0;

// a library for performing overflow-safe math, updated with awesomeness from of DappHub (https://github.com/dapphub/ds-math)
library BoringMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b == 0 || (c = a * b) / b == a, "BoringMath: Mul Overflow");
    }

    function to128(uint256 a) internal pure returns (uint128 c) {
        require(a <= type(uint128).max, "BoringMath: uint128 Overflow");
        c = uint128(a);
    }

    function to64(uint256 a) internal pure returns (uint64 c) {
        require(a <= type(uint64).max, "BoringMath: uint64 Overflow");
        c = uint64(a);
    }

    function to32(uint256 a) internal pure returns (uint32 c) {
        require(a <= type(uint32).max, "BoringMath: uint32 Overflow");
        c = uint32(a);
    }
}

library BoringMath128 {
    function add(uint128 a, uint128 b) internal pure returns (uint128 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint128 a, uint128 b) internal pure returns (uint128 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

library BoringMath64 {
    function add(uint64 a, uint64 b) internal pure returns (uint64 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint64 a, uint64 b) internal pure returns (uint64 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

library BoringMath32 {
    function add(uint32 a, uint32 b) internal pure returns (uint32 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint32 a, uint32 b) internal pure returns (uint32 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

// File @boringcrypto/boring-solidity/contracts/BoringOwnable.sol@v1.0.4
// Audit on 5-Jan-2021 by Keno and BoringCrypto

// P1 - P3: OK
pragma solidity ^0.8.0;

// Source: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol + Claimable.sol
// Edited by BoringCrypto

// T1 - T4: OK
contract BoringOwnableData {
    // V1 - V5: OK
    address public owner;
    // V1 - V5: OK
    address public pendingOwner;
}

// T1 - T4: OK
contract BoringOwnable is BoringOwnableData {
    // E1: OK
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // F1 - F9: OK
    // C1 - C21: OK
    function transferOwnership(
        address newOwner,
        bool direct,
        bool renounce
    ) public onlyOwner {
        if (direct) {
            // Checks
            require(newOwner != address(0) || renounce, "Ownable: zero address");

            // Effects
            emit OwnershipTransferred(owner, newOwner);
            owner = newOwner;
            pendingOwner = address(0);
        } else {
            // Effects
            pendingOwner = newOwner;
        }
    }

    // F1 - F9: OK
    // C1 - C21: OK
    function claimOwnership() public {
        address _pendingOwner = pendingOwner;

        // Checks
        require(msg.sender == _pendingOwner, "Ownable: caller != pending owner");

        // Effects
        emit OwnershipTransferred(owner, _pendingOwner);
        owner = _pendingOwner;
        pendingOwner = address(0);
    }

    // M1 - M5: OK
    // C1 - C21: OK
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
}

// File contracts/mocks/CloneRewarderTime.sol

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC721ReceiverUpgradeable.sol";
import "./interfaces/ILPToken.sol";
import "./interfaces/ILiquidityProviders.sol";
import "hardhat/console.sol";

interface IMasterChefV2 {
    function lpToken(uint256 pid) external view returns (IERC20 _lpToken);
}

/// @author @0xKeno and @ankurdubey521
// TODO: Make contract upgradeable and add support for meta transactions
contract HyphenLiquidityFarming is BoringOwnable, IERC721ReceiverUpgradeable {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringERC20 for IERC20;

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
        uint128 accTokenPerShare;
        uint64 lastRewardTime;
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
    uint256 internal unlocked;

    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    event LogDeposit(address indexed user, address indexed baseToken, uint256 nftId, address indexed to);
    event LogWithdraw(address indexed user, address baseToken, uint256 nftId, address indexed to);
    event LogOnReward(address indexed user, address indexed baseToken, uint256 amount, address indexed to);
    event LogUpdatePool(address indexed baseToken, uint64 lastRewardTime, uint256 lpSupply, uint256 accToken1PerShare);
    event LogRewardPerSecond(address indexed baseToken, uint256 rewardPerSecond);
    event LogRewardPoolInitialized(address _baseToken, address _rewardToken, uint256 _rewardPerSecond);

    constructor(ILiquidityProviders _liquidityProviders, ILPToken _lpToken) {
        liquidityProviders = _liquidityProviders;
        lpToken = _lpToken;
        unlocked = 1;
    }

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

    function _onReward(
        address _baseToken,
        address _user,
        address _to,
        uint256,
        uint256 _lpTokenAmount
    ) internal lock {
        PoolInfo memory pool = updatePool(_baseToken);
        UserInfo storage user = userInfo[_baseToken][_user];
        uint256 pending;
        if (user.amount > 0) {
            pending = (user.amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt).add(
                user.unpaidRewards
            );
            IERC20 rewardToken = IERC20(rewardTokens[_baseToken]);
            uint256 balance = rewardToken.balanceOf(address(this));
            if (pending > balance) {
                // TODO add support for native token
                rewardToken.safeTransfer(_to, balance);
                user.unpaidRewards = pending - balance;
            } else {
                rewardToken.safeTransfer(_to, pending);
                user.unpaidRewards = 0;
            }
        }
        user.amount = _lpTokenAmount;
        user.rewardDebt = _lpTokenAmount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION;
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
    ) public onlyOwner {
        if (_token == address(0)) {
            _to.transfer(_amount);
        } else {
            IERC20(_token).safeTransfer(_to, _amount);
        }
    }

    /// @notice Deposit LP tokens
    /// @param _nftId LP token nftId to deposit.
    /// @param _to The receiver of `amount` deposit benefit.
    function deposit(uint256 _nftId, address _to) public {
        require(lpToken.isApprovedForAll(msg.sender, address(this)), "ERR__NOT_APPROVED_FOR_ALL");

        (address baseToken, , uint256 amount) = lpToken.tokenMetadata(_nftId);
        require(rewardTokens[baseToken] != address(0), "ERR__POOL_NOT_INITIALIZED");
        require(rewardPerSecond[baseToken] != 0, "ERR__POOL_NOT_INITIALIZED");

        amount /= liquidityProviders.BASE_DIVISOR();
        updatePool(baseToken);
        UserInfo storage user = userInfo[baseToken][_to];

        _onReward(baseToken, _to, _to, 0, user.amount.add(amount));

        nftIdsStaked[msg.sender].push(_nftId);
        totalSharesStaked[baseToken] = totalSharesStaked[baseToken].add(amount);
        lpToken.safeTransferFrom(msg.sender, address(this), _nftId);

        emit LogDeposit(msg.sender, baseToken, _nftId, _to);
    }

    function withdraw(uint256 _nftId, address _to) public {
        uint256 index;
        for (index = 0; index < nftIdsStaked[msg.sender].length; index++) {
            if (nftIdsStaked[msg.sender][index] == _nftId) {
                break;
            }
        }
        if (index == nftIdsStaked[msg.sender].length) {
            require(false, "ERR__NFT_NOT_STAKED");
        }
        nftIdsStaked[msg.sender][index] = nftIdsStaked[msg.sender][nftIdsStaked[msg.sender].length - 1];
        nftIdsStaked[msg.sender].pop();

        (address baseToken, , uint256 amount) = lpToken.tokenMetadata(_nftId);
        amount /= liquidityProviders.BASE_DIVISOR();

        updatePool(baseToken);
        UserInfo storage user = userInfo[baseToken][msg.sender];

        _onReward(baseToken, _to, _to, 0, user.amount.sub(amount));
        totalSharesStaked[baseToken] = totalSharesStaked[baseToken].sub(amount);
        lpToken.safeTransferFrom(address(this), _to, _nftId);

        emit LogWithdraw(msg.sender, baseToken, _nftId, _to);
    }

    function extractRewards(address _baseToken, address _to) external {
        UserInfo memory user = userInfo[_baseToken][msg.sender];
        _onReward(_baseToken, msg.sender, _to, 0, user.amount);
    }

    /// @notice View function to see pending Token
    /// @param _user Address of user.
    /// @return pending SUSHI reward for a given user.
    function pendingToken(address _baseToken, address _user) public view returns (uint256 pending) {
        PoolInfo memory pool = poolInfo[_baseToken];
        UserInfo storage user = userInfo[_baseToken][_user];
        uint256 accToken1PerShare = pool.accTokenPerShare;
        if (block.timestamp > pool.lastRewardTime && totalSharesStaked[_baseToken] != 0) {
            uint256 time = block.timestamp.sub(pool.lastRewardTime);
            uint256 sushiReward = time.mul(rewardPerSecond[_baseToken]);
            accToken1PerShare = accToken1PerShare.add(
                sushiReward.mul(ACC_TOKEN_PRECISION) / totalSharesStaked[_baseToken]
            );
        }
        pending = (user.amount.mul(accToken1PerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt).add(
            user.unpaidRewards
        );
    }

    /// @notice Update reward variables of the given pool.
    /// @return pool Returns the pool that was updated.
    function updatePool(address _baseToken) public returns (PoolInfo memory pool) {
        pool = poolInfo[_baseToken];
        if (block.timestamp > pool.lastRewardTime) {
            if (totalSharesStaked[_baseToken] > 0) {
                uint256 time = block.timestamp.sub(pool.lastRewardTime);
                uint256 sushiReward = time.mul(rewardPerSecond[_baseToken]);
                pool.accTokenPerShare = pool.accTokenPerShare.add(
                    (sushiReward.mul(ACC_TOKEN_PRECISION) / totalSharesStaked[_baseToken]).to128()
                );
            }
            pool.lastRewardTime = block.timestamp.to64();
            poolInfo[_baseToken] = pool;
            emit LogUpdatePool(_baseToken, pool.lastRewardTime, totalSharesStaked[_baseToken], pool.accTokenPerShare);
        }
    }

    function getNftIdsStaked(address _user) public view returns (uint256[] memory nftIds) {
        nftIds = nftIdsStaked[_user];
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
