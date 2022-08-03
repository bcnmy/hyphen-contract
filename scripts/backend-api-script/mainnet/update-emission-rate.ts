import { setTokenConfig } from "../add-supported-token";
import { getBackendConfig } from "../utils";

(async () => {
  let tokenConfig = [
    /**** Ethereum */
    // USDC - 0.003161
    {
        "tokenAddress": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", 
        "chainId": "1",
        "rewardPerSecond": "3161000000000000"
    },
    // USDT - 0.001365
    {
        "tokenAddress": "0xdac17f958d2ee523a2206206994597c13d831ec7", 
        "chainId": "1",
        "rewardPerSecond": "1365000000000000"
    },
    // ETH - 0.003789
    {
        "tokenAddress": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", 
        "chainId": "1",
        "rewardPerSecond": "3785000000000000"
    },
    // BICO -  0.000842
    {
        "tokenAddress": "0xf17e65822b568b3903685a7c9f496cf7656cc6c2", 
        "chainId": "1",
        "rewardPerSecond": "842000000000000"
    },  

    /**** Polygon */
    // USDC -  0.00201
    {
        "tokenAddress": "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", 
        "chainId": "137",
        "rewardPerSecond": "2010000000000000"
    },
    // USDT -  0.00139
    {
        "tokenAddress": "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", 
        "chainId": "137",
        "rewardPerSecond": "1390000000000000"
    },
    // ETH - 0.004107
    {
        "tokenAddress": "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619", 
        "chainId": "137",
        "rewardPerSecond": "4107000000000000"
    },
    // BICO - 0.000875
    {
        "tokenAddress": "0x91c89A94567980f0e9723b487b0beD586eE96aa7", 
        "chainId": "137",
        "rewardPerSecond": "875000000000000"
    },

    /**** Avalanche */
    // USDC - 0.0000408
    {
        "tokenAddress": "0xa7d7079b0fead91f3e65f86e8915cb59c1a4c664", 
        "chainId": "43114",
        "rewardPerSecond": "40800000000000"
    },
    // ETH - 0.0000056
    {
        "tokenAddress": "0x49d5c2bdffac6ce2bfdb6640f4f80f226bc10bab", 
        "chainId": "43114",
        "rewardPerSecond": "5600000000000"
    },

    /**** BNB */
    // USDT - 0.002245
    {
        "tokenAddress": "0x55d398326f99059ff775485246999027b3197955", 
        "chainId": "56",
        "rewardPerSecond": "2245000000000000" 
    },
    // USDC - 0.001688
    {
        "tokenAddress": "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", 
        "chainId": "56",
        "rewardPerSecond": "1688000000000000"
    },
    // ETH - 0.00066
    {
        "tokenAddress": "0x2170Ed0880ac9A755fd29B2688956BD959F933F8", 
        "chainId": "56",
        "rewardPerSecond": "660000000000000"
    },
    /****
     * 
     * /emission-rate/v2/add
     * 
     */
     /**** Optimism */
    // USDC - 0.000918
    {
        "baseToken": "0x7f5c764cbc14f9669b88837ca1490cca17c31607", 
        "rewardToken": "0xd6909e9e702024eb93312b989ee46794c0fb1c9d",
        "chainId": "10",
        "rewardPerSecond": "918000000000000" 
    },
    // ETH - 0.000579
    {
        "baseToken": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", 
        "rewardToken": "0xd6909e9e702024eb93312b989ee46794c0fb1c9d",
        "chainId": "10",
        "rewardPerSecond": "579000000000000"
    },

    /**** Arbitrum */
    // USDC - 0.000956
    {
        "baseToken": "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8", 
        "rewardToken": "0xa68Ec98D7ca870cF1Dd0b00EBbb7c4bF60A8e74d",
        "chainId": "42161",
        "rewardPerSecond": "956000000000000"
    },
    // ETH - 0.001336
    {
        "baseToken": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", 
        "rewardToken": "0xa68Ec98D7ca870cF1Dd0b00EBbb7c4bF60A8e74d",
        "chainId": "42161",
        "rewardPerSecond": "1336000000000000"
    },
  ];

//   setTokenConfig(tokenConfig, getBackendConfig("prod"));
})();
