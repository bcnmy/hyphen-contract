import { run, ethers, upgrades } from "hardhat";
import {
  LiquidityPool,
  LPToken,
  WhitelistPeriodManager,
  LiquidityProviders,
  TokenManager,
  ExecutorManager,
  SvgHelperBase,
  HyphenLiquidityFarming,
  // eslint-disable-next-line node/no-missing-import
} from "../typechain";
import type { BigNumberish, ContractFactory } from "ethers";

const LPTokenName = "Hyphen Liquidity Token";
const LPTokenSymbol = "Hyphen-LP";

interface IAddTokenParameters {
  tokenAddress: string;
  minCap: BigNumberish;
  maxCap: BigNumberish;
  depositConfigs: { chainId: number; minCap: BigNumberish; maxCap: BigNumberish }[];
  equilibriumFee: BigNumberish;
  maxFee: BigNumberish;
  transferOverhead: BigNumberish;
  maxWalletLiquidityCap: BigNumberish;
  maxLiquidityCap: BigNumberish;
  svgHelper: ContractFactory;
  decimals: number;
  rewardTokenAddress: string;
  rewardRatePerSecond: BigNumberish;
}

interface IContracts {
  liquidityProviders: LiquidityProviders;
  lpToken: LPToken;
  tokenManager: TokenManager;
  liquidityPool: LiquidityPool;
  whitelistPeriodManager: WhitelistPeriodManager;
  executorManager: ExecutorManager;
  liquidityFarming: HyphenLiquidityFarming;
  svgHelperMap: Record<string, SvgHelperBase>;
}
interface IDeployConfig {
  trustedForwarder: string;
  bicoOwner: string;
  pauser: string;
  tokens: IAddTokenParameters[];
}

const wait = (time: number) : Promise<void> => {
  return new Promise((resolve)=>{
    setTimeout(resolve, time);
  });
}


const deploy = async (deployConfig: IDeployConfig) => {
  const contracts = await deployCoreContracts(deployConfig.trustedForwarder, deployConfig.pauser);

  // const contracts: IContracts = {
  //   executorManager: await ethers.getContractAt("ExecutorManager","0xbd761D917fB77381B4398Bda89C7F0d9A2BD1399"),
  //   tokenManager: await ethers.getContractAt("TokenManager","0xd8Ce41FDF0fE96ea4F457d2A22faAF1d128C0954"),
  //   lpToken: await ethers.getContractAt("LPToken", "0xc49B65e5a350292Afda1f239eBefE562668717c2"),
  //   liquidityProviders: await ethers.getContractAt("LiquidityProviders", "0xebaB24F13de55789eC1F3fFe99A285754e15F7b9"),
  //   liquidityPool: await ethers.getContractAt("LiquidityPool", "0x2A5c2568b10A0E826BfA892Cf21BA7218310180b"),
  //   liquidityFarming: await ethers.getContractAt("HyphenLiquidityFarming", "0x781f4EfC37a08C0ea6631204E46B206330c8c161"),
  //   whitelistPeriodManager: await ethers.getContractAt("WhitelistPeriodManager","0x684F574CA8C6b52C2b713ad1D1eAcDDF3976e7EB"),
  //   svgHelperMap: {
  //     "0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664" : await ethers.getContractAt("SvgHelperBase", "0x0f66A75E8FB3980019d4DD8496c1A24efe4E0D89"),
  //     "0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB" : await ethers.getContractAt("SvgHelperBase", "0x5F59206E2965D91a535Ac904F40193aC94365556")
  //   }
  // }
  for (const token of deployConfig.tokens) {
    await addTokenSupport(contracts, token);
    contracts.svgHelperMap[token.tokenAddress] = await deploySvgHelper(
      contracts.lpToken,
      token,
      deployConfig.bicoOwner
    );
  }

  console.log(
    "Deployed contracts:",
    JSON.stringify(
      {
        ...Object.fromEntries(
          Object.entries(contracts)
            .filter(([name]) => name !== "svgHelperMap")
            .map(([name, contract]) => [name, contract.address])
        ),
        svgHelpers: Object.fromEntries(
          Object.entries(contracts.svgHelperMap).map(([name, contract]) => [name, contract.address])
        ),
      },
      null,
      2
    )
  );

  await configure(contracts, deployConfig.bicoOwner);
  await verify(contracts, deployConfig);
};

