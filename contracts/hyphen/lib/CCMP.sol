// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/ICCMPGateway.sol";

library CCMP {
    struct CCMPMessagePayload {
        address to;
        bytes _calldata;
    }

    struct GasFeePaymentArgs {
        address feeTokenAddress;
        uint256 feeAmount;
        address relayer;
    }

    function ccmpMsgOrigin(address _ccmpGateway)
        external
        view
        returns (address sourceChainSender, uint256 sourceChainId)
    {
        require(msg.sender == _ccmpGateway, "46");

        /*
         * Calldata Map:
         * |-------?? bytes--------|------32 bytes-------|---------20 bytes -------|
         * |---Original Calldata---|---Source Chain Id---|---Source Chain Sender---|
         */
        assembly {
            sourceChainSender := shr(96, calldataload(sub(calldatasize(), 20)))
            sourceChainId := calldataload(sub(calldatasize(), 52))
        }
    }

    

}
