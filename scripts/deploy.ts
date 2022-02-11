import { ethers, upgrades } from "hardhat";
import {
  LiquidityPool,
  LPToken,
  WhitelistPeriodManager,
  LiquidityProviders,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";

const addresses = {
  trustedForwarder: "0x0000000000000000000000000000000000000001",
  bicoOwner: "0x0000000000000000000000000000000000000001",
  pauser: "0x0000000000000000000000000000000000000001",
};
const LPTokenName = "BICO Liquidity Token";
const LPTokenSymbol = "BICOLP";

console.log(process.env)

async function main() {
  const { bicoOwner, trustedForwarder, pauser } = addresses;

  const [deployer] = await ethers.getSigners();

  console.log("Deployer:", deployer.address);

  const ExecutorManager = await ethers.getContractFactory("ExecutorManager");
  const executorManager = await ExecutorManager.deploy();
  await executorManager.deployed();
  console.log("ExecutorManager deployed to:", executorManager.address);

  const TokenManager = await ethers.getContractFactory("TokenManager");
  const tokenManager = await TokenManager.deploy(trustedForwarder);
  await tokenManager.deployed();
  console.log("TokenManager deployed to:", tokenManager.address);

  const LPToken = await ethers.getContractFactory("LPToken");
  const lpToken = (await upgrades.deployProxy(LPToken, [LPTokenName, LPTokenSymbol, trustedForwarder])) as LPToken;
  await lpToken.deployed();
  console.log("LPToken Proxy deployed to:", lpToken.address);

  const LiquidityProviders = await ethers.getContractFactory("LiquidityProviders");
  const liquidityProviders = (await upgrades.deployProxy(LiquidityProviders, [
    trustedForwarder,
    lpToken.address,
    tokenManager.address,
    pauser,
  ])) as LiquidityProviders;
  await liquidityProviders.deployed();
  console.log("LiquidityProviders Proxy deployed to:", liquidityProviders.address);

  const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
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
  const whitelistPeriodManager = (await upgrades.deployProxy(WhitelistPeriodManager, [
    trustedForwarder,
    liquidityProviders.address,
    tokenManager.address,
    lpToken.address,
    pauser,
  ])) as WhitelistPeriodManager;
  await whitelistPeriodManager.deployed();
  console.log("WhitelistPeriodManager Proxy deployed to:", whitelistPeriodManager.address);

  await liquidityProviders.setTokenManager(tokenManager.address);
  await liquidityProviders.setLiquidityPool(liquidityPool.address);
  await liquidityProviders.setWhiteListPeriodManager(whitelistPeriodManager.address);
  console.log("Configured LiquidityProviders");

  await lpToken.setLiquidtyPool(liquidityProviders.address);
  await lpToken.setWhiteListPeriodManager(whitelistPeriodManager.address);
  console.log("Configured LPToken");

  await whitelistPeriodManager.setAreWhiteListRestrictionsEnabled(false);
  console.log("Configured WhitelistPeriodManager");

  await tokenManager.transferOwnership(bicoOwner);
  await lpToken.transferOwnership(bicoOwner);
  await executorManager.transferOwnership(bicoOwner);
  await liquidityProviders.transferOwnership(bicoOwner);
  await liquidityPool.transferOwnership(bicoOwner);
  await whitelistPeriodManager.transferOwnership(bicoOwner);
  console.log(`Transferred Ownership to ${bicoOwner}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
