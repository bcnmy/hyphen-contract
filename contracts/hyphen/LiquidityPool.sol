// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./LiquidityProviders.sol";
import "../security/Pausable.sol";
import "./interfaces/IExecutorManager.sol";
import "../interfaces/IERC20Permit.sol";

contract LiquidityPool is LiquidityProviders, ReentrancyGuardUpgradeable, Pausable {
    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant BASE_DIVISOR = 10000000000; // Basis Points * 100 for better accuracy

    uint256 public baseGas;

    IExecutorManager private executorManager;
    uint256 public equilibriumFee; // Represented in basis points
    uint256 public maxFee; // Represented in basis points

    struct TokenInfo {
        uint256 transferOverhead;
        bool supportedToken;
        uint256 minCap;
        uint256 maxCap;
        uint256 liquidity;
        mapping(address => uint256) liquidityProvider;
    }

    struct TransferConfig {
        uint256 min;
        uint256 max;
    }

    struct PermitRequest {
        uint256 nonce;
        uint256 expiry;
        bool allowed;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    mapping(address => TokenInfo) public tokensInfo;
    mapping(bytes32 => bool) public processedHash;
    mapping(address => uint256) public gasFeeAccumulatedByToken;

    // Gas fee accumulated by token address => executor address
    mapping(address => mapping(address => uint256)) public gasFeeAccumulated;

    // mapping ( address => uint256 ) public totalTransferFeeByToken;

    /**
     * First key is toChainId and second key is token address being deposited on current chain
     * TODO To be used in next version, just creating the data structure here
     */
    mapping(uint256 => mapping(address => TransferConfig)) public depositConfig;

    /**
     * Store min/max amount of token to transfer based on token address
     * TODO To be used in next version, just creating the data structure here
     */
    mapping(address => TransferConfig) public transferConfig;

    // Incentive Pool amount per token address
    mapping(address => uint256) public incentivePool;

    event AssetSent(
        address indexed asset,
        uint256 indexed amount,
        uint256 indexed transferredAmount,
        address target,
        bytes depositHash
    );
    event Received(address indexed from, uint256 indexed amount);
    event Deposit(
        address indexed from,
        address indexed tokenAddress,
        address indexed receiver,
        uint256 toChainId,
        uint256 amount
    );
    event LiquidityAdded(address indexed from, address indexed tokenAddress, address indexed receiver, uint256 amount);
    event LiquidityRemoved(address indexed tokenAddress, uint256 indexed amount, address indexed sender);
    event FundsWithdrawn(address indexed tokenAddress, address indexed owner, uint256 indexed amount);
    event AdminFeeWithdraw(address indexed tokenAddress, address indexed owner, uint256 indexed amount);
    event GasFeeWithdraw(address indexed tokenAddress, address indexed owner, uint256 indexed amount);
    event AdminFeeChanged(uint256 indexed newAdminFee);
    event FeeChanged(uint256 equilibriumFee, uint256 maxFee);
    event TrustedForwarderChanged(address indexed forwarderAddress);
    event EthReceived(address, uint256);

    // MODIFIERS
    modifier onlyExecutor() {
        require(executorManager.getExecutorStatus(_msgSender()), "Only executor is allowed");
        _;
    }

    modifier tokenChecks(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be 0");
        require(tokensInfo[tokenAddress].supportedToken, "Token not supported");

        _;
    }

    function initialize(
        address _executorManagerAddress,
        address pauser,
        address _trustedForwarder,
        uint256 _equilibriumFee,
        uint256 _maxFee
    ) public initializer {
        require(_executorManagerAddress != address(0), "ExecutorManager cannot be 0x0");
        require(_trustedForwarder != address(0), "TrustedForwarder cannot be 0x0");
        require(_equilibriumFee != 0, "Equilibrium Fee cannot be 0");
        require(_maxFee != 0, "Max Fee cannot be 0");
        __LiquidityProviders_init(_trustedForwarder);
        __ReentrancyGuard_init();
        __Ownable_init();
        __Pausable_init(pauser);
        executorManager = IExecutorManager(_executorManagerAddress);
        equilibriumFee = _equilibriumFee;
        maxFee = _maxFee;
        baseGas = 21000;
    }

    function setTrustedForwarder(address trustedForwarder) public onlyOwner {
        require(trustedForwarder != address(0), "TrustedForwarder can't be 0");
        _trustedForwarder = trustedForwarder;
    }

    function getEquilibriumFee() public view returns (uint256) {
        return equilibriumFee;
    }

    function getMaxFee() public view returns (uint256) {
        return maxFee;
    }

    function changeFee(uint256 _equilibriumFee, uint256 _maxFee) external onlyOwner whenNotPaused {
        require(_equilibriumFee != 0, "Equilibrium Fee cannot be 0");
        require(_maxFee != 0, "Max Fee cannot be 0");
        equilibriumFee = _equilibriumFee;
        maxFee = _maxFee;
        emit FeeChanged(equilibriumFee, maxFee);
    }

    function setBaseGas(uint128 gas) external onlyOwner {
        baseGas = gas;
    }

    function getExecutorManager() public view returns (address) {
        return address(executorManager);
    }

    function setExecutorManager(address _executorManagerAddress) external onlyOwner {
        require(_executorManagerAddress != address(0), "Executor Manager cannot be 0");
        executorManager = IExecutorManager(_executorManagerAddress);
    }

    function setTokenTransferOverhead(address tokenAddress, uint256 gasOverhead)
        external
        tokenChecks(tokenAddress)
        onlyOwner
    {
        tokensInfo[tokenAddress].transferOverhead = gasOverhead;
    }

    function addSupportedToken(
        address tokenAddress,
        uint256 minCapLimit,
        uint256 maxCapLimit
    ) external onlyOwner {
        require(tokenAddress != address(0), "Token address cannot be 0");
        require(maxCapLimit > minCapLimit, "maxCapLimit > minCapLimit");
        tokensInfo[tokenAddress].supportedToken = true;
        tokensInfo[tokenAddress].minCap = minCapLimit;
        tokensInfo[tokenAddress].maxCap = maxCapLimit;
    }

    function removeSupportedToken(address tokenAddress) external tokenChecks(tokenAddress) onlyOwner {
        tokensInfo[tokenAddress].supportedToken = false;
    }

    function updateTokenCap(
        address tokenAddress,
        uint256 minCapLimit,
        uint256 maxCapLimit
    ) external tokenChecks(tokenAddress) onlyOwner {
        require(maxCapLimit > minCapLimit, "maxCapLimit > minCapLimit");
        tokensInfo[tokenAddress].minCap = minCapLimit;
        tokensInfo[tokenAddress].maxCap = maxCapLimit;
    }

    function getCurrentLiquidity(address tokenAddress) public view returns (uint256 currentLiquidity) {
        uint256 liquidityPoolBalance;
        if (tokenAddress == NATIVE) {
            liquidityPoolBalance = address(this).balance;
        } else {
            liquidityPoolBalance = IERC20Upgradeable(tokenAddress).balanceOf(address(this));
        }

        currentLiquidity =
            liquidityPoolBalance -
            gasFeeAccumulatedByToken[tokenAddress] -
            lpFeeAccruedByToken[tokenAddress] -
            incentivePool[tokenAddress];
    }

    function addNativeLiquidity() external payable tokenChecks(NATIVE) nonReentrant whenNotPaused {
        require(msg.value != 0, "Amount cannot be 0");
        address sender = _msgSender();
        tokensInfo[NATIVE].liquidity = tokensInfo[NATIVE].liquidity + msg.value;
        _addNativeLiquidity(NATIVE);
        emit LiquidityAdded(sender, NATIVE, address(this), msg.value);
    }

    function removeNativeLiquidity(uint256 amount) external tokenChecks(NATIVE) nonReentrant {
        require(amount != 0, "Amount cannot be 0");
        address sender = _msgSender();
        tokensInfo[NATIVE].liquidity = tokensInfo[NATIVE].liquidity - amount;
        _removeNativeLiquidity(NATIVE, amount);
        emit LiquidityRemoved(NATIVE, amount, sender);
    }

    function addTokenLiquidity(address tokenAddress, uint256 amount)
        external
        tokenChecks(tokenAddress)
        nonReentrant
        whenNotPaused
    {
        require(amount != 0, "Amount cannot be 0");
        address sender = _msgSender();
        tokensInfo[tokenAddress].liquidity = tokensInfo[tokenAddress].liquidity + amount;
        _addTokenLiquidity(tokenAddress, amount);
        emit LiquidityAdded(sender, tokenAddress, address(this), amount);
    }

    function removeTokenLiquidity(address tokenAddress, uint256 amount)
        external
        tokenChecks(tokenAddress)
        nonReentrant
    {
        require(amount != 0, "Amount cannot be 0");
        address sender = _msgSender();
        _removeTokenLiquidity(tokenAddress, amount);
        tokensInfo[tokenAddress].liquidity = tokensInfo[tokenAddress].liquidity - amount;
        emit LiquidityRemoved(tokenAddress, amount, sender);
    }

    function getLiquidity(address liquidityProviderAddress, address tokenAddress) public view returns (uint256) {
        return liquidityAddedAmount[liquidityProviderAddress][tokenAddress];
    }

    /**
     * @dev Function used to deposit tokens into pool to initiate a cross chain token transfer.
     * @param toChainId Chain id where funds needs to be transfered
     * @param tokenAddress ERC20 Token address that needs to be transfered
     * @param receiver Address on toChainId where tokens needs to be transfered
     * @param amount Amount of token being transfered
     */
    function depositErc20(
        uint256 toChainId,
        address tokenAddress,
        address receiver,
        uint256 amount
    ) public tokenChecks(tokenAddress) whenNotPaused {
        require(
            tokensInfo[tokenAddress].minCap <= amount && tokensInfo[tokenAddress].maxCap >= amount,
            "Deposit amount not in cap limits"
        );
        require(receiver != address(0), "Receiver address cannot be 0");
        require(amount != 0, "Amount cannot be 0");
        address sender = _msgSender();

        uint256 rewardAmount = getRewardAmount(amount, tokenAddress);
        if (rewardAmount != 0) {
            incentivePool[tokenAddress] = incentivePool[tokenAddress] - rewardAmount;
        }

        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(tokenAddress), sender, address(this), amount);
        // Emit (amount + reward amount) in event
        emit Deposit(sender, tokenAddress, receiver, toChainId, amount + rewardAmount);
    }

    function getRewardAmount(uint256 amount, address tokenAddress) public view returns (uint256 rewardAmount) {
        uint256 currentLiquidity = getCurrentLiquidity(tokenAddress);
        uint256 providedLiquidity = tokensInfo[tokenAddress].liquidity;
        if (currentLiquidity < providedLiquidity) {
            uint256 liquidityDifference = providedLiquidity - currentLiquidity;
            if (amount >= liquidityDifference) {
                rewardAmount = incentivePool[tokenAddress];
            } else {
                // Multiply by 10000 to avoid 0 reward amount for small amount and liquidity difference
                rewardAmount = (amount * incentivePool[tokenAddress] * 10000000000) / liquidityDifference;
                rewardAmount = rewardAmount / 10000000000;
            }
        }
    }

    /**
     * DAI permit and Deposit.
     */
    function permitAndDepositErc20(
        address tokenAddress,
        address receiver,
        uint256 amount,
        uint256 toChainId,
        PermitRequest calldata permitOptions
    ) external {
        IERC20Permit(tokenAddress).permit(
            _msgSender(),
            address(this),
            permitOptions.nonce,
            permitOptions.expiry,
            permitOptions.allowed,
            permitOptions.v,
            permitOptions.r,
            permitOptions.s
        );
        depositErc20(toChainId, tokenAddress, receiver, amount);
    }

    /**
     * EIP2612 and Deposit.
     */
    function permitEIP2612AndDepositErc20(
        address tokenAddress,
        address receiver,
        uint256 amount,
        uint256 toChainId,
        PermitRequest calldata permitOptions
    ) external {
        IERC20Permit(tokenAddress).permit(
            _msgSender(),
            address(this),
            amount,
            permitOptions.expiry,
            permitOptions.v,
            permitOptions.r,
            permitOptions.s
        );
        depositErc20(toChainId, tokenAddress, receiver, amount);
    }

    /**
     * @dev Function used to deposit native token into pool to initiate a cross chain token transfer.
     * @param receiver Address on toChainId where tokens needs to be transfered
     * @param toChainId Chain id where funds needs to be transfered
     */
    function depositNative(address receiver, uint256 toChainId) external payable whenNotPaused {
        require(
            tokensInfo[NATIVE].minCap <= msg.value && tokensInfo[NATIVE].maxCap >= msg.value,
            "Deposit amount not in Cap limit"
        );
        require(receiver != address(0), "Receiver address cannot be 0");
        require(msg.value != 0, "Amount cannot be 0");

        uint256 rewardAmount = getRewardAmount(msg.value, NATIVE);
        if (rewardAmount != 0) {
            incentivePool[NATIVE] = incentivePool[NATIVE] - rewardAmount;
        }
        emit Deposit(_msgSender(), NATIVE, receiver, toChainId, msg.value + rewardAmount);
    }

    function sendFundsToUser(
        address tokenAddress,
        uint256 amount,
        address payable receiver,
        bytes memory depositHash,
        uint256 tokenGasPrice
    ) external nonReentrant onlyExecutor tokenChecks(tokenAddress) whenNotPaused {
        uint256 initialGas = gasleft();
        require(
            tokensInfo[tokenAddress].minCap <= amount && tokensInfo[tokenAddress].maxCap >= amount,
            "Withdraw amnt not in Cap limits"
        );
        require(receiver != address(0), "Bad receiver address");

        (bytes32 hashSendTransaction, bool status) = checkHashStatus(tokenAddress, amount, receiver, depositHash);

        require(!status, "Already Processed");
        processedHash[hashSendTransaction] = true;

        uint256 amountToTransfer = getAmountToTransfer(initialGas, tokenAddress, amount, tokenGasPrice);
        if (tokenAddress == NATIVE) {
            require(address(this).balance >= amountToTransfer, "Not Enough Balance");
            bool success = receiver.send(amountToTransfer);
            require(success, "Native Transfer Failed");
        } else {
            require(IERC20Upgradeable(tokenAddress).balanceOf(address(this)) >= amountToTransfer, "Not Enough Balance");
            SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(tokenAddress), receiver, amountToTransfer);
        }

        emit AssetSent(tokenAddress, amount, amountToTransfer, receiver, depositHash);
    }

    /**
     * @dev Internal function to calculate amount of token that needs to be transfered afetr deducting all required fees.
     * Fee to be deducted includes gas fee, lp fee and incentive pool amount if needed.
     * @param initialGas Gas provided initially before any calculations began
     * @param tokenAddress Token address for which calculation needs to be done
     * @param amount Amount of token to be transfered before deducting the fee
     * @param tokenGasPrice Gas price in the token being transfered to be used to calculate gas fee
     * @return amountToTransfer Total amount to be transfered after deducting all fees.
     */
    function getAmountToTransfer(
        uint256 initialGas,
        address tokenAddress,
        uint256 amount,
        uint256 tokenGasPrice
    ) internal returns (uint256 amountToTransfer) {
        uint256 transferFeePerc = getTransferFee(tokenAddress, amount);
        uint256 lpFee;
        if (transferFeePerc > equilibriumFee) {
            // Here add some fee to incentive pool also
            lpFee = (amount * equilibriumFee) / BASE_DIVISOR;
            incentivePool[tokenAddress] =
                (incentivePool[tokenAddress] + (amount * (transferFeePerc - equilibriumFee))) /
                BASE_DIVISOR;
        } else {
            lpFee = (amount * transferFeePerc) / BASE_DIVISOR;
        }
        uint256 transferFeeAmount = (amount * transferFeePerc) / BASE_DIVISOR;

        _addLPFee(tokenAddress, lpFee);

        uint256 totalGasUsed = initialGas - gasleft();
        totalGasUsed = totalGasUsed + tokensInfo[tokenAddress].transferOverhead;
        totalGasUsed = totalGasUsed + baseGas;

        gasFeeAccumulatedByToken[tokenAddress] =
            gasFeeAccumulatedByToken[tokenAddress] +
            (totalGasUsed * tokenGasPrice);
        gasFeeAccumulated[tokenAddress][_msgSender()] =
            gasFeeAccumulated[tokenAddress][_msgSender()] +
            (totalGasUsed * tokenGasPrice);

        amountToTransfer = amount - (transferFeeAmount + (totalGasUsed * tokenGasPrice));
    }

    function getTransferFee(address tokenAddress, uint256 amount) public view returns (uint256 fee) {
        uint256 currentLiquidity = tokenAddress == NATIVE
            ? address(this).balance
            : IERC20Upgradeable(tokenAddress).balanceOf(address(this));
        uint256 providedLiquidity = tokensInfo[tokenAddress].liquidity;
        uint256 resultingLiquidity = currentLiquidity - amount;

        // Fee is represented in basis points * 10 for better accuracy
        uint256 numerator = providedLiquidity * equilibriumFee * maxFee; // F(max) * F(e) * L(e)
        uint256 denominator = equilibriumFee * providedLiquidity + (maxFee - equilibriumFee) * resultingLiquidity; // F(e) * L(e) + (F(max) - F(e)) * L(r)

        fee = numerator / denominator;
    }

    function checkHashStatus(
        address tokenAddress,
        uint256 amount,
        address payable receiver,
        bytes memory depositHash
    ) public view returns (bytes32 hashSendTransaction, bool status) {
        hashSendTransaction = keccak256(abi.encode(tokenAddress, amount, receiver, keccak256(depositHash)));

        status = processedHash[hashSendTransaction];
    }

    function withdrawErc20GasFee(address tokenAddress) external onlyExecutor whenNotPaused {
        require(tokenAddress != NATIVE, "Can't withdraw native token fee");
        // uint256 gasFeeAccumulated = gasFeeAccumulatedByToken[tokenAddress];
        uint256 _gasFeeAccumulated = gasFeeAccumulated[tokenAddress][_msgSender()];
        require(_gasFeeAccumulated != 0, "Gas Fee earned is 0");
        gasFeeAccumulatedByToken[tokenAddress] = gasFeeAccumulatedByToken[tokenAddress] - _gasFeeAccumulated;
        gasFeeAccumulated[tokenAddress][_msgSender()] = 0;
        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(tokenAddress), _msgSender(), _gasFeeAccumulated);
        emit GasFeeWithdraw(tokenAddress, _msgSender(), _gasFeeAccumulated);
    }

    function withdrawNativeGasFee() external onlyOwner whenNotPaused {
        uint256 _gasFeeAccumulated = gasFeeAccumulated[NATIVE][_msgSender()];
        require(_gasFeeAccumulated != 0, "Gas Fee earned is 0");
        gasFeeAccumulatedByToken[NATIVE] = 0;
        gasFeeAccumulatedByToken[NATIVE] = gasFeeAccumulatedByToken[NATIVE] - _gasFeeAccumulated;
        gasFeeAccumulated[NATIVE][_msgSender()] = 0;
        bool success = payable(_msgSender()).send(_gasFeeAccumulated);
        require(success, "Native Transfer Failed");

        emit GasFeeWithdraw(address(this), _msgSender(), _gasFeeAccumulated);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, LiquidityProviders)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, LiquidityProviders)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    receive() external payable {
        emit EthReceived(_msgSender(), msg.value);
    }
}
