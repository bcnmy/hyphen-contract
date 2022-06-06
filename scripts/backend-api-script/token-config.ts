import { setTokenConfig } from './add-supported-token';

(async () => {
    let tokenConfig = {
        url : process.env.ADD_SUPPORTED_TOKEN_URL || "",
        configData: [[
                {
                    "tokenSymbol": "ETH",
                    "decimal": 18,
                    "chainId": 5,
                    "tokenAddress": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
                },
                {
                    "tokenSymbol": "ETH",
                    "decimal": 18,
                    "chainId": 80001,
                    "tokenAddress": "0xa6fa4fb5f76172d178d61b04b0ecd319c5d1c0aa"
                }
            ],
            [
                {
                    "tokenSymbol": "ETH",
                    "decimal": 18,
                    "chainId": 4,
                    "tokenAddress": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
                },
                {
                    "tokenSymbol": "ETH",
                    "decimal": 18,
                    "chainId": 43113,
                    "tokenAddress": "0x7fcdc2c1ef3e4a0bcc8155a558bb20a7218f2b05"
                }
            ]
        ]
    }   
    setTokenConfig(tokenConfig)

})();