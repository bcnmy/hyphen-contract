let { BigNumber, ethers } = require("ethers");

// This amount should be get from exit transaction parameters including reward amount
let sentAmountDecimal = "1000.044162380608210561";
let receivedAmountDecimal = "999.263696621337790679";
let differenceInAmount = sentAmountDecimal - receivedAmountDecimal;

// Set the transfer Fee percentrage deducted in this transaction. Can be fetched from db or exit transaction logs on explorer.
let transferFeePerc = 0.045;
// let transferFee = sentAmountDecimal * transferFeePerc / 100;

let transferFee = 0.779819937184043763;
let expectedExecutorFeeInToken = differenceInAmount - transferFee;

console.log(expectedExecutorFeeInToken);
// If token is USDC, then what is the price of native token in USDC?
let nativeTokenPriceInToken = 0.5049751243781094527363184079;

let expectedExecutorFeeInNative = expectedExecutorFeeInToken / nativeTokenPriceInToken;
console.log(expectedExecutorFeeInNative);
let gasFeeDeductedOnChain = ethers.utils.parseUnits(expectedExecutorFeeInNative.toFixed(6), "18");

// Set the gas fee used by the executor. Can be fetched from explorer
let actualGasFeeByExecutor = ethers.utils.parseUnits("0.0014251622211", "18");
let gasUnaccountedFor = BigNumber.from(actualGasFeeByExecutor).sub(gasFeeDeductedOnChain);

// Final gas price of the trasnaction. Can be fetched from the explorer
let gasPrice = ethers.utils.parseUnits("5.9043", "9");

let transferOverhead = gasUnaccountedFor.div(gasPrice);

console.log(transferOverhead.toString());
