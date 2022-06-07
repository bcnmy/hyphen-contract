import axios from "axios";
import type { IBackendConfig } from "../types";
interface IDeployConfigData {
  chainId: number;
  depositConfig: IChainConfig;
}

interface IChainConfig {
  toChainIds: number[];
  tokenAddresses: string[];
  tokenConfigs: ITokenConfig[];
}

interface ITokenConfig {
  max: string;
  min: string;
}

const setConfig = async (configData: IDeployConfigData[], backendConfig: IBackendConfig) => {
  let response: any = { message: "Execution Finish", code: 200 };
  for (let i = 0; i < configData.length; i++) {
    const depositConfigRes = await axios.post(
      `${backendConfig.baseUrl}/api/v1/admin//supported-token/smart-contract/set-deposit-config`,
      configData[i],
      {
        headers: {
          "Content-Type": "application/json",
          username: backendConfig.apiUsername,
          password: backendConfig.apiPassword,
          key: backendConfig.apiKey,
        },
      }
    );
    const data = await depositConfigRes.data;

    response[i] = {
      message: data.message,
      code: data.code,
      txHash: data.txHash,
    };
  }

  console.log(response);
};

export { setConfig };
