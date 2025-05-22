import dotenv from "dotenv";

import axios from "axios";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";
import { createPublicClient, defineChain, http, parseAbiItem } from "viem";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

import type { Hex, WatchEventReturnType } from "viem";

dotenv.config();

const DeepLayer: Hex =
  "0x8c4bcfe5cac89ea732d9f507f46d56a7e37e3d161007060a5686b9399a9ea03c";
const AVS_DIRECTORY: Hex =
  "0x972411f5178b5de7b7616f1a65bdf5ada2c89f62693cbc6b7d2df165669aec37";
const AVS_MANAGER: Hex =
  "0xafcde1ad80463f96bb2163935b1669e6d68479b12973ea4286f56295c58a9233";
const DELEGATION_MANAGER: Hex =
  "0x5ce45c986b9b830939998114531c30a84a9da636912e5d9af596614d41364316";

const HOLESKY_NEBULA: Hex = "0x5629A11542f5582A466d281f3Ce8Aa5309f42837";

const API = axios.create({ baseURL: process.env.MAIN_URL });

type TokenLockedEvent = {
  uid: Hex;
  coinType: string;
  decimals: number;
  amount: string;
  receiver: Hex;
  block_number: string;
  chain_id: number;
};

interface EventListenerCallback {
  onEvent: (events: TokenLockedEvent[]) => void;
}

class EventSigner {
  async sign(event: TokenLockedEvent): Promise<
    | (TokenLockedEvent & {
        signature: Uint8Array<ArrayBufferLike>;
        signer: string;
      })
    | null
  > {
    if (!process.env.SECRET_KEY) throw new Error("Invalid secret key!");
    try {
      const signer = Ed25519Keypair.fromSecretKey(process.env.SECRET_KEY);
      const signature = await signer.sign(new TextEncoder().encode(event.uid));
      return {
        ...event,
        signature,
        signer: signer.getPublicKey().toSuiAddress(),
      };
    } catch (error) {
      console.error("Error attesting event:", error);
      return null;
    }
  }
}

const eventSigner = new EventSigner();

const callback: EventListenerCallback = {
  onEvent(events: TokenLockedEvent[]) {
    events.forEach(async (event) => {
      const data = await eventSigner.sign(event);
      if (data) {
        API.post("/submit", JSON.stringify(data));
      }
    });
  },
};

class EventListener {
  unwatch: WatchEventReturnType | undefined = undefined;

  async startListening(callback: EventListenerCallback) {
    const publicClient = createPublicClient({
      chain: defineChain({
        id: 17_000,
        name: "Holesky",
        nativeCurrency: { name: "Holesky Ether", symbol: "ETH", decimals: 18 },
        rpcUrls: {
          default: {
            http: ["https://rpc.ankr.com/eth_holesky"],
          },
        },
      }),
      transport: http(),
    });

    const fromBlock = await publicClient.getBlockNumber();

    console.log("Started listening from block: ", fromBlock);

    this.unwatch = publicClient.watchEvent({
      address: HOLESKY_NEBULA,
      fromBlock,
      event: parseAbiItem(
        "event TokenLocked(bytes32 indexed uid, string coinType, uint256 decimals, uint256 amount, bytes32 receiver)"
      ),
      pollingInterval: 15_000, // 15 Secs
      onLogs: (events) => {
        callback.onEvent(
          events.map((event) => {
            return {
              uid: event.args.uid!,
              coinType: event.args.coinType!,
              decimals: Number(event.args.decimals!),
              amount: String(event.args.amount!),
              receiver: event.args.receiver!,
              block_number: String(event.blockNumber),
              chain_id: 17_000,
            } as TokenLockedEvent;
          })
        );
      },
      onError: (error) => {
        console.log(error);
      },
    });
  }

  stopListening() {
    if (this.unwatch) this.unwatch();
  }
}

class Registrar {
  async registerToAVS() {
    if (!process.env.SECRET_KEY) throw new Error("Invalid secret key!");

    try {
      const transaction = new Transaction();
      transaction.moveCall({
        target: `${DeepLayer}::nebula::register_operator`,
        arguments: [
          transaction.object(AVS_MANAGER),
          transaction.object(AVS_DIRECTORY),
          transaction.object(DELEGATION_MANAGER),
          transaction.object(SUI_CLOCK_OBJECT_ID),
        ],
      });
      transaction.setGasBudget(50_000_000);

      const client = new SuiClient({ url: getFullnodeUrl("testnet") });
      const signer = Ed25519Keypair.fromSecretKey(process.env.SECRET_KEY);
      const { digest } = await client.signAndExecuteTransaction({
        signer,
        transaction,
      });
      console.log("Transaction digest:", digest);
    } catch (error) {}
  }
}

new EventListener().startListening(callback);
new Registrar().registerToAVS();
