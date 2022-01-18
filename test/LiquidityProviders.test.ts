import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import {
  ERC20Token,
  LiquidityProvidersImplementation,
  LPToken,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, ContractTransaction } from "ethers";

describe("LiquidityProviderTests", function () {
  interface TransactionCall {
    (): Promise<ContractTransaction>;
  }

  interface NftMetadata {
    token: string;
    totalSuppliedLiquidity: BigNumber | number;
    totalShares: BigNumber | number;
  }

  let owner: SignerWithAddress, pauser: SignerWithAddress, bob: SignerWithAddress;
  let charlie: SignerWithAddress, tf: SignerWithAddress, executor: SignerWithAddress;
  let proxyAdmin: SignerWithAddress;
  let token: ERC20Token, token2: ERC20Token;
  let lpToken: LPToken;
  let liquidityProviders: LiquidityProvidersImplementation;
  let trustedForwarder = "0xFD4973FeB2031D4409fB57afEE5dF2051b171104";
  const NATIVE = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
  const BASE = 10000000000;

  const expectLpTokenMintedWithMetadata = async (
    call: TransactionCall,
    account: SignerWithAddress,
    expectedTokenId: number,
    newMetadata: NftMetadata
  ) => {
    expect(await lpToken.exists(expectedTokenId)).to.be.false;
    const balanceBefore = await lpToken.balanceOf(account.address);
    await call();
    const balanceAfter = await lpToken.balanceOf(account.address);
    const actualChange = balanceAfter.sub(balanceBefore);
    expect(actualChange).to.equal(1);
    expect(await lpToken.ownerOf(expectedTokenId)).to.equal(account.address);
    const metadata = await lpToken.tokenMetadata(expectedTokenId);
    expect(metadata.token).to.equal(newMetadata.token);
    expect(metadata.totalSuppliedLiquidity).to.equal(newMetadata.totalSuppliedLiquidity);
    expect(metadata.totalShares).to.equal(newMetadata.totalShares);
  };

  const expectLpShareAndSlChangeToNftId = async (
    call: TransactionCall,
    account: SignerWithAddress,
    tokenId: number,
    lpShareDelta: number,
    totalSlDelta: number
  ) => {
    const metadata = await lpToken.tokenMetadata(tokenId);
    const balanceBefore = await lpToken.balanceOf(account.address);
    await call();
    const balanceAfter = await lpToken.balanceOf(account.address);
    const actualChange = balanceAfter.sub(balanceBefore);
    expect(actualChange).to.equal(0);

    expect(await lpToken.exists(tokenId)).to.be.true;
    expect(await lpToken.ownerOf(tokenId)).to.equal(account.address);
    const newMetadata = await lpToken.tokenMetadata(tokenId);
    expect(metadata.token).to.equal(newMetadata.token);
    expect(newMetadata.totalSuppliedLiquidity.sub(metadata.totalSuppliedLiquidity)).to.equal(totalSlDelta);
    expect(newMetadata.totalShares.sub(metadata.totalShares)).to.equal(lpShareDelta);
  };

  beforeEach(async function () {
    [owner, pauser, charlie, bob, tf, proxyAdmin, executor] = await ethers.getSigners();

    const liquidtyProvidersFactory = await ethers.getContractFactory("LiquidityProvidersImplementation");
    liquidityProviders = (await upgrades.deployProxy(liquidtyProvidersFactory, [
      trustedForwarder,
    ])) as LiquidityProvidersImplementation;
    await liquidityProviders.deployed();

    const erc20factory = await ethers.getContractFactory("ERC20Token");
    token = (await upgrades.deployProxy(erc20factory, ["USDT", "USDT"])) as ERC20Token;
    token2 = (await upgrades.deployProxy(erc20factory, ["USDC", "USDC"])) as ERC20Token;

    for (const signer of [owner, bob, charlie]) {
      await token.mint(signer.address, ethers.BigNumber.from(100000000).mul(ethers.BigNumber.from(10).pow(18)));
      await token2.mint(signer.address, ethers.BigNumber.from(100000000).mul(ethers.BigNumber.from(10).pow(18)));
    }

    const lpTokenFactory = await ethers.getContractFactory("LPToken");
    lpToken = (await upgrades.deployProxy(lpTokenFactory, [
      "LPToken",
      "LPToken",
      trustedForwarder,
      liquidityProviders.address,
    ])) as LPToken;

    await liquidityProviders.setLpToken(lpToken.address);
  });

  describe("Liquidity Addition", async function () {
    this.beforeEach(async () => {
      for (const tk of [token, token2]) {
        for (const signer of [owner, bob, charlie]) {
          await tk.connect(signer).approve(liquidityProviders.address, await tk.balanceOf(signer.address));
        }
      }
    });

    it("Should be able to add token liquidity", async function () {
      await expectLpTokenMintedWithMetadata(
        async () => await liquidityProviders.addTokenLiquidity(token.address, 100),
        owner,
        1,
        {
          token: token.address,
          totalShares: 100,
          totalSuppliedLiquidity: 100,
        }
      );
      await expectLpTokenMintedWithMetadata(
        async () => await liquidityProviders.addTokenLiquidity(token2.address, 200),
        owner,
        2,
        {
          token: token2.address,
          totalShares: 200,
          totalSuppliedLiquidity: 200,
        }
      );
      await expectLpTokenMintedWithMetadata(
        async () => await liquidityProviders.connect(bob).addTokenLiquidity(token2.address, 200),
        bob,
        3,
        {
          token: token2.address,
          totalShares: 200,
          totalSuppliedLiquidity: 200,
        }
      );
      await expectLpTokenMintedWithMetadata(
        async () => await liquidityProviders.connect(charlie).addTokenLiquidity(token2.address, 200),
        charlie,
        4,
        {
          token: token2.address,
          totalShares: 200,
          totalSuppliedLiquidity: 200,
        }
      );
      expect(await lpToken.getAllNftIdsByUser(owner.address)).to.deep.equal([1, 2].map(BigNumber.from));
      expect(await lpToken.getAllNftIdsByUser(bob.address)).to.deep.equal([3].map(BigNumber.from));
      expect(await lpToken.getAllNftIdsByUser(charlie.address)).to.deep.equal([4].map(BigNumber.from));
    });

    it("Should be able to add native liquidity", async function () {
      await expectLpTokenMintedWithMetadata(
        async () => await liquidityProviders.addNativeLiquidity({ value: 100 }),
        owner,
        1,
        {
          token: NATIVE,
          totalShares: 100,
          totalSuppliedLiquidity: 100,
        }
      );
    });
  });

  describe("Transfer Fee Addition", async function () {
    this.beforeEach(async () => {
      await token.connect(owner).approve(liquidityProviders.address, await token.balanceOf(owner.address));
      await token.connect(bob).approve(liquidityProviders.address, await token.balanceOf(bob.address));
      await liquidityProviders.addTokenLiquidity(token.address, 100);
      await liquidityProviders.addNativeLiquidity({ value: 100 });
    });

    it("Should be able to add lp rewards and update lp token price correctly for ERC20", async function () {
      await liquidityProviders.addLPFee(token.address, 20);
      expect(await liquidityProviders.getLpSharePriceInTermsOfBaseToken(token.address)).to.equal((120 / 100) * BASE);
    });

    it("Should be able to add lp rewards and update lp token price correctly for Native", async function () {
      await liquidityProviders.addLPFee(NATIVE, 20, { value: 20 });
      expect(await liquidityProviders.getLpSharePriceInTermsOfBaseToken(NATIVE)).to.equal((120 / 100) * BASE);
    });

    it("Should be able to mint correct lp shares amount after reward additon for ERC20", async function () {
      let currentReserve = (await liquidityProviders.tokenToTotalReserve(token.address)).toNumber(),
        currentSupply = (await liquidityProviders.tokenToTotalSharesMinted(token.address)).toNumber();
      for (const [fee, liquidty] of [
        [20, 50],
        [30, 40],
        [1000, 9876],
        [1234, 5678],
      ]) {
        await liquidityProviders.addLPFee(token.address, fee);
        currentReserve += fee;
        const expectedLpSharesAmount = Math.floor(liquidty / (currentReserve / currentSupply));
        await expectLpShareAndSlChangeToNftId(
          () => liquidityProviders.increaseTokenLiquidity(1, liquidty),
          owner,
          1,
          expectedLpSharesAmount,
          liquidty
        );
        currentReserve += liquidty;
        currentSupply += expectedLpSharesAmount;
      }
    });

    it("Should be able to mint correct lp shares amount after reward additon for NATIVE", async function () {
      let currentReserve = (await liquidityProviders.tokenToTotalReserve(NATIVE)).toNumber(),
        currentSupply = (await liquidityProviders.tokenToTotalSharesMinted(NATIVE)).toNumber();
      for (const [fee, liquidty] of [
        [20, 50],
        [30, 40],
        [1000, 9876],
        [1234, 5678],
      ]) {
        await liquidityProviders.addLPFee(NATIVE, fee, { value: fee });
        currentReserve += fee;
        const expectedLpSharesAmount = Math.floor(liquidty / (currentReserve / currentSupply));
        await expectLpShareAndSlChangeToNftId(
          () => liquidityProviders.increaseNativeLiquidity(2, { value: liquidty }),
          owner,
          2,
          expectedLpSharesAmount,
          liquidty
        );
        currentReserve += liquidty;
        currentSupply += expectedLpSharesAmount;
      }
    });
  });

  describe("LP Token Burning for ERC20 base", async function () {
    let totalTokenSuppliedLiquidity: Record<string, number>;
    let nftId: Record<string, number>;
    let totalTokenFee = 0;
    let totalTokenFeeClaimed = 0;

    this.beforeEach(async () => {
      totalTokenSuppliedLiquidity = {
        [owner.address]: 0,
        [bob.address]: 0,
        [charlie.address]: 0,
      };

      nftId = {
        [owner.address]: 0,
        [bob.address]: 0,
        [charlie.address]: 0,
      };

      for (const signer of [owner, bob, charlie]) {
        await token.connect(signer).approve(liquidityProviders.address, ethers.BigNumber.from(10).pow(20));
      }

      let counter = 0;

      for (const [signer, fee, liquidty] of [
        [bob, 20, 50],
        [charlie, 30, 40],
        [bob, 1000, 9876],
        [charlie, 1234, 5678],
        [owner, 1000, 9876],
        [bob, 1234, 5678],
      ] as [SignerWithAddress, number, number][]) {
        await liquidityProviders.connect(signer).addLPFee(token.address, fee);
        if (nftId[signer.address] === 0) {
          await liquidityProviders.connect(signer).addTokenLiquidity(token.address, liquidty);
          nftId[signer.address] = ++counter;
        } else {
          await liquidityProviders.connect(signer).increaseTokenLiquidity(nftId[signer.address], liquidty);
        }
        totalTokenSuppliedLiquidity[signer.address] += liquidty;
        totalTokenFee += fee;
      }
    });

    it("Should allow extraction of ERC20 liquidity and rewards", async function () {
      const extractReward = async (signer: SignerWithAddress) => {
        const totalLpSharesMinted = await liquidityProviders.tokenToTotalSharesMinted(token.address);
        const lpShares = (await lpToken.tokenMetadata(nftId[signer.address])).totalShares;
        const tokenBalance = await token.balanceOf(signer.address);
        await liquidityProviders.connect(signer).decreaseLiquidity(nftId[signer.address], lpShares);
        expect(totalLpSharesMinted.sub(await liquidityProviders.tokenToTotalSharesMinted(token.address))).to.equal(
          lpShares
        );
        expect((await lpToken.tokenMetadata(nftId[signer.address])).totalShares).to.equal(0);
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
    let nftId: Record<string, number>;
    let totalNativeFee = ethers.BigNumber.from(0);
    let totalNativeFeeClaimed = ethers.BigNumber.from(0);

    this.beforeEach(async () => {
      totalNativeSuppliedLiquidity = {
        [owner.address]: ethers.BigNumber.from(0),
        [bob.address]: ethers.BigNumber.from(0),
        [charlie.address]: ethers.BigNumber.from(0),
      };

      nftId = {
        [owner.address]: 0,
        [bob.address]: 0,
        [charlie.address]: 0,
      };

      let counter = 0;

      nftId = {
        [owner.address]: 0,
        [bob.address]: 0,
        [charlie.address]: 0,
      };

      for (const [signer, fee, liquidity] of [
        [bob, 20, 50],
        [charlie, 30, 40],
        [bob, 1000, 9876],
        [charlie, 1234, 5678],
        [owner, 1000, 9876],
        [bob, 1234, 5678],
      ] as [SignerWithAddress, number, number][]) {
        await liquidityProviders.connect(signer).addLPFee(NATIVE, fee, { value: fee });
        if (nftId[signer.address] === 0) {
          await liquidityProviders.connect(signer).addNativeLiquidity({ value: liquidity });
          nftId[signer.address] = ++counter;
        } else {
          await liquidityProviders.connect(signer).increaseNativeLiquidity(nftId[signer.address], { value: liquidity });
        }
        totalNativeSuppliedLiquidity[signer.address] = totalNativeSuppliedLiquidity[signer.address].add(liquidity);
        totalNativeFee = totalNativeFee.add(fee);
      }
    });

    it("Should allow extraction of NATIVE liquidity and rewards", async function () {
      const extractReward = async (signer: SignerWithAddress) => {
        const lpShareSupply = await liquidityProviders.tokenToTotalSharesMinted(NATIVE);
        const lpBalance = (await lpToken.tokenMetadata(nftId[signer.address])).totalShares;
        const nativeBalance = await ethers.provider.getBalance(signer.address);
        const { cumulativeGasUsed, effectiveGasPrice } = await (
          await liquidityProviders.connect(signer).decreaseLiquidity(nftId[signer.address], lpBalance)
        ).wait();
        expect(lpShareSupply.sub(await liquidityProviders.tokenToTotalSharesMinted(NATIVE))).to.equal(lpBalance);
        expect((await lpToken.tokenMetadata(nftId[signer.address])).totalShares).to.equal(0);
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

  describe("Fee Calculation and Extraction", async function () {
    this.beforeEach(async () => {
      await token.connect(owner).approve(liquidityProviders.address, await token.balanceOf(owner.address));
      await liquidityProviders.addTokenLiquidity(token.address, 100);
      await liquidityProviders.addNativeLiquidity({ value: 100 });
    });

    it("Should allow extraction of fee in ERC20", async function () {
      await liquidityProviders.addLPFee(token.address, 10);
      await liquidityProviders.increaseTokenLiquidity(1, 100);
      await liquidityProviders.addLPFee(token.address, 10);

      const price = await liquidityProviders.getLpSharePriceInTermsOfBaseToken(token.address);
      const expectedRewards = await liquidityProviders.getFeeAccumulatedOnNft(1);
      // Error of 1 here
      expect(expectedRewards).to.equal(20 - 1);
      // Error of 1 here
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(20 - 1);

      await expect(() =>
        liquidityProviders.extractFee(1, expectedRewards.mul(BASE).div(price).add(1))
      ).to.changeTokenBalances(token, [liquidityProviders, owner], [-19, 19]);
    });

    it("Should allow extraction of fee in NATIVE", async function () {
      await liquidityProviders.addLPFee(NATIVE, 10, { value: 10 });
      await liquidityProviders.increaseNativeLiquidity(2, { value: 100 });
      await liquidityProviders.addLPFee(NATIVE, 10, { value: 10 });

      const expectedRewards = await liquidityProviders.getFeeAccumulatedOnNft(2); // Error of 1 here ;
      const price = await liquidityProviders.getLpSharePriceInTermsOfBaseToken(NATIVE);
      expect(expectedRewards).to.equal(20 - 1);
      // Error of 1 here
      expect(await liquidityProviders.getFeeAccumulatedOnNft(2)).to.equal(20 - 1);

      await expect(() =>
        liquidityProviders.extractFee(2, expectedRewards.mul(BASE).div(price).add(1))
      ).to.changeEtherBalances([liquidityProviders, owner], [-19, 19]);
    });
  });
});
