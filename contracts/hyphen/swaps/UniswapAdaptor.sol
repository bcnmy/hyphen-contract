// SPDX-License-Identifier: MIT

/**
 *Submitted for verification at Etherscan.io on 2022-05-18
*/

pragma solidity 0.8.0;
import "../interfaces/ISwapAdaptor.sol";
import "../interfaces/ISwapRouter.sol";
import "../lib/TransferHelper.sol";

pragma abicoder v2;

contract UniswapAdaptor is ISwapAdaptor {

    ISwapRouter public immutable swapRouter;

    // For this example, we will set the pool fee to 0.3%.
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
        SwapRequest[] memory swapRequests
    ) override external returns (uint256 amountIn) {
        TransferHelper.safeTransferFrom(inputTokenAddress, msg.sender, address(this), amountInMaximum);

        TransferHelper.safeApprove(inputTokenAddress, address(swapRouter), amountInMaximum);

        uint256 index = 0;
        for(index = 0; index < swapRequests.length; index++) {

            ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
                tokenIn: inputTokenAddress,
                tokenOut: swapRequests[index].swapTokenAddress,
                fee: POOL_FEE,
                recipient: receiver,
                amountOut: swapRequests[index].swapAmount,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: 0
            });

            amountIn = swapRouter.exactOutputSingle(params);
        }

        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(inputTokenAddress, address(swapRouter), 0);
            TransferHelper.safeTransfer(inputTokenAddress, receiver, amountInMaximum - amountIn);
        }
    }

    /// @notice swapExactInputSingle swaps a fixed amount of DAI for a maximum possible amount of WETH9
    /// using the DAI/WETH9 0.3% pool by calling `exactInputSingle` in the swap router.
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its DAI for this function to succeed.
    /// @param amountIn The exact amount of DAI that will be swapped for WETH9.
    /// @return amountOut The amount of WETH9 received.
    // function swapExactInputSingle(uint256 amountIn) external returns (uint256 amountOut) {
    //     // msg.sender must approve this contract

    //     // Transfer the specified amount of DAI to this contract.
    //     TransferHelper.safeTransferFrom(DAI, msg.sender, address(this), amountIn);

    //     // Approve the router to spend DAI.
    //     TransferHelper.safeApprove(DAI, address(swapRouter), amountIn);

    //     // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
    //     // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
    //     ISwapRouter.ExactInputSingleParams memory params =
    //         ISwapRouter.ExactInputSingleParams({
    //             tokenIn: DAI,
    //             tokenOut: WETH9,
    //             fee: poolFee,
    //             recipient: msg.sender,
    //             deadline: block.timestamp,
    //             amountIn: amountIn,
    //             amountOutMinimum: 0,
    //             sqrtPriceLimitX96: 0
    //         });

    //     // The call to `exactInputSingle` executes the swap.
    //     amountOut = swapRouter.exactInputSingle(params);
    // }
}