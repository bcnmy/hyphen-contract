// SPDX-License-Identifier: MIT

/**
 *Submitted for verification at Etherscan.io on 2022-05-18
*/

pragma solidity 0.8.0;
import "../interfaces/ISwapAdaptor.sol";
import "../interfaces/ISwapRouter.sol";
import "../lib/TransferHelper.sol";

contract UniswapAdaptor is ISwapAdaptor {

    ISwapRouter public immutable swapRouter;
    uint24 public constant POOL_FEE = 3000;

    constructor(ISwapRouter _swapRouter) {
        swapRouter = _swapRouter; // "0xE592427A0AEce92De3Edee1F18E0157C05861564"
    }

    /// @notice swapExactOutputSingle swaps a minimum possible amount of DAI for a fixed amount of WETH.
    /// @dev The calling address must approve this contract to spend its DAI for this function to succeed. As the amount of input DAI is variable,
    /// the calling address will need to approve for a slightly higher amount, anticipating some variance.
    /// @param amountInMaximum The amount of DAI we are willing to spend to receive the specified amount of WETH9.
    /// @return amountIn The amount of DAI actually spent in the swap.
    function swap(
        address inputTokenAddress,
        uint256 amountInMaximum,
        address receiver,
        SwapRequest[] calldata swapRequests
    ) override external returns (uint256 amountIn) {
        TransferHelper.safeTransferFrom(inputTokenAddress, msg.sender, address(this), amountInMaximum);
        TransferHelper.safeApprove(inputTokenAddress, address(swapRouter), amountInMaximum);
        
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: inputTokenAddress,
            tokenOut: swapRequests[0].tokenAddress,
            fee: POOL_FEE,
            recipient: receiver,
            amountOut: swapRequests[0].amount,
            amountInMaximum: amountInMaximum,
            sqrtPriceLimitX96: 0
        });

        amountIn = swapRouter.exactOutputSingle(params);
        
        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(inputTokenAddress, address(swapRouter), 0);
            TransferHelper.safeTransfer(inputTokenAddress, receiver, amountInMaximum - amountIn);
        }
    }
}