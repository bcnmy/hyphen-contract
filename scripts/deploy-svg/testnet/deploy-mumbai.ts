import { ethers } from "hardhat";
import { deploy, deployToken } from "../deploy-utils";

(async () => {
  const config = {
    bicoOwner: "0x501b9bf108456d7d67d4c3d1928802de58292c22",
    svgToken: [{
      tokenAddress: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      svgHelper: await ethers.getContractFactory("PolygonMATIC"),
      decimals: 18
    }]
  };
  await deploy(config);
})();
