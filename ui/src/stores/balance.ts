import { CoinAPI } from "@/scripts/coin";
import { strategies } from "@/scripts/constant";
import { Contract } from "@/scripts/contract";
import { Clients } from "@/scripts/sui";
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
    getBalances(owner?: string) {
      this.getCoinBalances(owner);
      this.getRestakedBalances(owner);
      this.getTotalValueRestaked();
    },

    getOperatorBalances(owner?: string) {
      this.getTotalRestakedSUI();
      this.getYourShares();
      this.getTotalShares();
      this.getAVSSecured();
    },

    getAVSBalance(owner?: string) {
      this.getSUIStaked();
      this.getTotalNumOperators();
      this.getTotalNumStakers();
    },

    async getCoinBalances(owner?: string) {
      if (!owner) return;

      this.balances = await CoinAPI.getCoinsBalance(
        owner,
        strategies.map((strategy) => strategy.type)
      );
    },

    async getRestakedBalances(owner?: string) {
      if (!owner) return;

      const transactionBlock = await Contract.getStakerDepositShares(owner);
      if (!transactionBlock) return;

      const {} = await Clients.suiClient.dryRunTransactionBlock({
        transactionBlock: transactionBlock as any,
      });

      this.restaked_balances = {};
    },

    async getTotalValueRestaked() {
      const transactionBlock = await Contract.getDepositShares(
        strategies.map((strategy) => strategy.type)
      );
      if (!transactionBlock) return;

      const {} = await Clients.suiClient.dryRunTransactionBlock({
        transactionBlock: transactionBlock as any,
      });

      this.total_value_restaked = {};
    },

    async getTotalRestakedSUI() {},

    async getYourShares() {},

    async getTotalShares() {},

    async getAVSSecured() {},

    async getSUIStaked() {},

    async getTotalNumOperators() {},

    async getTotalNumStakers() {},
  },
});
