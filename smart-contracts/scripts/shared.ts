import dotenv from "dotenv";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

dotenv.config();

const Contract = {
  DeepLayer:
    "0x8c4bcfe5cac89ea732d9f507f46d56a7e37e3d161007060a5686b9399a9ea03c",
  AVSManager:
    "0xafcde1ad80463f96bb2163935b1669e6d68479b12973ea4286f56295c58a9233",
  AVSDirectory:
    "0x972411f5178b5de7b7616f1a65bdf5ada2c89f62693cbc6b7d2df165669aec37",
  StrategyFactory:
    "0xa5a3627871928f2c0c67195f62a3d04d921eb2e3566d9ce030a5badfd421c255",
  StrategyManager:
    "0xfd75910c3d514f3bee8e4f5935397d084360ee9198a547b39e05871fafeacc3e",
  RewardsCoordinator:
    "0xc58c64144c1aa5f92f795cc204cc0476bc9cb91276c34571a5ba95f7cdae3143",
  AllocationManager:
    "0x83ef04924a88e1fd1d0ba5faaef4295babc1e0559a19281978fbd9087cfde3ea",
  DelegationManager:
    "0x5ce45c986b9b830939998114531c30a84a9da636912e5d9af596614d41364316",
  Nebula: "0x81ef5c1b3b5230372797d09b66ec3c03a90c5058be5d98ee6808fa30a2ad4477",
  NebulaCap:
    "0x5de46dc76af4b57fc27f4e502e6ae8f342335ee0e5caf91e302fc100618209b9",
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
      "0x825c9a5093a7d686fbb95c6cabaef97e37e4c30dee867a606c62ff5366d3e211",
    faucet:
      "0x4e0e3cae00f77614ad73a508f27316b7bc81c95fc47a6700c1769031824d8d2d",
  },
  {
    module: "hasui",
    coinType: "HASUI",
    treasuryCap:
      "0x5e181d2efbc2b8055dbe541db18a6d3a3a14b0921e803ec2ba0017addafe2b09",
    faucet:
      "0xbbcdc923ff540b739d0e976f54c37403e36e90d8bffe28abcb25d882ae2a467c",
  },
  {
    module: "pyth",
    coinType: "PYTH",
    treasuryCap:
      "0xf38314def6da2ef64cabb8c3d4d3cd8882dc0b04014eb651ef95c39bf43cbffa",
    faucet:
      "0xd381851cf0dee6bb81af3fd0b1a8b84c35569a00df437d3c3e0ef5aa80c1d076",
  },
  {
    module: "stsui",
    coinType: "STSUI",
    treasuryCap:
      "0x790da7f0e1d338f2a0b4c2a8f4bfaf0ea4654eab92b90c2baa3b7e134ca531a2",
    faucet:
      "0x25a29d43d7ae60c18fda39359692788345aa5c077affab6b200c3a3afa6f793e",
  },
  {
    module: "cert",
    coinType: "CERT",
    treasuryCap:
      "0xf58017c72fca9e22a07ccd1cfaf1d9c0ed42bb91bfcd7df2f3c1b3724d5fec4e",
    faucet:
      "0x112cad2de14d528d2c9dc383b4972aa43ce8d19b3b9be86ce3514397617862f1",
  },
  {
    module: "lbtc",
    coinType: "LBTC",
    treasuryCap:
      "0x04227d09ca903d9f18b59bcb12ad6c73183946294b3f6755f442eff8456839e4",
    faucet:
      "0xb27375b69641ee6536da89d401800cc60d676428d4a4b8b84aaf2f317ac2416c",
  },
];
const Eth_Coin = {
  module: "eth",
  coinType: "ETH",
  treasuryCap:
    "0xd9d037f91746b4ce75a627474820abeb9833d53842d2115a716b17c9ee1f4030",
  faucet: "0x9e7bce0635889378d057e9897e3cf0db44ddeb18a89c159f3ff33403faf5c34b",
};

const Operators = [
  {
    key: process.env.SECRET_KEY_MYSTEN,
    metdata_uri: JSON.stringify({
      name: "Font Labs",
      about:
        "At Mysten, we are building a company that aims to address these problems (and many others) by laying the foundations for a decentralized web stack suitable for mass adoption. The drive to unlock everything that web3 enables is our north star.",
      website: "https://mystenlabs.com",
      image: "https://mystenlabs.com",
    }),
  },
  {
    key: process.env.SECRET_KEY_PYTH,
    metdata_uri: JSON.stringify({
      name: "ShunLexxi",
      about:
        "Pyth is a protocol that allows market participants to publish pricing information on-chain for others to use.",
      website: "https://pyth.network",
      image: "https://pyth.network",
    }),
  },
  {
    key: process.env.SECRET_KEY_GOOGLE,
    metdata_uri: JSON.stringify({
      name: "Krypt0ne",
      about:
        "Our Web3 team at Google Cloud is dedicated to empowering the next generation of decentralized applications and services by providing developers and businesses with the essential tools, infrastructure, and knowledge to build and scale in the Web3 space.",
      website: "https://google.com",
      image: "https://google.com",
    }),
  },
];

export { Contract, client, signer, Coins, Operators, Eth_Coin };
