import { setConfig } from "./set-deposit-config";
import { getBackendConfig } from "./utils";

(async () => {
  let deposit_config = [
    {
      chainId: 5,
      depositConfig: {
        toChainIds: [69, 69, 69],
        tokenAddresses: [
          "0xb5B640E6414b6DeF4FC9B3C1EeF373925effeCcF",
          "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
          "0xDdc47b0cA071682e8dc373391aCA18dA0Fe28699",
        ],
        tokenConfigs: [
          {
            min: "100000000",
            max: "1000000000000",
          },
          {
            min: "100000000000000000000",
            max: "10000000000000000000000",
          },
          {
            min: "100000000000000000000",
            max: "10000000000000000000000",
          },
        ],
      },
    },
    {
      chainId: 80001,
      depositConfig: {
        toChainIds: [69, 69, 69],
        tokenAddresses: [
          "0xdA5289fCAAF71d52a80A254da614a192b693e977",
          "0xa6fa4fb5f76172d178d61b04b0ecd319c5d1c0aa",
          "0xac42d8319ce458b22a72b45f58c0dcfeee824691",
        ],
        tokenConfigs: [
          {
            min: "100000000",
            max: "1000000000000",
          },
          {
            min: "100000000000000000000",
            max: "10000000000000000000000",
          },
          {
            min: "100000000000000000000",
            max: "10000000000000000000000",
          },
        ],
      },
    },
    {
      chainId: 43113,
      depositConfig: {
        toChainIds: [69],
        tokenAddresses: ["0x7fcdc2c1ef3e4a0bcc8155a558bb20a7218f2b05"],
        tokenConfigs: [
          {
            min: "100000000000000000000",
            max: "10000000000000000000000",
          },
        ],
      },
    },
    {
      chainId: 97,
      depositConfig: {
        toChainIds: [69],
        tokenAddresses: ["0x756289346D2b3C867966899c6D0467EdEb4Da3C4"],
        tokenConfigs: [
          {
            min: "100000000000000000000",
            max: "10000000000000000000000",
          },
        ],
      },
    },
  ];

  setConfig(deposit_config, getBackendConfig("staging"));
})();
