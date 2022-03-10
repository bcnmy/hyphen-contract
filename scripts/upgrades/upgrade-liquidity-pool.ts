import { upgradeLiquidityPool } from "./upgrade";
import { verifyImplementation } from "../helpers";
import { ethers } from "hardhat";

(async () => {
  const proxy = "0xB726675394b2dDeE2C897ad31a62C7545Ad7C68D";
  const [signer] = await ethers.getSigners();
  console.log("Proxy: ", proxy, " Deployer: ", signer.address);
  console.log("Upgrading Proxy...");
  await upgradeLiquidityPool(proxy);
  await verifyImplementation(proxy);
})();
