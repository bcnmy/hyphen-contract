import { ethers } from "hardhat";
import Lock from "async-lock";
import { ERC20Token__factory, LiquidityProviders__factory, LPToken__factory } from "../../typechain";

import { getContractAddressesByChain } from "../upgrades/upgrade-all/upgrade-all";
import { BigNumber, providers } from "ethers";

(async () => {
  const [signer] = await ethers.getSigners();
  const chainId = await signer.getChainId();
  const contracts = await getContractAddressesByChain(process.env.PROD_API_URL!, chainId);

  const LpToken = LPToken__factory.connect(contracts.lpToken!, signer);
  const LiquidityProviders = LiquidityProviders__factory.connect(contracts.liquidityProviders!, signer);
  console.log(`ChainId: ${chainId}`);
  const totalSupply = await LpToken.totalSupply();
  console.log(`Total supply of LP Token: ${totalSupply.toString()}`);

  const promises = new Array(totalSupply.toNumber()).fill(1).map(async (_, i) => {
    await Promise.all([new Promise((resolve) => setTimeout(resolve, i * 150))]);
    const getData = async () => {
      const tokenId: number = i + 1;
      const metadata = await LpToken.tokenMetadata(tokenId);
      const value = await LiquidityProviders.sharesToTokenAmount(metadata.shares, metadata.token);
      return {
        tokenId,
        shares: metadata.shares,
        value: value,
        token: metadata.token,
      };
    };
    while (true) {
      try {
        const data = await getData();
        console.log(`TokenId: ${data.tokenId}, Token: ${data.token}, Shares: ${data.shares}, Value: ${data.value}`);
        return data;
      } catch (e) {
        console.log(e);
        await new Promise((resolve) => setTimeout(resolve, 500));
      }
    }
  });

  const getDecimals = async (token: string) => {
    if (token === "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE") {
      return 18;
    }
    return ERC20Token__factory.connect(token, signer).decimals();
  };

  const getSymbol = async (token: string) => {
    if (token === "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE") {
      return {
        1: "ETH",
        42161: "ETH",
        10: "ETH",
        137: "MATIC",
      }[chainId];
    }
    return ERC20Token__factory.connect(token, signer).symbol();
  };

  const transform = async (data: Record<string, BigNumber>) =>
    Object.fromEntries(
      await Promise.all(
        Object.entries(data).map(async ([key, value]) => [
          await getSymbol(key),
          ethers.utils.formatUnits(value, await getDecimals(key)),
        ])
      )
    );

  const tokenMetadata = await Promise.all(promises);
  const totalValue: Record<string, BigNumber> = {};
  for (const metadata of tokenMetadata) {
    if (!totalValue[metadata.token]) {
      totalValue[metadata.token] = BigNumber.from(0);
    }
    totalValue[metadata.token] = totalValue[metadata.token].add(metadata.value);
  }
  console.log(`Total value of LP Token: ${JSON.stringify(await transform(totalValue), null, 2)}`);

  const balances: Record<string, BigNumber> = {};
  for (const key in totalValue) {
    if (key === "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE") {
      balances[key] = await ethers.provider.getBalance(contracts.liquidityPool!);
    } else {
      balances[key] = await ERC20Token__factory.connect(key, signer).balanceOf(contracts.liquidityPool!);
    }
  }
  console.log(`Total balance of Tokens: ${JSON.stringify(await transform(balances), null, 2)}`);
})();
