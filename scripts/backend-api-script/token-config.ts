import { setTokenConfig } from "./add-supported-token";
import { getBackendConfig } from "./utils";

(async () => {
  let tokenConfig = [
    // USDC 
    [
      {
        tokenSymbol: "USDC",
        decimal: 6,
        chainId: 1,
        tokenAddress: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
      },
      {
        tokenSymbol: "USDC",
        decimal: 6,
        chainId: 10,
        tokenAddress: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
      },
    ],
    [
      {
        tokenSymbol: "USDC",
        decimal: 6,
        chainId: 137,
        tokenAddress: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
      },
      {
        tokenSymbol: "USDC",
        decimal: 6,
        chainId: 10,
        tokenAddress: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
      },
    ],
    [
      {
        tokenSymbol: "USDC",
        decimal: 6,
        chainId: 43114,
        tokenAddress: "0xa7d7079b0fead91f3e65f86e8915cb59c1a4c664",
      },
      {
        tokenSymbol: "USDC",
        decimal: 6,
        chainId: 10,
        tokenAddress: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
      },
    ],
    [
      {
        tokenSymbol: "USDC",
        decimal: 18,
        chainId: 56,
        tokenAddress: "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d",
      },
      {
        tokenSymbol: "USDC",
        decimal: 6,
        chainId: 10,
        tokenAddress: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
      },
    ],
    // BICO
    [
      {
        tokenSymbol: "BICO",
        decimal: 18,
        chainId: 1,
        tokenAddress: "0xf17e65822b568b3903685a7c9f496cf7656cc6c2",
      },
      {
        tokenSymbol: "BICO",
        decimal: 18,
        chainId: 10,
        tokenAddress: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
      },
    ],
    [
      {
        tokenSymbol: "BICO",
        decimal: 18,
        chainId: 137,
        tokenAddress: "0x91c89A94567980f0e9723b487b0beD586eE96aa7",
      },
      {
        tokenSymbol: "BICO",
        decimal: 18,
        chainId: 10,
        tokenAddress: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
      },
    ],
    [
      {
        tokenSymbol: "BICO",
        decimal: 18,
        chainId: 56,
        tokenAddress: "0x06250a4962558F0F3E69FC07F4c67BB9c9eAc739",
      },
      {
        tokenSymbol: "BICO",
        decimal: 18,
        chainId: 10,
        tokenAddress: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
      },
    ],
    // ETH
    [
      {
        tokenSymbol: "ETH",
        decimal: 18,
        chainId: 1,
        tokenAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      },
      {
        tokenSymbol: "ETH",
        decimal: 18,
        chainId: 10,
        tokenAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      },
    ],
    [
      {
        tokenSymbol: "ETH",
        decimal: 18,
        chainId: 137,
        tokenAddress: "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619",
      },
      {
        tokenSymbol: "ETH",
        decimal: 18,
        chainId: 10,
        tokenAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      },
    ],
    [
      {
        tokenSymbol: "ETH",
        decimal: 18,
        chainId: 56,
        tokenAddress: "0x2170Ed0880ac9A755fd29B2688956BD959F933F8",
      },
      {
        tokenSymbol: "ETH",
        decimal: 18,
        chainId: 10,
        tokenAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      },
    ],
    [
      {
        tokenSymbol: "ETH",
        decimal: 18,
        chainId: 43114,
        tokenAddress: "0x49d5c2bdffac6ce2bfdb6640f4f80f226bc10bab",
      },
      {
        tokenSymbol: "ETH",
        decimal: 18,
        chainId: 10,
        tokenAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      },
    ],
  ];

  setTokenConfig(tokenConfig, getBackendConfig("staging"));
})();
