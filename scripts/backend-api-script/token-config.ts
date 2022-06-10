import { setTokenConfig } from "./add-supported-token";
import { getBackendConfig } from "./utils";

(async () => {
  let tokenConfig = [
    [
      {
        tokenSymbol: "BICO",
        decimal: 18,
        chainId: 5,
        tokenAddress: "",
      },
      {
        tokenSymbol: "BICO",
        decimal: 18,
        chainId: 69,
        tokenAddress: "0x439725d33Fe46f1C167F6116aeEd7d910E482D2E",
      },
    ],
    [
      {
        tokenSymbol: "USDC",
        decimal: 18,
        chainId: 80001,
        tokenAddress: "0xdA5289fCAAF71d52a80A254da614a192b693e977",
      },
      {
        tokenSymbol: "USDC",
        decimal: 18,
        chainId: 69,
        tokenAddress: "0x4995E4dd58Fa9eF9D80F3111777fdd4bC3300a7C",
      },
    ],
  ];

  setTokenConfig(tokenConfig, getBackendConfig("staging"));
})();
