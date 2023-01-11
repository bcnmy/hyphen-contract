import { run, ethers, upgrades } from "hardhat";
import {
  ERC20Token,
  SvgHelperBase
} from "../../typechain";
import { BigNumberish, providers } from "ethers";
import type { ITokenConfig, ISvgToken } from "../types";

const deploy = async (deployConfig: ITokenConfig) => {
  
  let svgHelperMap: { [tokenAddress: string]: SvgHelperBase } = {};
  for (const token of deployConfig.svgToken) {
    svgHelperMap[token.tokenAddress] = await deploySvgHelper(
      token,
      deployConfig.bicoOwner
    );
    console.log(`${token.tokenAddress} => ${ svgHelperMap[token.tokenAddress]}`);
  }
  
  await verify(svgHelperMap, deployConfig);
};

const deploySvgHelper = async (
  token: ISvgToken,
  bicoOwner: string
): Promise<SvgHelperBase> => {
  console.log(`Deploying SVG helper for token ${token.tokenAddress}...`);
  const svgHelper = (await token.svgHelper.deploy([token.decimals])) as SvgHelperBase;
  console.log("SvgHelper deployed to:", svgHelper.address);
  await svgHelper.deployed();
  await (await svgHelper.transferOwnership(bicoOwner)).wait();
  console.log("Transfer ownership to:", bicoOwner);
  return svgHelper;
};

const getImplementationAddress = async (
  proxyAddress: string,
  provider: providers.JsonRpcProvider = ethers.provider
) => {
  return ethers.utils.hexlify(
    ethers.BigNumber.from(
      await provider.send("eth_getStorageAt", [
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
  svgHelperMap: { [tokenAddress: string]: SvgHelperBase },
  config: ITokenConfig
) => {
  console.log("Verifying Contracts...");
  for (const token of config.svgToken) {
    await verifyContract(svgHelperMap[token.tokenAddress].address, [token.decimals]);
  }
};

const deployToken = async (
  name: string,
  symbol: string,
  decimals: number,
  initialMintAddresses: string[],
  initialMintAmountPerAddress: BigNumberish
) => {
  const [signer] = await ethers.getSigners();
  const erc20factory = await ethers.getContractFactory("ERC20Token", signer);
  const token = (await upgrades.deployProxy(erc20factory, [name, symbol, decimals])) as ERC20Token;
  await token.deployed();
  console.log(`Deployed token ${name} at ${token.address}`);

  for (const address of initialMintAddresses) {
    await (await token.mint(address, initialMintAmountPerAddress)).wait();
    console.log(`Minted ${initialMintAmountPerAddress} ${name} to ${address}`);
  }

  await verifyImplementation(token.address);

  return token;
};

export {
  verify,
  deploy,
  verifyContract,
  verifyImplementation,
  getImplementationAddress,
  deployToken
};
