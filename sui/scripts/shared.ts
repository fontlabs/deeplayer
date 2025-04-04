import dotenv from "dotenv";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

dotenv.config();

const Addresses = {
  DeepLayer: "",
};

const client = new SuiClient({
  url: getFullnodeUrl("testnet"),
});

const signer = Ed25519Keypair.fromSecretKey(process.env.SECRET_KEY!);

export { Addresses, client, signer };
