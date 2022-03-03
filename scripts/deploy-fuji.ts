import { ethers } from "hardhat";
import { deploy } from "./helpers";

(async () => {
  const config = {
    trustedForwarder: "0x6271Ca63D30507f2Dcbf99B52787032506D75BBF",
    bicoOwner: "0x46b65ae065341D034fEA45D76c6fA936EAfBfdeb",
    pauser: "0x46b65ae065341D034fEA45D76c6fA936EAfBfdeb",
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
        svgHelper: await ethers.getContractFactory("AvalancheUSDT"),
        decimals: 18,
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
        svgHelper: await ethers.getContractFactory("AvalancheETH"),
        decimals: 18,
      },
    ],
  };
  await deploy(config);
})();
