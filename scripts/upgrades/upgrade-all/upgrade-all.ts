import { ethers } from "hardhat";
import axios from "axios";
import {
  upgradeLPToken,
  upgradeLiquidityFarmingV2,
  upgradeLiquidityPool,
  upgradeLiquidityProviders,
  upgradeTokenManager,
  upgradeWhiteListPeriodManager,
} from "../upgrade";
import { verifyImplementation } from "../../deploy/deploy-utils";

import type { IContractAddresses } from "../../types";

export const getContractAddresses = async (baseUrl: string, chainId: number): Promise<IContractAddresses> => {
  const response = (await axios.get(`${baseUrl}/api/v1/configuration/networks`)).data.message as any[];
  const chain = response.filter((c) => c.chainId === chainId)[0];
  return chain.contracts.hyphen;
};

export const upgradeAllContracts = async (addresses: IContractAddresses) => {
  await upgradeAndVerify(addresses.lpToken, upgradeLPToken);
  await upgradeAndVerify(addresses.liquidityPool, upgradeLiquidityPool);
  await upgradeAndVerify(addresses.liquidityProviders, upgradeLiquidityProviders);
  await upgradeAndVerify(addresses.tokenManager, upgradeTokenManager);
  await upgradeAndVerify(addresses.liquidityFarming, upgradeLiquidityFarmingV2);
  await upgradeAndVerify(addresses.whitelistPeriodManager, upgradeWhiteListPeriodManager);
};

const upgradeAndVerify = async (proxy: string, upgrader: (address: string) => Promise<void>) => {
  try {
    const [signer] = await ethers.getSigners();
    console.log("Proxy: ", proxy, " Deployer: ", signer.address);
    console.log("Upgrading Proxy...");
    await upgrader(proxy);
    await new Promise<void>((resolve) => {
      setTimeout(resolve, 5000);
    });
    await verifyImplementation(proxy);
  } catch (e) {
    console.error(`Error upgrading ${proxy}: ${e}`);
  }
};
