import { expect, use } from "chai";
import { ethers, upgrades } from "hardhat";
import {
  ERC20Token,
  LiquidityPool,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("LiquidityPoolTests", function () {
  let alice: SignerWithAddress, bob: SignerWithAddress, charlie: SignerWithAddress, tf: SignerWithAddress;
  let token: ERC20Token, liquidityPool: LiquidityPool;

  before(async function () {
    [alice, bob, charlie, tf] = await ethers.getSigners();

    console.log("Deploying Deposit Pool...");
    const liquidtyPoolFactory = await ethers.getContractFactory("LiquidityPool");
    liquidityPool = (await upgrades.deployProxy(liquidtyPoolFactory, [tf.address])) as LiquidityPool;
    await liquidityPool.deployed();
    console.log(`Liquiidty Pool deployed at: ${liquidityPool.address}`);

    console.log("Deploying Token...");
    const erc20factory = await ethers.getContractFactory("ERC20Token");
    token = (await upgrades.deployProxy(erc20factory, ["USDT", "USDT"])) as ERC20Token;
    console.log(`Token Deployed at ${token.address}`);

    console.log("Minting Tokens...");
    for (const signer of [alice, bob, charlie]) {
      await token.mint(signer.address, ethers.BigNumber.from(1000).mul(ethers.BigNumber.from(10).pow(18)));
    }
    console.log("Tokens minted");
  });

  it("Should Deploy Liquidity Pool Correctly", async function () {
    expect(await liquidityPool.owner()).to.equal(alice.address);
  });

  it("Should be able to add liquidity successfully", async function () {
    for (const signer of [alice, bob, charlie]) {
      await (
        await token
          .connect(signer)
          .approve(liquidityPool.address, ethers.BigNumber.from(100).mul(ethers.BigNumber.from(10).pow(18)))
      ).wait();
      await expect(() => liquidityPool.connect(signer).addLiquidity(token.address, 1e5)).to.changeTokenBalances(
        token,
        [signer, liquidityPool],
        [-1e5, 1e5]
      );
    }
  });

  it("Should be able to add reward successfully", async function () {
    await expect(() => liquidityPool.addReward(token.address, 3e5)).to.changeTokenBalances(
      token,
      [alice, liquidityPool],
      [-3e5, 3e5]
    );
  });

  it("Should be able to remove liquidity", async function () {
    const aliceLiquidity = 1e5;

    await expect(() => liquidityPool.removeLiquidity(token.address, aliceLiquidity)).to.changeTokenBalances(
      token,
      [liquidityPool, alice],
      [-aliceLiquidity, aliceLiquidity]
    );
  });

  it("Should be able to extract rewards", async function () {
    const expectedRewardAlice = 3e5 / 3;
    expect(await liquidityPool.calculateReward(alice.address, token.address)).to.equal(expectedRewardAlice);
    await expect(() => liquidityPool.connect(alice).extractReward(token.address)).to.changeTokenBalances(
      token,
      [liquidityPool, alice],
      [-expectedRewardAlice, expectedRewardAlice]
    );
    expect(await liquidityPool.calculateReward(alice.address, token.address)).to.equal(0);
  });

  it("Should be able to handle more rewards properly", async function () {
    await liquidityPool.addReward(token.address, 2e5);
    await liquidityPool.addReward(token.address, 8e5);

    const expectedRewardBob = 3e5 / 3 + 2e5 / 2 + 8e5 / 2;
    const bobLiquidity = 1e5;

    await expect(() => liquidityPool.connect(bob).removeLiquidity(token.address, bobLiquidity)).to.changeTokenBalances(
      token,
      [liquidityPool, bob],
      [-bobLiquidity, bobLiquidity]
    );

    expect(await liquidityPool.calculateReward(bob.address, token.address)).to.equal(expectedRewardBob);
    await expect(() => liquidityPool.connect(bob).extractReward(token.address)).to.changeTokenBalances(
      token,
      [liquidityPool, bob],
      [-expectedRewardBob, expectedRewardBob]
    );
    expect(await liquidityPool.calculateReward(bob.address, token.address)).to.equal(0);
  });

  it("Should be able to handle more rewards properly", async function () {
    await liquidityPool.addReward(token.address, 5e5);

    const expectedRewardCharlie = 3e5 / 3 + 2e5 / 2 + 8e5 / 2 + 5e5;
    const charlieLiquidity = 1e5;

    await expect(() =>
      liquidityPool.connect(charlie).removeLiquidity(token.address, charlieLiquidity)
    ).to.changeTokenBalances(token, [liquidityPool, charlie], [-charlieLiquidity, charlieLiquidity]);

    expect(await liquidityPool.calculateReward(charlie.address, token.address)).to.equal(expectedRewardCharlie);
    await expect(() => liquidityPool.connect(charlie).extractReward(token.address)).to.changeTokenBalances(
      token,
      [liquidityPool, charlie],
      [-expectedRewardCharlie, expectedRewardCharlie]
    );
    expect(await liquidityPool.calculateReward(charlie.address, token.address)).to.equal(0);
  });

  it("Should be able to extractRewards only", async function () {
    await liquidityPool.connect(alice).addLiquidity(token.address, 1e6);
    await liquidityPool.connect(bob).addLiquidity(token.address, 2e6);
    await liquidityPool.connect(charlie).addLiquidity(token.address, 3e6);
    await liquidityPool.addReward(token.address, 12e7);

    const expectedRewardAlice = (12e7 / 6e6) * 1e6;
    expect(await liquidityPool.calculateReward(alice.address, token.address)).to.equal(expectedRewardAlice);
    await expect(() => liquidityPool.connect(alice).extractReward(token.address)).to.changeTokenBalances(
      token,
      [liquidityPool, alice],
      [-expectedRewardAlice, expectedRewardAlice]
    );
    expect(await liquidityPool.calculateReward(alice.address, token.address)).to.equal(0);

    const expectedRewardBob = (12e7 / 6e6) * 2e6;
    expect(await liquidityPool.calculateReward(bob.address, token.address)).to.equal(expectedRewardBob);
    await expect(() => liquidityPool.connect(bob).extractReward(token.address)).to.changeTokenBalances(
      token,
      [liquidityPool, bob],
      [-expectedRewardBob, expectedRewardBob]
    );
    expect(await liquidityPool.calculateReward(bob.address, token.address)).to.equal(0);

    const expectedRewardCharlie = (12e7 / 6e6) * 3e6;
    expect(await liquidityPool.calculateReward(charlie.address, token.address)).to.equal(expectedRewardCharlie);
    await expect(() => liquidityPool.connect(charlie).extractReward(token.address)).to.changeTokenBalances(
      token,
      [liquidityPool, charlie],
      [-expectedRewardCharlie, expectedRewardCharlie]
    );
    expect(await liquidityPool.calculateReward(charlie.address, token.address)).to.equal(0);
  });

  it("Should be able to partially extract liquidity and extract correct rewards", async function () {
    await liquidityPool.addReward(token.address, 12e7);

    await expect(() => liquidityPool.connect(alice).removeLiquidity(token.address, 1e6 / 8)).to.changeTokenBalances(
      token,
      [liquidityPool, alice],
      [-1e6 / 8, 1e6 / 8]
    );
    await expect(() => liquidityPool.connect(bob).removeLiquidity(token.address, 2e6 / 4)).to.changeTokenBalances(
      token,
      [liquidityPool, bob],
      [-2e6 / 4, 2e6 / 4]
    );
    await expect(() => liquidityPool.connect(charlie).removeLiquidity(token.address, 3e6 / 2)).to.changeTokenBalances(
      token,
      [liquidityPool, charlie],
      [-3e6 / 2, 3e6 / 2]
    );

    await liquidityPool.addReward(token.address, 12e7);

    const newTotalLiquidity = (1e6 * 7) / 8 + (2e6 * 3) / 4 + 3e6 / 2;

    const expectedRewardAlice = Math.floor((12e7 / 6e6) * 1e6 + (12e7 / newTotalLiquidity) * ((1e6 * 7) / 8));
    expect(await liquidityPool.calculateReward(alice.address, token.address)).to.equal(expectedRewardAlice);
    await expect(() => liquidityPool.connect(alice).extractReward(token.address)).to.changeTokenBalances(
      token,
      [liquidityPool, alice],
      [-expectedRewardAlice, expectedRewardAlice]
    );
    expect(await liquidityPool.calculateReward(alice.address, token.address)).to.equal(0);

    const expectedRewardBob = Math.floor((12e7 / 6e6) * 2e6 + (12e7 / newTotalLiquidity) * ((2e6 * 3) / 4));
    expect(await liquidityPool.calculateReward(bob.address, token.address)).to.equal(expectedRewardBob);
    await expect(() => liquidityPool.connect(bob).extractReward(token.address)).to.changeTokenBalances(
      token,
      [liquidityPool, bob],
      [-expectedRewardBob, expectedRewardBob]
    );
    expect(await liquidityPool.calculateReward(bob.address, token.address)).to.equal(0);

    const expectedRewardCharlie = Math.floor((12e7 / 6e6) * 3e6 + (12e7 / newTotalLiquidity) * (3e6 / 2));
    expect(await liquidityPool.calculateReward(charlie.address, token.address)).to.equal(expectedRewardCharlie);
    await expect(() => liquidityPool.connect(charlie).extractReward(token.address)).to.changeTokenBalances(
      token,
      [liquidityPool, charlie],
      [-expectedRewardCharlie, expectedRewardCharlie]
    );
    expect(await liquidityPool.calculateReward(charlie.address, token.address)).to.equal(0);
  });

  it("Should be able to withdraw remaining liquidity", async function () {
    const aliceLiquidity = await liquidityPool.liquidityAddedAmount(alice.address, token.address);
    const bobLiquidity = await liquidityPool.liquidityAddedAmount(bob.address, token.address);
    const charlieLiquidity = await liquidityPool.liquidityAddedAmount(charlie.address, token.address);

    await expect(() =>
      liquidityPool.connect(alice).removeLiquidity(token.address, aliceLiquidity)
    ).to.changeTokenBalances(token, [liquidityPool, alice], [-aliceLiquidity, aliceLiquidity]);
    await expect(() => liquidityPool.connect(bob).removeLiquidity(token.address, bobLiquidity)).to.changeTokenBalances(
      token,
      [liquidityPool, bob],
      [-bobLiquidity, bobLiquidity]
    );
    await expect(() =>
      liquidityPool.connect(charlie).removeLiquidity(token.address, charlieLiquidity)
    ).to.changeTokenBalances(token, [liquidityPool, charlie], [-charlieLiquidity, charlieLiquidity]);
  });
});
