let { BigNumber, ethers } = require("ethers");

// This amount should be get from exit transaction parameters including reward amount
let sentAmountDecimal = "100.034865722000000000";
let receivedAmountDecimal = "99.117062201702917424";
let differenceInAmount = sentAmountDecimal - receivedAmountDecimal;

// Set the transfer Fee percentrage deducted in this transaction. Can be fetched from db or exit transaction logs on explorer.
let transferFeePerc = 0.1
// let transferFee = sentAmountDecimal * transferFeePerc / 100;

let transferFee = 0.101002733058320060;
let expectedExecutorFeeInToken = differenceInAmount - transferFee;

console.log(expectedExecutorFeeInToken);
// If token is USDC, then what is the price of native token in USDC?
let nativeTokenPriceInToken = 1959.65;

let expectedExecutorFeeInNative = expectedExecutorFeeInToken / nativeTokenPriceInToken;
console.log(expectedExecutorFeeInNative)
let gasFeeDeductedOnChain =  ethers.utils.parseUnits(expectedExecutorFeeInNative.toFixed(6), "18");

// Set the gas fee used by the executor. Can be fetched from explorer
let actualGasFeeByExecutor = ethers.utils.parseUnits("0.000687140002198848", "18");
let gasUnaccountedFor = BigNumber.from(actualGasFeeByExecutor).sub(gasFeeDeductedOnChain);

// Final gas price of the trasnaction. Can be fetched from the explorer
let gasPrice = ethers.utils.parseUnits("2.500000008","9");

let transferOverhead = gasUnaccountedFor.div(gasPrice);

console.log(transferOverhead.toString());