import { defineStore } from "pinia";
import type { Hex } from "viem";

export const useWalletStore = defineStore("wallet", {
  state: () => ({
    address: null as Hex | null,
    balances: {} as Record<Hex, number>,
    approvals: {} as Record<Hex, number>,
  }),
  actions: {
    setAddress(newAddress: Hex | null) {
      this.address = newAddress;
    },
    setBalance(token: Hex, balance: number) {
      this.balances[token] = balance;
    },
    setApproval(token: Hex, approval: number) {
      this.approvals[token] = approval;
    },
  },
});