async function deployCoreContracts(trustedForwarder: string, pauser: string): Promise<IContracts> {
  const [deployer] = await ethers.getSigners();

  console.log("Deployer:", deployer.address);

  const ExecutorManager = await ethers.getContractFactory("ExecutorManager");
  console.log("Deploying ExecutorManager...");
  const executorManager = await ExecutorManager.deploy();
  await executorManager.deployed();
  console.log("ExecutorManager deployed to:", executorManager.address);
  await wait(5000);
  const TokenManager = await ethers.getContractFactory("TokenManager");
  console.log("Deploying TokenManager...");
  const tokenManager = await TokenManager.deploy(trustedForwarder);
  await tokenManager.deployed();
  console.log("TokenManager deployed to:", tokenManager.address);

  await wait(5000);
  const LPToken = await ethers.getContractFactory("LPToken");
  console.log("Deploying LPToken...");
  const lpToken = (await upgrades.deployProxy(LPToken, [
    LPTokenName,
    LPTokenSymbol,
    trustedForwarder,
    pauser,
  ])) as LPToken;
  await lpToken.deployed();
  console.log("LPToken Proxy deployed to:", lpToken.address);

  await wait(5000);
  const LiquidityProviders = await ethers.getContractFactory("LiquidityProviders");
  console.log("Deploying LiquidityProviders...");
  const liquidityProviders = (await upgrades.deployProxy(LiquidityProviders, [
    trustedForwarder,
    lpToken.address,
    tokenManager.address,
    pauser,
  ])) as LiquidityProviders;
  await liquidityProviders.deployed();
  console.log("LiquidityProviders Proxy deployed to:", liquidityProviders.address);

  await wait(5000);
  const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
  console.log("Deploying LiquidityPool...");
  const liquidityPool = (await upgrades.deployProxy(LiquidityPool, [
    executorManager.address,
    pauser,
    trustedForwarder,
    tokenManager.address,
    liquidityProviders.address,
  ])) as LiquidityPool;
  await liquidityPool.deployed();
  console.log("LiquidityPool Proxy deployed to:", liquidityPool.address);

  await wait(5000);
  const WhitelistPeriodManager = await ethers.getContractFactory("WhitelistPeriodManager");
  console.log("Deploying WhitelistPeriodManager...");
  const whitelistPeriodManager = (await upgrades.deployProxy(WhitelistPeriodManager, [
    trustedForwarder,
    liquidityProviders.address,
    tokenManager.address,
    lpToken.address,
    pauser,
  ])) as WhitelistPeriodManager;
  await whitelistPeriodManager.deployed();
  console.log("WhitelistPeriodManager Proxy deployed to:", whitelistPeriodManager.address);

  await wait(5000);
  const LiquidityFarmingFactory = await ethers.getContractFactory("HyphenLiquidityFarming");
  console.log("Deploying LiquidityFarmingFactory...");
  const liquidityFarming = (await upgrades.deployProxy(LiquidityFarmingFactory, [
    trustedForwarder,
    pauser,
    liquidityProviders.address,
    lpToken.address,
  ])) as HyphenLiquidityFarming;
  await liquidityFarming.deployed();
  console.log("LiquidityFarmingFactory Proxy deployed to:", liquidityFarming.address);
  await wait(5000);
  await (await whitelistPeriodManager.setIsExcludedAddressStatus([liquidityFarming.address], [true])).wait();

  return {
    executorManager,
    tokenManager,
    lpToken,
    liquidityProviders,
    liquidityPool,
    whitelistPeriodManager,
    liquidityFarming,
    svgHelperMap: {},
  };
}

const deploySvgHelper = async (
  lpToken: LPToken,
  token: IAddTokenParameters,
  bicoOwner: string
): Promise<SvgHelperBase> => {
  console.log(`Deploying SVG helper for token ${token.tokenAddress}...`);
  const svgHelper = (await token.svgHelper.deploy([token.decimals])) as SvgHelperBase;
  await svgHelper.deployed();
  await (await lpToken.setSvgHelper(token.tokenAddress, svgHelper.address)).wait();
  await (await svgHelper.transferOwnership(bicoOwner)).wait();
  console.log("SvgHelper deployed to:", svgHelper.address);
  return svgHelper;
};

