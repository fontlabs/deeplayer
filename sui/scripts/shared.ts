import dotenv from "dotenv";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

dotenv.config();

const Contract = {
  DeepLayer:
    "0xf52e10b4ceb96a57686e6df13661e1873e1b02ad566e560c106ad70ff2c4bdfe",
  AVSDirectory:
    "0x6c657abead0a727adb3b95e8b27dc66e6c774041f2ae1fb1f95a30c8a0fd8e32",
  StrategyFactory:
    "0xcc628e6a4e73cbe20974dfd6d66d778e3521f39f805ac03a63b59302aa469703",
  StrategyManager:
    "0x66164e4c4d7aa32c9ce81e02a5c335c21160f850890b929b77e84786f711d986",
  RewardsCoordinator:
    "0xea669ed0d6ebb63a64da296dd1253d32056d2addab322d407edc29099cfaf573",
  AllocationManager:
    "0x026a05d8070e624cb815e48235b51b389e5d25912d6cc4027acd3c37e77fa7f6",
  DelegationManager:
    "0x0a54afc3604e4c22a9127b0e687d3860df93eeb3723461d5be247acfdcfd0719",
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
      "0xcca5bc8bf8900217797e356086ee97f52727f62ca75eb982dadc13913a5608a3",
    faucet:
      "0xdd88bd2e6da7cf2d9d8439325e5ee5d91fdbe906a6cdd7bcbd071e3efc7e55ba",
  },
  {
    module: "hasui",
    coinType: "HASUI",
    treasuryCap:
      "0xdbd0acd43878ff60569e8d76e7f00562b7c9fef46770fc1ad87bed8666e10bcd",
    faucet:
      "0x7293ab304154fdf860486d59a9836891b22af2cd09dc4a7e72af143b338e6f5d",
  },
  {
    module: "pyth",
    coinType: "PYTH",
    treasuryCap:
      "0x1314c326cbd4b235e72365cf3ee296c16a90fa3f89cefcc9ebcb8fb2cf85ba97",
    faucet:
      "0x85db0862f42860ee97a50c89988d5b49842fd94e6c5761d5d0a74cbe98badaac",
  },
  {
    module: "stsui",
    coinType: "STSUI",
    treasuryCap:
      "0x38c7eb760607369f1289428449ced2f4ac487514a6d4f73bae3ef05be3dcab7b",
    faucet:
      "0x0ac606d8fa57bccedc0432efcff4fa0f85132c0d02256ab92f2cd18680f2cb1c",
  },
  {
    module: "cert",
    coinType: "CERT",
    treasuryCap:
      "0xc6045ea9f8b9258b7367a9be4bd6e5ebee2ad942170d169f7d05c0e218f511f9",
    faucet:
      "0x8b2f4fc6fda2f1bae5bdc2428713d562307207073eac66378599d953e7d545d5",
  },
  {
    module: "lbtc",
    coinType: "LBTC",
    treasuryCap:
      "0xfab9e586a29884aa5958ff47fba7e9a133b85a7f623476087d1052466c3d778f",
    faucet:
      "0x5277cfdd4efe8cfe637aeec0a1c267a4c73d243b463181c1c39e2b5679d066b6",
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
