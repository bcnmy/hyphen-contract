// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

enum SwapOperation {ExactInput, ExactOutput}

struct SwapRequest {
    address tokenAddress;
    uint256 percentage;
    uint256 amount;
    SwapOperation operation;
}
