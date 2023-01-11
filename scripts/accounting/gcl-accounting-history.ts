import { ethers } from "hardhat";
import {
  ERC20Token__factory,
  LiquidityPool__factory,
  LiquidityProviders__factory,
  LPToken__factory,
} from "../../typechain";
import path, { resolve } from "path";

import { getContractAddressesByChain } from "../upgrades/upgrade-all/upgrade-all";
import { formatUnits } from "ethers/lib/utils";
import { createObjectCsvWriter } from "csv-writer";

const token = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

(async () => {
  const [signer] = await ethers.getSigners();
  const chainId = await signer.getChainId();
  const contracts = await getContractAddressesByChain(process.env.PROD_API_URL!, chainId);

  const LpToken = LPToken__factory.connect(contracts.lpToken!, signer);
  const LiquidityProviders = LiquidityProviders__factory.connect(contracts.liquidityProviders!, signer);
  const LiquidityPool = LiquidityPool__factory.connect(contracts.liquidityPool!, signer);
  console.log(`ChainId: ${chainId}`);

  // const startBlock = { 1: 14375018 }[chainId];
  // if (!startBlock) {
  //   throw new Error("No start block for this chain");
  // }
  // const endingBlock = await ethers.provider.getBlockNumber();

  const startBlock = 15716092;
  const endingBlock = 15716279;

  // const samples = 10000;
  const samples = endingBlock - startBlock + 1;
  const blocks = new Array(samples)
    .fill(1)
    .map((_, i) => startBlock + Math.floor((endingBlock - startBlock) * (i / samples)));

  const getDecimals = async (token: string) => {
    if (token === "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE") {
      return 18;
    }
    return ERC20Token__factory.connect(token, signer).decimals();
  };

  const getTokenBalane = async (account: string, token: string, block: number) => {
    if (token.toLowerCase() === "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE".toLowerCase()) {
      return await ethers.provider.getBalance(account, block);
    } else {
      return await ERC20Token__factory.connect(token, signer).balanceOf(account, {
        blockTag: block,
      });
    }
  };

  const getBlockData = async (block: number) => {
    try {
      const poolcl = await LiquidityPool.getCurrentLiquidity(token, {
        blockTag: block,
      });
      const poolBalance = await getTokenBalane(contracts.liquidityPool!, token, block);
      const totalLpFee = await LiquidityProviders.totalLPFees(token, { blockTag: block });
      const gasFeeAccumulatedByToken = await LiquidityPool.gasFeeAccumulatedByToken(token, { blockTag: block });
      const incentivePool = await LiquidityPool.incentivePool(token, { blockTag: block });
      const decimals = await getDecimals(token);
      return {
        block,
        poolcl: formatUnits(poolcl, decimals).toString(),
        totalLpFee: formatUnits(totalLpFee, decimals).toString(),
        gasFeeAccumulatedByToken: formatUnits(gasFeeAccumulatedByToken, decimals).toString(),
        incentivePool: formatUnits(incentivePool, decimals).toString(),
        poolBalance: formatUnits(poolBalance, decimals).toString(),
      };
    } catch (e) {
      console.log(block, e);
      return null;
    }
  };

  const blockdata = (
    await Promise.all(
      blocks.map(async (block, i) => {
        await new Promise((resolve) => setTimeout(resolve, 300 * i));
        const data = await getBlockData(block);
        if (!data) return null;
        console.log(
          `${i}/${blocks.length} ${data.block} ${data.poolcl} ${data.totalLpFee} ${data.gasFeeAccumulatedByToken} ${data.incentivePool} ${data.poolBalance}`
        );
        return data;
      })
    )
  ).filter((x) => x);

  await createObjectCsvWriter({
    path: resolve(__dirname, `${chainId}-accounting-history.csv`),
    header: [
      { id: "block", title: "Block Number" },
      { id: "poolcl", title: "Pool Current Liquidity" },
      { id: "totalLpFee", title: "Total LP Fee" },
      { id: "gasFeeAccumulatedByToken", title: "Gas Fee Accumulated By Token" },
      { id: "incentivePool", title: "Incentive Pool" },
      { id: "poolBalance", title: "Pool Balance" },
    ],
  }).writeRecords(blockdata as any);
})();
