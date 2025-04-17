import { CoinAPI } from "@/scripts/coin";
import { operators, strategies } from "@/scripts/constant";
import { Contract } from "@/scripts/contract";
import { Clients } from "@/scripts/sui";
import { bcs } from "@mysten/sui/bcs";
import { SUI_TYPE_ARG } from "@mysten/sui/utils";
import { defineStore } from "pinia";

const SUI_FRAMEWORK_ADDRESS =
  "0x0000000000000000000000000000000000000000000000000000000000000002";

export const useBalanceStore = defineStore("balance", {
  state: () => ({
    // restake
    balances: {} as { [key: string]: bigint },
    value_restaked: {} as { [key: string]: bigint },
    total_value_restaked: {} as { [key: string]: bigint },

    // operator
    total_restaked_sui: {} as { [key: string]: bigint },
    your_shares: {} as { [key: string]: bigint },
    total_shares: {} as { [key: string]: { [key: string]: bigint } },
    avs_secured: {} as { [key: string]: number },

    // avs
    sui_restaked: {} as { [key: string]: bigint },
    total_num_operators: {} as { [key: string]: number },
    total_num_stakers: {} as { [key: string]: number },
  }),
  actions: {
    getBalances(owner: string | undefined) {
      if (owner) {
        this.getCoinBalances(owner);
        this.getValueRestaked(owner);
      }
      this.getTotalValueRestaked();
    },

    getOperatorBalances() {
      this.getOperatorShares();
      this.getAVSSecured();
    },

    getAVSBalance() {
      this.getTotalAVSValueRestaked();
      this.getTotalNumOperators();
      this.getTotalNumStakers();
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
            .replace(SUI_TYPE_ARG, `${SUI_FRAMEWORK_ADDRESS}::sui::SUI`)
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

    async getTotalValueRestaked() {
      const transaction = Contract.getAllTotalShares(
        strategies.map((strategy) =>
          strategy.type
            .replace(SUI_TYPE_ARG, `${SUI_FRAMEWORK_ADDRESS}::sui::SUI`)
            .replace("0x", "")
        )
      );

      const { results } = await Clients.suiClient.devInspectTransactionBlock({
        transactionBlock: transaction,
        sender: SUI_FRAMEWORK_ADDRESS,
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

    async getOperatorShares() {
      for (let index = 0; index < operators.length; index++) {
        const operator = operators[index].address;

        console.log(operator);

        const transaction = Contract.getOperatorShares(
          strategies.map((strategy) =>
            strategy.type
              .replace(SUI_TYPE_ARG, `${SUI_FRAMEWORK_ADDRESS}::sui::SUI`)
              .replace("0x", "")
          ),
          operator
        );

        const { results } = await Clients.suiClient.devInspectTransactionBlock({
          transactionBlock: transaction,
          sender: SUI_FRAMEWORK_ADDRESS,
        });
        if (!results) return;
        if (!results[0].returnValues) return;

        const total_shares = bcs
          .vector(bcs.U64)
          .parse(Uint8Array.from(results[0].returnValues[0][0]));

        strategies.forEach((strategy, index) => {
          const shares = {} as { [key: string]: bigint };
          shares[strategy.type] = BigInt(total_shares[index]);
          this.total_shares[operator] = {
            ...this.total_shares[operator],
            ...shares,
          };
        });
      }
    },

    async getAVSSecured() {},

    async getTotalAVSValueRestaked() {},

    async getTotalNumOperators() {},

    async getTotalNumStakers() {},
  },
});
