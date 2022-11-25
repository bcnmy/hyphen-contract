// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ICCMPGateway.sol";

struct DepositAndCallArgs {
    uint256 toChainId;
    address tokenAddress; // Can be Native
    address receiver;
    uint256 amount;
    string tag;
    ICCMPGateway.CCMPMessagePayload[] payloads;
    ICCMPGateway.GasFeePaymentArgs gasFeePaymentArgs;
    string adaptorName;
    bytes routerArgs;
    bytes[] hyphenArgs;
}

struct SendFundsToUserFromCCMPArgs {
    uint256 tokenSymbol;
    uint256 sourceChainAmount;
    uint256 sourceChainDecimals;
    address payable receiver;
    bytes[] hyphenArgs;
}
