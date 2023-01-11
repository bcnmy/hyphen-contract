import { setConfig } from "../set-deposit-config";
import { getBackendConfig } from "../utils";

(async () => {
  let deposit_config = [
    {
      chainId: 5,
      depositConfig: {
        toChainIds: [80001],
        tokenAddresses: [
          "0xA4CBb208e19d528b1eB972590bD434E002A3Af0e", // MATIC
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
      chainId: 80001,
      depositConfig: {
        toChainIds: [5],
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

  setConfig(deposit_config, getBackendConfig("staging"));
})();
