import * as dotenv from "dotenv";
import { setConfig } from './set-deposit-config';

(async () => {
    let deposit_config = {
        url : process.env.DEPOSIT_CONFIG_URL || "",
        configData: [
            {
                "chainId": 5,
                "depositConfig" : {
                    "toChainIds" : [80001],
                    "tokenAddresses" : ["0x64ef393b6846114bad71e2cb2ccc3e10736b5716"],
                    "tokenConfigs" : [{
                        "max": "100000000000000000000",  
                        "min": "10000000000000000000000"
                    }]
                }
            }, 
            // add new config here
            {
                "chainId": 5,
                "depositConfig" : {
                    "toChainIds" : [80001],
                    "tokenAddresses" : ["0x64ef393b6846114bad71e2cb2ccc3e10736b5716"],
                    "tokenConfigs" : [{
                        "max": "100000000000000000000",  
                        "min": "10000000000000000000000"
                    }]
                }
            },
        ]
    }
    setConfig(deposit_config)

})();