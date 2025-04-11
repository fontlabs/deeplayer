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
    value_restaked: {} as { [key: string]: bigint },
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
    getBalances(owner: string) {
      this.getCoinBalances(owner);
      this.getValueRestaked(owner);
      this.getTotalValueRestaked(owner);
    },

    getOperatorBalances(owner: string) {
      this.getOperatorShares(owner);
      this.getAVSSecured(owner);
    },

    getAVSBalance(owner: string) {
      this.getTotalAVSValueRestaked(owner);
      this.getTotalNumOperators(owner);
      this.getTotalNumStakers(owner);
    },

    async getCoinBalances(owner: string) {
      this.balances = await CoinAPI.getCoinsBalance(
        owner,
        strategies.map((strategy) => strategy.type)
      );
    },

    async getValueRestaked(owner: string) {
      const transaction = Contract.getAllStakerShares(
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

      const { results } = await Clients.suiClient.devInspectTransactionBlock({
        transactionBlock: transaction,
        sender: owner,
      });
      if (!results) return;
      if (!results[0].returnValues) return;

      const value_restaked = bcs
        .vector(bcs.U64)
        .parse(Uint8Array.from(results[0].returnValues[0][0]));

      strategies.forEach((strategy, index) => {
        this.value_restaked[strategy.type] = BigInt(value_restaked[index]);
      });
    },

    async getTotalValueRestaked(owner: string) {
      const transaction = Contract.getAllTotalShares(
        strategies.map((strategy) =>
          strategy.type
            .replace(
              SUI_TYPE_ARG,
              "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI"
            )
            .replace("0x", "")
        )
      );

      const { results } = await Clients.suiClient.devInspectTransactionBlock({
        transactionBlock: transaction,
        sender: owner,
      });
      if (!results) return;
      if (!results[0].returnValues) return;

      const total_value_restaked = bcs
        .vector(bcs.U64)
        .parse(Uint8Array.from(results[0].returnValues[0][0]));

      strategies.forEach((strategy, index) => {
        this.total_value_restaked[strategy.type] = BigInt(
          total_value_restaked[index]
        );
      });
    },

    async getOperatorShares(owner: string) {},

    async getAVSSecured(owner: string) {},

    async getTotalAVSValueRestaked(owner: string) {},

    async getTotalNumOperators(owner: string) {},

    async getTotalNumStakers(owner: string) {},
  },
});
