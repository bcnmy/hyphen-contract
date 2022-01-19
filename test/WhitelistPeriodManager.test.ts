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
import { BigNumber, ContractTransaction } from "ethers";

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

    it("Should prevent Community LPs from exceeding per wallet cap", async function () {
      await expect(liquidityProviders.addTokenLiquidity(token.address, 11)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_CPWC"
      );
    });

    it("Should prevent multiple Community LPs to exceed global community cap", async function () {
      await liquidityProviders.addTokenLiquidity(token.address, 9);
      await liquidityProviders.connect(bob).addTokenLiquidity(token.address, 9);
      await expect(liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 9)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_CTC"
      );
    });

    it("Should allow institutional investors to add liquidity within cap", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25)).to.not.be.reverted;
    });

    it("Should allow institutional investors to add liquidity within cap - 2", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 500)).to.not.be.reverted;
      await expect(liquidityProviders.connect(elon).addTokenLiquidity(token.address, 500 - 25)).to.not.be.reverted;
    });

    it("Should prevent institutional investors from exceeding institutional cap", async function () {
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 500)).to.not.be.reverted;
      await expect(liquidityProviders.connect(elon).addTokenLiquidity(token.address, 500 - 25 + 1)).to.be.revertedWith(
        "ERR_LIQUIDITY_EXCEEDS_ITC"
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

    it("Should prevent Institutional LPs from exceeding total cap - 2", async function () {
      await expect(liquidityProviders.connect(owner).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(bob).addTokenLiquidity(token.address, 10)).to.not.be.reverted;
      await expect(liquidityProviders.connect(charlie).addTokenLiquidity(token.address, 5)).to.not.be.reverted;
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1000 - 25)).to.not.be.reverted;
      await expect(liquidityProviders.connect(dan).addTokenLiquidity(token.address, 1)).to.be.revertedWith(
        "ERR__LIQUIDITY_EXCEEDS_PTTC"
      );
    });
  });
});
