import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import {
  ERC20Token,
  LiquidityPool,
  LiquidityProvidersTest,
  WhitelistPeriodManager,
  LPToken,
  ExecutorManager,
  TokenManager,
  HyphenLiquidityFarming,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";

import { getLocaleString } from "./utils";

const advanceTime = async (secondsToAdvance: number) => {
  await ethers.provider.send("evm_increaseTime", [secondsToAdvance]);
  await ethers.provider.send("evm_mine", []);
};

describe("LiquidityFarmingTests", function () {
  let owner: SignerWithAddress, pauser: SignerWithAddress, bob: SignerWithAddress;
  let charlie: SignerWithAddress, tf: SignerWithAddress, executor: SignerWithAddress;
  let token: ERC20Token, token2: ERC20Token;
  let lpToken: LPToken;
  let wlpm: WhitelistPeriodManager;
  let liquidityProviders: LiquidityProvidersTest;
  let liquidityPool: LiquidityPool;
  let executorManager: ExecutorManager;
  let tokenManager: TokenManager;
  let farmingContract: HyphenLiquidityFarming;
  let trustedForwarder = "0xFD4973FeB2031D4409fB57afEE5dF2051b171104";
  const NATIVE = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
  let BASE: BigNumber = BigNumber.from(10).pow(18);

  const perWalletMaxCap = getLocaleString(1000 * 1e18);
  const tokenMaxCap = getLocaleString(1000000 * 1e18);

  const perWalletNativeMaxCap = getLocaleString(1 * 1e18);
  const tokenNativeMaxCap = getLocaleString(200 * 1e18);

  beforeEach(async function () {
    [owner, pauser, charlie, bob, tf, , executor] = await ethers.getSigners();

    const tokenManagerFactory = await ethers.getContractFactory("TokenManager");
    tokenManager = (await tokenManagerFactory.deploy(tf.address)) as TokenManager;

    const erc20factory = await ethers.getContractFactory("ERC20Token");
    token = (await upgrades.deployProxy(erc20factory, ["USDT", "USDT"])) as ERC20Token;
    token2 = (await upgrades.deployProxy(erc20factory, ["USDC", "USDC"])) as ERC20Token;
    for (const signer of [owner, bob, charlie]) {
      await token.mint(signer.address, ethers.BigNumber.from(100000000).mul(ethers.BigNumber.from(10).pow(18)));
      await token2.mint(signer.address, ethers.BigNumber.from(100000000).mul(ethers.BigNumber.from(10).pow(18)));
    }
    await tokenManager.addSupportedToken(token.address, BigNumber.from(1), BigNumber.from(10).pow(30), 0, 0);
    await tokenManager.addSupportedToken(token2.address, BigNumber.from(1), BigNumber.from(10).pow(30), 0, 0);
    await tokenManager.addSupportedToken(NATIVE, BigNumber.from(1), BigNumber.from(10).pow(30), 0, 0);

    const executorManagerFactory = await ethers.getContractFactory("ExecutorManager");
    executorManager = (await executorManagerFactory.deploy()) as ExecutorManager;

    const lpTokenFactory = await ethers.getContractFactory("LPToken");
    lpToken = (await upgrades.deployProxy(lpTokenFactory, ["LPToken", "LPToken", tf.address])) as LPToken;

    const liquidtyProvidersFactory = await ethers.getContractFactory("LiquidityProvidersTest");
    liquidityProviders = (await upgrades.deployProxy(liquidtyProvidersFactory, [
      trustedForwarder,
      lpToken.address,
      tokenManager.address,
      pauser.address,
    ])) as LiquidityProvidersTest;
    await liquidityProviders.deployed();
    await lpToken.setLiquidtyPool(liquidityProviders.address);
    await liquidityProviders.setLpToken(lpToken.address);

    const wlpmFactory = await ethers.getContractFactory("WhitelistPeriodManager");
    wlpm = (await upgrades.deployProxy(wlpmFactory, [
      tf.address,
      liquidityProviders.address,
      tokenManager.address,
      lpToken.address,
      pauser.address,
    ])) as WhitelistPeriodManager;
    await wlpm.setLiquidityProviders(liquidityProviders.address);
    await liquidityProviders.setWhiteListPeriodManager(wlpm.address);
    await lpToken.setWhiteListPeriodManager(wlpm.address);
    await wlpm.setCaps(
      [token.address, NATIVE],
      [tokenMaxCap, tokenNativeMaxCap],
      [perWalletMaxCap, perWalletNativeMaxCap]
    );
    await wlpm.setAreWhiteListRestrictionsEnabled(false);

    const lpFactory = await ethers.getContractFactory("LiquidityPool");
    liquidityPool = (await upgrades.deployProxy(lpFactory, [
      executorManager.address,
      pauser.address,
      tf.address,
      tokenManager.address,
      liquidityProviders.address,
    ])) as LiquidityPool;
    await liquidityProviders.setLiquidityPool(liquidityPool.address);

    const farmingFactory = await ethers.getContractFactory("HyphenLiquidityFarming");
    farmingContract = (await farmingFactory.deploy(
      liquidityProviders.address,
      lpToken.address
    )) as HyphenLiquidityFarming;
  });

  this.afterEach(async function () {
    expect(await token.balanceOf(liquidityProviders.address)).to.equal(0);
    expect(await token2.balanceOf(liquidityProviders.address)).to.equal(0);
    expect(await ethers.provider.getBalance(liquidityProviders.address)).to.equal(0);
  });

  it("Should be able to create reward pools", async function () {
    for (const signer of [owner, bob, charlie]) {
      await lpToken.connect(signer).setApprovalForAll(farmingContract.address, true);
      for (const tk of [token, token2]) {
        await tk.connect(signer).approve(farmingContract.address, ethers.constants.MaxUint256);
      }
    }

    await expect(farmingContract.initalizeRewardPool(token.address, token2.address, 10))
      .to.emit(farmingContract, "LogRewardPoolInitialized")
      .withArgs(token.address, token2.address, 10);
  });

  describe("Deposit", async () => {
    beforeEach(async function () {
      await farmingContract.initalizeRewardPool(token.address, token2.address, 10);

      for (const signer of [owner, bob, charlie]) {
        await lpToken.connect(signer).setApprovalForAll(farmingContract.address, true);
        for (const tk of [token, token2]) {
          await tk.connect(signer).approve(farmingContract.address, ethers.constants.MaxUint256);
          await tk.connect(signer).approve(liquidityProviders.address, ethers.constants.MaxUint256);
        }
      }

      await liquidityProviders.addTokenLiquidity(token.address, 10);
      await liquidityProviders.addTokenLiquidity(token2.address, 10);
    });

    it("Should be able to deposit lp tokens", async function () {
      await farmingContract.deposit(1, owner.address);
      expect((await farmingContract.userInfo(token.address, owner.address)).amount).to.equal(10);
      expect(await farmingContract.pendingToken(token.address, owner.address)).to.equal(0);
    });

    it("Should be able to deposit lp tokens and delegate to another account", async function () {
      await farmingContract.deposit(1, bob.address);
      expect((await farmingContract.userInfo(token.address, bob.address)).amount).to.equal(10);
      expect(await farmingContract.pendingToken(token.address, bob.address)).to.equal(0);
      expect((await farmingContract.userInfo(token.address, owner.address)).amount).to.equal(0);
      expect(await farmingContract.pendingToken(token.address, owner.address)).to.equal(0);
    });

    it("Should not be able to depoit LP token of un-initialized pools", async function () {
      await expect(farmingContract.deposit(2, owner.address)).to.be.revertedWith("ERR__POOL_NOT_INITIALIZED");
    });

    it("Should be able to accrue token rewards", async function () {
      await farmingContract.deposit(1, owner.address);
      await advanceTime(100);
      expect(await farmingContract.pendingToken(token.address, owner.address)).to.equal(10 * 100);
    });

    it("Should be able to create deposits in different tokens", async function () {
      await farmingContract.initalizeRewardPool(token2.address, token.address, 10);
      await farmingContract.deposit(1, owner.address);
      const { timestamp: startTimeStamp } = await ethers.provider.getBlock(await ethers.provider.getBlockNumber());
      await advanceTime(100);
      await farmingContract.deposit(2, owner.address);
      await advanceTime(100);
      const { timestamp: endTimeStamp } = await ethers.provider.getBlock(await ethers.provider.getBlockNumber());
      expect((await farmingContract.userInfo(token.address, owner.address)).amount).to.equal(10);
      expect(await farmingContract.pendingToken(token.address, owner.address)).to.equal(
        (endTimeStamp - startTimeStamp) * 10
      );
      expect((await farmingContract.userInfo(token2.address, owner.address)).amount).to.equal(10);
      expect(await farmingContract.pendingToken(token2.address, owner.address)).to.equal(1000);
    });
  });
});
