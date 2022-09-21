// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../hyphen/interfaces/ICCMPGateway.sol";

contract CCMPGatewayMock is ICCMPGateway {
    struct sendMessageArgs {
        uint256 destinationChainId;
        string adaptorName;
        CCMP.CCMPMessagePayload[] payloads;
        CCMP.GasFeePaymentArgs gasFeePaymentArgs;
        bytes routerArgs;
    }

    sendMessageArgs public lastCallArgs;

    bool shouldRevert = false;

    function sendMessage(
        uint256 _destinationChainId,
        string calldata _adaptorName,
        CCMP.CCMPMessagePayload[] calldata _payloads,
        CCMP.GasFeePaymentArgs calldata _gasFeePaymentArgs,
        bytes calldata _routerArgs
    ) external payable override returns (bool sent) {
        if (shouldRevert) {
            revert("Mocked revert");
        }

        sent = true;

        lastCallArgs.destinationChainId = _destinationChainId;
        lastCallArgs.adaptorName = _adaptorName;
        lastCallArgs.routerArgs = _routerArgs;
        lastCallArgs.gasFeePaymentArgs = _gasFeePaymentArgs;

        for (uint256 i = 0; i < _payloads.length; i++) {
            lastCallArgs.payloads.push(_payloads[i]);
        }
    }

    function lastCallPayload() external view returns (CCMP.CCMPMessagePayload[] memory) {
        return lastCallArgs.payloads;
    }

    function setRevertStatus(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }
}
