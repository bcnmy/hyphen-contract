import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { Signer } from "ethers";
import type {
  BToken,
  DepositPool,
  ERC20Upgradeable,
  IUniswapV2Router02,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";

type SignerWithAddress = Signer & { address: string };

describe("TrustlessDepositPoolTests", function () {
  let alice: SignerWithAddress,
    bob: SignerWithAddress,
    charlie: SignerWithAddress;
  let USDT: ERC20Upgradeable, bUSDT: BToken, depositPool: DepositPool;
  const WETHAddress = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";

  before(async function () {
    [alice, bob, charlie] = await ethers.getSigners();

    USDT = (await ethers.getContractAt(
      "contracts/interfaces/IERC20.sol:IERC20",
      "0xdac17f958d2ee523a2206206994597c13d831ec7"
    )) as ERC20Upgradeable;

    console.log("Deploying Deposit Pool...");
    const depositPoolFactory = await ethers.getContractFactory("DepositPool");
    depositPool = (await upgrades.deployProxy(depositPoolFactory, [
      charlie.address,
    ])) as DepositPool;
    await depositPool.deployed();
    console.log(`DepositPool deployed at: ${depositPool.address}`);

    console.log("Deploying bUSDT...");
    const bUSDTFactory = await ethers.getContractFactory("bToken");
    bUSDT = (await upgrades.deployProxy(bUSDTFactory, [
      "bUSDT",
      "bUSDT",
      18,
      USDT.address,
      charlie.address,
      depositPool.address,
      depositPool.address,
    ])) as BToken;
    await bUSDT.deployed();
    console.log(`bUSDT deployed at: ${bUSDT.address}`);

    console.log("Swapping ETH for USDT...");

    const uniswapRouter = (await ethers.getContractAt(
      "IUniswapV2Router02",
      "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"
    )) as IUniswapV2Router02;
    await uniswapRouter
      .connect(bob)
      .swapExactETHForTokens(
        0,
        [WETHAddress, USDT.address],
        await bob.getAddress(),
        "1000000000000000000000000",
        {
          value: ethers.utils.parseEther("1000").toString(),
        }
      );
  });

  it("Should Deploy Deposit Pool Correctly", async function () {
    expect(await depositPool.owner()).to.equal(alice.address);
  });

  it("Should register token correctly", async function () {
    await depositPool.connect(alice).updateBToken(USDT.address, bUSDT.address);
    expect(await depositPool.baseAddressToBTokenAddress(USDT.address)).to.equal(
      bUSDT.address
    );
  });

  it("Should update executor metadata correctly", async function () {
    await depositPool.connect(bob).updateExecutorBaseUrl("bob.eth.limo");
    expect(await depositPool.getExecutorBaseUrl(bob.address)).to.equal(
      "bob.eth.limo"
    );
  });

  it("Should add executor stake correctly", async function () {
    const balance = await USDT.balanceOf(bob.address);

    console.log("Procesing USDT Approval...");
    await USDT.connect(bob).approve(depositPool.address, 0);
    await USDT.connect(bob).approve(depositPool.address, balance);

    console.log("Staking USDT...");
    await expect(async () => {
      await depositPool.connect(bob).addStake(USDT.address, balance);
    }).changeTokenBalances(USDT, [bUSDT, bob], [balance, -balance]);

    expect(await bUSDT.balanceOf(bob.address)).to.equal(balance);
    expect(
      await depositPool.getExecutorStake(bob.address, USDT.address)
    ).to.equal(balance);
  });

  it("Should remove stake correctly", async function () {
    const balance = await bUSDT.balanceOf(bob.address);
    console.log("Procesing bUSDT Approval...");
    await bUSDT.connect(bob).approve(depositPool.address, 0);
    await bUSDT.connect(bob).approve(depositPool.address, balance);

    console.log("Unstaking USDT...");
    await expect(async () => {
      await depositPool.connect(bob).removeStake(USDT.address, balance);
    }).changeTokenBalances(USDT, [bUSDT, bob], [-balance, +balance]);

    expect(await bUSDT.balanceOf(bob.address)).to.equal(0);
    expect(
      await depositPool.getExecutorStake(bob.address, USDT.address)
    ).to.equal(0);
  });

  it("Should slash stake correctly", async function () {
    const balance = await USDT.balanceOf(bob.address);

    console.log("Procesing USDT Approval...");
    await USDT.connect(bob).approve(depositPool.address, 0);
    await USDT.connect(bob).approve(depositPool.address, balance);

    console.log("Staking USDT...");
    await depositPool.connect(bob).addStake(USDT.address, balance);

    console.log("Slashing stake...");
    await depositPool
      .connect(alice)
      .slashStake(bob.address, USDT.address, balance);
  });

  it("Should prevent executors from removing stashed stake", async function () {
    const balance = await depositPool.slashedFundsBalance(USDT.address);

    await expect(
      depositPool.connect(bob).removeStake(USDT.address, balance)
    ).to.be.revertedWith("ERR_INSUFFICIENT_STAKE");
  });
});
