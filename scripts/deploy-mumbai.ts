import { deploy } from "./deploy";
import { verify } from "./verify";

const addresses = {
  trustedForwarder: "0x9399BB24DBB5C4b782C70c2969F58716Ebbd6a3b",
  bicoOwner: "0xE4F868C9Afeb08d29f37Ce1c831F5413bFf5Cc83",
  pauser: "0xE4F868C9Afeb08d29f37Ce1c831F5413bFf5Cc83",
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
