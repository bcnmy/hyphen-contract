import { ethers } from "hardhat";
import { deploy } from "./helpers";

const addresses = {
  trustedForwarder: "0x9399BB24DBB5C4b782C70c2969F58716Ebbd6a3b",
  bicoOwner: "0x817377683A2899A6879eA12AaC60e68032D3748F",
  pauser: "0x817377683A2899A6879eA12AaC60e68032D3748F",
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
    },
    {
      tokenAddress: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      minCap: ethers.BigNumber.from(10).pow(18 - 2),
      maxCap: ethers.BigNumber.from(10).pow(18 + 2),
      toChainIds: [5, 43113],
      equilibriumFee: 10000000,
      maxFee: 200000000,
      maxWalletLiquidityCap: ethers.BigNumber.from(10).pow(18 + 4),
      maxLiquidityCap: ethers.BigNumber.from(10).pow(18 + 5),
    },
  ],
};

deploy(addresses);
