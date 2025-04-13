import { config } from "./config";
import { waitForTransactionReceipt, writeContract } from "@wagmi/core";
import type { Hex } from "viem";
import { nebulaAbi } from "../abis/nebula";

const Contract = {
  address: "0xF42A8457851E209d95f876937f8f043b14dA23c1" as Hex,

  async lock(token: Hex, amount: bigint, receiver: Hex): Promise<Hex | null> {
    try {
      const result = await writeContract(config, {
        abi: nebulaAbi,
        address: this.address,
        functionName: "lock",
        args: [token, amount, receiver],
      });

      const receipt = await waitForTransactionReceipt(config, {
        hash: result,
      });

      return receipt.transactionHash;
    } catch (error) {
      return null;
    }
  },

  async lockETH(amount: bigint, receiver: Hex): Promise<Hex | null> {
    try {
      const result = await writeContract(config, {
        abi: nebulaAbi,
        address: this.address,
        functionName: "lockETH",
        args: [receiver],
        value: amount,
      });

      const receipt = await waitForTransactionReceipt(config, {
        hash: result,
      });

      return receipt.transactionHash;
    } catch (error) {
      return null;
    }
  },
};

export { Contract };
