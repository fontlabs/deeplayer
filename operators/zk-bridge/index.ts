import dotenv from "dotenv";
import type { Hex, WatchEventReturnType } from "viem";
import { createPublicClient, http, parseAbiItem } from "viem";
import { sepolia } from "viem/chains";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { bcs } from "@mysten/sui/bcs";

dotenv.config();

const SUI_CONTRACT: Hex = "0x";
const SUI_CONTRACT_STATE: Hex = "0x";

const ETHEREUM_CONTRACT: Hex = "0x";
const ETHEREUM_START_BLOCK: bigint = BigInt(0);

type EthereumMessage = {
  id: Hex;
  token: Hex;
  decimals: bigint;
  amount: bigint;
  receiver: Hex;
  block_number: bigint;
};

interface EventListenerCallback {
  onEvent: (events: EthereumMessage[]) => void;
}

class EventSubmitter {
  async submitEvent(event: EthereumMessage) {
    try {
      const client = new SuiClient({ url: getFullnodeUrl("mainnet") });

      if (!process.env.SECRET_KEY) throw new Error("Invalid secret key!");

      const signer = Ed25519Keypair.fromSecretKey(process.env.SECRET_KEY);

      const expiry = Date.now() + 30_000;
      const salt = new TextEncoder().encode(event.id);
      const expiryBytes = new TextEncoder().encode(expiry.toString());

      const msg = new Uint8Array([...salt, ...expiryBytes]);
      const { signature } = await signer.signPersonalMessage(msg);

      let signature_with_salt_and_expiry = new TextEncoder().encode(signature);

      const transaction = new Transaction();
      transaction.moveCall({
        target: `${SUI_CONTRACT}::zk_bridge_module::submit`,
        arguments: [
          transaction.object(SUI_CONTRACT_STATE),
          transaction.pure(
            bcs.vector(bcs.u8()).serialize(signature_with_salt_and_expiry)
          ),
          transaction.pure(bcs.vector(bcs.u8()).serialize(salt)),
          transaction.pure.u64(expiry),
          transaction.pure.address(event.id),
          transaction.pure.address(event.token),
          transaction.pure.u64(event.decimals),
          transaction.pure.u64(event.amount),
          transaction.pure.address(event.receiver),
          transaction.pure.u64(event.block_number),
        ],
        typeArguments: [],
      });
      transaction.setGasBudget(500_000);
      transaction.setSender(signer.getPublicKey().toSuiAddress());

      await client.signAndExecuteTransaction({
        signer,
        transaction,
      });
    } catch (error) {}
  }
}

const eventSubmitter = new EventSubmitter();

const callback: EventListenerCallback = {
  onEvent(events: EthereumMessage[]) {
    events.forEach((event) => eventSubmitter.submitEvent(event));
  },
};

class EventListener {
  unwatch: WatchEventReturnType | undefined = undefined;

  startListening(callback: EventListenerCallback) {
    const publicClient = createPublicClient({
      chain: sepolia,
      transport: http(),
    });

    this.unwatch = publicClient.watchEvent({
      address: ETHEREUM_CONTRACT,
      fromBlock: ETHEREUM_START_BLOCK,
      event: parseAbiItem(
        "event TokenLocked(address indexed id, bytes32 token, uint256 decimals, uint256 amount, bytes32 receiver)"
      ),
      onLogs: (events) =>
        callback.onEvent(
          events.map((event) => {
            return {
              id: event.args.id!,
              token: event.args.token!,
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
