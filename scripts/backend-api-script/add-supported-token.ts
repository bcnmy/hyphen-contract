import axios from "axios";
import type { IBackendConfig } from "../types";

const setTokenConfig = async (configData: any, backendConfig: IBackendConfig) => {
  let response: any = { message: "Execution Finish", code: 200 };
  console.log(configData.length);

  for (let i = 0; i < configData.length; i++) {
    const tokenConfigRes = await axios.post(`${backendConfig.baseUrl}/api/v1/db/add`, configData[i], {
      headers: {
        "Content-Type": "application/json",
        username: backendConfig.apiUsername,
        password: backendConfig.apiPassword,
        key: backendConfig.apiKey,
      },
    });
    const data = tokenConfigRes.data;
    if (!data.pairOne) {
      response[i] = {
        code: data.code,
        message: data.message,
      };
    } else {
      response[i] = {
        pairOne: data.pairOne,
        pairTwo: data.pairTwo,
      };
    }
  }
  console.log(response);
};

export { setTokenConfig };
