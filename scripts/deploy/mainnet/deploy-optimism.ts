import { ethers } from "hardhat";
import { parseUnits } from "ethers/lib/utils";
import { deploy } from "../deploy-utils";
import type { IDeployConfig } from "../../types";

(async () => {
  const config: IDeployConfig = {
    trustedForwarder: "",
    bicoOwner: "0xd76b82204be75ab9610b04cf27c4f4a34291d5e6",
    pauser: "",
    tokens: [
      // USDC
      {
        tokenAddress: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
        minCap: parseUnits("", 6),
        maxCap: parseUnits("", 6),
        depositConfigs: [
          {
            chainId: 1,
            minCap: parseUnits("", 6),
            // Max Cap needs to be less than the maxTransfer Fee on destination chain id to cover for incentive amount
            maxCap: parseUnits("", 6),
          },
          {
            chainId: 137,
            minCap: parseUnits("", 6),
            // Max Cap needs to be less than the maxTransfer Fee on destination chain id to cover for incentive amount
            maxCap: parseUnits("", 6),
          },
          {
            chainId: 43114,
            minCap: parseUnits("", 6),
            // Max Cap needs to be less than the maxTransfer Fee on destination chain id to cover for incentive amount
            maxCap: parseUnits("", 6),
          },
          {
            chainId: 56,
            minCap: parseUnits("", 6),
            // Max Cap needs to be less than the maxTransfer Fee on destination chain id to cover for incentive amount
            maxCap: parseUnits("", 6),
          },
        ],
        equilibriumFee: ethers.utils.parseUnits("", 8),
        maxFee: ethers.utils.parseUnits("", 8),
        transferOverhead: 89491,
        maxWalletLiquidityCap: parseUnits("", 6),
        maxLiquidityCap: parseUnits("", 6),
        svgHelper: await ethers.getContractFactory("OPTUSDC"),
        decimals: 6,
        rewardTokenAddress: "",
        rewardRatePerSecond: parseUnits("", 18),
        excessStateTransferFeePer: parseUnits("", 8),
      },
      // BICO
      {
        tokenAddress: "",
        minCap: parseUnits("", 18),
        maxCap: parseUnits("", 18),
        depositConfigs: [
          {
            chainId: 1,
            minCap: parseUnits("", 18),
            // Max Cap needs to be less than the maxTransfer Fee on destination chain id to cover for incentive amount
            maxCap: parseUnits("", 18),
          },
          {
            chainId: 137,
            minCap: parseUnits("", 18),
            // Max Cap needs to be less than the maxTransfer Fee on destination chain id to cover for incentive amount
            maxCap: parseUnits("", 18),
          },
          {
            chainId: 43114,
            minCap: parseUnits("", 18),
            // Max Cap needs to be less than the maxTransfer Fee on destination chain id to cover for incentive amount
            maxCap: parseUnits("", 18),
          },
          {
            chainId: 56,
            minCap: parseUnits("", 18),
            // Max Cap needs to be less than the maxTransfer Fee on destination chain id to cover for incentive amount
            maxCap: parseUnits("", 18),
          },
        ],
        equilibriumFee: ethers.utils.parseUnits("", 8),
        maxFee: ethers.utils.parseUnits("", 8),
        transferOverhead: 85949,
        maxWalletLiquidityCap: parseUnits("", 18),
        maxLiquidityCap: parseUnits("", 18),
        svgHelper: await ethers.getContractFactory("OPTBICO"),
        decimals: 18,
        rewardTokenAddress: "",
        rewardRatePerSecond: parseUnits("", 18),
        excessStateTransferFeePer: parseUnits("", 8),
      },
      // ETH
      {
        tokenAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
        minCap: parseUnits("", 18),
        maxCap: parseUnits("", 18),
        depositConfigs: [
          {
            chainId: 1,
            minCap: parseUnits("", 18),
            // Max Cap needs to be less than the maxTransfer Fee on destination chain id to cover for incentive amount
            maxCap: parseUnits("", 18),
          },
          {
            chainId: 137,
            minCap: parseUnits("", 18),
            // Max Cap needs to be less than the maxTransfer Fee on destination chain id to cover for incentive amount
            maxCap: parseUnits("", 18),
          },
          {
            chainId: 56,
            minCap: parseUnits("", 18),
            // Max Cap needs to be less than the maxTransfer Fee on destination chain id to cover for incentive amount
            maxCap: parseUnits("", 18),
          },
          {
            chainId: 43114,
            minCap: parseUnits("", 18),
            // Max Cap needs to be less than the maxTransfer Fee on destination chain id to cover for incentive amount
            maxCap: parseUnits("", 18),
          },
        ],
        equilibriumFee: ethers.utils.parseUnits("", 8),
        maxFee: ethers.utils.parseUnits("", 8),
        transferOverhead: 0,
        maxWalletLiquidityCap: parseUnits("", 18),
        maxLiquidityCap: parseUnits("", 18),
        svgHelper: await ethers.getContractFactory("OPTETH"),
        decimals: 18,
        rewardTokenAddress: "",
        rewardRatePerSecond: parseUnits("", 18),
        excessStateTransferFeePer: parseUnits("", 8),
      },
    ],
  };
  await deploy(config);
})();
