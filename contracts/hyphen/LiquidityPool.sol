// $$\   $$\                     $$\                                 $$$$$$$\                      $$\
// $$ |  $$ |                    $$ |                                $$  __$$\                     $$ |
// $$ |  $$ |$$\   $$\  $$$$$$\  $$$$$$$\   $$$$$$\  $$$$$$$\        $$ |  $$ | $$$$$$\   $$$$$$\  $$ |
// $$$$$$$$ |$$ |  $$ |$$  __$$\ $$  __$$\ $$  __$$\ $$  __$$\       $$$$$$$  |$$  __$$\ $$  __$$\ $$ |
// $$  __$$ |$$ |  $$ |$$ /  $$ |$$ |  $$ |$$$$$$$$ |$$ |  $$ |      $$  ____/ $$ /  $$ |$$ /  $$ |$$ |
// $$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$   ____|$$ |  $$ |      $$ |      $$ |  $$ |$$ |  $$ |$$ |
// $$ |  $$ |\$$$$$$$ |$$$$$$$  |$$ |  $$ |\$$$$$$$\ $$ |  $$ |      $$ |      \$$$$$$  |\$$$$$$  |$$ |
// \__|  \__| \____$$ |$$  ____/ \__|  \__| \_______|\__|  \__|      \__|       \______/  \______/ \__|
//           $$\   $$ |$$ |
//           \$$$$$$  |$$ |
//            \______/ \__|
//
// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./lib/Fee.sol";
import "./lib/CCMP.sol";
import "./metatx/ERC2771ContextUpgradeable.sol";
import "../security/Pausable.sol";
import "./structures/TokenConfig.sol";
import "./interfaces/IExecutorManager.sol";
import "./interfaces/ILiquidityProviders.sol";
import "../interfaces/IERC20Permit.sol";
import "./interfaces/ITokenManager.sol";
import "./interfaces/ISwapAdaptor.sol";
import "./interfaces/ICCMPGateway.sol";

/**
 * Error Codes:
 * 1: Only executor is allowed
 * 2: Only liquidityProviders is allowed
 * 3: Token not supported
 * 4: ExecutorManager cannot be 0x0
 * 5: TrustedForwarder cannot be 0x0
 * 6: LiquidityProviders cannot be 0x0
 * 7: LiquidityProviders can't be 0
 * 8: TokenManager can't be 0
 * 9: Executor Manager cannot be 0
 * 10: Amount mismatch
 * 11: Token symbol not set
 * 12: Liquidity pool not set
 * 13: Total percentage cannot be > 100
 * 14: To chain must be different than current chain
 * 15: wrong function
 * 16: Deposit amount not in Cap limit
 * 17: Receiver address cannot be 0
 * 18: Amount cannot be 0
 * 19: Total percentage cannot be > 100
 * 20: To chain must be different than current chain
 * 21: Deposit amount not in Cap limit
 * 22: Receiver address cannot be 0
 * 23: Amount cannot be 0
 * 24: Invalid sender contract
 * 25: Token not supported
 * 26: Withdraw amount not in Cap limit
 * 27: Bad receiver address
 * 28: Insufficient funds to cover transfer fee
 * 29: Native Transfer Failed
 * 30: Native Transfer Failed
 * 31: Wrong method call
 * 32: Swap adaptor not found
 * 33: Native Transfer to Adaptor Failed
 * 34: Withdraw amount not in Cap limit
 * 35: Bad receiver address
 * 36: Already Processed
 * 37: Insufficient funds to cover transfer fee
 * 38: Can't withdraw native token fee
 * 39: Gas Fee earned is 0
 * 40: Gas Fee earned is 0
 * 41: Native Transfer Failed
 * 42: Invalid receiver
 * 43: ERR__INSUFFICIENT_BALANCE
 * 44: ERR__NATIVE_TRANSFER_FAILED
 * 45: ERR__INSUFFICIENT_BALANCE
 * 46: InvalidOrigin
 */

