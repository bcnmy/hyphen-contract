pragma solidity ^0.8.0;
import "../interfaces/ISwapAdaptor.sol";
import "../interfaces/ISwapRouter.sol";
import "../lib/TransferHelper.sol";
import "hardhat/console.sol";

contract MockAdaptor is ISwapAdaptor {
    ISwapRouter public immutable swapRouter;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant POOL_FEE = 3000;
    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(ISwapRouter _swapRouter) {
        swapRouter = _swapRouter; // "0xE592427A0AEce92De3Edee1F18E0157C05861564"
    }

    function swap(
        address inputTokenAddress,
        uint256 amountInMaximum,
        address receiver,
        SwapRequest[] memory swapRequests
    ) external override returns (uint256 amountIn) {
    }

    function swapNative(
        uint256 amountInMaximum,
        address receiver,
        SwapRequest[] calldata swapRequests
    ) override external returns (uint256 amountOut) {
    }
}