import { ethers } from "hardhat";
import { deploy } from "./deploy";
import { verify } from "./verify";
import { addTokenSupport } from "./add-token-support";

const addresses = {
  trustedForwarder: "0x6271Ca63D30507f2Dcbf99B52787032506D75BBF",
  bicoOwner: "0xe0E67a6F478D7ED604Cf528bDE6C3f5aB034b59D",
  pauser: "0xe0E67a6F478D7ED604Cf528bDE6C3f5aB034b59D",
  tokens: [
    {
      tokenAddress: "0xB4E0F6FEF81BdFea0856bB846789985c9CFf7e85",
      minCap: ethers.BigNumber.from(10).pow(18 + 2),
      maxCap: ethers.BigNumber.from(10).pow(18 + 4),
      equilibriumFee: 0,
      maxFee: 100,
      toChainIds: [5, 80001],
    },
    {
      tokenAddress: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      minCap: ethers.BigNumber.from(10).pow(18 - 2),
      maxCap: ethers.BigNumber.from(10).pow(18 + 2),
      equilibriumFee: 0,
      maxFee: 100,
      toChainIds: [5, 80001],
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
