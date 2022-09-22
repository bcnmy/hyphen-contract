import { setTokenConfig } from "../add-supported-token";
import { getBackendConfig } from "../utils";

(async () => {
  let tokenConfig = [
    // USDT
    [
      {
        "tokenSymbol": "USDT",
        "decimal": 6,
        "chainId": 42161,
        "tokenAddress": "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9"
      },
      {
        "tokenSymbol": "USDT",
        "decimal": 6,
        "chainId": 250,
        "tokenAddress": "0x049d68029688eabf473097a2fc38ef61633a3c7a"
      }
    ]
  ];

  setTokenConfig(tokenConfig, getBackendConfig("prod"));
})();
