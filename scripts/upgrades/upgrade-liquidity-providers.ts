import { upgradeLiquidityProviders } from "./upgrade";
import { verifyImplementation } from "../helpers";
import { ethers } from "hardhat";

(async () => {
  const proxy = "0x17D42A784928a8168a871fA627bb1e4023D25C2A";
  const [signer] = await ethers.getSigners();
  console.log("Proxy: ", proxy, " Deployer: ", signer.address);
  console.log("Upgrading Proxy...");
  await new Promise((resolve) => setTimeout(resolve, 5000));
  await upgradeLiquidityProviders(proxy);
  await verifyImplementation(proxy);
})();
