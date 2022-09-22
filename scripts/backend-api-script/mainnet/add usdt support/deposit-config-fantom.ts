import { setConfig } from "../set-deposit-config";
import { getBackendConfig } from "../utils";

(async () => {
  let deposit_config = [
    {
      chainId: 1,
      depositConfig: {
        toChainIds: [250],
        tokenAddresses: [
          "0xdac17f958d2ee523a2206206994597c13d831ec7", // USDT
        ],
        tokenConfigs: [
          {
            min: "10000000",
            max: "60000000000",
          },
        ],
      },
    },
    {
      chainId: 137,
      depositConfig:  {
        toChainIds: [250],
        tokenAddresses: [
          "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", // USDT
        ],
        tokenConfigs: [
          {
            min: "10000000",
            max: "60000000000",
          },
        ],
      },
    },
    {
      chainId: 43114,
      depositConfig:  {
        toChainIds: [250],
        tokenAddresses: [
          "0xc7198437980c041c805a1edcba50c1ce5db95118", // USDT
        ],
        tokenConfigs: [
          {
            min: "10000000",
            max: "60000000000",
          },
        ],
      },
    },
    {
      chainId: 56,
      depositConfig:  {
        toChainIds: [250],
        tokenAddresses: [
          "0x55d398326f99059ff775485246999027b3197955", // USDT
        ],
        tokenConfigs: [
          {
            min: "10000000",
            max: "60000000000",
          },
        ],
      },
    },
    {
      chainId: 10,
      depositConfig:  {
        toChainIds: [250],
        tokenAddresses: [
          "0x94b008aa00579c1307b0ef2c499ad98a8ce58e58", // USDT
        ],
        tokenConfigs: [
          {
            min: "10000000",
            max: "60000000000",
          },
        ],
      },
    },
    {
      chainId: 42161,
      depositConfig:  {
        toChainIds: [250],
        tokenAddresses: [
          "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9", // USDT
        ],
        tokenConfigs: [
          {
            min: "10000000",
            max: "60000000000",
          },
        ],
      },
    }
  ];

  setConfig(deposit_config, getBackendConfig("prod"));
})();
