import { SUI_CLOCK_OBJECT_ID, SUI_TYPE_ARG } from "@mysten/sui/utils";
import dotenv from "dotenv";
import type { Hex, WatchEventReturnType } from "viem";
import { createPublicClient, defineChain, http, parseAbiItem } from "viem";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { bcs } from "@mysten/sui/bcs";

dotenv.config();

const holesky = /*#__PURE__*/ defineChain({
  id: 17000,
  name: "Holesky",
  nativeCurrency: { name: "Holesky Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: {
      http: ["https://rpc.ankr.com/eth_holesky"],
    },
  },
  blockExplorers: {
    default: {
      name: "Etherscan",
      url: "https://holesky.etherscan.io",
      apiUrl: "https://api-holesky.etherscan.io/api",
    },
  },
  contracts: {
    multicall3: {
      address: "0xca11bde05977b3631167028862be2a173976ca11",
      blockCreated: 77,
    },
    ensRegistry: {
      address: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e",
      blockCreated: 801613,
    },
    ensUniversalResolver: {
      address: "0xa6AC935D4971E3CD133b950aE053bECD16fE7f3b",
      blockCreated: 973484,
    },
  },
  testnet: true,
});

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

const HOLESKY_NEBULA: Hex = "0xa2236475db73775aD69aE4b4099Ac4B8FF374085";

const client = new SuiClient({ url: getFullnodeUrl("testnet") });

type TokenLockedEvent = {
  uid: Hex;
  coinType: string;
  decimals: number;
  amount: bigint;
  receiver: Hex;
  block_number: bigint;
};

interface EventListenerCallback {
  onEvent: (events: TokenLockedEvent[]) => void;
}
class EventAttester {
  async attestEvent(event: TokenLockedEvent) {
    if (!process.env.SECRET_KEY_2) throw new Error("Invalid secret key!");

    try {
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
            bcs.vector(bcs.U8).serialize(new TextEncoder().encode(event.uid))
          ),
          transaction.pure.u64(holesky.id),
          transaction.pure.u64(event.block_number),
          transaction.pure.u64(event.amount),
          transaction.pure.u8(event.decimals),
          transaction.pure.address(event.receiver),
          transaction.object(SUI_CLOCK_OBJECT_ID),
        ],
        typeArguments: [event.coinType],
      });
      transaction.setGasBudget(5_000_000);

      const signer = Ed25519Keypair.fromSecretKey(process.env.SECRET_KEY_2);

      const { digest } = await client.signAndExecuteTransaction({
        signer,
        transaction,
      });
      console.log("Transaction Digest:", digest);
    } catch (error) {
      console.error("Error attesting event:", error);
    }
  }
}

const eventAttester = new EventAttester();

const callback: EventListenerCallback = {
  onEvent(events: TokenLockedEvent[]) {
    events.forEach((event) => eventAttester.attestEvent(event));
  },
};

class EventListener {
  unwatch: WatchEventReturnType | undefined = undefined;

  async startListening(callback: EventListenerCallback) {
    const publicClient = createPublicClient({
      chain: holesky,
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
      pollingInterval: 60_000, // 1 Min
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
  async tryRegisterToAVS() {
    if (!process.env.SECRET_KEY_2) throw new Error("Invalid secret key!");

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

      const signer = Ed25519Keypair.fromSecretKey(process.env.SECRET_KEY_2);

      const { digest } = await client.signAndExecuteTransaction({
        signer,
        transaction,
      });
      console.log("Transaction digest:", digest);
    } catch (error) {}
  }
}

new EventListener().startListening(callback);
// new Registrar().tryRegisterToAVS();
