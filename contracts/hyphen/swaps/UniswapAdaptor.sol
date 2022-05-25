// SPDX-License-Identifier: MIT

/**
 *Submitted for verification at Etherscan.io on 2022-05-18
*/

pragma solidity 0.8.0;
import "../interfaces/ISwapAdaptor.sol";
import "../interfaces/ISwapRouter.sol";
import "../lib/TransferHelper.sol";

contract UniswapAdaptor is ISwapAdaptor {

    uint24 public constant POOL_FEE = 3000;
    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    
    address public immutable WRAPPER_ADDRESS;
    ISwapRouter public immutable swapRouter;

    constructor(ISwapRouter _swapRouter, address wrapperAddress) {
        WRAPPER_ADDRESS = wrapperAddress;
        swapRouter = _swapRouter; // "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45"
    }

    /// @notice swapForFixedInput swaps a fixed amount of DAI for a maximum possible amount of WETH9
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its DAI for this function to succeed.
    /// @param inputTokenAddress Erc20 token address.
    /// @param amountInMaximum The exact amount of Erc20 that will be swapped for desired token.
    /// @param receiver address where all tokens will be sent.
    /// @return amountOut The amount of Swapped token received.
    function swap(
        address inputTokenAddress,
        uint256 amountInMaximum,
        address receiver,
        SwapRequest[] calldata swapRequests
    ) override external returns (uint256 amountOut) {

        require(inputTokenAddress != NATIVE, "wrong function");
        uint256 swapArrayLength = swapRequests.length;

        require(swapArrayLength <= 2, "too many swap requests");
        require(swapArrayLength == 1 || swapRequests[1].operation == SwapOperation.ExactInput, "Invalid swap operation");

        TransferHelper.safeTransferFrom(inputTokenAddress, msg.sender, address(this), amountInMaximum);
        TransferHelper.safeApprove(inputTokenAddress, address(swapRouter), amountInMaximum);
        
        uint256 amountIn;
        if(swapArrayLength == 1) {
            if (swapRequests[0].operation == SwapOperation.ExactOutput ){
                amountIn = _fixedOutputSwap (
                    inputTokenAddress,
                    amountInMaximum,
                    receiver,
                    swapRequests[0]
                );
                if(amountIn < amountInMaximum) {
                    TransferHelper.safeApprove(inputTokenAddress, address(swapRouter), 0);
                    TransferHelper.safeTransfer(inputTokenAddress, receiver, amountInMaximum - amountIn);
                }
            } else {
                _fixedInputSwap (
                    inputTokenAddress,
                    amountInMaximum,
                    receiver,
                    swapRequests[0]
                );
            }
        } else {
            amountIn = _fixedOutputSwap (
                inputTokenAddress,
                amountInMaximum,
                receiver,
                swapRequests[0]
            );
            if(amountIn < amountInMaximum){
                amountOut = _fixedInputSwap (
                    inputTokenAddress,
                    amountInMaximum - amountIn,
                    receiver,
                    swapRequests[1]
                );
            } 
        }
    }

    /// @notice swapNative swaps a fixed amount of WETH for a maximum possible amount of Swap tokens
    /// @dev The calling address must send Native token to this contract to spend at least `amountIn` worth of its WETH for this function to succeed.
    /// @param amountInMaximum The exact amount of WETH that will be swapped for Desired token.
    /// @param receiver Address to with tokens will be sent after swap.
    /// @return amountOut The amount of Desired token received.
    function swapNative(
        uint256 amountInMaximum,
        address receiver,
        SwapRequest[] calldata swapRequests
    ) override external returns (uint256 amountOut) {
        require(swapRequests.length == 1 , "only 1 swap request allowed");
        amountOut = _fixedInputSwap(WRAPPER_ADDRESS, amountInMaximum, receiver, swapRequests[0]);
    }

    function _fixedOutputSwap(
        address inputTokenAddress,
        uint256 amountInMaximum,
        address receiver,
        SwapRequest calldata swapRequests
    ) internal returns (uint256 amountIn) {
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: inputTokenAddress,
            tokenOut: swapRequests.tokenAddress,
            fee: POOL_FEE,
            recipient: receiver,
            amountOut: swapRequests.amount,
            amountInMaximum: amountInMaximum,
            sqrtPriceLimitX96: 0
        });

        amountIn = swapRouter.exactOutputSingle(params);
    }

     function _fixedInputSwap(
        address inputTokenAddress,
        uint256 amount,
        address receiver,
        SwapRequest calldata swapRequests
    ) internal returns (uint256 amountOut) {
         ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: inputTokenAddress,
                tokenOut: swapRequests.tokenAddress,
                fee: POOL_FEE,
                recipient: receiver,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        amountOut = swapRouter.exactInputSingle(params);
    }
}