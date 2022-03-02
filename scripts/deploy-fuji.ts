import { ethers } from "hardhat";
import { deploy } from "./helpers";

const config = {
  trustedForwarder: "0x6271Ca63D30507f2Dcbf99B52787032506D75BBF",
  bicoOwner: "0x817377683A2899A6879eA12AaC60e68032D3748F",
  pauser: "0x817377683A2899A6879eA12AaC60e68032D3748F",
  tokens: [
    {
      tokenAddress: "0xB4E0F6FEF81BdFea0856bB846789985c9CFf7e85",
      minCap: ethers.BigNumber.from(10).pow(18 + 2),
      maxCap: ethers.BigNumber.from(10).pow(18 + 4),
      toChainIds: [5, 80001],
      equilibriumFee: 10000000,
      maxFee: 200000000,
      maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(18 + 4),
      maxLiquidityCap: ethers.BigNumber.from(10).pow(18 + 5),
    },
    {
      tokenAddress: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      minCap: ethers.BigNumber.from(10).pow(18 - 2),
      maxCap: ethers.BigNumber.from(10).pow(18 + 2),
      toChainIds: [5, 80001],
      equilibriumFee: 10000000,
      maxFee: 200000000,
      maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(18 + 4),
      maxLiquidityCap: ethers.BigNumber.from(10).pow(18 + 5),
    },
  ],
};

deploy(config);
