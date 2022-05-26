pragma solidity ^0.8.0;
import "../interfaces/ISwapAdaptor.sol";
import "../interfaces/ISwapRouter.sol";
import "../lib/TransferHelper.sol";

contract MockSwapRouter {
    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn){
        return params.amountOut;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut){
        return params.amountIn;
    }
}
