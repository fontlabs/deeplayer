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
  "0x7b941196e87bbf0f0ee85717c68f49ad88ef598b81943ff4bde11dfea5e1b9a4";
const AVS_DIRECTORY: Hex =
  "0x9cad346e85eea93d429ab78aba5e1547bd9782fe41c30dfbe301a622957910cc";
const AVS_MANAGER: Hex =
  "0x9e792c8287424fd3927f3070a7d3e4537df6543a6405ee25de0ff1b5f9933104";
const DELEGATION_MANAGER: Hex =
  "0x4f9789410e46b594e2f67a2b0c5a1cedf4ac453f8083e4f800c5745d8bac1e48";

const HOLESKY_NEBULA: Hex = "0xa2236475db73775aD69aE4b4099Ac4B8FF374085";

const API = axios.create({ baseURL: process.env.MAIN_URL });

type TokenLockedEvent = {
  uid: Hex;
  coinType: string;
  decimals: number;
  amount: bigint;
  receiver: Hex;
  block_number: bigint;
  chain_id: number;
};

interface EventListenerCallback {
  onEvent: (events: TokenLockedEvent[]) => void;
}

class EventSigner {
  async sign(
    event: TokenLockedEvent
  ): Promise<
    (TokenLockedEvent & { signature: string; signer: string }) | null
  > {
    if (!process.env.SECRET_KEY_KRYPTONE)
      throw new Error("Invalid secret key!");
    try {
      const signer = Ed25519Keypair.fromSecretKey(
        process.env.SECRET_KEY_KRYPTONE
      );
      const { signature } = await signer.signPersonalMessage(
        new TextEncoder().encode(event.uid)
      );
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
        API.post("/submit", data);
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
      pollingInterval: 60_000, // 1 Minutes
      onLogs: (events) => {
        console.log(events);
        callback.onEvent(
          events.map((event) => {
            return {
              uid: event.args.uid!,
              coinType: event.args.coinType!,
              decimals: Number(event.args.decimals!),
              amount: event.args.amount!,
              receiver: event.args.receiver!,
              block_number: event.blockNumber,
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
    if (!process.env.SECRET_KEY_KRYPTONE)
      throw new Error("Invalid secret key!");

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
      const signer = Ed25519Keypair.fromSecretKey(
        process.env.SECRET_KEY_KRYPTONE
      );
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
