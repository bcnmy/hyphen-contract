import { upgradeLiquidityFarming } from "./upgrade";
import { verifyImplementation } from "../helpers";
import { ethers } from "hardhat";

(async () => {
  const proxy = "0xBFAE64B3f3BBC05D466Adb5D5FAd8f520E61FAF8";
  const [signer] = await ethers.getSigners();
  console.log("Proxy: ", proxy, " Deployer: ", signer.address);
  console.log("Upgrading Proxy...");
  await new Promise((resolve) => setTimeout(resolve, 5000));
  await upgradeLiquidityFarming(proxy);
  await verifyImplementation(proxy);
})();
