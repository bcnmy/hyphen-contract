import { ethers } from "hardhat";
import { BigNumberish } from "ethers";

const addTokenSupport = async (
  tokenManagerAddress: string,
  tokenAddress: string,
  minCap: BigNumberish,
  maxCap: BigNumberish,
  equilibriumFee: BigNumberish,
  maxFee: BigNumberish,
  toChainIds: number[]
) => {
  const [signer] = await ethers.getSigners();
  const tokenManager = await ethers.getContractAt("TokenManager", tokenManagerAddress, signer);
  await (await tokenManager.addSupportedToken(tokenAddress, minCap, maxCap, equilibriumFee, maxFee)).wait();
  await (
    await tokenManager.setDepositConfig(
      toChainIds,
      new Array(toChainIds.length).fill(tokenAddress),
      new Array(toChainIds.length).fill({ min: minCap, max: maxCap })
    )
  ).wait();
  console.log("Added token support for", tokenAddress);
};

export { addTokenSupport };
