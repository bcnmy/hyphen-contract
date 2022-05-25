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
    
    address public immutable WRAPPED_NATIVE_TOKEN_ADDRESS;
    ISwapRouter public immutable swapRouter;

    constructor(ISwapRouter _swapRouter, address wNativeTokenAddress) {
        WRAPPED_NATIVE_TOKEN_ADDRESS = wNativeTokenAddress;
        swapRouter = _swapRouter; // "0xE592427A0AEce92De3Edee1F18E0157C05861564"
    }

    /// @notice swapForFixedInput swaps a fixed amount of DAI for a maximum possible amount of WETH9
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its DAI for this function to succeed.
    /// @param amountInMaximum The exact amount of DAI that will be swapped for WETH9.
    /// @return amountOut The amount of WETH9 received.
    function swap(
        address inputTokenAddress,
        uint256 amountInMaximum,
        address receiver,
        SwapRequest[] calldata swapRequests
    ) override external returns (uint256 amountOut) {

        require(inputTokenAddress != NATIVE, "wrong function");
        uint256 swapArrayLength = swapRequests.length;

        // Only first element should have ExactOutput operation
        if(swapArrayLength > 1) {
            for( uint256 index=0; index < swapArrayLength; index++ ) {
                require(index == 0 || swapRequests[index].operation != SwapOperation.ExactOutput, "Invalid swap request");
            }   
        } else {
            require(swapRequests[0].operation == SwapOperation.ExactOutput, "Invalid swap request");
        }
        

        TransferHelper.safeTransferFrom(inputTokenAddress, msg.sender, address(this), amountInMaximum);
        TransferHelper.safeApprove(inputTokenAddress, address(swapRouter), amountInMaximum);
        
        uint256 amountIn = _fixedOutputSwap (
            inputTokenAddress,
            amountInMaximum,
            receiver,
            swapRequests[0]
        );

        if(amountIn < amountInMaximum){
            if(swapArrayLength > 1) {
                amountOut = _fixedInputSwap (
                    inputTokenAddress,
                    amountInMaximum,
                    receiver,
                    swapRequests[1]
                );
            } else {
                TransferHelper.safeApprove(inputTokenAddress, address(swapRouter), 0);
                TransferHelper.safeTransfer(inputTokenAddress, receiver, amountInMaximum - amountIn);
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
        amountOut = _fixedInputSwap(WRAPPED_NATIVE_TOKEN_ADDRESS, amountInMaximum, receiver, swapRequests[1]);
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