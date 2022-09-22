import { setTokenConfig } from "../add-supported-token";
import { getBackendConfig } from "../utils";

(async () => {
  let tokenConfig = [
    // USDC 
    [
      {
        "tokenSymbol": "MATIC",
        "decimal": 18,
        "chainId": 1,
        "tokenAddress": "0x7d1afa7b718fb893db30a3abc0cfc608aacfebb0",
      },
      {
        "tokenSymbol": "MATIC",
        "decimal": 18,
        "chainId": 137,
        "tokenAddress": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      },
    ],
    [
      {
        "tokenSymbol": "USDT",
        "decimal": 6,
        "chainId": 1,
        "tokenAddress": "0xdac17f958d2ee523a2206206994597c13d831ec7",
      },
      {
        "tokenSymbol": "USDT",
        "decimal": 6,
        "chainId": 250,
        "tokenAddress": "0x049d68029688eabf473097a2fc38ef61633a3c7a",
      },
    ],
    [
      {
        "tokenSymbol": "USDT",
        "decimal": 6,
        "chainId": 1,
        "tokenAddress": "0xdac17f958d2ee523a2206206994597c13d831ec7",
      },
      {
        "tokenSymbol": "USDT",
        "decimal": 6,
        "chainId": 43114,
        "tokenAddress": "0xc7198437980c041c805a1edcba50c1ce5db95118",
      },
    ],
    [
      {
        "tokenSymbol": "USDT",
        "decimal": 6,
        "chainId": 1,
        "tokenAddress": "0xdac17f958d2ee523a2206206994597c13d831ec7",
      },
      {
        "tokenSymbol": "USDT",
        "decimal": 6,
        "chainId": 10,
        "tokenAddress": "0x94b008aa00579c1307b0ef2c499ad98a8ce58e58",
      },
    ],
    [
      {
        "tokenSymbol": "USDT",
        "decimal": 6,
        "chainId": 1,
        "tokenAddress": "0xdac17f958d2ee523a2206206994597c13d831ec7",
      },
      {
        "tokenSymbol": "USDT",
        "decimal": 6,
        "chainId": 42161,
        "tokenAddress": "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9",
      },
    ]
  ];

  setTokenConfig(tokenConfig, getBackendConfig("prod"));
})();
