import dotenv from "dotenv";

import { SUI_CLOCK_OBJECT_ID, SUI_TYPE_ARG } from "@mysten/sui/utils";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { bcs } from "@mysten/sui/bcs";
import http from "http";

import type { Hex } from "viem";

type TokenLockedEvent = {
  uid: Hex;
  coinType: string;
  decimals: number;
  amount: bigint;
  receiver: Hex;
  block_number: bigint;
  chain_id: number;
  signature: Uint8Array<ArrayBufferLike>;
  signer: string;
};

type SignedTokenLockedEvent = {
  uid: Hex;
  coinType: string;
  decimals: number;
  amount: bigint;
  receiver: Hex;
  block_number: bigint;
  chain_id: number;
  signatures: Uint8Array<ArrayBufferLike>[];
  signers: string[];
};

dotenv.config();

const MinAttestation = 2;
const MemPool: Record<string, TokenLockedEvent[]> = {};
const ProcessingPool: Record<string, boolean> = {};

const DeepLayer: Hex =
  "0x8c4bcfe5cac89ea732d9f507f46d56a7e37e3d161007060a5686b9399a9ea03c";
const NEBULA: Hex =
  "0x81ef5c1b3b5230372797d09b66ec3c03a90c5058be5d98ee6808fa30a2ad4477";
const AVS_DIRECTORY: Hex =
  "0x972411f5178b5de7b7616f1a65bdf5ada2c89f62693cbc6b7d2df165669aec37";
const AVS_MANAGER: Hex =
  "0xafcde1ad80463f96bb2163935b1669e6d68479b12973ea4286f56295c58a9233";
const DELEGATION_MANAGER: Hex =
  "0x5ce45c986b9b830939998114531c30a84a9da636912e5d9af596614d41364316";

const COIN_METADATA: Record<string, Hex> = {};

const LBTC_TYPE_ARG = `${DeepLayer}::lbtc::LBTC`;
const ETH_TYPE_ARG = `${DeepLayer}::eth::ETH`;

COIN_METADATA[SUI_TYPE_ARG] =
  "0x587c29de216efd4219573e08a1f6964d4fa7cb714518c2c8a0f29abfa264327d";
COIN_METADATA[LBTC_TYPE_ARG] =
  "0xc22de7e5ab4042c473acc1c58924f0366e43ea3f838516b64810a8bcc7f5f695";
COIN_METADATA[ETH_TYPE_ARG] =
  "0x7ff5a65a182ac8704d12cda4b2a1c53bef2095752112667919f3b1fe5cce0983";

const client = new SuiClient({ url: getFullnodeUrl("testnet") });

interface SubmitCallback {
  onSubmit: (event: TokenLockedEvent) => void;
}

class Attester {
  getSignedEvent(events: TokenLockedEvent[]): SignedTokenLockedEvent | null {
    if (!events.every((event) => event.uid == events[0].uid)) return null;
    if (!events.every((event) => event.coinType == events[0].coinType))
      return null;
    if (!events.every((event) => event.decimals == events[0].decimals))
      return null;
    if (!events.every((event) => event.amount == events[0].amount)) return null;
    if (!events.every((event) => event.receiver == events[0].receiver))
      return null;
    if (!events.every((event) => event.block_number == events[0].block_number))
      return null;
    if (!events.every((event) => event.chain_id == events[0].chain_id))
      return null;
    return {
      ...events[0],
      signatures: events.map((event) => event.signature),
      signers: events.map((event) => event.signer),
    };
  }

  async attest(events: TokenLockedEvent[]): Promise<boolean> {
    if (!process.env.SECRET_KEY) throw new Error("Invalid secret key!");

    const event = this.getSignedEvent(events);
    console.log("Last event:", event);

    if (!event) return false;

    if (ProcessingPool[event.uid]) return false;

    try {
      console.log("Processing");
      ProcessingPool[event.uid] = true;

      const tx = new Transaction();

      tx.moveCall({
        target: `${DeepLayer}::nebula::attest`,
        arguments: [
          tx.object(NEBULA),
          tx.object(COIN_METADATA[event.coinType]),
          tx.object(AVS_MANAGER),
          tx.object(AVS_DIRECTORY),
          tx.object(DELEGATION_MANAGER),
          bcs
            .vector(bcs.vector(bcs.U8))
            .serialize(event.signatures.map((signature) => signature)),
          bcs.vector(bcs.Address).serialize(event.signers),
          bcs.vector(bcs.U8).serialize(new TextEncoder().encode(event.uid)),
          tx.pure.u64(event.chain_id),
          tx.pure.u64(event.block_number),
          tx.pure.u64(event.amount),
          tx.pure.u8(event.decimals),
          tx.pure.address(event.receiver),
          tx.object(SUI_CLOCK_OBJECT_ID),
        ],
        typeArguments: [event.coinType],
      });
      tx.setGasBudget(5_000_000);

      const signer = Ed25519Keypair.fromSecretKey(process.env.SECRET_KEY);
      const { digest } = await client.signAndExecuteTransaction({
        signer,
        transaction: tx,
      });

      console.log("Transaction Digest:", digest);

      delete MemPool[event.uid];
      delete ProcessingPool[event.uid];

      return true;
    } catch (error) {
      console.error("Error attesting event:", error);
      delete ProcessingPool[event.uid];
      return false;
    }
  }
}

const attester = new Attester();

const callback: SubmitCallback = {
  onSubmit(event: TokenLockedEvent) {
    if (!MemPool[event.uid]) MemPool[event.uid] = [];

    MemPool[event.uid].push(event);

    if (MemPool[event.uid].length >= MinAttestation) {
      attester.attest(MemPool[event.uid]);
    }
  },
};

class Server {
  start() {
    const server = http.createServer((req, res) => {
      if (req.url === "/submit" && req.method === "POST") {
        let body = "";

        req.on("data", (chunk) => {
          body += chunk.toString(); // Convert Buffer to string
        });

        req.on("end", () => {
          try {
            const data = JSON.parse(body); // assuming it's JSON
            console.log("Received POST data:", data);

            // You can call your callback with the parsed data
            callback.onSubmit(data);

            res.setHeader("Content-Type", "application/json");
            res.writeHead(200);
            res.end(JSON.stringify({ message: "Received", data }));
          } catch (err: any) {
            res.writeHead(400);
            res.end(JSON.stringify({ error: err.message }));
          }
        });
      } else {
        res.setHeader("Content-Type", "application/json");
        res.writeHead(200);
        res.end(JSON.stringify({ message: "OK" }));
      }
    });

    server.listen(process.env.PORT);
  }
}

const server = new Server();
server.start();
