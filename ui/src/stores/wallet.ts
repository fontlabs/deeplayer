import { defineStore } from "pinia";

export const useWalletStore = defineStore("wallet", {
  state: () => ({
    address: null as string | null,
  }),
  actions: {
    setAddress(address: string | null) {
      this.address = address;
    },
  },
});
