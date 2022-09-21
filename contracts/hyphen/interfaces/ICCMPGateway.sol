// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/CCMP.sol";

interface ICCMPGateway {
    function sendMessage(
        uint256 _destinationChainId,
        string calldata _adaptorName,
        CCMP.CCMPMessagePayload[] calldata _payloads,
        CCMP.GasFeePaymentArgs calldata _gasFeePaymentArgs,
        bytes calldata _routerArgs
    ) external payable returns (bool sent);
}
