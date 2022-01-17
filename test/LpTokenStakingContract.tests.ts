import { expect, use } from "chai";
import { ethers, upgrades } from "hardhat";
import {
  ERC20Token,
  LpTokenStakingContract,
  LPToken,
  LiquidityProvidersImplementation,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";

describe("LpTokenStakingContractTests", function () {
  let alice: SignerWithAddress, bob: SignerWithAddress, charlie: SignerWithAddress, tf: SignerWithAddress;
  let token: ERC20Token, bicoToken: ERC20Token;
  let liquidityProviders: LiquidityProvidersImplementation,
    lpToken: LPToken,
    lpTokenStakingContract: LpTokenStakingContract;

  before(async function () {
    [alice, bob, charlie, tf] = await ethers.getSigners();

    const liquidtyPoolFactory = await ethers.getContractFactory("LiquidityProvidersImplementation");
    liquidityProviders = (await upgrades.deployProxy(liquidtyPoolFactory, [
      tf.address,
    ])) as LiquidityProvidersImplementation;
    await liquidityProviders.deployed();

    const erc20factory = await ethers.getContractFactory("ERC20Token");
    token = (await upgrades.deployProxy(erc20factory, ["USDT", "USDT"])) as ERC20Token;
    await token.deployed();
    bicoToken = (await upgrades.deployProxy(erc20factory, ["BICO", "BICO"])) as ERC20Token;
    await bicoToken.deployed();

    for (const signer of [alice, bob, charlie]) {
      for (const tk of [token, bicoToken]) {
        await tk.mint(signer.address, ethers.BigNumber.from(1000).mul(ethers.BigNumber.from(10).pow(18)));
      }
    }

    const lpTokenFactory = await ethers.getContractFactory("LPToken");
    lpToken = (await upgrades.deployProxy(lpTokenFactory, [
      "lpToken",
      "lpToken",
      tf.address,
      liquidityProviders.address,
    ])) as LPToken;
    await lpToken.deployed();
    await liquidityProviders.setLpToken(lpToken.address);

    const stakingFactory = await ethers.getContractFactory("LpTokenStakingContract");
    lpTokenStakingContract = (await upgrades.deployProxy(stakingFactory, [
      tf.address,
      lpToken.address,
      bicoToken.address,
    ])) as LpTokenStakingContract;
    await lpTokenStakingContract.deployed();

    for (const signer of [alice, bob, charlie]) {
      for (const tk of [bicoToken, token]) {
        await tk.connect(signer).approve(lpTokenStakingContract.address, await tk.balanceOf(signer.address));
        await tk.connect(signer).approve(liquidityProviders.address, await tk.balanceOf(signer.address));
      }
    }
  });

  it("Should be able to stake lp token", async function () {
    let counter = 0;
    for (const signer of [alice, bob, charlie]) {
      await liquidityProviders.connect(signer).addTokenLiquidity(token.address, 1e5);
      await lpToken.connect(signer).setApprovalForAll(lpTokenStakingContract.address, true);
      await expect(lpTokenStakingContract.connect(signer).stakeLpToken(++counter))
        .to.emit(lpTokenStakingContract, "LpTokenStaked")
        .withArgs(signer.address, counter, 1e5, counter);

      expect(await lpToken.ownerOf(counter)).to.equal(lpTokenStakingContract.address);
      expect(await lpTokenStakingContract.sharesAddedForTokenByLp(signer.address, token.address)).to.equal(1e5);
      expect(await lpTokenStakingContract.getAllNftIdsStakedByUser(signer.address)).to.deep.equal(
        [counter].map(BigNumber.from)
      );
    }
  });

  it("Should be able to add reward successfully", async function () {
    await expect(() => lpTokenStakingContract.addBicoReward(token.address, 3e5)).to.changeTokenBalances(
      bicoToken,
      [alice, lpTokenStakingContract],
      [-3e5, 3e5]
    );
  });

  it("Should be able to unstake lp token successfully", async function () {
    await lpTokenStakingContract.unstakeLpToken(1);
    expect(await lpToken.ownerOf(1)).to.equal(alice.address);
    expect(await lpTokenStakingContract.sharesAddedForTokenByLp(alice.address, token.address)).to.equal(0);
    expect((await lpTokenStakingContract.getAllNftIdsStakedByUser(alice.address)).length).to.equal(0);
  });

  it("Should be able to extract rewards", async function () {
    const expectedRewardAlice = 3e5 / 3;
    expect(await lpTokenStakingContract.calculateReward(alice.address, token.address)).to.equal(expectedRewardAlice);
    await expect(() => lpTokenStakingContract.connect(alice).extractReward(token.address)).to.changeTokenBalances(
      bicoToken,
      [lpTokenStakingContract, alice],
      [-expectedRewardAlice, expectedRewardAlice]
    );
    expect(await lpTokenStakingContract.calculateReward(alice.address, token.address)).to.equal(0);
  });

  it("Should be able to handle more rewards properly", async function () {
    await lpTokenStakingContract.addBicoReward(token.address, 2e5);
    await lpTokenStakingContract.addBicoReward(token.address, 8e5);

    const expectedRewardBob = 3e5 / 3 + 2e5 / 2 + 8e5 / 2;

    await lpTokenStakingContract.connect(bob).unstakeLpToken(2);
    expect(await lpToken.ownerOf(2)).to.equal(bob.address);
    expect(await lpTokenStakingContract.sharesAddedForTokenByLp(bob.address, token.address)).to.equal(0);
    expect((await lpTokenStakingContract.getAllNftIdsStakedByUser(bob.address)).length).to.equal(0);

    expect(await lpTokenStakingContract.calculateReward(bob.address, token.address)).to.equal(expectedRewardBob);
    await expect(() => lpTokenStakingContract.connect(bob).extractReward(token.address)).to.changeTokenBalances(
      bicoToken,
      [lpTokenStakingContract, bob],
      [-expectedRewardBob, expectedRewardBob]
    );
    expect(await lpTokenStakingContract.calculateReward(bob.address, token.address)).to.equal(0);
  });

  it("Should be able to handle more rewards properly", async function () {
    await lpTokenStakingContract.addBicoReward(token.address, 5e5);

    const expectedRewardCharlie = 3e5 / 3 + 2e5 / 2 + 8e5 / 2 + 5e5;

    await lpTokenStakingContract.connect(charlie).unstakeLpToken(3);
    expect(await lpToken.ownerOf(3)).to.equal(charlie.address);
    expect(await lpTokenStakingContract.sharesAddedForTokenByLp(charlie.address, token.address)).to.equal(0);
    expect((await lpTokenStakingContract.getAllNftIdsStakedByUser(charlie.address)).length).to.equal(0);

    expect(await lpTokenStakingContract.calculateReward(charlie.address, token.address)).to.equal(
      expectedRewardCharlie
    );
    await expect(() => lpTokenStakingContract.connect(charlie).extractReward(token.address)).to.changeTokenBalances(
      bicoToken,
      [lpTokenStakingContract, charlie],
      [-expectedRewardCharlie, expectedRewardCharlie]
    );
    expect(await lpTokenStakingContract.calculateReward(charlie.address, token.address)).to.equal(0);
  });

  it("Should be able to extractRewards only", async function () {
    await liquidityProviders.connect(alice).increaseTokenLiquidity(1, 1e6 - 1e5);
    await liquidityProviders.connect(bob).increaseTokenLiquidity(2, 2e6 - 1e5);
    await liquidityProviders.connect(charlie).increaseTokenLiquidity(3, 3e6 - 1e5);
    await lpTokenStakingContract.connect(alice).stakeLpToken(1);
    await lpTokenStakingContract.connect(bob).stakeLpToken(2);
    await lpTokenStakingContract.connect(charlie).stakeLpToken(3);
    await lpTokenStakingContract.addBicoReward(token.address, 12e7);

    const expectedRewardAlice = (12e7 / 6e6) * 1e6;
    expect(await lpTokenStakingContract.calculateReward(alice.address, token.address)).to.equal(expectedRewardAlice);
    await expect(() => lpTokenStakingContract.connect(alice).extractReward(token.address)).to.changeTokenBalances(
      bicoToken,
      [lpTokenStakingContract, alice],
      [-expectedRewardAlice, expectedRewardAlice]
    );
    expect(await lpTokenStakingContract.calculateReward(alice.address, token.address)).to.equal(0);

    const expectedRewardBob = (12e7 / 6e6) * 2e6;
    expect(await lpTokenStakingContract.calculateReward(bob.address, token.address)).to.equal(expectedRewardBob);
    await expect(() => lpTokenStakingContract.connect(bob).extractReward(token.address)).to.changeTokenBalances(
      bicoToken,
      [lpTokenStakingContract, bob],
      [-expectedRewardBob, expectedRewardBob]
    );
    expect(await lpTokenStakingContract.calculateReward(bob.address, token.address)).to.equal(0);

    const expectedRewardCharlie = (12e7 / 6e6) * 3e6;
    expect(await lpTokenStakingContract.calculateReward(charlie.address, token.address)).to.equal(
      expectedRewardCharlie
    );
    await expect(() => lpTokenStakingContract.connect(charlie).extractReward(token.address)).to.changeTokenBalances(
      bicoToken,
      [lpTokenStakingContract, charlie],
      [-expectedRewardCharlie, expectedRewardCharlie]
    );
    expect(await lpTokenStakingContract.calculateReward(charlie.address, token.address)).to.equal(0);
  });
});
