import fetch from 'node-fetch';

interface IDeployConfig {
    url: string,
    configData: IDeployConfigData[]
}

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

const setConfig = async (depositConfig: IDeployConfig) => {
    let response: any = {message: "Execution Finish", code: 200};
    for(let i = 0; i < depositConfig.configData.length; i++) {

        let depositConfigRes = await fetch(depositConfig.url, {
            method: "POST",
            body: JSON.stringify(depositConfig.configData[i]),
            headers: {
                "Content-Type": "application/json",
                "username": process.env.API_USERNAME || "",
                "password":  process.env.API_PASSWORD || "",
                "key":  process.env.API_AUTH_KEY || "",
            }
        });
        const data = await depositConfigRes.json();

        response[i]= {
            message: data.message,
            code: data.code,
            txHash: data.txHash
        }
    }

    console.log(response);
}

export {
    setConfig
}