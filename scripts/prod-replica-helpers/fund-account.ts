import { ethers } from "hardhat";
import { ERC20Token__factory } from "../../typechain";
import { getContractAddresses, getSupportedTokenAddresses } from "../upgrades/upgrade-all/upgrade-all";
import { impersonateAndExecute, sendTransaction, setNativeBalance } from "./utils";

const fundErc20FromLiquidityPool = async (liquidityPoolAddress: string, tokenAddress: string, to: string) => {
  await impersonateAndExecute(liquidityPoolAddress, async (signer) => {
    const { chainId } = await ethers.provider.getNetwork();
    const token = ERC20Token__factory.connect(tokenAddress, signer);
    const liquidity = await token.balanceOf(signer.address);
    const amount = liquidity.div(1000);
    console.log(`Funding ${to} with ${amount} ${tokenAddress} from Liquidity Pool on chain ${chainId}...`);
    await sendTransaction(token.transfer(to, amount), "Funding ERC20 Token");
    const finalBalance = await token.balanceOf(to);
    console.log(`${to} has ${finalBalance} ${tokenAddress} on chain ${chainId}`);
  });
};

(async () => {
  await setNativeBalance(process.env.TRANSACTOR_ADDRESS!, ethers.utils.parseEther("1000"));
  const { chainId } = await ethers.provider.getNetwork();
  const { liquidityPool } = await getContractAddresses(process.env.PROD_API_URL!, chainId);
  const liquidityPoolNativeBalance = await ethers.provider.getBalance(liquidityPool);
  if (liquidityPoolNativeBalance.eq(0)) {
    await setNativeBalance(liquidityPool, ethers.utils.parseEther("1000"));
  }
  const supportedTokenAddresses = (await getSupportedTokenAddresses(process.env.PROD_API_URL!, chainId)).filter(
    (x) => x.toLowerCase() !== "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  );
  console.log(`Supported ERC20 Tokens on chain ${chainId}: ${JSON.stringify(supportedTokenAddresses, null, 2)}`);
  for (const token of supportedTokenAddresses) {
    await fundErc20FromLiquidityPool(liquidityPool, token, process.env.TRANSACTOR_ADDRESS!);
  }
})();
