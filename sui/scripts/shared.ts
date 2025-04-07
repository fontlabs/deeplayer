import dotenv from "dotenv";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

dotenv.config();

const Addresses = {
  DeepLayer:
    "0x2f0b1dd354dd818e3173c104d7e6f8a682fc8908c0920d85caf9bfb9a220dfba",
  StrategyFactory:
    "0xce7cda2fe94a759e88aa873317704186e29addbf78f6784cdbe422b7031a17fb",
  StrategyManager: "",
  AllocationManager: "",
  DelegationManager: "",
};

const client = new SuiClient({
  url: getFullnodeUrl("testnet"),
});

const signer = Ed25519Keypair.fromSecretKey(process.env.SECRET_KEY!);

const Coins = [
  {
    module: "afsui",
    coinType: "AFSUI",
    treasuryCap:
      "0x28b308bd67a7bd35f11374f02eb12dcfc59dd91f65e7128a71177e40d1ce9614",
    faucet:
      "0x3bacfda6dec8aea1458772ea14069572df2f76ebfca70d22f4a88fe721c5ab47",
  },
  {
    module: "hasui",
    coinType: "HASUI",
    treasuryCap:
      "0xaf08578e111c6481b0737e5971ce30abaac8c476c309f20343f279e90fc9d81c",
    faucet:
      "0xeedd96b45aeca6967b96b33fc0e6cee4ac358c6855c6d247a7bb33516b2926e8",
  },
  {
    module: "pyth",
    coinType: "PYTH",
    treasuryCap:
      "0x6d8c143ece4980b2cd38e94e1e6a220dd6a31dc0599ad36a66f7b5217af9ba6b",
    faucet:
      "0x9e3a8c3af83fde8c203e7424a87caf406960bcfa3193cf30cc2521754b33bc1b",
  },
  {
    module: "stsui",
    coinType: "STSUI",
    treasuryCap:
      "0x13aa27c6c41a893f33109af777dea6f8f975167b1cd925a86e8a2276a8399852",
    faucet:
      "0x4782f2ad736ae090bf9842b683dab08c802a2d5de8179d16e52fe1a29fd4936b",
  },
  {
    module: "cert",
    coinType: "CERT",
    treasuryCap:
      "0xc863f69843818a288aecb83237d515b73d51d879e74409f2f9d736b80c887413",
    faucet:
      "0x47e2274e8d5bbc77d3a37b6f818c0ed8bdfcfc2ec36a64a393b1b2e22bc65134",
  },
  {
    module: "wbtc",
    coinType: "WBTC",
    treasuryCap:
      "0x739a7a845dce8c661ac74e778f5671105d16d0396e72fdbf49f11f4ab6241733",
    faucet:
      "0xacde9528df8bc0666493bd4d0f5d90c671754d9bc897782423e837eaba2031c3",
  },
];

const Operators = [
  {
    key: process.env.SECRET_KEY_MYSTEN,
    metdata_uri: JSON.stringify({
      name: "Mysten Labs (Unofficial)",
      about:
        "At Mysten, we are building a company that aims to address these problems (and many others) by laying the foundations for a decentralized web stack suitable for mass adoption. The drive to unlock everything that web3 enables is our north star.",
      website: "https://mystenlabs.com",
      image: "https://mystenlabs.com",
    }),
  },
  {
    key: process.env.SECRET_KEY_PYTH,
    metdata_uri: JSON.stringify({
      name: "Pyth (Unofficial)",
      about:
        "Pyth is a protocol that allows market participants to publish pricing information on-chain for others to use.",
      website: "https://pyth.network",
      image: "https://pyth.network",
    }),
  },
  {
    key: process.env.SECRET_KEY_GOOGLE,
    metdata_uri: JSON.stringify({
      name: "Google (Unofficial)",
      about:
        "Our Web3 team at Google Cloud is dedicated to empowering the next generation of decentralized applications and services by providing developers and businesses with the essential tools, infrastructure, and knowledge to build and scale in the Web3 space.",
      website: "https://google.com",
      image: "https://google.com",
    }),
  },
];

export { Addresses, client, signer, Coins, Operators };
