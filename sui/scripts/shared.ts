import dotenv from "dotenv";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

dotenv.config();

const Addresses = {
  DeepLayer:
    "0x43d20dbffe39e23263ac2f3e5c1d0222b6ba23dfa0855960638db8f81283fb08",
  StrategyFactory:
    "0x1b8c4dc84618e8e2a9c16927586d7103ec60be9433b21f7f38a34481919ae87f",
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
      "0x09e6c3e83732634162b9d6a9cb49b8295ae9e28b30ddc49673743331ccfdb89f",
    faucet:
      "0x1fa7bcb766364ef9730265d9b5f8765d99a5ac063fb110de03e2b9b7a33b8c0d",
  },
  {
    module: "hasui",
    coinType: "HASUI",
    treasuryCap:
      "0x2ddd9dfa115c6b2ab67e25566ae6a2f4c453ce79fa621b2d31e69b1a80dc1c40",
    faucet:
      "0x410aa2661941f0ee2bba8d690db3aa0fee348da5f172b78509aef9d4280be120",
  },
  {
    module: "pyth",
    coinType: "PYTH",
    treasuryCap:
      "0x117f70ffd22c867a8fe98bd7acc25f74bc7a762838070bf8f91fe2b754e56577",
    faucet:
      "0x0f46a1a36223c27a3f7b61a7372103b6626c5dc8d13fc67d5b25bf4a349a7c37",
  },
  {
    module: "stsui",
    coinType: "STSUI",
    treasuryCap:
      "0xfe8f65e9ad78553a9aef4cbb0d023bfbbede0bb9ae3868c7199e9b9d1370fa6d",
    faucet:
      "0xfbed9b76a297b625e95a09023083d301d93c2dc53a718157d6d511e04fb1adcb",
  },
  {
    module: "cert",
    coinType: "CERT",
    treasuryCap:
      "0x3493ed5273c1a27582470d760ba3248cbec4391b07e2d36117a968733fd65f7e",
    faucet:
      "0xf31dc24f09435bc186362689cd51efdd15133e84acb93f233dba813d1acfecfa",
  },
  {
    module: "wbtc",
    coinType: "WBTC",
    treasuryCap:
      "0x8a302524b924d1cb7ef451229122f3f43b274cada0a7c6ca3c9027c73b3ce31a",
    faucet:
      "0xc00af52335d203478910167855dac6bdc78a52d8580bb64c7fcd707e51535424",
  },
];

export { Addresses, client, signer, Coins };
