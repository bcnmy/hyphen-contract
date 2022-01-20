import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import {
  ERC20Token,
  LiquidityProvidersImplementation,
  WhitelistPeriodManager,
  LPToken,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";

describe("WhiteListPeriodManager", function () {
  let owner: SignerWithAddress, pauser: SignerWithAddress, bob: SignerWithAddress;
  let charlie: SignerWithAddress, tf: SignerWithAddress, executor: SignerWithAddress;
  let dan: SignerWithAddress, elon: SignerWithAddress;
  let token: ERC20Token;
  let lpToken: LPToken;
  let wlpm: WhitelistPeriodManager;
  let liquidityProviders: LiquidityProvidersImplementation;
  let trustedForwarder = "0xFD4973FeB2031D4409fB57afEE5dF2051b171104";
  const NATIVE = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
  let BASE: BigNumber;

  beforeEach(async function () {
    [owner, pauser, charlie, bob, dan, elon, tf, executor] = await ethers.getSigners();

    const liquidtyProvidersFactory = await ethers.getContractFactory("LiquidityProvidersImplementation");
    liquidityProviders = (await upgrades.deployProxy(liquidtyProvidersFactory, [
      trustedForwarder,
    ])) as LiquidityProvidersImplementation;
    await liquidityProviders.deployed();

    const erc20factory = await ethers.getContractFactory("ERC20Token");
    token = (await upgrades.deployProxy(erc20factory, ["USDT", "USDT"])) as ERC20Token;

    for (const signer of [owner, bob, charlie, dan, elon]) {
      await token.mint(signer.address, ethers.BigNumber.from(100000000).mul(ethers.BigNumber.from(10).pow(18)));
    }

    const lpTokenFactory = await ethers.getContractFactory("LPToken");
    lpToken = (await upgrades.deployProxy(lpTokenFactory, ["LPToken", "LPToken", tf.address])) as LPToken;
    await liquidityProviders.setLpToken(lpToken.address);
    await lpToken.setLiquidtyPool(liquidityProviders.address);

    const wlpmFactory = await ethers.getContractFactory("WhitelistPeriodManager");
    wlpm = (await upgrades.deployProxy(wlpmFactory, [
      tf.address,
      liquidityProviders.address,
    ])) as WhitelistPeriodManager;
    await wlpm.setLiquidityPool(liquidityProviders.address);
    await liquidityProviders.setWhiteListPeriodManager(wlpm.address);
    await lpToken.setWhiteListPeriodManager(wlpm.address);

    BASE = BigNumber.from(10).pow(27);

    for (const signer of [owner, bob, charlie, dan, elon]) {
      await token.connect(signer).approve(liquidityProviders.address, await token.balanceOf(signer.address));
    }
  });

  describe("Setup", async function () {
    it("Should set Token Caps properly", async function () {
      await wlpm.setCaps([token.address], [1000], [500], [10]);
      expect(await wlpm.perTokenTotalCap(token.address)).to.equal(1000);
      expect(await wlpm.perTokenCommunityCap(token.address)).to.equal(500);
      expect(await wlpm.perWalletCapForCommunityLp(token.address)).to.equal(10);
    });

    it("Should revert if invalid caps are provided", async function () {
      await expect(wlpm.setCaps([token.address], [1000], [1001], [10])).to.be.revertedWith("ERR__COMM_CAP_GT_PTTC");
      await expect(wlpm.setCaps([token.address], [1000], [500], [501])).to.be.revertedWith("ERR__PWC_GT_PTCC");
    });

    it("Should revert if invalid total cap is provided", async function () {
      await wlpm.setCaps([token.address], [1000], [500], [10]);
      await expect(wlpm.setTotalCap(token.address, 499)).to.be.revertedWith("ERR__TOTAL_CAP_LT_PTCC");
    });

    it("Should revert if invalid community total cap is provided", async function () {
      await wlpm.setCaps([token.address], [1000], [500], [10]);
      await expect(wlpm.setCommunityCap(token.address, 9)).to.be.revertedWith("ERR__COMM_CAP_LT_PWCFCL");
      await expect(wlpm.setCommunityCap(token.address, 10001)).to.be.revertedWith("ERR__COMM_CAP_GT_PTTC");
    });

    it("Should revert if invalid per community wallet cap is provided", async function () {
      await wlpm.setCaps([token.address], [1000], [500], [10]);
      await expect(wlpm.setPerWalletCapForCommunityLp(token.address, 501)).to.be.revertedWith("ERR__PWC_GT_PTCC");
    });

    it("Should set institutional addresses properly", async function () {
      await wlpm.setInstitutionalLpStatus([owner.address, bob.address], [true, false]);
      expect(await wlpm.isInstitutionalLp(owner.address)).to.be.true;
      expect(await wlpm.isInstitutionalLp(bob.address)).to.be.false;
      expect(await wlpm.isInstitutionalLp(charlie.address)).to.be.false;
      await wlpm.setInstitutionalLpStatus([owner.address], [false]);
      expect(await wlpm.isInstitutionalLp(owner.address)).to.be.false;
    });
  });

  describe("With Sample Caps", async function () {
    this.beforeEach(async function () {
      await wlpm.setInstitutionalLpStatus([dan.address, elon.address], [true, true]);
      await wlpm.setCaps([token.address], [1000], [25], [10]);
    });

    it("Should allow Community LPs to add liquidity within per wallet capacity", async function () {
      await expect(liquidityProviders.addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 5)).to.not.be.reverted;
    });

    it("Should allow community LP to increase liquidity to same NFT within cap", async function () {
      await expect(liquidityProviders.addTokenLiquidity(token.address, 5)).to.not.be.reverted;
      await expect(liquidityProviders.increaseTokenLiquidity(1, 5)).to.not.be.reverted;
    });

    it("Should prevent Community LPs from exceeding per wallet cap", async function () {
      await expect(liquidityProviders.addTokenLiquidity(token.address, 11)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_CPWC"
      );
    });

    it("Should prevent community LP from increasing liquidity to same NFT above cap", async function () {
      await expect(liquidityProviders.addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.increaseTokenLiquidity(1, 6)).to.be.revertedWith("ERR__LIQUIDITY_EXCEEDS_CPWC");
    });

    it("Should prevent multiple Community LPs to exceed global community cap", async function () {
      await liquidityProviders.addTokenLiquidity(token.address, 9);
      await liquidityProviders.connect(bob).addTokenLiquidity(token.address, 9);
      await expect(liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 9)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_CTC"
      );
    });

    it("Should prevent multiple Community LPs to exceed global community cap - 2", async function () {
      await liquidityProviders.addTokenLiquidity(token.address, 9);
      await liquidityProviders.connect(bob).addTokenLiquidity(token.address, 9);
      await liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 6);
      await expect(liquidityProviders.connect(charlie).increaseTokenLiquidity(3, 2)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_CTC"
      );
    });

    it("Should allow institutional investors to add liquidity within cap", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25)).to.not.be.reverted;
    });

    it("Should allow institutional investors to increase liquidity within cap", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 500 - 25)).to.not.be.reverted;
      await expect(liquidityProviders.connect(dan).increaseTokenLiquidity(1, 500)).to.not.be.reverted;
    });

    it("Should allow institutional investors to add liquidity within cap - 2", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 500)).to.not.be.reverted;
      await expect(liquidityProviders.connect(elon).addTokenLiquidity(token.address, 500 - 25)).to.not.be.reverted;
    });

    it("Should prevent institutional investors from exceeding institutional cap", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 500)).to.not.be.reverted;
      await expect(liquidityProviders.connect(elon).addTokenLiquidity(token.address, 500 - 25 + 1)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_ITC"
      );
    });

    it("Should prevent institutional investors from increasing liquidity on same nft exceeding institutional cap", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 500)).to.not.be.reverted;
      await expect(liquidityProviders.connect(dan).increaseTokenLiquidity(1, 500 - 25 + 1)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_ITC"
      );
    });

    it("Should prevent Community LPs from exceeding total cap", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25)).to.not.be.reverted;
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 10)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_PTTC"
      );
    });

    it("Should prevent Community LPs from exceeding total cap when adding liquidity to same NFT", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25)).to.not.be.reverted;
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 5)).to.not.be.reverted;
      await expect(liquidityProviders.connect(charlie).increaseTokenLiquidity(4, 1)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_PTTC"
      );
    });

    it("Should prevent Community LPs from exceeding total cap - 2", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25)).to.not.be.reverted;
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 5)).to.not.be.reverted;
      await expect(liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 1)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_PTTC"
      );
    });

    it("Should prevent Institutional LPs from exceeding total cap", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 5)).to.not.be.reverted;
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25 + 1)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_PTTC"
      );
    });

    it("Should prevent Institutional LPs from exceeding total cap via liquidity addition to same NFT", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 5)).to.not.be.reverted;
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25)).to.not.be.reverted;
      await expect(liquidityProviders.connect(dan).increaseTokenLiquidity(4, 1)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_PTTC"
      );
    });

    it("Should prevent Institutional LPs from exceeding total cap - 2", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 5)).to.not.be.reverted;
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25)).to.not.be.reverted;
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_PTTC"
      );
    });

    it("Should allow Community LPs to add more liquidity within cap after removing", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await liquidityProviders.decreaseLiquidity(1, 5);
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 5)).to.not.be.reverted;
    });

    it("Should allow Institutions to add more liquidity within cap after removing", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25)).to.not.be.reverted;
      await liquidityProviders.connect(dan).decreaseLiquidity(1, 500);
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 500)).to.not.be.reverted;
    });

    it("Should allow Institutions to add more liquidity to same NFT within cap after removing", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25)).to.not.be.reverted;
      await liquidityProviders.connect(dan).decreaseLiquidity(1, 500);
      await expect(liquidityProviders.connect(dan).increaseTokenLiquidity(1, 500)).to.not.be.reverted;
    });

    it("Should allow One Institution to take another institution's share after 1st has removed", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25)).to.not.be.reverted;
      await liquidityProviders.connect(dan).decreaseLiquidity(1, 500);
      await expect(liquidityProviders.connect(elon).addTokenLiquidity(token.address, 500)).to.not.be.reverted;
    });

    it("Should allow community LPs to add more Liquidity after transferring their NFT", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await lpToken.transferFrom(owner.address, bob.address, 1);
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
    });

    it("Should allow Institutions to add more Liquidity after transferring their NFT", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 500)).to.not.be.reverted;
      await lpToken.connect(dan).transferFrom(dan.address, elon.address, 1);
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 400)).to.not.be.reverted;
    });

    it("Should block NFT receiver's limit for adding liquidity", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await lpToken.transferFrom(owner.address, bob.address, 1);
      await expect(liquidityProviders.connect(bob).increaseTokenLiquidity(1, 10)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_CPWC"
      );
    });

    it("Should block NFT receiver's limit for adding liquidity - 2", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 5)).to.not.be.reverted;
      await lpToken.transferFrom(owner.address, bob.address, 1);
      await expect(liquidityProviders.connect(bob).increaseTokenLiquidity(1, 5)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).increaseTokenLiquidity(1, 1)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_CPWC"
      );
    });

    it("Should block NFT receiver's limit for adding liquidity - 3", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 500)).to.not.be.reverted;
      await lpToken.connect(dan).transferFrom(dan.address, elon.address, 1);
      await expect(liquidityProviders.connect(elon).increaseTokenLiquidity(1, 500 - 25 + 1)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_ITC"
      );
    });

    it("Should prevent NFT transfer if receiver's limit is exhaused", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 5)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 6)).to.not.be.reverted;
      await expect(lpToken.transferFrom(owner.address, bob.address, 1)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_CPWC"
      );
    });

    it("Should prevent NFT transfer if receiver's limit is exhaused - 2", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 1)).to.not.be.reverted;
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25)).to.not.be.reverted;
      await expect(lpToken.transferFrom(owner.address, dan.address, 1)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_ITC"
      );
    });
  });

  describe("Cap Manipulation", async function () {
    this.beforeEach(async function () {
      await wlpm.setInstitutionalLpStatus([dan.address, elon.address], [true, true]);
      await wlpm.setCaps([token.address], [1000], [25], [10]);
    });

    it("Should prevent setting community cap below current community contribution", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 5)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 6)).to.not.be.reverted;
      await expect(wlpm.setCommunityCap(token.address, 11)).to.not.be.reverted;
      await expect(wlpm.setCommunityCap(token.address, 10)).to.be.revertedWith("ERR__TOTAL_CAP_LESS_THAN_CSL");
    });

    it("Should prevent setting community cap above institution contribution", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 400)).to.not.be.reverted;
      await expect(liquidityProviders.connect(elon).addTokenLiquidity(token.address, 300)).to.not.be.reverted;
      await expect(wlpm.setCommunityCap(token.address, 300)).to.not.be.reverted;
      await expect(wlpm.setCommunityCap(token.address, 301)).to.be.revertedWith("ERR__COMM_CAP_EXCEEDS_AVAILABLE");
    });

    it("Should prevent setting total cap below total contribution", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 400)).to.not.be.reverted;
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(wlpm.setTotalCap(token.address, 410)).to.not.be.reverted;
      await expect(wlpm.setTotalCap(token.address, 409)).to.be.revertedWith("ERR__TOTAL_CAP_LESS_THAN_SL");
    });

    it("Should allow community member to add more liquidity after increasing per wallet cap", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).increaseTokenLiquidity(2, 5)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_CPWC"
      );
      await wlpm.setPerWalletCapForCommunityLp(token.address, 13);
      await expect(liquidityProviders.connect(owner).increaseTokenLiquidity(1, 3)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).increaseTokenLiquidity(2, 2)).to.not.be.reverted;
    });

    it("Should allow community member to add more liquidity after increasing community cap", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 5)).to.not.be.reverted;
      await expect(liquidityProviders.connect(charlie).increaseTokenLiquidity(3, 5)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_CTC"
      );
      await wlpm.setCommunityCap(token.address, 30);
      await expect(liquidityProviders.connect(charlie).increaseTokenLiquidity(3, 5)).to.not.be.reverted;
    });

    it("Should allow institutions to add more LP after decreasing community cap", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 500)).to.not.be.reverted;
      await expect(liquidityProviders.connect(elon).addTokenLiquidity(token.address, 500 - 25)).to.not.be.reverted;
      await expect(liquidityProviders.connect(dan).increaseTokenLiquidity(1, 10)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_ITC"
      );
      await wlpm.setCommunityCap(token.address, 10);
      await expect(liquidityProviders.connect(dan).increaseTokenLiquidity(1, 10)).to.not.be.reverted;
    });
  });

  describe("Max Community LP", async function () {
    this.beforeEach(async function () {
      await wlpm.setInstitutionalLpStatus([dan.address, elon.address], [true, true]);
      await wlpm.setCaps([token.address], [1000], [300], [100]);
    });

    it("Should return correct max community lp value", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      expect(await wlpm.getMaxCommunityLpPositon(token.address)).to.equal(10);
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 30)).to.not.be.reverted;
      expect(await wlpm.getMaxCommunityLpPositon(token.address)).to.equal(30);
      await expect(liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 50)).to.not.be.reverted;
      expect(await wlpm.getMaxCommunityLpPositon(token.address)).to.equal(50);
      await expect(liquidityProviders.connect(bob).increaseTokenLiquidity(2, 25)).to.not.be.reverted;
      expect(await wlpm.getMaxCommunityLpPositon(token.address)).to.equal(55);
      await expect(liquidityProviders.connect(bob).decreaseLiquidity(2, 40)).to.not.be.reverted;
      expect(await wlpm.getMaxCommunityLpPositon(token.address)).to.equal(50);
      await expect(liquidityProviders.connect(charlie).decreaseLiquidity(3, 25)).to.not.be.reverted;
      expect(await wlpm.getMaxCommunityLpPositon(token.address)).to.equal(25);
      await expect(liquidityProviders.connect(charlie).decreaseLiquidity(3, 25)).to.not.be.reverted;
      expect(await wlpm.getMaxCommunityLpPositon(token.address)).to.equal(15);
    });
  });
});
