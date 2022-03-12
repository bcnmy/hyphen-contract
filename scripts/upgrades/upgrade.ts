import { ethers, upgrades } from "hardhat";

export async function upgradeLiquidityPool(proxyAddress: string) {
  const contract = await upgrades.upgradeProxy(proxyAddress, await ethers.getContractFactory("LiquidityPool"));
  await contract.deployed();
  console.log("LiquidityPool Upgraded");
}

export async function upgradeLiquidityProviders(proxyAddress: string) {
  const contract = await upgrades.upgradeProxy(proxyAddress, await ethers.getContractFactory("LiquidityProviders"));
  await contract.deployed();
  console.log("LiquidityProviders Upgraded");
}

export async function upgradeLPToken(proxyAddress: string) {
  const contract = await upgrades.upgradeProxy(proxyAddress, await ethers.getContractFactory("LPToken"));
  await contract.deployed();
  console.log("LpToken Upgraded");
}

export async function upgradeWhiteListPeriodManager(proxyAddress: string) {
  const contract = await upgrades.upgradeProxy(proxyAddress, await ethers.getContractFactory("WhitelistPeriodManager"));
  await contract.deployed();
  console.log("WhitelistPeriodManager Upgraded");
}

export async function upgradeLiquidityFarming(proxyAddress: string) {
  const contract = await upgrades.upgradeProxy(proxyAddress, await ethers.getContractFactory("HyphenLiquidityFarming"));
  await contract.deployed();
  console.log("LiquidityFarming Upgraded");
}
