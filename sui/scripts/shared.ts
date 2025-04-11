import dotenv from "dotenv";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

dotenv.config();

const Contract = {
  DeepLayer:
    "0x75883ea1ba2ba25d4ea8ef3fef720511af880936549e2927ddb8422db88691c7",
  AVSDirectory:
    "0x61dd4a12b50ec2494c422007c97efb1e200baf351b390db766fbf82fec677e1b",
  StrategyFactory:
    "0x148fb2188709766a2fd51c46e572ff42d9cdb512fcc891fb8c3267de3c724ee4",
  StrategyManager:
    "0x8395b1e9e6fcb845930ab3d97a807971cdc90cc1d5fff2bf45953ec750b98ca4",
  RewardsCoordinator:
    "0x40a8d600650b6f3947df6fe04f0018bb57f34efef311404403120e67d50904d1",
  AllocationManager:
    "0xf0dfffde1b7200b0d93de58aa4a4973cf1fc8a8e0eedebcad503f15c6d66dfe3",
  DelegationManager:
    "0x34dc47d3fee8a06103a130ff686d45ed54f56cc9aab4521001d979d45ada1b91",
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
      "0x0dfc901f2f71387f7fd1282fa727ec2eeff6c853eccee5eda6eda755f175e6bc",
    faucet:
      "0x8ef3c576afce65777825052e5ca2ff1e0502bc46b2195c0e3333e8549785411d",
  },
  {
    module: "hasui",
    coinType: "HASUI",
    treasuryCap:
      "0x1f36a5f5e78af513627c937102442b00b20990494e80da64227141888e688779",
    faucet:
      "0x3dc7716af9ad73f88bd8a760fc990e33d62d235dfcfe06fd20258cbd704e750d",
  },
  {
    module: "pyth",
    coinType: "PYTH",
    treasuryCap:
      "0x5c5bc01616ee4923cd4319ed25c404f2eed2daedd4757c4588a50eaf952a7195",
    faucet:
      "0x15925860e11a78dfe4eb76a4545006ef88c521fbfd41fe3ef315ddf97998f1df",
  },
  {
    module: "stsui",
    coinType: "STSUI",
    treasuryCap:
      "0xce4b68250373c8c3938a42e7d5ea2b601387aea05289c829183eae1d1ed2f44e",
    faucet:
      "0x6cf2273d40d8573afa3885372edcda3777b9449ebfc018e9a3e333b922a69718",
  },
  {
    module: "cert",
    coinType: "CERT",
    treasuryCap:
      "0x43b1731ea57ca3350e0fd7f95f335b72b5bfe7126e3fd753ae5a80d59ecc90f1",
    faucet:
      "0xc16ed3db2bf10942e068f6c080ba4934e4ec17f3063dc10c8af05c847c4c41f6",
  },
  {
    module: "lbtc",
    coinType: "LBTC",
    treasuryCap:
      "0x997e34ae21077dc5270c210d2f77f3f2aa63eeadedf6b02c64bfc953ebdddb40",
    faucet:
      "0x804d1d25a0f91868b6547d0e12631a6aa41732fbc46719aed6993f21bb591218",
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

export { Contract, client, signer, Coins, Operators };
