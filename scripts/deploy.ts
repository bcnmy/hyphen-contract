import { ethers, upgrades, run } from "hardhat";
import {
  LiquidityPool,
  LPToken,
  WhitelistPeriodManager,
  LiquidityProviders,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";

const LPTokenName = "BICO Liquidity Token";
const LPTokenSymbol = "BICOLP";

async function deploy(bicoOwner: string, trustedForwarder: string, pauser: string) {
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

  await (await liquidityProviders.setTokenManager(tokenManager.address)).wait();
  await (await liquidityProviders.setLiquidityPool(liquidityPool.address)).wait();
  await (await liquidityProviders.setWhiteListPeriodManager(whitelistPeriodManager.address)).wait();
  console.log("Configured LiquidityProviders");

  await (await lpToken.setLiquidityPool(liquidityProviders.address)).wait();
  await (await lpToken.setWhiteListPeriodManager(whitelistPeriodManager.address)).wait();

  console.log("Configured LPToken");

  await (await whitelistPeriodManager.setAreWhiteListRestrictionsEnabled(false)).wait();
  console.log("Configured WhitelistPeriodManager");

  await (await tokenManager.transferOwnership(bicoOwner)).wait();
  await (await lpToken.transferOwnership(bicoOwner)).wait();
  await (await executorManager.transferOwnership(bicoOwner)).wait();
  await (await liquidityProviders.transferOwnership(bicoOwner)).wait();
  await (await liquidityPool.transferOwnership(bicoOwner)).wait();
  await (await whitelistPeriodManager.transferOwnership(bicoOwner)).wait();
  console.log(`Transferred Ownership to ${bicoOwner}`);

  return {
    executorManagerAddress: executorManager.address,
    tokenManagerAddress: tokenManager.address,
    lpTokenAddress: lpToken.address,
    liquidityProvidersAddress: liquidityProviders.address,
    liquidityPoolAddress: liquidityPool.address,
    whitelistPeriodManagerAddress: whitelistPeriodManager.address,
  };
}

export { deploy };
