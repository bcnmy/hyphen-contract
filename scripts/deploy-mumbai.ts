import { ethers } from "hardhat";
import { deploy } from "./helpers";

(async () => {
  const config = {
    trustedForwarder: "0x9399BB24DBB5C4b782C70c2969F58716Ebbd6a3b",
    bicoOwner: "0x46b65ae065341D034fEA45D76c6fA936EAfBfdeb",
    pauser: "0x46b65ae065341D034fEA45D76c6fA936EAfBfdeb",
    tokens: [
      {
        tokenAddress: "0xeabc4b91d9375796aa4f69cc764a4ab509080a58",
        minCap: ethers.BigNumber.from(10).pow(18 + 2),
        maxCap: ethers.BigNumber.from(10).pow(18 + 4),
        toChainIds: [5, 43113],
        equilibriumFee: 10000000,
        maxFee: 200000000,
        maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(18 + 4),
        maxLiquidityCap: ethers.BigNumber.from(10).pow(18 + 5),
        svgHelper: await ethers.getContractFactory("PolygonUSDT"),
        decimals: 18,
      },
      {
        tokenAddress: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
        minCap: ethers.BigNumber.from(10).pow(6 + 2),
        maxCap: ethers.BigNumber.from(10).pow(6 + 4),
        toChainIds: [5, 43113],
        equilibriumFee: 100,
        maxFee: 2000,
        maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(6 + 4),
        maxLiquidityCap: ethers.BigNumber.from(10).pow(6 + 6),
        svgHelper: await ethers.getContractFactory("PolygonUSDC"),
        decimals: 6,
      },
      {
        tokenAddress: "0x91c89A94567980f0e9723b487b0beD586eE96aa7",
        minCap: ethers.BigNumber.from(10).pow(18 + 2),
        maxCap: ethers.BigNumber.from(10).pow(18 + 4),
        toChainIds: [5, 43113],
        equilibriumFee: 10000000,
        maxFee: 200000000,
        maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(18 + 4),
        maxLiquidityCap: ethers.BigNumber.from(10).pow(18 + 6),
        svgHelper: await ethers.getContractFactory("PolygonBICO"),
        decimals: 18,
      },
      {
        tokenAddress: "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619",
        minCap: ethers.BigNumber.from(10).pow(18 - 2),
        maxCap: ethers.BigNumber.from(10).pow(18 + 2),
        toChainIds: [5, 43113],
        equilibriumFee: 10000000,
        maxFee: 200000000,
        maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(18 + 4),
        maxLiquidityCap: ethers.BigNumber.from(10).pow(18 + 5),
        svgHelper: await ethers.getContractFactory("PolygonETH"),
        decimals: 18,
      },
    ],
  };
  await deploy(config);
})();
