import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";
import dotenv from "dotenv";
import type { Hex, WatchEventReturnType } from "viem";
import { createPublicClient, http, parseAbiItem } from "viem";
import { holesky } from "viem/chains";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { bcs } from "@mysten/sui/bcs";

dotenv.config();

const SUI_CONTRACT: Hex = "0x";
const AVS_DIRECTORY: Hex = "0x";
const SUI_CONTRACT_STATE: Hex = "0x";

const ETHEREUM_CONTRACT: Hex = "0x";

type EthereumMessage = {
  uid: Hex;
  coinType: string;
  decimals: bigint;
  amount: bigint;
  receiver: Hex;
  block_number: bigint;
};

interface EventListenerCallback {
  onEvent: (events: EthereumMessage[]) => void;
}
class EventAttester {
  async attestEvent(event: EthereumMessage) {
    try {
      const client = new SuiClient({ url: getFullnodeUrl("testnet") });

      if (!process.env.SECRET_KEY) throw new Error("Invalid secret key!");

      const signer = Ed25519Keypair.fromSecretKey(process.env.SECRET_KEY);

      const expiry = Date.now() + 30_000;
      const salt = new TextEncoder().encode(event.uid);
      const expiryBytes = new TextEncoder().encode(expiry.toString());

      const msg = new Uint8Array([...salt, ...expiryBytes]);
      const { signature } = await signer.signPersonalMessage(msg);

      let signature_bytes = new TextEncoder().encode(signature);

      const transaction = new Transaction();
      transaction.moveCall({
        target: `${SUI_CONTRACT}::nebula::attest`,
        arguments: [
          transaction.object(SUI_CONTRACT_STATE),
          transaction.object(AVS_DIRECTORY),
          transaction.pure(bcs.vector(bcs.u8()).serialize(signature_bytes)),
          transaction.pure(bcs.vector(bcs.u8()).serialize(salt)),
          transaction.pure.u64(expiry),
          transaction.pure.address(event.uid),
          transaction.pure.u64(holesky.id),
          transaction.pure.u64(event.block_number),
          transaction.pure.u64(event.amount),
          transaction.pure.u64(event.decimals),
          transaction.pure.address(event.receiver),
          transaction.object(SUI_CLOCK_OBJECT_ID),
        ],
        typeArguments: [event.coinType],
      });
      transaction.setGasBudget(5_000_000);
      const { digest } = await client.signAndExecuteTransaction({
        signer,
        transaction,
      });
    } catch (error) {}
  }
}

const eventAttester = new EventAttester();

const callback: EventListenerCallback = {
  onEvent(events: EthereumMessage[]) {
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

    this.unwatch = publicClient.watchEvent({
      address: ETHEREUM_CONTRACT,
      fromBlock,
      event: parseAbiItem(
        "event TokenLocked(bytes32 indexed uid, string coinType, uint256 decimals, uint256 amount, bytes32 receiver)"
      ),
      onLogs: (events) =>
        callback.onEvent(
          events.map((event) => {
            return {
              uid: event.args.uid!,
              coinType: event.args.coinType!,
              decimals: event.args.decimals!,
              amount: event.args.amount!,
              receiver: event.args.receiver!,
              block_number: event.blockNumber,
            };
          })
        ),
    });
  }

  stopListening() {
    if (this.unwatch) this.unwatch();
  }
}

const eventListener = new EventListener();
eventListener.startListening(callback);
