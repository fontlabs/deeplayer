import dotenv from "dotenv";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

dotenv.config();

const Contract = {
  DeepLayer:
    "0x7b941196e87bbf0f0ee85717c68f49ad88ef598b81943ff4bde11dfea5e1b9a4",
  AVSManager:
    "0x9e792c8287424fd3927f3070a7d3e4537df6543a6405ee25de0ff1b5f9933104",
  AVSDirectory:
    "0x9cad346e85eea93d429ab78aba5e1547bd9782fe41c30dfbe301a622957910cc",
  StrategyFactory:
    "0x469ae718fda2fcf93fa64ed4e8555ba03c521807ff0eb3ebc90d8ac78eb62aa9",
  StrategyManager:
    "0x72bc80b016c2d9faebfff315d3dd2e0d3d252f8335c51b09bcec2f1f9ee9a8fc",
  RewardsCoordinator:
    "0x5fe16ed96834f9f01a52e1a2a52d7a7a4a02fe9e8983575de70f92cee9c1fb62",
  AllocationManager:
    "0x3946025d5bb43d7538b5d50b18bf35356dfd4a29036e8253e8c7f548e085d6bc",
  DelegationManager:
    "0x4f9789410e46b594e2f67a2b0c5a1cedf4ac453f8083e4f800c5745d8bac1e48",
  Nebula: "0x4930528af3c3cab6aaf414d12cd89217f2ab79e3b148ae7cd758c116938346ce",
  NebulaCap:
    "0xb2cd019b592ccdccf8ef83399a676b0161ab4eef94588b26f3c2fc7c1fa17322",
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
      "0x774fa28be92c76f67b5c2ec5caa0ec9341a0df67101a031eb5b95ec0e96e14ce",
    faucet:
      "0x21829c8ca17ff4f6bd64b67fe97753a8319d350a4742c8e0c7466553118ec3c8",
  },
  {
    module: "hasui",
    coinType: "HASUI",
    treasuryCap:
      "0x7c84e6226c3018415d1aee792817efa40d97da5cf97b5cbb674aa73b136e7158",
    faucet:
      "0xfdac848252c3a0afaaf43e03546d695d0c31bd0a23f81fca98f0613d9ce2d148",
  },
  {
    module: "pyth",
    coinType: "PYTH",
    treasuryCap:
      "0x08fdd64acc96d6e2327779a795376b54394bae2508e7475b43913614da37c5f1",
    faucet:
      "0x7242123351ca5afaf22ef4fe1f76c2a894f1eeb5bed3be17376ac7ddd38ca585",
  },
  {
    module: "stsui",
    coinType: "STSUI",
    treasuryCap:
      "0x368a3f442b233245daf7f7e67d4802e2cf7db391125ff45c144065d58a10c9ac",
    faucet:
      "0x078021c2b29f1ea2f6d2853296bb1bc49ea0df9f05c6e38aa39dade77a75d9c0",
  },
  {
    module: "cert",
    coinType: "CERT",
    treasuryCap:
      "0xefdd1fd712c32539da80a491ddfb734d31703e7d8c49af09415435e1fc0cddda",
    faucet:
      "0x55c9e2b668bf5259ec306c4fb4d1e3d40300cf9e98e24e3afa4546483bdad115",
  },
  {
    module: "lbtc",
    coinType: "LBTC",
    treasuryCap:
      "0x46214e41fd1f4b2056222e894993591130163a592d4a78925b4b088cafc74ce9",
    faucet:
      "0x2eb5c249c3b460b2ca5c6c126845bc39ef255ff92837d6f7df74ac31b8463335",
  },
];
const Eth_Coin = {
  module: "eth",
  coinType: "ETH",
  treasuryCap:
    "0x93339726a9497b17d2451ad340f17d099ba3f1a9c9f07b0cfc89fe21b1a1f7a8",
  faucet: "0xf1e97fb47ac8e2567f3c50d30d6bf594ad92dd3684e47b26ad6bc0f12ebd3603",
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
