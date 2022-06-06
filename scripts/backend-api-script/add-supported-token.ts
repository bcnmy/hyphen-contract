import fetch from 'node-fetch';

interface ITokenConfig {
    url: string,
    configData: any,
}

const setTokenConfig = async (tokenConfig: ITokenConfig) => {
    let response: any = {message: "Execution Finish", code: 200};
    console.log(tokenConfig.configData.length);
    for(let i = 0; i < tokenConfig.configData.length; i++) {

        let tokenConfigRes = await fetch(tokenConfig.url, {
            method: "POST",
            body: JSON.stringify(tokenConfig.configData[i]),
            headers: {
                "Content-Type": "application/json",
                "username": process.env.API_USERNAME || "",
                "password":  process.env.API_PASSWORD || "",
                "key":  process.env.API_AUTH_KEY || "",
            }
        });
        const data = await tokenConfigRes.json();

        if(!data.pairOne){
            response[i]= {
                code: data.code,
                message: data.message,
            }
        } else {
            response[i]= {
                pairOne: data.pairOne,
                pairTwo: data.pairTwo,
            }
        }
    }
    console.log(response);
}

export {
    setTokenConfig
}