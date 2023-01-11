import { setTokenConfig } from "../add-supported-token";
import { getBackendConfig } from "../utils";

(async () => {
  let tokenConfig = [
    // USDC 
    [
      {
        tokenSymbol: "MATIC",
        decimal: 18,
        chainId: 5,
        tokenAddress: "0xA4CBb208e19d528b1eB972590bD434E002A3Af0e",
      },
      {
        tokenSymbol: "MATIC",
        decimal: 18,
        chainId: 80001,
        tokenAddress: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      },
    ],
  ];

  setTokenConfig(tokenConfig, getBackendConfig("staging"));
})();
