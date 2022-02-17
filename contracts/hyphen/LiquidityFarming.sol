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

    function onReward(
        address baseToken,
        address _user,
        address to,
        uint256,
        uint256 lpTokenAmount
    ) internal lock {
        PoolInfo memory pool = updatePool(baseToken);
        UserInfo storage user = userInfo[baseToken][_user];
        uint256 pending;
        if (user.amount > 0) {
            pending = (user.amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt).add(
                user.unpaidRewards
            );
            IERC20 rewardToken = IERC20(rewardTokens[baseToken]);
            uint256 balance = rewardToken.balanceOf(address(this));
            if (pending > balance) {
                rewardToken.safeTransfer(to, balance);
                user.unpaidRewards = pending - balance;
            } else {
                rewardToken.safeTransfer(to, pending);
                user.unpaidRewards = 0;
            }
        }
        user.amount = lpTokenAmount;
        user.rewardDebt = lpTokenAmount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION;
        emit LogOnReward(_user, baseToken, pending - user.unpaidRewards, to);
    }

    /// @notice Sets the sushi per second to be distributed. Can only be called by the owner.
    /// @param _rewardPerSecond The amount of Sushi to be distributed per second.
    function setRewardPerSecond(address _baseToken, uint256 _rewardPerSecond) public onlyOwner {
        rewardPerSecond[_baseToken] = _rewardPerSecond;
        emit LogRewardPerSecond(_baseToken, _rewardPerSecond);
    }

    /// @notice Allows owner to reclaim/withdraw any tokens (including reward tokens) held by this contract
    /// @param token Token to reclaim, use 0x00 for Ethereum
    /// @param amount Amount of tokens to reclaim
    /// @param to Receiver of the tokens, first of his name, rightful heir to the lost tokens,
    /// reightful owner of the extra tokens, and ether, protector of mistaken transfers, mother of token reclaimers,
    /// the Khaleesi of the Great Token Sea, the Unburnt, the Breaker of blockchains.
    function reclaimTokens(
        address token,
        uint256 amount,
        address payable to
    ) public onlyOwner {
        if (token == address(0)) {
            to.transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /// @notice Deposit LP tokens
    /// @param nftId LP token nftId to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function deposit(uint256 nftId, address to) public {
        require(lpToken.isApprovedForAll(msg.sender, address(this)), "ERR__NOT_APPROVED_FOR_ALL");

        (address baseToken, , uint256 amount) = lpToken.tokenMetadata(nftId);
        require(rewardTokens[baseToken] != address(0), "ERR__POOL_NOT_INITIALIZED");
        require(rewardPerSecond[baseToken] != 0, "ERR__POOL_NOT_INITIALIZED");

        amount /= liquidityProviders.BASE_DIVISOR();
        PoolInfo memory pool = updatePool(baseToken);
        UserInfo storage user = userInfo[baseToken][to];

        user.amount = user.amount.add(amount);
        user.rewardDebt = user.rewardDebt.add(amount.mul(pool.accTokenPerShare) / ACC_SUSHI_PRECISION);

        onReward(baseToken, to, to, 0, user.amount);
        lpToken.safeTransferFrom(msg.sender, address(this), nftId);

        emit LogDeposit(msg.sender, baseToken, nftId, to);
    }

    function withdraw(uint256 nftId, address to) public {
        (address baseToken, , uint256 amount) = lpToken.tokenMetadata(nftId);
        amount /= liquidityProviders.BASE_DIVISOR();

        PoolInfo memory pool = updatePool(baseToken);
        UserInfo storage user = userInfo[baseToken][msg.sender];

        user.rewardDebt = user.rewardDebt.sub(amount.mul(pool.accTokenPerShare) / ACC_SUSHI_PRECISION);
        user.amount = user.amount.sub(amount);

        onReward(baseToken, to, to, 0, user.amount);
        lpToken.safeTransferFrom(address(this), to, nftId);

        emit LogWithdraw(msg.sender, baseToken, nftId, to);
    }

    /// @notice View function to see pending Token
    /// @param _user Address of user.
    /// @return pending SUSHI reward for a given user.
    function pendingToken(address _baseToken, address _user) public view returns (uint256 pending) {
        PoolInfo memory pool = poolInfo[_baseToken];
        UserInfo storage user = userInfo[_baseToken][_user];
        uint256 accToken1PerShare = pool.accTokenPerShare;
        uint256 lpSupply = liquidityProviders.totalSharesMinted(_baseToken);
        lpSupply /= liquidityProviders.BASE_DIVISOR();
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 time = block.timestamp.sub(pool.lastRewardTime);
            uint256 sushiReward = time.mul(rewardPerSecond[_baseToken]);
            accToken1PerShare = accToken1PerShare.add(sushiReward.mul(ACC_TOKEN_PRECISION) / lpSupply);
        }
        pending = (user.amount.mul(accToken1PerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt).add(
            user.unpaidRewards
        );
    }

    /// @notice Update reward variables of the given pool.
    /// @return pool Returns the pool that was updated.
    function updatePool(address baseToken) public returns (PoolInfo memory pool) {
        pool = poolInfo[baseToken];
        if (block.timestamp > pool.lastRewardTime) {
            uint256 lpSupply = liquidityProviders.totalSharesMinted(baseToken);
            lpSupply /= liquidityProviders.BASE_DIVISOR();
            if (lpSupply > 0) {
                uint256 time = block.timestamp.sub(pool.lastRewardTime);
                uint256 sushiReward = time.mul(rewardPerSecond[baseToken]);
                pool.accTokenPerShare = pool.accTokenPerShare.add(
                    (sushiReward.mul(ACC_TOKEN_PRECISION) / lpSupply).to128()
                );
            }
            pool.lastRewardTime = block.timestamp.to64();
            poolInfo[baseToken] = pool;
            emit LogUpdatePool(baseToken, pool.lastRewardTime, lpSupply, pool.accTokenPerShare);
        }
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
