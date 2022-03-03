import { ethers } from "hardhat";
import { deploy } from "./helpers";

(async () => {
  const config = {
    trustedForwarder: "0xE041608922d06a4F26C0d4c27d8bCD01daf1f792",
    bicoOwner: "0x46b65ae065341D034fEA45D76c6fA936EAfBfdeb",
    pauser: "0x46b65ae065341D034fEA45D76c6fA936EAfBfdeb",
    tokens: [
      {
        tokenAddress: "0x64ef393b6846114bad71e2cb2ccc3e10736b5716",
        minCap: ethers.BigNumber.from(10).pow(18 + 2),
        maxCap: ethers.BigNumber.from(10).pow(18 + 4),
        toChainIds: [43113, 80001],
        equilibriumFee: 10000000,
        maxFee: 200000000,
        maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(18 + 4),
        maxLiquidityCap: ethers.BigNumber.from(10).pow(18 + 6),
        svgHelper: await ethers.getContractFactory("EthereumUSDT"),
        decimals: 18,
      },
      {
        tokenAddress: "0xb5B640E6414b6DeF4FC9B3C1EeF373925effeCcF",
        minCap: ethers.BigNumber.from(10).pow(6 + 2),
        maxCap: ethers.BigNumber.from(10).pow(6 + 4),
        toChainIds: [43113, 80001],
        equilibriumFee: 100,
        maxFee: 2000,
        maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(6 + 4),
        maxLiquidityCap: ethers.BigNumber.from(10).pow(6 + 6),
        svgHelper: await ethers.getContractFactory("EthereumUSDC"),
        decimals: 6,
      },
      {
        tokenAddress: "0xDdc47b0cA071682e8dc373391aCA18dA0Fe28699",
        minCap: ethers.BigNumber.from(10).pow(18 + 2),
        maxCap: ethers.BigNumber.from(10).pow(18 + 4),
        toChainIds: [43113, 80001],
        equilibriumFee: 10000000,
        maxFee: 200000000,
        maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(18 + 4),
        maxLiquidityCap: ethers.BigNumber.from(10).pow(18 + 6),
        svgHelper: await ethers.getContractFactory("EthereumBICO"),
        decimals: 18,
      },
      {
        tokenAddress: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
        minCap: ethers.BigNumber.from(10).pow(18 - 2),
        maxCap: ethers.BigNumber.from(10).pow(18 + 2),
        toChainIds: [43113, 80001],
        equilibriumFee: 10000000,
        maxFee: 200000000,
        maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(18 + 4),
        maxLiquidityCap: ethers.BigNumber.from(10).pow(18 + 6),
        svgHelper: await ethers.getContractFactory("EthereumETH"),
        decimals: 18,
      },
    ],
  };
  await deploy(config);
})();