const configure = async (contracts: IContracts, bicoOwner: string) => {
  await wait(5000);
  await (await contracts.liquidityProviders.setTokenManager(contracts.tokenManager.address)).wait();
  await wait(5000);
  await (await contracts.liquidityProviders.setLiquidityPool(contracts.liquidityPool.address)).wait();
  await wait(5000);
  await (await contracts.liquidityProviders.setWhiteListPeriodManager(contracts.whitelistPeriodManager.address)).wait();

  console.log("Configured LiquidityProviders");
  await wait(5000);
  await (await contracts.lpToken.setLiquidityProviders(contracts.liquidityProviders.address)).wait();
  await wait(5000);
  await (await contracts.lpToken.setWhiteListPeriodManager(contracts.whitelistPeriodManager.address)).wait();
  await wait(5000);
  console.log("Configured LPToken");

  await (await contracts.tokenManager.transferOwnership(bicoOwner)).wait();
  await wait(5000);
  await (await contracts.lpToken.transferOwnership(bicoOwner)).wait();
  await wait(5000);
  await (await contracts.executorManager.transferOwnership(bicoOwner)).wait();
  await wait(5000);
  await (await contracts.liquidityProviders.transferOwnership(bicoOwner)).wait();
  await wait(5000);
  await (await contracts.liquidityPool.transferOwnership(bicoOwner)).wait();
  await wait(5000);
  await (await contracts.whitelistPeriodManager.transferOwnership(bicoOwner)).wait();


  console.log(`Transferred Ownership to ${bicoOwner}`);
};

const addTokenSupport = async (contracts: IContracts, token: IAddTokenParameters) => {
  // Add support for token
  console.log(`Adding token support for ${token.tokenAddress}...`);
  await (
    await contracts.tokenManager.addSupportedToken(
      token.tokenAddress,
      token.minCap,
      token.maxCap,
      token.equilibriumFee,
      token.maxFee,
      token.transferOverhead
    )
  ).wait();

  let chainIdArray = [];
  let minMaxArray = [];
  for (let index = 0; index < token.depositConfigs.length; index++) {
    let entry = token.depositConfigs[index];
    chainIdArray.push(entry.chainId);
    minMaxArray.push({ min: entry.minCap, max: entry.maxCap });
  }

  console.log(`Setting Deposit Config for ${token.tokenAddress}...`);
  await (
    await contracts.tokenManager.setDepositConfig(
      chainIdArray,
      new Array(chainIdArray.length).fill(token.tokenAddress),
      minMaxArray
    )
  ).wait();

  console.log(`Setting Whitelist Period Fee Config for ${token.tokenAddress}...`);
  await (
    await contracts.whitelistPeriodManager.setCap(
      token.tokenAddress,
      token.maxLiquidityCap,
      token.maxWalletLiquidityCap
    )
  ).wait();

  console.log(`Initializing reward pool for ${token.tokenAddress}...`);
  await (
    await contracts.liquidityFarming.initalizeRewardPool(
      token.tokenAddress,
      token.rewardTokenAddress,
      token.rewardRatePerSecond
    )
  ).wait();

  console.log("Added token support for", token.tokenAddress);
};

const getImplementationAddress = async (proxyAddress: string) => {
  return ethers.utils.hexlify(
    ethers.BigNumber.from(
      await ethers.provider.send("eth_getStorageAt", [
        proxyAddress,
        "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
        "latest",
      ])
    )
  );
};

const verifyContract = async (address: string, constructorArguments: any[]) => {
  try {
    await run("verify:verify", {
      address,
      constructorArguments,
    });
  } catch (e) {
    console.log(`Failed to verify Contract ${address} `, e);
  }
};

const verifyImplementation = async (address: string) => {
  try {
    await run("verify:verify", {
      address: await getImplementationAddress(address),
    });
  } catch (e) {
    console.log(`Failed to verify Contract ${address} `, e);
  }
};

const verify = async (
  contracts: IContracts,
  config: { trustedForwarder: string; pauser: string; tokens: IAddTokenParameters[] }
) => {
  console.log("Verifying Contracts...");
  for (const token of config.tokens) {
    await verifyContract(contracts.svgHelperMap[token.tokenAddress].address, [token.decimals]);
  }
  await verifyContract(contracts.executorManager.address, []);
  await verifyContract(contracts.tokenManager.address, [config.trustedForwarder]);
  await verifyImplementation(contracts.lpToken.address);
  await verifyImplementation(contracts.liquidityProviders.address);
  await verifyImplementation(contracts.liquidityPool.address);
  await verifyImplementation(contracts.whitelistPeriodManager.address);
  await verifyImplementation(contracts.liquidityFarming.address);
};

export {
  deployCoreContracts as deployContracts,
  configure,
  addTokenSupport,
  verify,
  deploy,
  verifyContract,
  verifyImplementation,
  IDeployConfig,
};