contract LiquidityPool is
    Initializable,
    ReentrancyGuardUpgradeable,
    Pausable,
    OwnableUpgradeable,
    ERC2771ContextUpgradeable
{
    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant BASE_DIVISOR = 10000000000; // Basis Points * 100 for better accuracy

    uint256 public baseGas;

    IExecutorManager private executorManager;
    ITokenManager public tokenManager;
    ILiquidityProviders public liquidityProviders;

    mapping(bytes32 => bool) public processedHash;
    mapping(address => uint256) public gasFeeAccumulatedByToken;

    // Gas fee accumulated by token address => executor address
    mapping(address => mapping(address => uint256)) public gasFeeAccumulated;

    // Incentive Pool amount per token address
    mapping(address => uint256) public incentivePool;

    mapping(string => address) public swapAdaptorMap;

    // CCMP Integration
    address public _ccmpGateway;
    // Token Address => chainId => Symbol
    mapping(address => mapping(uint256 => uint256)) public tokenAddressToSymbol;
    // Symbol => chainId => Token Address
    mapping(uint256 => mapping(uint256 => address)) public symbolToTokenAddress;
    // Chain Id => Liquidity Pool Address
    mapping(uint256 => address) public chainIdToLiquidityPoolAddress;

    event AssetSent(
        address indexed asset,
        uint256 indexed amount,
        uint256 indexed transferredAmount,
        address target,
        bytes depositHash,
        uint256 fromChainId,
        uint256 lpFee,
        uint256 transferFee,
        uint256 gasFee
    );
    event AssetSentFromCCMP(
        address indexed asset,
        uint256 tokenSymbol,
        uint256 indexed amount,
        uint256 indexed transferredAmount,
        address target,
        uint256 fromChainId,
        uint256 lpFee,
        uint256 transferFee
    );
    event Deposit(
        address indexed from,
        address indexed tokenAddress,
        address indexed receiver,
        uint256 toChainId,
        uint256 amount,
        uint256 reward,
        string tag
    );
    event DepositAndCall(
        address indexed from,
        address indexed tokenAddress,
        uint256 tokenSymbol,
        address indexed receiver,
        uint256 amount,
        uint256 reward,
        string tag
    );
    event DepositAndSwap(
        address indexed from,
        address indexed tokenAddress,
        address indexed receiver,
        uint256 toChainId,
        uint256 amount,
        uint256 reward,
        string tag,
        SwapRequest[] swapRequests
    );

    // MODIFIERS
    modifier onlyExecutor() {
        require(executorManager.getExecutorStatus(_msgSender()), "1");
        _;
    }

    modifier tokenChecks(address tokenAddress) {
        (, bool supportedToken, , , ) = tokenManager.tokensInfo(tokenAddress);
        require(supportedToken, "3");
        _;
    }

    function _verifyExitParams(
        address tokenAddress,
        uint256 amount,
        address payable receiver
    ) internal view {
        TokenConfig memory config = tokenManager.getTransferConfig(tokenAddress);
        require(config.min <= amount && config.max >= amount, "26");
        require(receiver != address(0), "27");
    }

    function initialize(
        address _executorManagerAddress,
        address _pauser,
        address _trustedForwarder,
        address _tokenManager,
        address _liquidityProviders
    ) public initializer {
        require(_executorManagerAddress != address(0), "4");
        require(_trustedForwarder != address(0), "5");
        require(_liquidityProviders != address(0), "6");
        __ERC2771Context_init(_trustedForwarder);
        __ReentrancyGuard_init();
        __Ownable_init();
        __Pausable_init(_pauser);
        executorManager = IExecutorManager(_executorManagerAddress);
        tokenManager = ITokenManager(_tokenManager);
        liquidityProviders = ILiquidityProviders(_liquidityProviders);
        baseGas = 21000;
    }

    function setSwapAdaptor(string calldata name, address _swapAdaptor) external onlyOwner {
        swapAdaptorMap[name] = _swapAdaptor;
    }

    function setTrustedForwarder(address trustedForwarder) external onlyOwner {
        _setTrustedForwarder(trustedForwarder);
    }

    function setLiquidityProviders(address _liquidityProviders) external onlyOwner {
        require(_liquidityProviders != address(0), "7");
        liquidityProviders = ILiquidityProviders(_liquidityProviders);
    }

    function setCCMPGateway(address _newCCMPGateway) external onlyOwner {
        _ccmpGateway = _newCCMPGateway;
    }

    function setTokenSymbol(
        address tokenAddress,
        uint256 symbol,
        uint256 chainId
    ) external onlyOwner {
        tokenAddressToSymbol[tokenAddress][chainId] = symbol;
        symbolToTokenAddress[symbol][chainId] = tokenAddress;
    }

    function setLiquidityPoolAddress(uint256 chainId, address liquidityPoolAddress) external onlyOwner {
        chainIdToLiquidityPoolAddress[chainId] = liquidityPoolAddress;
    }

    function setTokenManager(address _tokenManager) external onlyOwner {
        require(_tokenManager != address(0), "8");
        tokenManager = ITokenManager(_tokenManager);
    }

    function setBaseGas(uint128 gas) external onlyOwner {
        baseGas = gas;
    }

    function setExecutorManager(address _executorManagerAddress) external onlyOwner {
        require(_executorManagerAddress != address(0), "9");
        executorManager = IExecutorManager(_executorManagerAddress);
    }

    function getCurrentLiquidity(address tokenAddress) public view returns (uint256 currentLiquidity) {
        uint256 liquidityPoolBalance = liquidityProviders.getCurrentLiquidity(tokenAddress);

        currentLiquidity =
            liquidityPoolBalance -
            liquidityProviders.totalLPFees(tokenAddress) -
            gasFeeAccumulatedByToken[tokenAddress] -
            incentivePool[tokenAddress];
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
        uint256 amount,
        string calldata tag
    ) public tokenChecks(tokenAddress) whenNotPaused nonReentrant {
        address sender = _msgSender();
        uint256 rewardAmount = _depositErc20(sender, toChainId, tokenAddress, receiver, amount);

        // Emit (amount + reward amount) in event
        emit Deposit(sender, tokenAddress, receiver, toChainId, amount + rewardAmount, rewardAmount, tag);
    }

    function depositAndCall(
        uint256 toChainId,
        address tokenAddress, // Can be Native
        address receiver,
        uint256 amount,
        string memory tag,
        CCMP.CCMPMessagePayload[] calldata payloads,
        bytes calldata ccmpArgs
    ) external payable tokenChecks(tokenAddress) whenNotPaused nonReentrant {
        uint256 rewardAmount = 0;
        if (tokenAddress == NATIVE) {
            require(msg.value == amount, "10");
            rewardAmount = _depositNative(receiver, toChainId);
        } else {
            rewardAmount = _depositErc20(_msgSender(), toChainId, tokenAddress, receiver, amount);
        }

        uint256 tokenSymbol = tokenAddressToSymbol[tokenAddress][block.chainid];
        require(tokenSymbol != 0, "11");

        _invokeCCMP(toChainId, tokenSymbol, amount + rewardAmount, receiver, payloads, ccmpArgs);

        emit DepositAndCall(
            _msgSender(),
            tokenAddress,
            tokenSymbol,
            receiver,
            amount + rewardAmount,
            rewardAmount,
            tag
        );
    }

    function _invokeCCMP(
        uint256 toChainId,
        uint256 tokenSymbol,
        uint256 transferredAmount,
        address receiver,
        CCMP.CCMPMessagePayload[] calldata payloads,
        bytes calldata ccmpArgs
    ) internal {
        (string memory adaptorName, CCMP.GasFeePaymentArgs memory gasFeePaymentArgs, bytes memory routerArgs) = abi
            .decode(ccmpArgs, (string, CCMP.GasFeePaymentArgs, bytes));

        // Send Message to CCMP Gateway
        address toChainLiquidityPool = chainIdToLiquidityPoolAddress[toChainId];
        require(toChainLiquidityPool != address(0), "12");
        CCMP.CCMPMessagePayload[] memory updatedPayloads = new CCMP.CCMPMessagePayload[](payloads.length + 1);
        updatedPayloads[0] = CCMP.CCMPMessagePayload({
            to: toChainLiquidityPool,
            _calldata: abi.encodeWithSelector(
                this.sendFundsToUserFromCCMP.selector,
                tokenSymbol,
                transferredAmount,
                receiver
            )
        });
        uint256 length = payloads.length;
        for (uint256 i = 1; i < length; ) {
            updatedPayloads[i] = payloads[i - 1];
            unchecked {
                ++i;
            }
        }

        ICCMPGateway(_ccmpGateway).sendMessage(toChainId, adaptorName, updatedPayloads, gasFeePaymentArgs, routerArgs);
    }

    /**
     * @dev Function used to deposit tokens into pool to initiate a cross chain token swap And transfer .
     * @param toChainId Chain id where funds needs to be transfered
     * @param tokenAddress ERC20 Token address that needs to be transfered
     * @param receiver Address on toChainId where tokens needs to be transfered
     * @param amount Amount of token being transfered
     * @param tag Dapp unique identifier
     * @param swapRequest information related to token swap on exit chain
     */
    function depositAndSwapErc20(
        address tokenAddress,
        address receiver,
        uint256 toChainId,
        uint256 amount,
        string calldata tag,
        SwapRequest[] calldata swapRequest
    ) external tokenChecks(tokenAddress) whenNotPaused nonReentrant {
        uint256 totalPercentage = 0;
        {
            uint256 swapArrayLength = swapRequest.length;
            unchecked {
                for (uint256 index = 0; index < swapArrayLength; ++index) {
                    totalPercentage += swapRequest[index].percentage;
                }
            }
        }

        require(totalPercentage <= 100 * BASE_DIVISOR, "13");
        address sender = _msgSender();
        uint256 rewardAmount = _depositErc20(sender, toChainId, tokenAddress, receiver, amount);
        // Emit (amount + reward amount) in event
        emit DepositAndSwap(
            sender,
            tokenAddress,
            receiver,
            toChainId,
            amount + rewardAmount,
            rewardAmount,
            tag,
            swapRequest
        );
    }

    function _depositErc20(
        address sender,
        uint256 toChainId,
        address tokenAddress,
        address receiver,
        uint256 amount
    ) internal returns (uint256) {
        require(toChainId != block.chainid, "14");
        require(tokenAddress != NATIVE, "15");
        TokenConfig memory config = tokenManager.getDepositConfig(toChainId, tokenAddress);

        require(config.min <= amount && config.max >= amount, "16");
        require(receiver != address(0), "17");
        require(amount != 0, "18");

        uint256 rewardAmount = getRewardAmount(amount, tokenAddress);
        if (rewardAmount != 0) {
            incentivePool[tokenAddress] = incentivePool[tokenAddress] - rewardAmount;
        }
        liquidityProviders.increaseCurrentLiquidity(tokenAddress, amount);
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(tokenAddress), sender, address(this), amount);
        return rewardAmount;
    }

    function getRewardAmount(uint256 amount, address tokenAddress) public view returns (uint256 rewardAmount) {
        uint256 currentLiquidity = getCurrentLiquidity(tokenAddress);
        uint256 providedLiquidity = liquidityProviders.getSuppliedLiquidityByToken(tokenAddress);
        if (currentLiquidity < providedLiquidity) {
            uint256 liquidityDifference = providedLiquidity - currentLiquidity;
            if (amount >= liquidityDifference) {
                rewardAmount = incentivePool[tokenAddress];
            } else {
                // Multiply by 10000000000 to avoid 0 reward amount for small amount and liquidity difference
                rewardAmount = (amount * incentivePool[tokenAddress] * 10000000000) / liquidityDifference;
                rewardAmount = rewardAmount / 10000000000;
            }
        }
    }

    /**
     * @dev Function used to deposit native token into pool to initiate a cross chain token transfer.
     * @param receiver Address on toChainId where tokens needs to be transfered
     * @param toChainId Chain id where funds needs to be transfered
     */
    function depositNative(
        address receiver,
        uint256 toChainId,
        string calldata tag
    ) external payable whenNotPaused nonReentrant {
        uint256 rewardAmount = _depositNative(receiver, toChainId);
        emit Deposit(_msgSender(), NATIVE, receiver, toChainId, msg.value + rewardAmount, rewardAmount, tag);
    }

    function depositNativeAndSwap(
        address receiver,
        uint256 toChainId,
        string calldata tag,
        SwapRequest[] calldata swapRequest
    ) external payable whenNotPaused nonReentrant {
        uint256 totalPercentage = 0;
        {
            uint256 swapArrayLength = swapRequest.length;
            unchecked {
                for (uint256 index = 0; index < swapArrayLength; ++index) {
                    totalPercentage += swapRequest[index].percentage;
                }
            }
        }

        require(totalPercentage <= 100 * BASE_DIVISOR, "19");

        uint256 rewardAmount = _depositNative(receiver, toChainId);
        emit DepositAndSwap(
            _msgSender(),
            NATIVE,
            receiver,
            toChainId,
            msg.value + rewardAmount,
            rewardAmount,
            tag,
            swapRequest
        );
    }

    function _depositNative(address receiver, uint256 toChainId) internal returns (uint256) {
        require(toChainId != block.chainid, "20");
        require(
            tokenManager.getDepositConfig(toChainId, NATIVE).min <= msg.value &&
                tokenManager.getDepositConfig(toChainId, NATIVE).max >= msg.value,
            "21"
        );
        require(receiver != address(0), "22");
        require(msg.value != 0, "23");

        uint256 rewardAmount = getRewardAmount(msg.value, NATIVE);
        if (rewardAmount != 0) {
            incentivePool[NATIVE] = incentivePool[NATIVE] - rewardAmount;
        }
        liquidityProviders.increaseCurrentLiquidity(NATIVE, msg.value);
        return rewardAmount;
    }

    function _calculateAndUpdateFeeComponents(address _tokenAddress, uint256 _amount)
        private
        returns (
            uint256 lpFee,
            uint256 incentivePoolFee,
            uint256 transferFeeAmount
        )
    {
        TokenInfo memory tokenInfo = tokenManager.getTokensInfo(_tokenAddress);
        (lpFee, incentivePoolFee, transferFeeAmount) = Fee.getFeeComponents(
            _amount,
            getCurrentLiquidity(_tokenAddress),
            liquidityProviders.getSuppliedLiquidityByToken(_tokenAddress),
            tokenInfo.equilibriumFee,
            tokenInfo.maxFee,
            tokenManager.excessStateTransferFeePerc(_tokenAddress)
        );

        // Update Incentive Pool Fee
        if (incentivePoolFee != 0) {
            incentivePool[_tokenAddress] += incentivePoolFee;
        }

        // Update LP Fee
        liquidityProviders.addLPFee(_tokenAddress, lpFee);
    }

    function sendFundsToUserFromCCMP(
        uint256 tokenSymbol,
        uint256 amount,
        address payable receiver
    ) external whenNotPaused {
        // CCMP Verification
        (address senderContract, uint256 sourceChainId) = CCMP.ccmpMsgOrigin(_ccmpGateway);
        require(senderContract == chainIdToLiquidityPoolAddress[sourceChainId], "24");

        // Get local token address
        address tokenAddress = symbolToTokenAddress[tokenSymbol][block.chainid];
        require(tokenAddress != address(0), "25");

        _verifyExitParams(tokenAddress, amount, receiver);

        (uint256 lpFee, uint256 incentivePoolFee, uint256 transferFeeAmount) = _calculateAndUpdateFeeComponents(
            tokenAddress,
            amount
        );

        // Calculate final amount  to transfer
        uint256 amountToTransfer;
        require(transferFeeAmount <= amount, "28");
        unchecked {
            amountToTransfer = amount - (transferFeeAmount);
        }

        // Send funds to user
        liquidityProviders.decreaseCurrentLiquidity(tokenAddress, amountToTransfer);
        _releaseFunds(tokenAddress, receiver, amountToTransfer);

        emit AssetSentFromCCMP(
            tokenAddress,
            tokenSymbol,
            amount,
            amountToTransfer,
            receiver,
            sourceChainId,
            lpFee,
            incentivePoolFee
        );
    }

    function sendFundsToUserV2(
        address tokenAddress,
        uint256 amount,
        address payable receiver,
        bytes calldata depositHash,
        uint256 nativeTokenPriceInTransferredToken,
        uint256 fromChainId,
        uint256 tokenGasBaseFee
    ) external nonReentrant onlyExecutor whenNotPaused {
        uint256[4] memory transferDetails = _calculateAmountAndDecreaseAvailableLiquidity(
            tokenAddress,
            amount,
            receiver,
            depositHash,
            nativeTokenPriceInTransferredToken,
            tokenGasBaseFee
        );
        _releaseFunds(tokenAddress, receiver, transferDetails[0]);

        emit AssetSent(
            tokenAddress,
            amount,
            transferDetails[0],
            receiver,
            depositHash,
            fromChainId,
            transferDetails[1],
            transferDetails[2],
            transferDetails[3]
        );
    }

    function _releaseFunds(
        address tokenAddress,
        address payable receiver,
        uint256 amount
    ) internal {
        if (tokenAddress == NATIVE) {
            (bool success, ) = receiver.call{value: amount}("");
            require(success, "30");
        } else {
            SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(tokenAddress), receiver, amount);
        }
    }

    function swapAndSendFundsToUser(
        address tokenAddress,
        uint256 amount,
        address payable receiver,
        bytes calldata depositHash,
        uint256 nativeTokenPriceInTransferredToken,
        uint256 tokenGasBaseFee,
        uint256 fromChainId,
        uint256 swapGasOverhead,
        SwapRequest[] calldata swapRequests,
        string memory swapAdaptor
    ) external nonReentrant onlyExecutor whenNotPaused {
        require(swapRequests.length > 0, "31");
        require(swapAdaptorMap[swapAdaptor] != address(0), "32");

        uint256[4] memory transferDetails = _calculateAmountAndDecreaseAvailableLiquidity(
            tokenAddress,
            amount,
            receiver,
            depositHash,
            nativeTokenPriceInTransferredToken,
            tokenGasBaseFee
        );

        if (tokenAddress == NATIVE) {
            (bool success, ) = swapAdaptorMap[swapAdaptor].call{value: transferDetails[0]}("");
            require(success, "33");
            ISwapAdaptor(swapAdaptorMap[swapAdaptor]).swapNative(transferDetails[0], receiver, swapRequests);
        } else {
            {
                uint256 gasBeforeApproval = gasleft();
                SafeERC20Upgradeable.safeApprove(
                    IERC20Upgradeable(tokenAddress),
                    address(swapAdaptorMap[swapAdaptor]),
                    0
                );
                SafeERC20Upgradeable.safeApprove(
                    IERC20Upgradeable(tokenAddress),
                    address(swapAdaptorMap[swapAdaptor]),
                    transferDetails[0]
                );

                swapGasOverhead += (gasBeforeApproval - gasleft());
            }
            {
                // Calculate Gas Fee
                uint256 swapGasFee = calculateAndUpdateGasFee(
                    tokenAddress,
                    nativeTokenPriceInTransferredToken,
                    swapGasOverhead,
                    0,
                    _msgSender()
                );

                transferDetails[0] -= swapGasFee; // Deduct swap gas fee from amount to be sent
                transferDetails[3] += swapGasFee; // Add swap gas fee to gas fee
            }

            ISwapAdaptor(swapAdaptorMap[swapAdaptor]).swap(tokenAddress, transferDetails[0], receiver, swapRequests);
        }

        emit AssetSent(
            tokenAddress,
            amount,
            transferDetails[0],
            receiver,
            depositHash,
            fromChainId,
            transferDetails[1],
            transferDetails[2],
            transferDetails[3]
        );
    }

    function _calculateAmountAndDecreaseAvailableLiquidity(
        address tokenAddress,
        uint256 amount,
        address payable receiver,
        bytes calldata depositHash,
        uint256 nativeTokenPriceInTransferredToken,
        uint256 tokenGasBaseFee
    ) internal returns (uint256[4] memory) {
        uint256 initialGas = gasleft();
        _verifyExitParams(tokenAddress, amount, receiver);

        require(receiver != address(0), "35");
        (bytes32 hashSendTransaction, bool status) = checkHashStatus(tokenAddress, amount, receiver, depositHash);

        require(!status, "36");
        processedHash[hashSendTransaction] = true;
        // uint256 amountToTransfer, uint256 lpFee, uint256 transferFeeAmount, uint256 gasFee
        uint256[4] memory transferDetails = getAmountToTransferV2(
            initialGas,
            tokenAddress,
            amount,
            nativeTokenPriceInTransferredToken,
            tokenGasBaseFee
        );

        liquidityProviders.decreaseCurrentLiquidity(tokenAddress, transferDetails[0]);

        return transferDetails;
    }

    /**
     * @dev Internal function to calculate amount of token that needs to be transfered afetr deducting all required fees.
     * Fee to be deducted includes gas fee, lp fee and incentive pool amount if needed.
     * @param initialGas Gas provided initially before any calculations began
     * @param tokenAddress Token address for which calculation needs to be done
     * @param amount Amount of token to be transfered before deducting the fee
     * @param nativeTokenPriceInTransferredToken Price of native token in terms of the token being transferred (multiplied base div), used to calculate gas fee
     * @return [ amountToTransfer, lpFee, transferFeeAmount, gasFee ]
     */

    function getAmountToTransferV2(
        uint256 initialGas,
        address tokenAddress,
        uint256 amount,
        uint256 nativeTokenPriceInTransferredToken,
        uint256 tokenGasBaseFee
    ) internal returns (uint256[4] memory) {
        TokenInfo memory tokenInfo = tokenManager.getTokensInfo(tokenAddress);
        (uint256 lpFee, , uint256 transferFeeAmount) = _calculateAndUpdateFeeComponents(tokenAddress, amount);

        // Calculate Gas Fee
        uint256 totalGasUsed = initialGas + tokenInfo.transferOverhead + baseGas - gasleft();
        uint256 gasFee = calculateAndUpdateGasFee(
            tokenAddress,
            nativeTokenPriceInTransferredToken,
            totalGasUsed,
            tokenGasBaseFee,
            _msgSender()
        );
        require(transferFeeAmount + gasFee <= amount, "37");
        unchecked {
            uint256 amountToTransfer = amount - (transferFeeAmount + gasFee);
            return [amountToTransfer, lpFee, transferFeeAmount, gasFee];
        }
    }

    function calculateAndUpdateGasFee(
        address tokenAddress,
        uint256 nativeTokenPriceInTransferredToken,
        uint256 gasUsed,
        uint256 tokenGasBaseFee,
        address sender
    ) private returns (uint256) {
        uint256 gasFee = Fee.calculateGasFee(nativeTokenPriceInTransferredToken, gasUsed, tokenGasBaseFee);
        gasFeeAccumulatedByToken[tokenAddress] += gasFee;
        gasFeeAccumulated[tokenAddress][sender] += gasFee;
        return gasFee;
    }

    function getTransferFee(address tokenAddress, uint256 amount) external view returns (uint256) {
        TokenInfo memory tokenInfo = tokenManager.getTokensInfo(tokenAddress);

        return
            Fee.getTransferFee(
                amount,
                getCurrentLiquidity(tokenAddress),
                liquidityProviders.getSuppliedLiquidityByToken(tokenAddress),
                tokenInfo.equilibriumFee,
                tokenInfo.maxFee,
                tokenManager.excessStateTransferFeePerc(tokenAddress)
            );
    }

    function checkHashStatus(
        address tokenAddress,
        uint256 amount,
        address payable receiver,
        bytes calldata depositHash
    ) public view returns (bytes32 hashSendTransaction, bool status) {
        hashSendTransaction = keccak256(abi.encode(tokenAddress, amount, receiver, keccak256(depositHash)));

        status = processedHash[hashSendTransaction];
    }

    function withdrawErc20GasFee(address tokenAddress) external onlyExecutor whenNotPaused nonReentrant {
        require(tokenAddress != NATIVE, "38");
        uint256 gasFeeAccumulatedByExecutor = _updateGasFeeAccumulated(tokenAddress, _msgSender());
        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(tokenAddress), _msgSender(), gasFeeAccumulatedByExecutor);
    }

    function withdrawNativeGasFee() external onlyExecutor whenNotPaused nonReentrant {
        uint256 gasFeeAccumulatedByExecutor = _updateGasFeeAccumulated(NATIVE, _msgSender());
        (bool success, ) = payable(_msgSender()).call{value: gasFeeAccumulatedByExecutor}("");
        require(success, "41");
    }

    function _updateGasFeeAccumulated(address tokenAddress, address executor)
        private
        returns (uint256 gasFeeAccumulatedByExecutor)
    {
        gasFeeAccumulatedByExecutor = gasFeeAccumulated[tokenAddress][executor];
        require(gasFeeAccumulatedByExecutor != 0, "39");
        gasFeeAccumulatedByToken[tokenAddress] = gasFeeAccumulatedByToken[tokenAddress] - gasFeeAccumulatedByExecutor;
        gasFeeAccumulated[tokenAddress][executor] = 0;
    }

    function transfer(
        address _tokenAddress,
        address receiver,
        uint256 _tokenAmount
    ) external whenNotPaused nonReentrant {
        require(receiver != address(0), "42");
        require(_msgSender() == address(liquidityProviders), "2");
        if (_tokenAddress == NATIVE) {
            require(address(this).balance >= _tokenAmount, "43");
            (bool success, ) = receiver.call{value: _tokenAmount}("");
            require(success, "44");
        } else {
            IERC20Upgradeable baseToken = IERC20Upgradeable(_tokenAddress);
            require(baseToken.balanceOf(address(this)) >= _tokenAmount, "45");
            SafeERC20Upgradeable.safeTransfer(baseToken, receiver, _tokenAmount);
        }
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

    receive() external payable {}
}
