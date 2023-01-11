import { setConfig } from "../set-deposit-config";
import { getBackendConfig } from "../utils";

(async () => {
  let deposit_config = [
    {
      chainId: 1,
      depositConfig: {
        toChainIds: [137],
        tokenAddresses: [
          "0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0", // MATIC
        ],
        tokenConfigs: [
          {
            min: "10000000000000000000", // 10 matic
            max: "500000000000000000000000", // 500000 matic
          },
        ],
      },
    },
    {
      chainId: 137,
      depositConfig: {
        toChainIds: [1],
        tokenAddresses: [
          "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE", // MATIC
        ],
        tokenConfigs: [
          {
            min: "100000000000000000000", // 100 matic
            max: "500000000000000000000000",
          },
        ],
      },
    }
  ];

  setConfig(deposit_config, getBackendConfig("prod"));
})();
