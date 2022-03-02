import { ethers } from "hardhat";
import { EthereumETH__factory, EthereumUSDT__factory } from "../typechain";
import { deploy } from "./helpers";

const config = {
  trustedForwarder: "0xE041608922d06a4F26C0d4c27d8bCD01daf1f792",
  bicoOwner: "0x817377683A2899A6879eA12AaC60e68032D3748F",
  pauser: "0x817377683A2899A6879eA12AaC60e68032D3748F",
  tokens: [
    {
      tokenAddress: "0x64ef393b6846114bad71e2cb2ccc3e10736b5716",
      minCap: ethers.BigNumber.from(10).pow(18 + 2),
      maxCap: ethers.BigNumber.from(10).pow(18 + 4),
      toChainIds: [43113, 80001],
      equilibriumFee: 10000000,
      maxFee: 200000000,
      maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(18 + 4),
      maxLiquidityCap: ethers.BigNumber.from(10).pow(18 + 5),
      svgHelper: EthereumUSDT__factory,
    },
    {
      tokenAddress: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      minCap: ethers.BigNumber.from(10).pow(18 - 2),
      maxCap: ethers.BigNumber.from(10).pow(18 + 2),
      toChainIds: [43113, 80001],
      equilibriumFee: 10000000,
      maxFee: 200000000,
      maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(18 + 4),
      maxLiquidityCap: ethers.BigNumber.from(10).pow(18 + 5),
      svgHelper: EthereumETH__factory,
    },
  ],
};

deploy(config);
