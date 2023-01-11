import { ethers } from "hardhat";
import { LiquidityPool__factory, TokenManager__factory } from "../../typechain";
import { IContractAddresses } from "../types";
import { getContractAddresses, getSupportedTokens } from "../upgrades/upgrade-all/upgrade-all";

const ccmpGatewayAddress = "0x404172100D6A428F5Eae378650f4259CC803de7c";
const ccmpExecutorAddress = "0x8A97B3CD2451DA24a78D9827E4f3511A573cC7B3";

const tokenSymbols: Record<string, number> = {
  USDT: 1,
  USDC: 2,
  ETH: 3,
  BICO: 4,
  MATIC: 5,
};

export const configureLiquidityPool = async (
  contracts: Record<number, IContractAddresses>,
  chainId: number,
  debug: boolean = false
) => {
  const [signer] = await ethers.getSigners();
  debug && console.log(`Configuring liquidity pool on chainId ${chainId}...`);
  const liquidityPoolAddress = contracts[chainId].liquidityPool;
  if (!liquidityPoolAddress) {
    throw new Error("Liquidity pool address not found");
  }

  // Set LiquidityPool contract addresses
  const LiquidityPool = LiquidityPool__factory.connect(liquidityPoolAddress, signer);
  const LiquidityPoolList = Object.entries(contracts)
    .filter(([_chainId, _]) => chainId.toString() !== _chainId.toString())
    .filter(([_chainId, { liquidityPool }]) => _chainId && liquidityPool)
    .map(([_chainId, { liquidityPool }]) => [_chainId, liquidityPool]);
  debug && console.log(`LiquidityPool list: ${JSON.stringify(LiquidityPoolList, null, 2)}`);
  let { wait, hash } = await LiquidityPool.setLiquidityPoolAddress(
    LiquidityPoolList.map(([chainId, _]) => chainId!),
    LiquidityPoolList.map(([_, liquidityPool]) => liquidityPool!)
  );
  debug && console.log(`LiquidityPool set tx hash: ${hash}`);
  let { blockNumber, status } = await wait();
  if (status === 1) {
    debug && console.log(`LiquidityPool set tx successful at block ${blockNumber}`);
  } else {
    debug && console.error(`LiquidityPool set tx failed at block ${blockNumber}`);
  }

  // Set CCMP gateway and executor
  ({ wait, hash } = await LiquidityPool.setCCMPContracts(ccmpExecutorAddress, ccmpGatewayAddress));
  debug && console.log(`CCMP Gateway and Executor set tx hash: ${hash}`);
  ({ blockNumber, status } = await wait());
  if (status === 1) {
    debug && console.log(`CCMP Gateway and Executor set tx successful at block ${blockNumber}`);
  } else {
    debug && console.error(`CCMP Gateway and Executor set tx failed at block ${blockNumber}`);
  }
};

export const configureTokenManager = async (
  contracts: Record<number, IContractAddresses>,
  chainId: number,
  debug: boolean = false
) => {
  const [signer] = await ethers.getSigners();
  debug && console.log(`Configuring liquidity pool on chainId ${chainId}...`);
  const tokenManagerAddress = contracts[chainId].tokenManager;
  if (!tokenManagerAddress) {
    throw new Error("TokenManager address not found");
  }

  // Set Token symbols
  const TokenManager = TokenManager__factory.connect(tokenManagerAddress, signer);
  const supportedTokens = await getSupportedTokens(process.env.INTEGRATION_API_URL!, chainId);
  const tokenSymbolList = supportedTokens
    .map((token) => [token.address, tokenSymbols[token.symbol]])
    .filter(([_address, _symbol]) => _address && _symbol);
  debug && console.log(`Token list: ${JSON.stringify(tokenSymbolList, null, 2)}`);

  let { wait, hash } = await TokenManager.setTokenSymbol(
    tokenSymbolList.map(([address, _]) => (address as string)!),
    tokenSymbolList.map(([_, symbol]) => symbol!)
  );
  debug && console.log(`Token Symbol set tx hash: ${hash}`);
  let { blockNumber, status } = await wait();
  if (status === 1) {
    debug && console.log(`Token Symbol set tx successful at block ${blockNumber}`);
  } else {
    debug && console.error(`Token Symbol set tx failed at block ${blockNumber}`);
  }
};

if (require.main === module) {
  (async () => {
    const signer = (await ethers.getSigners())[0];
    console.log(`Signer address: ${signer.address}`);
    const chainId = await signer.getChainId();
    const contracts = await getContractAddresses(process.env.INTEGRATION_API_URL!);
    await configureLiquidityPool(contracts, chainId, true);
    await configureTokenManager(contracts, chainId, true);
  })();
}
