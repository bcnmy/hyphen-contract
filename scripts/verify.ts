import { run, ethers } from "hardhat";

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
  executorManagerAddress: string,
  tokenManagerAddress: string,
  lpTokenAddress: string,
  liquidityProvidersAddress: string,
  liquidityPoolAddress: string,
  whitelistPeriodManagerAddres: string,
  config: { trustedForwarder: string; pauser: string }
) => {
  console.log("Verifying Contracts...");
  await Promise.all([
    verifyContract(executorManagerAddress, []),
    verifyContract(tokenManagerAddress, [config.trustedForwarder]),
    verifyImplementation(lpTokenAddress),
    verifyImplementation(liquidityProvidersAddress),
    verifyImplementation(liquidityPoolAddress),
    verifyImplementation(whitelistPeriodManagerAddres),
  ]);
};

export { verify };
