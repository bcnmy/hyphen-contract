import { ethers } from "hardhat";
import { deploy } from "./deploy";
import { verify } from "./verify";
import { addTokenSupport } from "./add-token-support";

const addresses = {
  trustedForwarder: "0x9399BB24DBB5C4b782C70c2969F58716Ebbd6a3b",
  bicoOwner: "0xe0E67a6F478D7ED604Cf528bDE6C3f5aB034b59D",
  pauser: "0xe0E67a6F478D7ED604Cf528bDE6C3f5aB034b59D",
  tokens: [
    {
      tokenAddress: "0xeabc4b91d9375796aa4f69cc764a4ab509080a58",
      minCap: ethers.BigNumber.from(10).pow(18 + 2),
      maxCap: ethers.BigNumber.from(10).pow(18 + 4),
      equilibriumFee: 0,
      maxFee: 100,
      toChainIds: [5, 43113],
    },
    {
      tokenAddress: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      minCap: ethers.BigNumber.from(10).pow(18 - 2),
      maxCap: ethers.BigNumber.from(10).pow(18 + 2),
      equilibriumFee: 0,
      maxFee: 100,
      toChainIds: [5, 43113],
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
