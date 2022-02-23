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
  EthereumEthSVG,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";

let { getLocaleString } = require("./utils");

describe("NftSvgTests", function () {
  let owner: SignerWithAddress, pauser: SignerWithAddress, bob: SignerWithAddress;
  let charlie: SignerWithAddress, tf: SignerWithAddress, executor: SignerWithAddress;
  let token: ERC20Token, token2: ERC20Token;
  let lpToken: LPToken;
  let wlpm: WhitelistPeriodManager;
  let liquidityProviders: LiquidityProvidersTest;
  let liquidityPool: LiquidityPool;
  let executorManager: ExecutorManager;
  let tokenManager: TokenManager;
  let ethereumEthSvg: EthereumEthSVG;
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
    tokenManager = await tokenManagerFactory.deploy(tf.address);

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
    executorManager = await executorManagerFactory.deploy();

    const lpTokenFactory = await ethers.getContractFactory("LPToken");
    lpToken = (await upgrades.deployProxy(lpTokenFactory, [
      "LPToken",
      "LPToken",
      tf.address,
      pauser.address,
    ])) as LPToken;

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
    await lpToken.setLiquidtyProviders(liquidityProviders.address);

    const ethereumEthSvgFactory = await ethers.getContractFactory("EthereumEthSVG");
    ethereumEthSvg = (await upgrades.deployProxy(ethereumEthSvgFactory, [
      18,
      "https://gateway.pinata.cloud/ipfs/QmXKVXRM3PJLo19v74f925Mj7eb1Q3hNbHKkqr1hhNrEfH",
    ])) as EthereumEthSVG;
  });

  this.afterEach(async function () {
    expect(await token.balanceOf(liquidityProviders.address)).to.equal(0);
    expect(await token2.balanceOf(liquidityProviders.address)).to.equal(0);
    expect(await ethers.provider.getBalance(liquidityProviders.address)).to.equal(0);
  });

  it("Should divide by 100 correctly", async function () {
    for (let i = 0; i < 1000; i++) {
      expect(await ethereumEthSvg.divideByPowerOf10(i, 2, 2)).to.equal(
        (i / 100).toLocaleString("en-us", { maximumFractionDigits: 2 })
      );
    }
  });

  it("Should divide by 100000 correctly", async function () {
    for (let i = 1000; i < 5000; i++) {
      expect(await ethereumEthSvg.divideByPowerOf10(i, 5, 4)).to.equal(ethers.utils.formatUnits(i, 5));
    }
  });
});
