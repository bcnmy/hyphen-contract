import { setTokenConfig } from "../add-supported-token";
import { getBackendConfig } from "../utils";

(async () => {
  let tokenConfig = [
    // USDC 
    [
      {
        tokenSymbol: "MATIC",
        decimal: 18,
        chainId: 1,
        tokenAddress: "0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0",
      },
      {
        tokenSymbol: "MATIC",
        decimal: 18,
        chainId: 137,
        tokenAddress: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      },
    ],
  ];

  setTokenConfig(tokenConfig, getBackendConfig("prod"));
})();
