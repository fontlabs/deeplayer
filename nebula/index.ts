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
  signature: string;
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
  signatures: string[];
  signers: string[];
};

dotenv.config();

const MinAttestation = 2;
const MemPool: Record<string, TokenLockedEvent[]> = {};
const ProcessingPool: Record<string, boolean> = {};

const DeepLayer: Hex =
  "0x7b941196e87bbf0f0ee85717c68f49ad88ef598b81943ff4bde11dfea5e1b9a4";
const NEBULA: Hex =
  "0x4930528af3c3cab6aaf414d12cd89217f2ab79e3b148ae7cd758c116938346ce";
const AVS_DIRECTORY: Hex =
  "0x9cad346e85eea93d429ab78aba5e1547bd9782fe41c30dfbe301a622957910cc";
const AVS_MANAGER: Hex =
  "0x9e792c8287424fd3927f3070a7d3e4537df6543a6405ee25de0ff1b5f9933104";
const DELEGATION_MANAGER: Hex =
  "0x4f9789410e46b594e2f67a2b0c5a1cedf4ac453f8083e4f800c5745d8bac1e48";

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
    if (!event) return false;

    if (ProcessingPool[event.uid]) return false;

    try {
      ProcessingPool[event.uid] = true;

      const transaction = new Transaction();

      transaction.moveCall({
        target: `${DeepLayer}::nebula::attest`,
        arguments: [
          transaction.object(NEBULA),
          transaction.object(COIN_METADATA[event.coinType]),
          transaction.object(AVS_MANAGER),
          transaction.object(AVS_DIRECTORY),
          transaction.object(DELEGATION_MANAGER),
          transaction.pure(
            bcs
              .vector(bcs.vector(bcs.U8))
              .serialize(
                event.signatures.map((signature) =>
                  new TextEncoder().encode(signature)
                )
              )
          ),
          transaction.pure(
            bcs.vector(bcs.U8).serialize(new TextEncoder().encode(event.uid))
          ),
          transaction.pure(bcs.vector(bcs.Address).serialize(event.signers)),
          transaction.pure.u64(event.chain_id),
          transaction.pure.u64(event.block_number),
          transaction.pure.u64(event.amount),
          transaction.pure.u8(event.decimals),
          transaction.pure.address(event.receiver),
          transaction.object(SUI_CLOCK_OBJECT_ID),
        ],
        typeArguments: [event.coinType],
      });
      transaction.setGasBudget(5_000_000);

      const signer = Ed25519Keypair.fromSecretKey(process.env.SECRET_KEY);
      const { digest } = await client.signAndExecuteTransaction({
        signer,
        transaction,
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
    if (!MemPool[event.uid]) {
      MemPool[event.uid] = [];
    } else if (!MemPool[event.uid].find((e) => e.signer == event.signer)) {
      MemPool[event.uid].push(event);
    }

    if (MemPool[event.uid].length >= MinAttestation) {
      attester.attest(MemPool[event.uid]);
    }
  },
};

class Server {
  readonly port = 8000;
  readonly host = "localhost";

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
          } catch (err) {
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

    server.listen(this.port, this.host, () => {
      console.log(`Server is running on http://${this.host}:${this.port}`);
    });
  }
}

new Server().start();
