import { deploy } from "./deploy";
import { verify } from "./verify";

const addresses = {
  trustedForwarder: "0x3D1D6A62c588C1Ee23365AF623bdF306Eb47217A",
  bicoOwner: "0x0000000000000000000000000000000000000001",
  pauser: "0x0000000000000000000000000000000000000001",
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
