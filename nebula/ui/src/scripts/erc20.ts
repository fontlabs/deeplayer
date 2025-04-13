import { config } from "./config";
import {
  waitForTransactionReceipt,
  getBalance,
  writeContract,
  readContract,
} from "@wagmi/core";
import { erc20Abi, parseEther, zeroAddress, zeroHash, type Hex } from "viem";
import { tokenAbi } from "../abis/token";

const TokenContract = {
  async mint(token: Hex, amount: bigint): Promise<Hex | null> {
    try {
      const result = await writeContract(config, {
        abi: tokenAbi,
        address: token,
        functionName: "mint",
        args: [amount],
      });

      const receipt = await waitForTransactionReceipt(config, {
        hash: result,
      });

      return receipt.transactionHash;
    } catch (error) {
      return null;
    }
  },

  async getAllowance(token: Hex, wallet: Hex, spender: Hex): Promise<bigint> {
    try {
      console.log(token);

      if (token == zeroAddress)
        return BigInt(parseEther(Number.MAX_VALUE.toString()));

      return await readContract(config, {
        abi: erc20Abi,
        address: token,
        functionName: "allowance",
        args: [wallet, spender],
      });
    } catch (error) {
      return BigInt(0);
    }
  },

  async approve(token: Hex, spender: Hex, amount: bigint): Promise<Hex | null> {
    try {
      if (token == zeroAddress) return zeroHash;

      const result = await writeContract(config, {
        abi: erc20Abi,
        address: token,
        functionName: "approve",
        args: [spender, amount],
      });

      const receipt = await waitForTransactionReceipt(config, { hash: result });

      return receipt.transactionHash;
    } catch (error) {
      return null;
    }
  },

  async getTokenBalance(token: Hex, address: Hex): Promise<bigint> {
    try {
      const { value } = await getBalance(config, {
        token: token == zeroAddress ? undefined : token,
        address,
      });
      return value;
    } catch (error) {
      return BigInt(0);
    }
  },
};

export { TokenContract };
