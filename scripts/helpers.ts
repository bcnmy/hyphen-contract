import { run, ethers, upgrades } from "hardhat";
import {
  LiquidityPool,
  LPToken,
  WhitelistPeriodManager,
  LiquidityProviders,
  TokenManager,
  ExecutorManager,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";
import type { BigNumberish } from "ethers";

const LPTokenName = "BICO Liquidity Token";
const LPTokenSymbol = "BICOLP";

interface IAddTokenParameters {
  tokenAddress: string;
  minCap: BigNumberish;
  maxCap: BigNumberish;
  toChainIds: number[];
  equilibriumFee: BigNumberish;
  maxFee: BigNumberish;
  maxWalletLiquidityCap: BigNumberish;
  maxLiquidityCap: BigNumberish;
}

interface IContracts {
  liquidityProviders: LiquidityProviders;
  lpToken: LPToken;
  tokenManager: TokenManager;
  liquidityPool: LiquidityPool;
  whitelistPeriodManager: WhitelistPeriodManager;
  executorManager: ExecutorManager;
}

const deploy = async (deployConfig: {
  trustedForwarder: string;
  bicoOwner: string;
  pauser: string;
  tokens: IAddTokenParameters[];
}) => {
  const contracts = await deployContracts(deployConfig.bicoOwner, deployConfig.trustedForwarder, deployConfig.pauser);
  for (const token of deployConfig.tokens) {
    await addTokenSupport(contracts, token);
  }
  await configure(contracts, deployConfig.bicoOwner);
  await verify(contracts, deployConfig);
};

async function deployContracts(bicoOwner: string, trustedForwarder: string, pauser: string): Promise<IContracts> {
  const [deployer] = await ethers.getSigners();

  console.log("Deployer:", deployer.address);

  const ExecutorManager = await ethers.getContractFactory("ExecutorManager");
  console.log("Deploying ExecutorManager...");
  const executorManager = await ExecutorManager.deploy();
  await executorManager.deployed();
  console.log("ExecutorManager deployed to:", executorManager.address);

  const TokenManager = await ethers.getContractFactory("TokenManager");
  console.log("Deploying TokenManager...");
  const tokenManager = await TokenManager.deploy(trustedForwarder);
  await tokenManager.deployed();
  console.log("TokenManager deployed to:", tokenManager.address);

  const LPToken = await ethers.getContractFactory("LPToken");
  console.log("Deploying LPToken...");
  const lpToken = (await upgrades.deployProxy(LPToken, [
    LPTokenName,
    LPTokenSymbol,
    trustedForwarder,
    pauser,
  ])) as LPToken;
  await lpToken.deployed();
  console.log("LPToken Proxy deployed to:", lpToken.address);

  const LiquidityProviders = await ethers.getContractFactory("LiquidityProviders");
  console.log("Deploying LiquidityProviders...");
  const liquidityProviders = (await upgrades.deployProxy(LiquidityProviders, [
    trustedForwarder,
    lpToken.address,
    tokenManager.address,
    pauser,
  ])) as LiquidityProviders;
  await liquidityProviders.deployed();
  console.log("LiquidityProviders Proxy deployed to:", liquidityProviders.address);

  const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
  console.log("Deploying LiquidityPool...");
  const liquidityPool = (await upgrades.deployProxy(LiquidityPool, [
    executorManager.address,
    pauser,
    trustedForwarder,
    tokenManager.address,
    liquidityProviders.address,
  ])) as LiquidityPool;
  await liquidityPool.deployed();
  console.log("LiquidityPool Proxy deployed to:", liquidityPool.address);

  const WhitelistPeriodManager = await ethers.getContractFactory("WhitelistPeriodManager");
  console.log("Deploying WhitelistPeriodManager...");
  const whitelistPeriodManager = (await upgrades.deployProxy(WhitelistPeriodManager, [
    trustedForwarder,
    liquidityProviders.address,
    tokenManager.address,
    lpToken.address,
    pauser,
  ])) as WhitelistPeriodManager;
  await whitelistPeriodManager.deployed();
  console.log("WhitelistPeriodManager Proxy deployed to:", whitelistPeriodManager.address);

  return {
    executorManager,
    tokenManager,
    lpToken,
    liquidityProviders,
    liquidityPool,
    whitelistPeriodManager,
  };
}

const configure = async (contracts: IContracts, bicoOwner: string) => {
  await (await contracts.liquidityProviders.setTokenManager(contracts.tokenManager.address)).wait();
  await (await contracts.liquidityProviders.setLiquidityPool(contracts.liquidityPool.address)).wait();
  await (await contracts.liquidityProviders.setWhiteListPeriodManager(contracts.whitelistPeriodManager.address)).wait();
  console.log("Configured LiquidityProviders");

  await (await contracts.lpToken.setLiquidityProviders(contracts.liquidityProviders.address)).wait();
  await (await contracts.lpToken.setWhiteListPeriodManager(contracts.whitelistPeriodManager.address)).wait();
  console.log("Configured LPToken");

  await (await contracts.tokenManager.transferOwnership(bicoOwner)).wait();
  await (await contracts.lpToken.transferOwnership(bicoOwner)).wait();
  await (await contracts.executorManager.transferOwnership(bicoOwner)).wait();
  await (await contracts.liquidityProviders.transferOwnership(bicoOwner)).wait();
  await (await contracts.liquidityPool.transferOwnership(bicoOwner)).wait();
  await (await contracts.whitelistPeriodManager.transferOwnership(bicoOwner)).wait();

  console.log(`Transferred Ownership to ${bicoOwner}`);
};

const addTokenSupport = async (contracts: IContracts, token: IAddTokenParameters) => {
  await (
    await contracts.tokenManager.addSupportedToken(
      token.tokenAddress,
      token.minCap,
      token.maxCap,
      token.equilibriumFee,
      token.maxFee
    )
  ).wait();
  await (
    await contracts.tokenManager.setDepositConfig(
      token.toChainIds,
      new Array(token.toChainIds.length).fill(token.tokenAddress),
      new Array(token.toChainIds.length).fill({ min: token.minCap, max: token.maxCap })
    )
  ).wait();
  await (
    await contracts.whitelistPeriodManager.setCap(
      token.tokenAddress,
      token.maxLiquidityCap,
      token.maxWalletLiquidityCap
    )
  ).wait();
  console.log("Added token support for", token.tokenAddress);
};

const getImplementationAddress = async (proxyAddress: string) => {
  return ethers.utils.hexlify(
    ethers.BigNumber.from(
      await ethers.provider.send("eth_getStorageAt", [
        proxyAddress,
        "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
        "latest",
      ])
    )
  );
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

const verifyImplementation = async (address: string) => {
  try {
    await run("verify:verify", {
      address: await getImplementationAddress(address),
    });
  } catch (e) {
    console.log(`Failed to verify Contract ${address} `, e);
  }
};

const verify = async (contracts: IContracts, config: { trustedForwarder: string; pauser: string }) => {
  console.log("Verifying Contracts...");
  await Promise.all([
    verifyContract(contracts.executorManager.address, []),
    verifyContract(contracts.tokenManager.address, [config.trustedForwarder]),
    verifyImplementation(contracts.lpToken.address),
    verifyImplementation(contracts.liquidityProviders.address),
    verifyImplementation(contracts.liquidityPool.address),
    verifyImplementation(contracts.whitelistPeriodManager.address),
  ]);
};

export { deployContracts, configure, addTokenSupport, verify, deploy };
