import { setConfig } from "../set-deposit-config";
import { getBackendConfig } from "../utils";

(async () => {
  let deposit_config = [
    {
      chainId: 5,
      depositConfig: {
        toChainIds: [1422, 1422, 1422],
        tokenAddresses: [
          "0xb5B640E6414b6DeF4FC9B3C1EeF373925effeCcF", // USDC
          "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE", // ETH
          "0xDdc47b0cA071682e8dc373391aCA18dA0Fe28699", // BICO
        ],
        tokenConfigs: [
          {
            min: "100000000",
            max: "52000000000",
          },
          {
            min: "20000000000000000",
            max: "135000000000000000000",
          },
          {
            min: "10000000000000000000",
            max: "500000000000000000000000",
          },
        ],
      },
    },
    {
      chainId: 80001,
      depositConfig: {
        toChainIds: [1422, 1422, 1422],
        tokenAddresses: [
          "0xdA5289fCAAF71d52a80A254da614a192b693e977", // USDC
          "0xa6fa4fb5f76172d178d61b04b0ecd319c5d1c0aa", // ETH
          "0xac42d8319ce458b22a72b45f58c0dcfeee824691", // BICO
        ],
        tokenConfigs: [
          {
            min: "100000000",
            max: "52000000000",
          },
          {
            min: "3900000000000000",
            max: "135000000000000000000",
          },
          {
            min: "10000000000000000000",
            max: "500000000000000000000000",
          },
        ],
      },
    },
    {
      chainId: 43113,
      depositConfig: {
        toChainIds: [1422],
        tokenAddresses: [
          "0x7fcdc2c1ef3e4a0bcc8155a558bb20a7218f2b05", // ETH
        ],
        tokenConfigs: [
          {
            min: "3900000000000000",
            max: "135000000000000000000",
          },
        ],
      },
    },
    {
      chainId: 420,
      depositConfig: {
        toChainIds: [1422, 1422, 1422],
        tokenAddresses: [
          "0x359a5ECa3Af6db9b04dF09Bb417f97890219Fe5D", // USDC
          "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", // ETH
          "0x2D138B861a6c3DE6Ec1d4Dbc69cd4AeF36F0Cf43", // Bico
        ],
        tokenConfigs: [
          {
            min: "100000000",
            max: "52000000000",
          },
          {
            min: "3900000000000000",
            max: "135000000000000000000",
          },
          {
            min: "10000000000000000000",
            max: "500000000000000000000000",
          },
        ],
      },
    },
    {
      chainId: 97,
      depositConfig: {
        toChainIds: [1422],
        tokenAddresses: [
          "0x756289346D2b3C867966899c6D0467EdEb4Da3C4", // Bico
        ],
        tokenConfigs: [
          {
            min: "10000000000000000000",
            max: "500000000000000000000000",
          },
        ],
      },
    },
    {
      chainId: 421613,
      depositConfig: {
        toChainIds: [1422, 1422, 1422],
        tokenAddresses: [
          "0xc84c9BD3898f9c167915FE945f8C722709018d24", // USDC
          "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", // ETH
          "0x2B30269b3c73Cb69C44453fC41BE82c5EC046836", // Bico
        ],
        tokenConfigs: [
          {
            min: "100000000",
            max: "52000000000",
          },
          {
            min: "3900000000000000",
            max: "135000000000000000000",
          },
          {
            min: "10000000000000000000",
            max: "500000000000000000000000",
          },
        ],
      },
    },
    {
      chainId: 4002,
      depositConfig: {
        toChainIds: [1422, 1422, 1422],
        tokenAddresses: [
          "0x7f61a8ee767585c6075e3c084e57e020d734f3aa", // USDC
          "0x7af97a21978c4ba05e4ab03a86190fdd3f739866", // ETH
          "0x85f09b027310c8efeba4ef3786e7c10e64e9942c", // Bico
        ],
        tokenConfigs: [
          {
            min: "100000000",
            max: "52000000000",
          },
          {
            min: "3900000000000000",
            max: "135000000000000000000",
          },
          {
            min: "10000000000000000000",
            max: "500000000000000000000000",
          },
        ],
      },
    },
  ];

  setConfig(deposit_config, getBackendConfig("integration"));
})();
