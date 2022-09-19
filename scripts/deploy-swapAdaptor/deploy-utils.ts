import { run, ethers, upgrades } from "hardhat";
import {
  ERC20Token,
  SvgHelperBase,
  UniswapAdaptor
} from "../../typechain";
import { BigNumberish, providers } from "ethers";
import type { ITokenConfig } from "../types";


export interface swapAdaptorConfig {
  _swapRouter: string;
  nativeWrapAddress: string;
}

const deploy = async (deployConfig: swapAdaptorConfig) => {
  
    let swapAdaptorContract = await deploySwapAdaptor(
      deployConfig
    );
    console.log("swapAdaptor deployed to:", swapAdaptorContract.address);
    await verify(swapAdaptorContract, deployConfig);
};

const deploySwapAdaptor = async (
  deployConfig: swapAdaptorConfig
): Promise<UniswapAdaptor> => {
  const UniswapAdaptor = await ethers.getContractFactory("UniswapAdaptor");
  // const uniswapAdaptor = await ethers.getContractAt("UniswapAdaptor", "0x030e5095CDdFBE875067557016A909cAcF021B9B")
  console.log("Deploying UniswapAdaptor...");
  const uniswapAdaptor = await UniswapAdaptor.deploy(
    deployConfig._swapRouter,
    deployConfig.nativeWrapAddress
  );
  await uniswapAdaptor.deployed();
  console.log("uniswapAdaptor deployed to:", uniswapAdaptor.address);

  return uniswapAdaptor;
};

const verifyContract = async (address: string, constructorArguments: any[]) => {
  try {
    await run("verify:verify", {
      address,
      constructorArguments,
    });
  } catch (e) {
    console.log(`Failed to verify Contract ${address} `, e);
  }
};

const verify = async (
  swapAdaptorContract: UniswapAdaptor,
  config: swapAdaptorConfig
) => {
  console.log("Verifying Contracts...");
  console.log(swapAdaptorContract.address);
  console.log([config._swapRouter,config.nativeWrapAddress]);
  await verifyContract( swapAdaptorContract.address, [config._swapRouter,config.nativeWrapAddress]);
};

export {
  verify,
  deploy,
  verifyContract,
};
