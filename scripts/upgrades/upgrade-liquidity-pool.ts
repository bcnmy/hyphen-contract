import { upgradeLiquidityPool } from "./upgrade";
import { verifyImplementation } from "../helpers";
import { ethers } from "hardhat";

(async () => {
  const proxy = "0x8033Bd14c4C114C14C910fe05Ff13DB4C481a85D";
  const [signer] = await ethers.getSigners();
  console.log("Proxy: ", proxy, " Deployer: ", signer.address);
  console.log("Upgrading Proxy...");
  await new Promise((resolve) => setTimeout(resolve, 5000));
  await upgradeLiquidityPool(proxy);
  await verifyImplementation(proxy);
})();
