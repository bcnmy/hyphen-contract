import { ethers } from "hardhat";
import { deploy } from "./deploy";
import { verify } from "./verify";
import { addTokenSupport } from "./add-token-support";

const addresses = {
  trustedForwarder: "0xE041608922d06a4F26C0d4c27d8bCD01daf1f792",
  bicoOwner: "0xe0E67a6F478D7ED604Cf528bDE6C3f5aB034b59D",
  pauser: "0xe0E67a6F478D7ED604Cf528bDE6C3f5aB034b59D",
  tokens: [
    {
      tokenAddress: "0x64ef393b6846114bad71e2cb2ccc3e10736b5716",
      minCap: ethers.BigNumber.from(10).pow(18 + 2),
      maxCap: ethers.BigNumber.from(10).pow(18 + 4),
      equilibriumFee: 0,
      maxFee: 100,
      toChainIds: [43113, 80001],
    },
    {
      tokenAddress: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      minCap: ethers.BigNumber.from(10).pow(18 - 2),
      maxCap: ethers.BigNumber.from(10).pow(18 + 2),
      equilibriumFee: 0,
      maxFee: 100,
      toChainIds: [43113, 80001],
    },
  ],
};

(async () => {
  const {
    executorManagerAddress,
    tokenManagerAddress,
    liquidityPoolAddress,
    lpTokenAddress,
    liquidityProvidersAddress,
    whitelistPeriodManagerAddress,
  } = await deploy(addresses.bicoOwner, addresses.trustedForwarder, addresses.pauser);

  for (const { tokenAddress, minCap, maxCap, equilibriumFee, maxFee, toChainIds } of addresses.tokens) {
    await addTokenSupport(tokenManagerAddress, tokenAddress, minCap, maxCap, equilibriumFee, maxFee, toChainIds);
  }

  await verify(
    executorManagerAddress,
    tokenManagerAddress,
    lpTokenAddress,
    liquidityPoolAddress,
    liquidityProvidersAddress,
    whitelistPeriodManagerAddress,
    addresses
  );
})();
