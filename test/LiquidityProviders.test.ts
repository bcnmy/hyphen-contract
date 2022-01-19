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
  let token: ERC20Token, token2: ERC20Token;
  let lpToken: LPToken;
  let liquidityProviders: LiquidityProvidersImplementation;
  let trustedForwarder = "0xFD4973FeB2031D4409fB57afEE5dF2051b171104";
  const NATIVE = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
  let BASE: BigNumber;

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
    [owner, pauser, charlie, bob, tf, , executor] = await ethers.getSigners();

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

    BASE = BigNumber.from(10).pow(27);
  });

  describe("Liquidity Addition", async function () {
    this.beforeEach(async () => {
      for (const tk of [token, token2]) {
        for (const signer of [owner, bob, charlie]) {
          await tk.connect(signer).approve(liquidityProviders.address, await tk.balanceOf(signer.address));
        }
      }
    });

    it("Should return proper share price when reserver is empty", async function () {
      expect(await liquidityProviders.getLpSharePriceInTermsOfBaseToken(token.address)).to.equal(BASE);
      expect(await liquidityProviders.getLpSharePriceInTermsOfBaseToken(NATIVE)).to.equal(BASE);
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

    it("Should not be able to add native liquidity using addTokenLiquidity", async function () {
      await expect(liquidityProviders.addTokenLiquidity(NATIVE, 10)).to.be.revertedWith("ERR__WRONG_FUNCTION");
    });

    it("Added liquidity should be non zero", async function () {
      await expect(liquidityProviders.addTokenLiquidity(token.address, 0)).to.be.revertedWith("ERR__AMOUNT_IS_0");
    });

    it("Should not allow non owners to add liquidity to NFT", async function () {
      await liquidityProviders.addTokenLiquidity(token.address, 1000);
      await expect(liquidityProviders.connect(bob).increaseTokenLiquidity(1, 1000)).to.be.revertedWith(
        "ERR__TRANSACTOR_DOES_NOT_OWN_NFT"
      );
      await liquidityProviders.addNativeLiquidity({ value: 1000 });
      await expect(liquidityProviders.connect(bob).increaseTokenLiquidity(2, 1000)).to.be.revertedWith(
        "ERR__TRANSACTOR_DOES_NOT_OWN_NFT"
      );
    });
  });

  describe("Transfer Fee Addition and LP Token Price Increase", async function () {
    this.beforeEach(async () => {
      await token.connect(owner).approve(liquidityProviders.address, await token.balanceOf(owner.address));
      await token.connect(bob).approve(liquidityProviders.address, await token.balanceOf(bob.address));
      await liquidityProviders.addTokenLiquidity(token.address, 100);
      await liquidityProviders.addNativeLiquidity({ value: 100 });
    });

    it("Should be able to add lp rewards and update lp token price correctly for ERC20", async function () {
      await liquidityProviders.addLPFee(token.address, 20);
      expect(await liquidityProviders.getLpSharePriceInTermsOfBaseToken(token.address)).to.equal(
        BASE.mul(120).div(100)
      );
    });

    it("Should be able to add lp rewards and update lp token price correctly for Native", async function () {
      await liquidityProviders.addLPFee(NATIVE, 20, { value: 20 });
      expect(await liquidityProviders.getLpSharePriceInTermsOfBaseToken(NATIVE)).to.equal(BASE.mul(120).div(100));
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

  describe("LP Share Burning for ERC20 base", async function () {
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

    it("Should revert if attempted to burn more shares than available", async function () {
      const shares = (await lpToken.tokenMetadata(1)).totalShares;
      await expect(liquidityProviders.connect(bob).decreaseLiquidity(1, shares.add(1))).to.be.revertedWith(
        "ERR__INVALID_SHARES_AMOUNT"
      );
      await expect(liquidityProviders.connect(bob).decreaseLiquidity(1, shares)).to.not.be.reverted;
    });

    it("Should revert if attempted to burn 0 shares", async function () {
      await expect(liquidityProviders.connect(bob).decreaseLiquidity(1, 0)).to.be.revertedWith(
        "ERR__INVALID_SHARES_AMOUNT"
      );
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

    it("Should revert if attempted to burn more shares than available", async function () {
      const shares = (await lpToken.tokenMetadata(1)).totalShares;
      await expect(liquidityProviders.connect(bob).decreaseLiquidity(1, shares.add(1))).to.be.revertedWith(
        "ERR__INVALID_SHARES_AMOUNT"
      );
    });

    it("Should revert if attempted to burn 0 shares", async function () {
      await expect(liquidityProviders.connect(bob).decreaseLiquidity(1, 0)).to.be.revertedWith(
        "ERR__INVALID_SHARES_AMOUNT"
      );
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
      expect(expectedRewards).to.equal(20);

      await expect(() =>
        liquidityProviders.extractFee(1, expectedRewards.mul(BASE).div(price).add(1))
      ).to.changeTokenBalances(token, [liquidityProviders, owner], [-20, 20]);
    });

    it("Should allow extraction of fee in NATIVE", async function () {
      await liquidityProviders.addLPFee(NATIVE, 10, { value: 10 });
      await liquidityProviders.increaseNativeLiquidity(2, { value: 100 });
      await liquidityProviders.addLPFee(NATIVE, 10, { value: 10 });

      const expectedRewards = await liquidityProviders.getFeeAccumulatedOnNft(2); // Error of 1 here ;
      const price = await liquidityProviders.getLpSharePriceInTermsOfBaseToken(NATIVE);
      expect(expectedRewards).to.equal(20);

      await expect(() =>
        liquidityProviders.extractFee(2, expectedRewards.mul(BASE).div(price).add(1))
      ).to.changeEtherBalances([liquidityProviders, owner], [-20, 20]);
    });

    it("Should revert if more shares are burnt than available for reward", async function () {
      await liquidityProviders.addLPFee(token.address, 10);
      const rewards = await liquidityProviders.getFeeAccumulatedOnNft(1);
      const shares = rewards.mul(BASE).div(await liquidityProviders.getLpSharePriceInTermsOfBaseToken(token.address));
      await expect(liquidityProviders.extractFee(1, shares.add(1))).to.be.revertedWith("ERR__INSUFFICIENT_REWARDS");
      await expect(liquidityProviders.extractFee(1, shares)).to.not.be.reverted;
    });
  });

  describe("Real world flow tests", async function () {
    const shares = async (baseValue: number | BigNumber, token: ERC20Token): Promise<BigNumber> => {
      const price = await liquidityProviders.getLpSharePriceInTermsOfBaseToken(token.address);
      return BigNumber.from(baseValue).mul(BASE).div(price);
    };
    const mulBy10e18 = (num: number): BigNumber => BigNumber.from(10).pow(18).mul(num);

    this.beforeEach(async () => {
      await token.connect(owner).approve(liquidityProviders.address, await token.balanceOf(owner.address));
      await token.connect(bob).approve(liquidityProviders.address, await token.balanceOf(owner.address));
      await token.connect(charlie).approve(liquidityProviders.address, await token.balanceOf(owner.address));
    });

    it("Case #1: Single LP", async function () {
      await liquidityProviders.addTokenLiquidity(token.address, 100);
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(0);

      await liquidityProviders.addLPFee(token.address, 50);
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(50);

      // Error of 1 here, should be 50
      await expect(async () => liquidityProviders.decreaseLiquidity(1, await shares(50, token))).to.changeTokenBalances(
        token,
        [liquidityProviders, owner],
        [-49, 49]
      );

      // Error of 1 here, should be 50
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(51);
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(50);

      await liquidityProviders.addLPFee(token.address, 50);
      // Error of 1 here, should be 50
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(51);
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(100);

      // Error of 1 here, should be 50
      await expect(async () => liquidityProviders.extractFee(1, await shares(50, token))).to.changeTokenBalances(
        token,
        [liquidityProviders, owner],
        [-49, 49]
      );
      // Error of 1 here, should be 50
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(51);
      // Error of 1 here, should be 50
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(51);

      // Error of 2 here, should be 20
      await expect(async () => liquidityProviders.decreaseLiquidity(1, await shares(20, token))).to.changeTokenBalances(
        token,
        [liquidityProviders, owner],
        [-18, 18]
      );
      // Error of 3 here, should be 30
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(33);
      // Error of 1 here, should be 50
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(51);

      await liquidityProviders.addLPFee(token.address, 90);
      // Error of 3 here, should be 30
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(33);
      // Error of 1 here, should be 140
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(141);

      // Error of 4 here, should be 140
      await expect(async () => liquidityProviders.extractFee(1, await shares(140, token))).to.changeTokenBalances(
        token,
        [liquidityProviders, owner],
        [-136, 136]
      );
      // Error of 3 here, should be 30
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(33);
      // Error of 5 here, should be 0
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(5);

      // Error of 2 here, should be 30
      await expect(async () => liquidityProviders.decreaseLiquidity(1, await shares(30, token))).to.changeTokenBalances(
        token,
        [liquidityProviders, owner],
        [-28, 28]
      );
      // Error of 5 here, should be 0
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(5);
      // Error of 5 here, should be 0
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(5);

      await liquidityProviders.increaseTokenLiquidity(1, 100);
      // Error of 5 here, should be 100
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(105);
      // Error of 5 here, should be 0
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(5);

      await liquidityProviders.addLPFee(token.address, 10);
      // Error of 5 here, should be 100
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(105);
      // Error of 4 here, should be 10
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(14);

      await liquidityProviders.increaseTokenLiquidity(1, 100);
      // Error of 5 here, should be 200
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(205);
      // Error of 5 here, should be 10
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(15);

      await liquidityProviders.addLPFee(token.address, 10);
      // Error of 5 here, should be 200
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(205);
      // Error of 5 here, should be 20
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(25);
    });

    it("Case #1: Single LP, Large Token Values", async function () {
      await liquidityProviders.addTokenLiquidity(token.address, mulBy10e18(100));
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(0);

      await liquidityProviders.addLPFee(token.address, mulBy10e18(50));
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(mulBy10e18(50));

      // Error of 1 here, should be 50 * 1e18
      await expect(async () =>
        liquidityProviders.decreaseLiquidity(1, await shares(mulBy10e18(50), token))
      ).to.changeTokenBalances(token, [liquidityProviders, owner], [mulBy10e18(-50).add(1), mulBy10e18(50).sub(1)]);

      // Error of 1 here, should be 50 * 1e18
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(mulBy10e18(50).add(1));
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(mulBy10e18(50));

      await liquidityProviders.addLPFee(token.address, mulBy10e18(50));
      // Error of 1 here, should be 50 * 1e18
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(mulBy10e18(50).add(1));
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(mulBy10e18(100));

      // Error of 1 here, should be 50 * 10e18
      await expect(async () =>
        liquidityProviders.extractFee(1, await shares(mulBy10e18(50), token))
      ).to.changeTokenBalances(token, [liquidityProviders, owner], [mulBy10e18(-50).add(1), mulBy10e18(50).sub(1)]);
      // Error of 1 here, should be 50* 10e18
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(mulBy10e18(50).add(1));
      // Error of 1 here, should be 50 * 10e18
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(mulBy10e18(50).add(1));

      // Error of 2 here, should be 20 * 10e18
      await expect(async () =>
        liquidityProviders.decreaseLiquidity(1, await shares(mulBy10e18(20), token))
      ).to.changeTokenBalances(token, [liquidityProviders, owner], [mulBy10e18(-20).add(2), mulBy10e18(20).sub(2)]);
      // Error of 3 here, should be 30 * 10e18
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(mulBy10e18(30).add(3));
      // Error of 1 here, should be 50 * 10e18
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(mulBy10e18(50).add(1));

      await liquidityProviders.addLPFee(token.address, mulBy10e18(90));
      // Error of 3 here, should be 30 * 10e18
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(mulBy10e18(30).add(3));
      // Error of 1 here, should be 140 * 10e18
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(mulBy10e18(140).add(1));

      // Error of 3 here, should be 140 * 1e18
      await expect(async () =>
        liquidityProviders.extractFee(1, await shares(mulBy10e18(140), token))
      ).to.changeTokenBalances(token, [liquidityProviders, owner], [mulBy10e18(-140).add(3), mulBy10e18(140).sub(3)]);
      // Error of 3 here, should be 30 * 1e18
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(mulBy10e18(30).add(3));
      // Error of 4 here, should be 0
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(4);

      // Error of 3 here, should be 30 * 1e18
      await expect(async () =>
        liquidityProviders.decreaseLiquidity(1, await shares(mulBy10e18(30), token))
      ).to.changeTokenBalances(token, [liquidityProviders, owner], [mulBy10e18(-30).add(3), mulBy10e18(30).sub(3)]);
      // Error of 6 here, should be 0
      expect((await lpToken.tokenMetadata(1)).totalSuppliedLiquidity).equal(6);
      // Error of 4 here, should be 0
      expect(await liquidityProviders.getFeeAccumulatedOnNft(1)).to.equal(4);
    });
  });
});
