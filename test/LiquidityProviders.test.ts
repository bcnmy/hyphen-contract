import { expect, use } from "chai";
import { ethers, upgrades } from "hardhat";
import {
  ERC20Token,
  LiquidityProvidersImplementation,
  LPToken,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";

describe("LiquidityProviderTests", function () {
  let owner: SignerWithAddress, pauser: SignerWithAddress, bob: SignerWithAddress;
  let charlie: SignerWithAddress, tf: SignerWithAddress, executor: SignerWithAddress;
  let proxyAdmin: SignerWithAddress;
  let token: ERC20Token;
  let lpTokenForERC20: LPToken, lpTokenForNative: LPToken;
  let liquidityProviders: LiquidityProvidersImplementation;
  let trustedForwarder = "0xFD4973FeB2031D4409fB57afEE5dF2051b171104";
  const NATIVE = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
  const BASE = 10000000000;

  beforeEach(async function () {
    [owner, pauser, charlie, bob, tf, proxyAdmin, executor] = await ethers.getSigners();

    const liquidtyProvidersFactory = await ethers.getContractFactory("LiquidityProvidersImplementation");
    liquidityProviders = (await upgrades.deployProxy(liquidtyProvidersFactory, [
      trustedForwarder,
    ])) as LiquidityProvidersImplementation;
    await liquidityProviders.deployed();

    const erc20factory = await ethers.getContractFactory("ERC20Token");
    token = (await upgrades.deployProxy(erc20factory, ["USDT", "USDT"])) as ERC20Token;

    for (const signer of [owner, bob, charlie]) {
      await token.mint(signer.address, ethers.BigNumber.from(100000000).mul(ethers.BigNumber.from(10).pow(18)));
    }

    const lpTokenFactory = await ethers.getContractFactory("LPToken");
    lpTokenForERC20 = (await upgrades.deployProxy(lpTokenFactory, [
      "lUSDT",
      "lUSDT",
      await token.decimals(),
      trustedForwarder,
      liquidityProviders.address,
    ])) as LPToken;
    lpTokenForNative = (await upgrades.deployProxy(lpTokenFactory, [
      "lETH",
      "lETH",
      await token.decimals(),
      trustedForwarder,
      liquidityProviders.address,
    ])) as LPToken;
  });

  describe("Setup", async function () {
    it("Should be able to add tokens", async function () {
      await expect(liquidityProviders.setLpToken(token.address, lpTokenForERC20.address))
        .to.emit(liquidityProviders, "NewTokenRegistered")
        .withArgs(token.address, lpTokenForERC20.address);
      await expect(liquidityProviders.setLpToken(NATIVE, lpTokenForNative.address))
        .to.emit(liquidityProviders, "NewTokenRegistered")
        .withArgs(NATIVE, lpTokenForNative.address);
      expect(await liquidityProviders.baseTokenToLpToken(token.address)).to.equal(lpTokenForERC20.address);
      expect(await liquidityProviders.baseTokenToLpToken(NATIVE)).to.equal(lpTokenForNative.address);
      expect(await liquidityProviders.lpTokenToBaseToken(lpTokenForERC20.address)).to.equal(token.address);
      expect(await liquidityProviders.lpTokenToBaseToken(lpTokenForNative.address)).to.equal(NATIVE);
    });
  });

  describe("Liquidity Addition", async function () {
    this.beforeEach(async () => {
      await liquidityProviders.setLpToken(token.address, lpTokenForERC20.address);
      await liquidityProviders.setLpToken(NATIVE, lpTokenForNative.address);
      await token.connect(owner).approve(liquidityProviders.address, await token.balanceOf(owner.address));
      await token.connect(bob).approve(liquidityProviders.address, await token.balanceOf(bob.address));
    });

    it("Should be able to add token liquidity", async function () {
      await expect(async () => await liquidityProviders.addTokenLiquidity(token.address, 100)).changeTokenBalance(
        lpTokenForERC20,
        owner,
        100
      );
    });

    it("Should be able to add native liquidity", async function () {
      await expect(
        async () =>
          await liquidityProviders.addNativeLiquidity({
            value: 100,
          })
      ).changeTokenBalance(lpTokenForNative, owner, 100);
    });
  });

  describe("Transfer Fee Addition", async function () {
    this.beforeEach(async () => {
      await liquidityProviders.setLpToken(token.address, lpTokenForERC20.address);
      await liquidityProviders.setLpToken(NATIVE, lpTokenForNative.address);
      await token.connect(owner).approve(liquidityProviders.address, await token.balanceOf(owner.address));
      await token.connect(bob).approve(liquidityProviders.address, await token.balanceOf(bob.address));
      await liquidityProviders.addTokenLiquidity(token.address, 100);
      await liquidityProviders.addNativeLiquidity({ value: 100 });
    });

    it("Should be able to add lp rewards and update lp token price correctly for ERC20", async function () {
      await liquidityProviders.addLPFee(token.address, 20);
      expect(await liquidityProviders.getLpTokenPriceInTermsOfBaseToken(token.address)).to.equal((120 / 100) * BASE);
    });

    it("Should be able to add lp rewards and update lp token price correctly for Native", async function () {
      await liquidityProviders.addLPFee(NATIVE, 20, { value: 20 });
      expect(await liquidityProviders.getLpTokenPriceInTermsOfBaseToken(NATIVE)).to.equal((120 / 100) * BASE);
    });

    it("Should be able to mint correct lp token amount after reward additon for ERC20", async function () {
      let currentReserve = (await liquidityProviders.totalReserve(token.address)).toNumber(),
        currentSupply = (await lpTokenForERC20.totalSupply()).toNumber();
      for (const [fee, liquidty] of [
        [20, 50],
        [30, 40],
        [1000, 9876],
        [1234, 5678],
      ]) {
        await liquidityProviders.addLPFee(token.address, fee);
        currentReserve += fee;
        const expectedLpTokenAmount = Math.floor(liquidty / (currentReserve / currentSupply));
        await expect(() => liquidityProviders.addTokenLiquidity(token.address, liquidty)).to.changeTokenBalance(
          lpTokenForERC20,
          owner,
          expectedLpTokenAmount
        );
        currentReserve += liquidty;
        currentSupply += expectedLpTokenAmount;
      }
    });

    it("Should be able to mint correct lp token amount after reward additon for NATIVE", async function () {
      let currentReserve = (await liquidityProviders.totalReserve(NATIVE)).toNumber(),
        currentSupply = (await lpTokenForNative.totalSupply()).toNumber();
      for (const [fee, liquidty] of [
        [20, 50],
        [30, 40],
        [1000, 9876],
        [1234, 5678],
      ]) {
        await liquidityProviders.addLPFee(NATIVE, fee, { value: fee });
        currentReserve += fee;
        const expectedLpTokenAmount = Math.floor(liquidty / (currentReserve / currentSupply));
        await expect(() => liquidityProviders.addNativeLiquidity({ value: liquidty })).to.changeTokenBalance(
          lpTokenForNative,
          owner,
          expectedLpTokenAmount
        );
        currentReserve += liquidty;
        currentSupply += expectedLpTokenAmount;
      }
    });
  });

  describe("LP Token Burning for ERC20 base", async function () {
    let totalTokenSuppliedLiquidity: Record<string, number>;
    let totalTokenFee = 0;
    let totalTokenFeeClaimed = 0;

    this.beforeEach(async () => {
      totalTokenSuppliedLiquidity = {
        [owner.address]: 0,
        [bob.address]: 0,
        [charlie.address]: 0,
      };

      await liquidityProviders.setLpToken(token.address, lpTokenForERC20.address);

      for (const signer of [owner, bob, charlie]) {
        for (const tk of [lpTokenForERC20, token]) {
          await tk.connect(signer).approve(liquidityProviders.address, ethers.BigNumber.from(10).pow(20));
        }
      }

      for (const [signer, fee, liquidty] of [
        [bob, 20, 50],
        [charlie, 30, 40],
        [bob, 1000, 9876],
        [charlie, 1234, 5678],
        [owner, 1000, 9876],
        [bob, 1234, 5678],
      ] as [SignerWithAddress, number, number][]) {
        await liquidityProviders.connect(signer).addLPFee(token.address, fee);
        await liquidityProviders.connect(signer).addTokenLiquidity(token.address, liquidty);
        totalTokenSuppliedLiquidity[signer.address] += liquidty;
        totalTokenFee += fee;
      }
    });

    it("Should allow extraction of ERC20 liquidity and rewards", async function () {
      const extractReward = async (signer: SignerWithAddress) => {
        const lpTokenSupply = await lpTokenForERC20.totalSupply();
        const lpBalance = await lpTokenForERC20.balanceOf(signer.address);
        const tokenBalance = await token.balanceOf(signer.address);
        await liquidityProviders.connect(signer).burnLpTokens(lpTokenForERC20.address, lpBalance);
        expect(lpTokenSupply.sub(await lpTokenForERC20.totalSupply())).to.equal(lpBalance);
        expect(await lpTokenForERC20.balanceOf(signer.address)).to.equal(0);
        const claimedFee = (await token.balanceOf(signer.address))
          .sub(tokenBalance.add(totalTokenSuppliedLiquidity[signer.address]))
          .toNumber();
        totalTokenFeeClaimed += claimedFee;
        expect(claimedFee).is.greaterThan(0);
      };
      for (const signer of [owner, bob, charlie]) {
        await extractReward(signer);
      }

      // There is an error of 1 here
      expect(Math.abs(totalTokenFeeClaimed - totalTokenFee) <= 1).to.be.true;
    });
  });

  describe("LP Token Burning for Native base", async function () {
    let totalNativeSuppliedLiquidity: Record<string, BigNumber>;
    let totalNativeFee = ethers.BigNumber.from(0);
    let totalNativeFeeClaimed = ethers.BigNumber.from(0);

    this.beforeEach(async () => {
      totalNativeSuppliedLiquidity = {
        [owner.address]: ethers.BigNumber.from(0),
        [bob.address]: ethers.BigNumber.from(0),
        [charlie.address]: ethers.BigNumber.from(0),
      };

      await liquidityProviders.setLpToken(NATIVE, lpTokenForNative.address);

      for (const signer of [owner, bob, charlie]) {
        for (const tk of [lpTokenForNative, token]) {
          await tk.connect(signer).approve(liquidityProviders.address, ethers.BigNumber.from(10).pow(20));
        }
      }

      for (const [signer, fee, liquidity] of [
        [bob, 20, 50],
        [charlie, 30, 40],
        [bob, 1000, 9876],
        [charlie, 1234, 5678],
        [owner, 1000, 9876],
        [bob, 1234, 5678],
      ] as [SignerWithAddress, number, number][]) {
        await liquidityProviders.connect(signer).addLPFee(NATIVE, fee, { value: fee });
        await liquidityProviders.connect(signer).addNativeLiquidity({ value: liquidity });
        totalNativeSuppliedLiquidity[signer.address] = totalNativeSuppliedLiquidity[signer.address].add(liquidity);
        totalNativeFee = totalNativeFee.add(fee);
      }
    });

    it("Should allow extraction of NATIVE liquidity and rewards", async function () {
      const extractReward = async (signer: SignerWithAddress) => {
        const lpTokenSupply = await lpTokenForNative.totalSupply();
        const lpBalance = await lpTokenForNative.balanceOf(signer.address);
        const nativeBalance = await ethers.provider.getBalance(signer.address);
        const { cumulativeGasUsed, effectiveGasPrice } = await (
          await liquidityProviders.connect(signer).burnLpTokens(lpTokenForNative.address, lpBalance)
        ).wait();
        expect(lpTokenSupply.sub(await lpTokenForNative.totalSupply())).to.equal(lpBalance);
        expect(await lpTokenForNative.balanceOf(signer.address)).to.equal(0);
        const claimedFee = (await ethers.provider.getBalance(signer.address))
          .add(cumulativeGasUsed.mul(effectiveGasPrice))
          .sub(nativeBalance.add(totalNativeSuppliedLiquidity[signer.address]));
        totalNativeFeeClaimed = totalNativeFeeClaimed.add(claimedFee);
        expect(claimedFee.toNumber()).is.greaterThan(0);
      };

      for (const signer of [owner, bob, charlie]) {
        await extractReward(signer);
      }

      // There is an error of 1 here
      if (totalNativeFeeClaimed.gte(totalNativeFee)) {
        expect(totalNativeFeeClaimed.sub(totalNativeFee).lte(1)).to.be.true;
      } else {
        expect(totalNativeFee.sub(totalNativeFeeClaimed).lte(1)).to.be.true;
      }
    });
  });
});
