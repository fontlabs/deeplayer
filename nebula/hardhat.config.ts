import { vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";

const MNEMONIC = vars.get("MNEMONIC");
const HOLESKY_API_KEY = vars.get("HOLESKY_API_KEY");

module.exports = {
  mocha: {
    timeout: 100000000,
  },
  solidity: {
    version: "0.8.28",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    holesky: {
      url: "https://rpc.ankr.com/eth_holesky",
      chainId: 17000,
      accounts: {
        mnemonic: MNEMONIC,
      },
    },
  },
  etherscan: {
    apiKey: {
      holesky: HOLESKY_API_KEY,
    },
    customChains: [
      {
        network: "holesky",
        chainId: 17000,
        urls: {
          apiURL: "https://api-holesky.etherscan.io/api",
          browserURL: "https://holesky.etherscan.io/",
        },
      },
    ],
  },
};
