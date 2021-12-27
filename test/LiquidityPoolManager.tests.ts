import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import {
  ERC20Token,
  LiquidityPool,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("LiquidityPoolTests", function () {
  let alice: SignerWithAddress,
    bob: SignerWithAddress,
    charlie: SignerWithAddress,
    tf: SignerWithAddress;
  let token: ERC20Token, liquidityPool: LiquidityPool;

  before(async function () {
    [alice, bob, charlie, tf] = await ethers.getSigners();

    console.log("Deploying Deposit Pool...");
    const liquidtyPoolFactory = await ethers.getContractFactory(
      "LiquidityPool"
    );
    liquidityPool = (await upgrades.deployProxy(liquidtyPoolFactory, [
      tf.address,
    ])) as LiquidityPool;
    await liquidityPool.deployed();
    console.log(`Liquiidty Pool deployed at: ${liquidityPool.address}`);

    console.log("Deploying Token...");
    const erc20factory = await ethers.getContractFactory("ERC20Token");
    token = (await upgrades.deployProxy(erc20factory, [
      "USDT",
      "USDT",
    ])) as ERC20Token;
    console.log(`Token Deployed at ${token.address}`);

    console.log("Minting Tokens...");
    for (const signer of [alice, bob, charlie]) {
      await token.mint(
        signer.address,
        ethers.BigNumber.from(1000).mul(ethers.BigNumber.from(10).pow(18))
      );
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
          .approve(
            liquidityPool.address,
            ethers.BigNumber.from(100).mul(ethers.BigNumber.from(10).pow(18))
          )
      ).wait();
      await expect(() =>
        liquidityPool.connect(signer).addLiquidity(token.address, 1e5)
      ).to.changeTokenBalances(token, [signer, liquidityPool], [-1e5, 1e5]);
    }
  });

  it("Should be able to add reward successfully", async function () {
    await expect(() =>
      liquidityPool.addReward(token.address, 3e5)
    ).to.changeTokenBalances(token, [alice, liquidityPool], [-3e5, 3e5]);
  });

  it("Should be able to remove liquidity with reward", async function () {
    const expectedTotalAmountAlice = 1e5 + 3e5 / 3;

    await expect(() =>
      liquidityPool.removeLiquidity(token.address)
    ).to.changeTokenBalances(
      token,
      [liquidityPool, alice],
      [-expectedTotalAmountAlice, expectedTotalAmountAlice]
    );
  });

  it("Should be able to handle more rewards properly", async function () {
    await liquidityPool.addReward(token.address, 2e5);
    await liquidityPool.addReward(token.address, 8e5);

    const expectedTotalAmountBob = 1e5 + 3e5 / 3 + 2e5 / 2 + 8e5 / 2;

    await expect(() =>
      liquidityPool.connect(bob).removeLiquidity(token.address)
    ).to.changeTokenBalances(
      token,
      [liquidityPool, bob],
      [-expectedTotalAmountBob, expectedTotalAmountBob]
    );
  });

  it("Should be able to handle more rewards properly", async function () {
    await liquidityPool.addReward(token.address, 5e5);

    const expectedTotalAmountCharlie = 1e5 + 3e5 / 3 + 2e5 / 2 + 8e5 / 2 + 5e5;

    await expect(() =>
      liquidityPool.connect(charlie).removeLiquidity(token.address)
    ).to.changeTokenBalances(
      token,
      [liquidityPool, charlie],
      [-expectedTotalAmountCharlie, expectedTotalAmountCharlie]
    );
  });
});
