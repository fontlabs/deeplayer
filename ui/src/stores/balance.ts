import { CoinAPI } from "@/scripts/coin";
import { strategies } from "@/scripts/constant";
import { Contract } from "@/scripts/contract";
import { Clients } from "@/scripts/sui";
import { bcs } from "@mysten/sui/bcs";
import type { SuiMoveObject } from "@mysten/sui/client";
import { SUI_TYPE_ARG } from "@mysten/sui/utils";
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

      const transaction = await Contract.getAllStakerShares(
        strategies.map((strategy) =>
          strategy.type
            .replace(
              SUI_TYPE_ARG,
              "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI"
            )
            .replace("0x", "")
        ),
        owner
      );
      if (!transaction) return;

      const { results } = await Clients.suiClient.devInspectTransactionBlock({
        transactionBlock: transaction,
        sender: owner,
      });
      if (!results) return;
      if (!results[0].returnValues) return;

      const restaked_balances = bcs
        .vector(bcs.U64)
        .parse(Uint8Array.from(results[0].returnValues[0][0]));

      strategies.forEach((strategy, index) => {
        this.restaked_balances[strategy.type] = BigInt(
          restaked_balances[index]
        );
      });
    },

    async getTotalValueRestaked() {},

    async getTotalRestakedSUI() {},

    async getYourShares() {},

    async getTotalShares() {},

    async getAVSSecured() {},

    async getSUIStaked() {},

    async getTotalNumOperators() {},

    async getTotalNumStakers() {},
  },
});
