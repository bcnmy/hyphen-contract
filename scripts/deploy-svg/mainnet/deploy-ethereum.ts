import { ethers } from "hardhat";
import { deploy, deployToken } from "../deploy-utils";

(async () => {

  const config = {
    bicoOwner: "0xd76b82204be75ab9610b04cf27c4f4a34291d5e6",
    svgToken: [{
      tokenAddress: "0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0", // pass token address here
      svgHelper: await ethers.getContractFactory("EthereumMATIC"),
      decimals: 18
    }] 
  };
  await deploy(config);
})();
