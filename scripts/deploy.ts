import { ethers } from "hardhat";

async function main() {
    const [owner] = await ethers.getSigners();
    const ownerAddress = owner.address;
    const trustedForwarder = '0x0000000000000000000000000000000000000001';

    console.log("Deployer:", ownerAddress);

    const ExecutorManager = await ethers.getContractFactory("ExecutorManager");
    const executorManager = await ExecutorManager.deploy();
    await executorManager.deployed();
    console.log("ExecutorManager deployed to:", executorManager.address);

    const TokenManager = await ethers.getContractFactory("TokenManager");
    const tokenManager = await TokenManager.deploy(trustedForwarder);
    await tokenManager.deployed();
    console.log("TokenManager deployed to:", tokenManager.address);

    const LPToken = await ethers.getContractFactory("LPToken");
    const lpToken = await LPToken.deploy();
    await lpToken.deployed();
    await lpToken.initialize("LP", "LP", trustedForwarder);
    console.log("LPToken deployed to:", lpToken.address);

    const LiquidityProviders = await ethers.getContractFactory("LiquidityProviders");
    const liquidityProviders = await LiquidityProviders.deploy();
    await liquidityProviders.deployed();
    await liquidityProviders.initialize(trustedForwarder, lpToken.address, tokenManager.address, ownerAddress);
    console.log("LiquidityProviders deployed to:", liquidityProviders.address);

    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    const liquidityPool = await LiquidityPool.deploy();
    await liquidityPool.deployed();
    await liquidityPool.initialize(executorManager.address, ownerAddress, trustedForwarder, tokenManager.address, liquidityProviders.address);
    console.log("LiquidityPool deployed to:", liquidityPool.address);

    const WhitelistPeriodManager = await ethers.getContractFactory("WhitelistPeriodManager");
    const whitelistPeriodManager = await WhitelistPeriodManager.deploy();
    await whitelistPeriodManager.deployed();
    await whitelistPeriodManager.initialize(trustedForwarder, liquidityProviders.address, tokenManager.address, lpToken.address, ownerAddress);
    console.log("WhitelistPeriodManager deployed to:", whitelistPeriodManager.address);

    await liquidityProviders.setTokenManager(tokenManager.address);
    await liquidityProviders.setLiquidityPool(liquidityPool.address);
    await liquidityProviders.setWhiteListPeriodManager(whitelistPeriodManager.address);
    console.log("Configured LiquidityProviders");

    await lpToken.setLiquidtyPool(liquidityProviders.address);
    await lpToken.setWhiteListPeriodManager(whitelistPeriodManager.address);
    console.log("Configured LPToken");

    await whitelistPeriodManager.setAreWhiteListRestrictionsEnabled(false);
    console.log("Configured WhitelistPeriodManager");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
