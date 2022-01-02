// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../security/Pausable.sol";
import "./ExecutorManager.sol";
import "../interfaces/IERC20Permit.sol";

contract LiquidityPoolManager is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable, 
    ERC2771ContextUpgradeable, Pausable {

    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 public baseGas;
    
    ExecutorManager private executorManager;
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

    mapping ( address => TokenInfo ) public tokensInfo;
    mapping ( bytes32 => bool ) public processedHash;
    mapping ( address => uint256 ) public gasFeeAccumulatedByToken;
    mapping ( address => uint256 ) public adminFeeAccumulatedByToken;
    
    /**
     * First key is toChainId and second key is token address being deposited on current chain
     * TODO To be used in next version, just creating the data structure here
     */    
    mapping ( uint256 => mapping ( address => TransferConfig ) ) public depositConfig;
    
    /**
     * Store min/max amount of token to transfer based on token address
     * TODO To be used in next version, just creating the data structure here
     */    
    mapping ( address => TransferConfig ) public transferConfig;

    // Incentive Pool amount per token address
    mapping(address => uint256) public incentivePool;

    event AssetSent(address indexed asset, uint256 indexed amount, uint256 indexed transferredAmount, address target, bytes depositHash);
    event Received(address indexed from, uint256 indexed amount);
    event Deposit(address indexed from, address indexed tokenAddress, address indexed receiver, uint256 toChainId, uint256 amount);
    event LiquidityAdded(address indexed from, address indexed tokenAddress, address indexed receiver, uint256 amount);
    event LiquidityRemoved(address indexed tokenAddress, uint256 indexed amount, address indexed sender);
    event FundsWithdrawn(address indexed tokenAddress, address indexed owner,  uint256 indexed amount);
    event AdminFeeWithdraw(address indexed tokenAddress, address indexed owner,  uint256 indexed amount);
    event GasFeeWithdraw(address indexed tokenAddress, address indexed owner,  uint256 indexed amount);
    event AdminFeeChanged(uint256 indexed newAdminFee);
    event FeeChanged(uint256 equilibriumFee, uint256 maxFee);
    event TrustedForwarderChanged(address indexed forwarderAddress);
    event EthReceived(address, uint);

    // MODIFIERS
    modifier onlyExecutor() {
        require(executorManager.getExecutorStatus(_msgSender()),
            "Only executor is allowed"
        );
        _;
    }

    modifier tokenChecks(address tokenAddress){
        require(tokenAddress != address(0), "Token address cannot be 0");
        require(tokensInfo[tokenAddress].supportedToken, "Token not supported");

        _;
    }

    function initialize(address _executorManagerAddress, address pauser, address _trustedForwarder, 
        uint256 _equilibriumFee, uint256 _maxFee) public initializer {
        require(_executorManagerAddress != address(0), "ExecutorManager cannot be 0x0");
        require(_trustedForwarder != address(0), "TrustedForwarder cannot be 0x0");
        require(_equilibriumFee != 0, "Equilibrium Fee cannot be 0");
        require(_maxFee != 0, "Max Fee cannot be 0");
        __ReentrancyGuard_init();
        __Ownable_init();
        __ERC2771Context_init(_trustedForwarder);
        __Pausable_init(pauser);
        executorManager = ExecutorManager(_executorManagerAddress);
        equilibriumFee = _equilibriumFee;
        maxFee = _maxFee;
        baseGas = 21000;
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

    function setBaseGas(uint128 gas) external onlyOwner{
        baseGas = gas;
    }

    function getExecutorManager() public view returns (address){
        return address(executorManager);
    }

    function setExecutorManager(address _executorManagerAddress) external onlyOwner {
        require(_executorManagerAddress != address(0), "Executor Manager cannot be 0");
        executorManager = ExecutorManager(_executorManagerAddress);
    }

    function setTokenTransferOverhead( address tokenAddress, uint256 gasOverhead ) external tokenChecks(tokenAddress) onlyOwner {
        tokensInfo[tokenAddress].transferOverhead = gasOverhead;
    }

    function addSupportedToken( address tokenAddress, uint256 minCapLimit, uint256 maxCapLimit ) external onlyOwner {
        require(tokenAddress != address(0), "Token address cannot be 0");  
        require(maxCapLimit > minCapLimit, "maxCapLimit > minCapLimit");        
        tokensInfo[tokenAddress].supportedToken = true;
        tokensInfo[tokenAddress].minCap = minCapLimit;
        tokensInfo[tokenAddress].maxCap = maxCapLimit;
    }

    function removeSupportedToken( address tokenAddress ) external tokenChecks(tokenAddress) onlyOwner {
        tokensInfo[tokenAddress].supportedToken = false;
    }

    function updateTokenCap( address tokenAddress, uint256 minCapLimit, uint256 maxCapLimit ) external tokenChecks(tokenAddress) onlyOwner {
        require(maxCapLimit > minCapLimit, "maxCapLimit > minCapLimit");                
        tokensInfo[tokenAddress].minCap = minCapLimit;        
        tokensInfo[tokenAddress].maxCap = maxCapLimit;
    }

    function addNativeLiquidity() external payable whenNotPaused {
        require(msg.value != 0, "Amount cannot be 0");
        address sender = _msgSender();
        tokensInfo[NATIVE].liquidityProvider[sender] = tokensInfo[NATIVE].liquidityProvider[sender]+ msg.value;
        tokensInfo[NATIVE].liquidity = tokensInfo[NATIVE].liquidity + msg.value;

        emit LiquidityAdded(sender, NATIVE, address(this), msg.value);
    }

    function removeNativeLiquidity(uint256 amount) external nonReentrant {
        require(amount != 0 , "Amount cannot be 0");
        address sender = _msgSender();
        require(tokensInfo[NATIVE].liquidityProvider[sender] >= amount, "Not enough balance");
        tokensInfo[NATIVE].liquidityProvider[sender] = tokensInfo[NATIVE].liquidityProvider[sender] - amount;
        tokensInfo[NATIVE].liquidity = tokensInfo[NATIVE].liquidity - amount;
        
        bool success = payable(sender).send(amount);
        require(success, "Native Transfer Failed");

        emit LiquidityRemoved( NATIVE, amount, sender);
    }

    function addTokenLiquidity( address tokenAddress, uint256 amount ) external tokenChecks(tokenAddress) whenNotPaused {
        require(amount != 0, "Amount cannot be 0");
        address sender = _msgSender();
        tokensInfo[tokenAddress].liquidityProvider[sender] = tokensInfo[tokenAddress].liquidityProvider[sender] + amount;
        tokensInfo[tokenAddress].liquidity = tokensInfo[tokenAddress].liquidity + amount;
        
        SafeERC20.safeTransferFrom(IERC20(tokenAddress), sender, address(this), amount);
        emit LiquidityAdded(sender, tokenAddress, address(this), amount);
    }

    function removeTokenLiquidity( address tokenAddress, uint256 amount ) external tokenChecks(tokenAddress) {
        require(amount != 0, "Amount cannot be 0");
        address sender = _msgSender();
        require(tokensInfo[tokenAddress].liquidityProvider[sender] >= amount, "Not enough balance");

        tokensInfo[tokenAddress].liquidityProvider[sender] = tokensInfo[tokenAddress].liquidityProvider[sender] - amount;
        tokensInfo[tokenAddress].liquidity = tokensInfo[tokenAddress].liquidity - amount;

        SafeERC20.safeTransfer(IERC20(tokenAddress), sender, amount);
        emit LiquidityRemoved( tokenAddress, amount, sender);

    }

    function getLiquidity(address liquidityProviderAddress, address tokenAddress) public view returns (uint256 ) {
        return tokensInfo[tokenAddress].liquidityProvider[liquidityProviderAddress];
    }

    function depositErc20( uint256 toChainId, address tokenAddress, address receiver, uint256 amount ) public tokenChecks(tokenAddress) whenNotPaused {
        require(tokensInfo[tokenAddress].minCap <= amount && tokensInfo[tokenAddress].maxCap >= amount, "Deposit amount not in cap limits");
        require(receiver != address(0), "Receiver address cannot be 0");
        require(amount != 0, "Amount cannot be 0");
        address sender = _msgSender();

        uint256 rewardAmount = getRewardAmount(amount, tokenAddress);
        if(rewardAmount != 0) {
            incentivePool[tokenAddress] = incentivePool[tokenAddress] - rewardAmount;
        }

        SafeERC20.safeTransferFrom(IERC20(tokenAddress), sender, address(this), amount);
        // Emit (amount + reward amount) in event
        emit Deposit(sender, tokenAddress, receiver, toChainId, amount + rewardAmount);
    }

    function getRewardAmount(uint256 amount, address tokenAddress) public view returns(uint256 rewardAmount) {
        uint256 currentLiquidity;
        if(tokenAddress == NATIVE) {
            currentLiquidity = address(this).balance;
        } else {
            currentLiquidity = IERC20(tokenAddress).balanceOf(address(this));
        }
        uint256 providedLiquidity = tokensInfo[tokenAddress].liquidity;
        if((currentLiquidity + amount) <= providedLiquidity) {
            uint256 liquidityDifference = providedLiquidity - currentLiquidity;
            if(amount >= liquidityDifference) {
                rewardAmount = incentivePool[tokenAddress];
            } else {
                // Multiply by 10000 to avoid 0 reward amount for small amount and liquidity difference
                rewardAmount = (amount * incentivePool[tokenAddress] * 10000) / liquidityDifference;
                rewardAmount = rewardAmount / 10000;
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
        )
        external {
            IERC20Permit(tokenAddress).permit(_msgSender(), address(this), permitOptions.nonce, permitOptions.expiry, permitOptions.allowed, permitOptions.v, permitOptions.r, permitOptions.s);
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
        )
        external {
            IERC20Permit(tokenAddress).permit(_msgSender(), address(this), amount, permitOptions.expiry, permitOptions.v, permitOptions.r, permitOptions.s);
            depositErc20(toChainId, tokenAddress, receiver, amount);            
    }

    function depositNative( address receiver, uint256 toChainId ) external whenNotPaused payable {
        require(tokensInfo[NATIVE].minCap <= msg.value && tokensInfo[NATIVE].maxCap >= msg.value, "Deposit amount not in Cap limit");
        require(receiver != address(0), "Receiver address cannot be 0");
        require(msg.value != 0, "Amount cannot be 0");
        
        uint256 rewardAmount = getRewardAmount(msg.value, NATIVE);
        if(rewardAmount != 0) {
            incentivePool[NATIVE] = incentivePool[NATIVE] - rewardAmount;
        }
        emit Deposit(_msgSender(), NATIVE, receiver, toChainId, msg.value + rewardAmount);
    }

    function sendFundsToUser(address tokenAddress, uint256 amount, address payable receiver, bytes memory depositHash, uint256 tokenGasPrice ) external nonReentrant onlyExecutor tokenChecks(tokenAddress) whenNotPaused {
        uint256 initialGas = gasleft();
        require(tokensInfo[tokenAddress].minCap <= amount && tokensInfo[tokenAddress].maxCap >= amount, "Withdraw amnt not in Cap limits");
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
            require(IERC20(tokenAddress).balanceOf(address(this)) >= amountToTransfer, "Not Enough Balance");
            SafeERC20.safeTransfer(IERC20(tokenAddress), receiver, amountToTransfer);
        }

        emit AssetSent(tokenAddress, amount, amountToTransfer, receiver, depositHash);
    }

    function getAmountToTransfer(uint256 initialGas, address tokenAddress, uint256 amount, uint256 tokenGasPrice) internal returns(uint256 amountToTransfer) {
        uint256 transferFee = getTransferFee(tokenAddress, amount);
        uint256 calculatedAdminFee;
        if(transferFee > equilibriumFee) {
            // Here add some fee to incentive pool also
            calculatedAdminFee = (amount * equilibriumFee)/100000;
            incentivePool[tokenAddress] = (incentivePool[tokenAddress] + (amount * (transferFee - equilibriumFee))) / 100000;
        } else {
            calculatedAdminFee = (amount * transferFee) / 100000;
        }
        uint256 transferFeeAmount = (amount * transferFee) / 100000;

        adminFeeAccumulatedByToken[tokenAddress] = adminFeeAccumulatedByToken[tokenAddress] + calculatedAdminFee; 

        uint256 totalGasUsed = initialGas - gasleft();
        totalGasUsed = totalGasUsed+ tokensInfo[tokenAddress].transferOverhead;
        totalGasUsed = totalGasUsed + baseGas;

        gasFeeAccumulatedByToken[tokenAddress] = gasFeeAccumulatedByToken[tokenAddress] + (totalGasUsed * tokenGasPrice);
        amountToTransfer = amount - (transferFeeAmount + (totalGasUsed * tokenGasPrice));
    }

    function getTransferFee(address tokenAddress, uint256 amount) public view returns (uint256 fee) {
        uint256 currentLiquidity = tokenAddress == NATIVE ? address(this).balance : IERC20(tokenAddress).balanceOf(address(this));
        uint256 providedLiquidity = tokensInfo[tokenAddress].liquidity;
        uint256 resultingLiquidity = currentLiquidity - amount;

        // Fee is represented in basis points * 10 for better accuracy 
        uint256 numerator = providedLiquidity * equilibriumFee * maxFee; // F(max) * F(e) * L(e)
        uint256 denominator = equilibriumFee * providedLiquidity + (maxFee - equilibriumFee) * resultingLiquidity; // F(e) * L(e) + (F(max) - F(e)) * L(r)

        fee = numerator / denominator;
    }

    function checkHashStatus(address tokenAddress, uint256 amount, address payable receiver, bytes memory depositHash) public view returns(bytes32 hashSendTransaction, bool status){
        hashSendTransaction = keccak256(
            abi.encode(
                tokenAddress,
                amount,
                receiver,
                keccak256(depositHash)
            )
        );

        status = processedHash[hashSendTransaction];
    }

    function withdrawErc20(address tokenAddress) external onlyOwner whenNotPaused {
        uint256 profitEarned = (IERC20(tokenAddress).balanceOf(address(this)))
                                - tokensInfo[tokenAddress].liquidity
                                - adminFeeAccumulatedByToken[tokenAddress]
                                - gasFeeAccumulatedByToken[tokenAddress];
        require(profitEarned != 0, "Profit earned is 0");
        address sender = _msgSender();

        SafeERC20.safeTransfer(IERC20(tokenAddress), sender, profitEarned);

        emit FundsWithdrawn(tokenAddress, sender,  profitEarned);
    }

    function withdrawErc20AdminFee(address tokenAddress, address receiver) external onlyOwner whenNotPaused {
        require(tokenAddress != NATIVE, "Can't withdraw native token fee");
        uint256 adminFeeAccumulated = adminFeeAccumulatedByToken[tokenAddress];
        require(adminFeeAccumulated != 0, "Admin Fee earned is 0");

        adminFeeAccumulatedByToken[tokenAddress] = 0;

        SafeERC20.safeTransfer(IERC20(tokenAddress), receiver, adminFeeAccumulated);
        emit AdminFeeWithdraw(tokenAddress, receiver, adminFeeAccumulated);
    }

    function withdrawErc20GasFee(address tokenAddress, address receiver) external onlyOwner whenNotPaused {
        require(tokenAddress != NATIVE, "Can't withdraw native token fee");
        uint256 gasFeeAccumulated = gasFeeAccumulatedByToken[tokenAddress];
        require(gasFeeAccumulated != 0, "Gas Fee earned is 0");

        gasFeeAccumulatedByToken[tokenAddress] = 0;

        SafeERC20.safeTransfer(IERC20(tokenAddress), receiver, gasFeeAccumulated);
        emit GasFeeWithdraw(tokenAddress, receiver, gasFeeAccumulated);
    }

    function withdrawNative() external onlyOwner whenNotPaused {
        uint256 profitEarned = (address(this).balance)
                                - tokensInfo[NATIVE].liquidity
                                - adminFeeAccumulatedByToken[NATIVE]
                                - gasFeeAccumulatedByToken[NATIVE];
        
        require(profitEarned != 0, "Profit earned is 0");

        address sender = _msgSender();
        bool success = payable(sender).send(profitEarned);
        require(success, "Native Transfer Failed");
        
        emit FundsWithdrawn(address(this), sender, profitEarned);
    }

    function withdrawNativeAdminFee(address payable receiver) external onlyOwner whenNotPaused {
        uint256 adminFeeAccumulated = adminFeeAccumulatedByToken[NATIVE];
        require(adminFeeAccumulated != 0, "Admin Fee earned is 0");
        adminFeeAccumulatedByToken[NATIVE] = 0;
        bool success = receiver.send(adminFeeAccumulated);
        require(success, "Native Transfer Failed");
        
        emit AdminFeeWithdraw(address(this), receiver, adminFeeAccumulated);
    }

    function withdrawNativeGasFee(address payable receiver) external onlyOwner whenNotPaused {
        uint256 gasFeeAccumulated = gasFeeAccumulatedByToken[NATIVE];
        require(gasFeeAccumulated != 0, "Gas Fee earned is 0");
        gasFeeAccumulatedByToken[NATIVE] = 0;
        bool success = receiver.send(gasFeeAccumulated);
        require(success, "Native Transfer Failed");
        
        emit GasFeeWithdraw(address(this), receiver, gasFeeAccumulated);
    }

    function _msgSender() internal view virtual override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address sender) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData() internal view virtual override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }

    receive() external payable {
        emit EthReceived(_msgSender(), msg.value);
    }
}