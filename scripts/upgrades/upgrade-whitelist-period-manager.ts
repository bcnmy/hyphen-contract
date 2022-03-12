import { upgradeWhiteListPeriodManager } from "./upgrade";
import { verifyImplementation } from "../helpers";
import { ethers } from "hardhat";

(async () => {
  const proxy = "0x33d06Fe3d23E18B43c69C2a5C871e0AC7E706055";
  const [signer] = await ethers.getSigners();
  console.log("Proxy: ", proxy, " Deployer: ", signer.address);
  console.log("Upgrading Proxy...");
  await new Promise((resolve) => setTimeout(resolve, 5000));
  await upgradeWhiteListPeriodManager(proxy);
  await verifyImplementation(proxy);
})();
