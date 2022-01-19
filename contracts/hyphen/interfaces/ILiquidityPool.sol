// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILiquidityPool {
    function __LiquidityProviders_init(address _trustedForwarder) external;

    function addNativeLiquidity() external;

    function addSupportedToken(
        address tokenAddress,
        uint256 minCapLimit,
        uint256 maxCapLimit,
        uint256 equilibriumFee,
        uint256 maxFee
    ) external;

    function addTokenLiquidity(address tokenAddress, uint256 amount) external;

    function baseGas() external view returns (uint256);

    function changeFee(
        address tokenAddress,
        uint256 _equilibriumFee,
        uint256 _maxFee
    ) external;

    function changePauser(address newPauser) external;

    function checkHashStatus(
        address tokenAddress,
        uint256 amount,
        address receiver,
        bytes memory depositHash
    ) external view returns (bytes32 hashSendTransaction, bool status);

    function claimFee(uint256 _nftId, uint256 _shares) external;

    function depositConfig(uint256, address) external view returns (uint256 min, uint256 max);

    function depositErc20(
        uint256 toChainId,
        address tokenAddress,
        address receiver,
        uint256 amount,
        string memory tag
    ) external;

    function depositNative(
        address receiver,
        uint256 toChainId,
        string memory tag
    ) external;

    function gasFeeAccumulated(address, address) external view returns (uint256);

    function gasFeeAccumulatedByToken(address) external view returns (uint256);

    function getCurrentLiquidity(address tokenAddress) external view returns (uint256 currentLiquidity);

    function getEquilibriumFee(address tokenAddress) external view returns (uint256);

    function getExecutorManager() external view returns (address);

    function getFeeAccumulatedOnNft(uint256 _nftId) external view returns (uint256);

    function getLpSharePriceInTermsOfBaseToken(address _baseToken) external view returns (uint256);

    function getMaxFee(address tokenAddress) external view returns (uint256);

    function getRewardAmount(uint256 amount, address tokenAddress) external view returns (uint256 rewardAmount);

    function getSuppliedLiquidity(uint256 _nftId) external view returns (uint256);

    function getTransferFee(address tokenAddress, uint256 amount) external view returns (uint256 fee);

    function incentivePool(address) external view returns (uint256);

    function increaseNativeLiquidity(uint256 _nftId) external;

    function increaseTokenLiquidity(uint256 _nftId, uint256 _amount) external;

    function initialize(
        address _executorManagerAddress,
        address pauser,
        address _trustedForwarder
    ) external;

    function isPauser(address pauser) external view returns (bool);

    function isTokenSupported(address _token) external view returns (bool);

    function isTrustedForwarder(address forwarder) external view returns (bool);

    function lpToken() external view returns (address);

    function owner() external view returns (address);

    function paused() external view returns (bool);

    function processedHash(bytes32) external view returns (bool);

    function removePoolShare(uint256 _nftId, uint256 _shares) external;

    function removeSupportedToken(address tokenAddress) external;

    function renounceOwnership() external;

    function renouncePauser() external;

    function sendFundsToUser(
        address tokenAddress,
        uint256 amount,
        address receiver,
        bytes memory depositHash,
        uint256 tokenGasPrice,
        uint256 fromChainId
    ) external;

    function setBaseGas(uint128 gas) external;

    function setExecutorManager(address _executorManagerAddress) external;

    function setLpToken(address _lpToken) external;

    function setTokenTransferOverhead(address tokenAddress, uint256 gasOverhead) external;

    function setTrustedForwarder(address trustedForwarder) external;

    function tokenToTotalReserve(address) external view returns (uint256);

    function tokenToTotalSharesMinted(address) external view returns (uint256);

    function tokensInfo(address)
        external
        view
        returns (
            uint256 transferOverhead,
            bool supportedToken,
            uint256 minCap,
            uint256 maxCap,
            uint256 liquidity,
            uint256 equilibriumFee,
            uint256 maxFee
        );

    function transferConfig(address) external view returns (uint256 min, uint256 max);

    function transferOwnership(address newOwner) external;

    function updateTokenCap(
        address tokenAddress,
        uint256 minCapLimit,
        uint256 maxCapLimit
    ) external;

    function withdrawErc20GasFee(address tokenAddress) external;

    function withdrawNativeGasFee() external;
}
