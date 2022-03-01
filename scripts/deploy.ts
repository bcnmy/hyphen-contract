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
  delay(5000);
  const TokenManager = await ethers.getContractFactory("TokenManager");
  console.log("Deploying TokenManager...");
  const tokenManager = await TokenManager.deploy(trustedForwarder);
  await tokenManager.deployed();
  console.log("TokenManager deployed to:", tokenManager.address);
  delay(5000);
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
  delay(5000);
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
  delay(5000);
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
  delay(5000);
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
  delay(5000);
  await liquidityProviders.setTokenManager(tokenManager.address);
  delay(5000);
  await liquidityProviders.setLiquidityPool(liquidityPool.address);
  delay(5000);
  await liquidityProviders.setWhiteListPeriodManager(whitelistPeriodManager.address);
  delay(5000);
  console.log("Configured LiquidityProviders");

  await lpToken.setLiquidityProviders(liquidityProviders.address);
  delay(5000);
  await lpToken.setWhiteListPeriodManager(whitelistPeriodManager.address);
  delay(5000);
  console.log("Configured LPToken");

  await whitelistPeriodManager.setAreWhiteListRestrictionsEnabled(false);
  delay(5000);
  console.log("Configured WhitelistPeriodManager");

  await tokenManager.transferOwnership(bicoOwner);
  delay(5000);
  await lpToken.transferOwnership(bicoOwner);
  delay(5000);
  await executorManager.transferOwnership(bicoOwner);
  delay(5000);
  await liquidityProviders.transferOwnership(bicoOwner);
  delay(5000);
  await liquidityPool.transferOwnership(bicoOwner);
  delay(5000);
  await whitelistPeriodManager.transferOwnership(bicoOwner);
  delay(5000);
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

const delay = (ms: number) => new Promise((res) => setTimeout(res, ms));

export { deploy };
