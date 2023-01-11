import { ethers } from "hardhat";
import { deploy, deployToken } from "../deploy-utils";

(async () => {

  /*** Enable only if needed */
  // const matic = await deployToken(
  //   "MATIC",
  //   "MATIC",
  //   18,
  //   ["0xF86B30C63E068dBB6bdDEa6fe76bf92F194Dc53c"],
  //   ethers.BigNumber.from(10).pow(20)
  // );

  const config = {
    bicoOwner: "0x501b9bf108456d7d67d4c3d1928802de58292c22",
    svgToken: [{
      tokenAddress: "", // pass token address here
      svgHelper: await ethers.getContractFactory("EthereumMATIC"),
      decimals: 18
    }] 
  };
  await deploy(config);
})();
