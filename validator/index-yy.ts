import dotenv from "dotenv";

import axios from "axios";
import {
  createPublicClient,
  defineChain,
  http as viemHTTP,
  parseAbiItem,
} from "viem";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import http from "http";

import type { Hex, WatchEventReturnType } from "viem";

dotenv.config();

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
  async sign(
    event: TokenLockedEvent,
    key: string
  ): Promise<
    | (TokenLockedEvent & {
        signature: number[];
        signer: string;
      })
    | null
  > {
    try {
      const signer = Ed25519Keypair.fromSecretKey(key);
      const signature = await signer.sign(new TextEncoder().encode(event.uid));

      return {
        ...event,
        signature: Array.from(signature),
        signer: signer.getPublicKey().toSuiAddress(),
      };
    } catch (error) {
      console.error("Error attesting event:", error);
      return null;
    }
  }
}

const eventSigner = new EventSigner();

const callbackFontLabs: EventListenerCallback = {
  onEvent(events: TokenLockedEvent[]) {
    events.forEach(async (event) => {
      const data = await eventSigner.sign(
        event,
        process.env.SECRET_KEY_FONTLABS!
      );
      if (data) {
        API.post("/submit", JSON.stringify(data));
      }
    });
  },
};

const callbackShunlexxi: EventListenerCallback = {
  onEvent(events: TokenLockedEvent[]) {
    events.forEach(async (event) => {
      const data = await eventSigner.sign(
        event,
        process.env.SECRET_KEY_SHUNLEXXI!
      );
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
      transport: viemHTTP(),
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

const eventListnerFontLabs = new EventListener();
eventListnerFontLabs.startListening(callbackFontLabs);

const eventListnerShunlexxi = new EventListener();
eventListnerShunlexxi.startListening(callbackShunlexxi);

class Server {
  start() {
    const server = http.createServer((_, res) => {
      res.setHeader("Content-Type", "application/json");
      res.writeHead(200);
      res.end(JSON.stringify({ message: "OK" }));
    });

    server.listen(process.env.PORT);
  }
}

const server = new Server();
server.start();
