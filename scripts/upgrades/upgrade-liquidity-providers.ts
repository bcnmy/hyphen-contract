import { upgradeLiquidityProviders } from "./upgrade";
import { verifyImplementation } from "../helpers";
import { ethers } from "hardhat";

(async () => {
  const proxy = "0xFD210117F5b9d98Eb710295E30FFF77dF2d80002";
  const [signer] = await ethers.getSigners();
  console.log("Proxy: ", proxy, " Deployer: ", signer.address);
  console.log("Upgrading Proxy..$.");
  await upgradeLiquidityProviders(proxy);
  await verifyImplementation(proxy);
})();
