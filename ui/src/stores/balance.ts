import { CoinAPI } from "@/scripts/coin";
import { strategy_ids } from "@/scripts/constant";
import { defineStore } from "pinia";

export const useBalanceStore = defineStore("balance", {
  state: () => ({
    // restake
    balances: {} as { [key: string]: bigint },
    restaked_balances: {} as { [key: string]: bigint },
    total_value_restaked: {} as { [key: string]: bigint },

    // operator
    total_restaked_sui: {} as { [key: string]: bigint },
    your_shares: {} as { [key: string]: bigint },
    total_shares: {} as { [key: string]: bigint },
    avs_secured: {} as { [key: string]: number },

    // avs
    sui_restaked: {} as { [key: string]: bigint },
    total_num_operators: {} as { [key: string]: number },
    total_num_stakers: {} as { [key: string]: number },
  }),
  actions: {
    async getBalances(owner?: string) {
      this.getCoinBalances(owner);
    },
    async getCoinBalances(owner?: string) {
      if (!owner) return;

      const result = await CoinAPI.getCoinsBalance(
        owner,
        strategy_ids.map((strategy) => strategy.coin.type)
      );

      this.balances = result;
    },
    async getRestakedBalances(owner?: string) {
      if (!owner) return;
    },
    async getTotalValueRestaked() {},
  },
});
