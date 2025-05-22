import type { Coin } from "./types";
import { CoinAPI } from "./coin";
import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";
import type { NightlyConnectSuiAdapter } from "@nightlylabs/wallet-selector-sui";
import { SUI_COIN } from "./constant";

const Contract = {
  DeepLayer:
    "0x8c4bcfe5cac89ea732d9f507f46d56a7e37e3d161007060a5686b9399a9ea03c",
  AVSDirectory:
    "0x972411f5178b5de7b7616f1a65bdf5ada2c89f62693cbc6b7d2df165669aec37",
  StrategyFactory:
    "0xa5a3627871928f2c0c67195f62a3d04d921eb2e3566d9ce030a5badfd421c255",
  StrategyManager:
    "0xfd75910c3d514f3bee8e4f5935397d084360ee9198a547b39e05871fafeacc3e",
  RewardsCoordinator:
    "0xc58c64144c1aa5f92f795cc204cc0476bc9cb91276c34571a5ba95f7cdae3143",
  AllocationManager:
    "0x83ef04924a88e1fd1d0ba5faaef4295babc1e0559a19281978fbd9087cfde3ea",
  DelegationManager:
    "0x5ce45c986b9b830939998114531c30a84a9da636912e5d9af596614d41364316",

  async mintCoin(
    sender: string,
    strategy: Coin,
    amount: bigint,
    adapter?: NightlyConnectSuiAdapter
  ): Promise<string | null> {
    if (!adapter) return null;

    try {
      const accounts = await adapter.getAccounts();
      if (accounts.length === 0) return null;

      const tx = new Transaction();

      if (!strategy.faucet) return null;

      tx.moveCall({
        target: `${this.DeepLayer}::${strategy.faucet.module}::mint`,
        arguments: [
          tx.object(strategy.faucet.object),
          tx.pure.u64(amount),
          tx.pure.address(sender),
        ],
        typeArguments: [strategy.type],
      });

      const { digest } = await adapter.signAndExecuteTransactionBlock({
        transactionBlock: tx as any,
        chain: "sui:testnet",
        account: accounts[0],
      });

      return digest;
    } catch (error) {
      console.log(error);

      return null;
    }
  },

  async depositIntoStrategy(
    sender: string,
    strategy: Coin,
    amount: bigint,
    adapter?: NightlyConnectSuiAdapter
  ): Promise<string | null> {
    if (!adapter) return null;

    try {
      const accounts = await adapter.getAccounts();
      if (accounts.length === 0) return null;

      const tx = new Transaction();

      let coinDesposited;
      if (strategy.type === SUI_COIN) {
        const [coinResult] = tx.splitCoins(tx.gas, [amount]);
        coinDesposited = coinResult;
      } else {
        const coins = await CoinAPI.getCoins(sender, strategy.type);
        const coinsObject = coins.data.map((coin) => coin.coinObjectId);
        if (coinsObject.length === 0) return null;
        const destinationInCoin = coinsObject[0];
        if (coinsObject.length > 1) {
          const [, ...otherInCoins] = coinsObject;
          tx.mergeCoins(destinationInCoin, otherInCoins);
        }
        const [coinResult] = tx.splitCoins(destinationInCoin, [
          tx.pure.u64(amount),
        ]);
        coinDesposited = coinResult;
      }

      tx.moveCall({
        target: `${this.DeepLayer}::delegation_module::deposit_into_strategy`,
        arguments: [
          tx.object(this.StrategyFactory),
          tx.object(this.StrategyManager),
          tx.object(this.AllocationManager),
          tx.object(this.DelegationManager),
          tx.object(coinDesposited),
        ],
        typeArguments: [strategy.type],
      });

      const { digest } = await adapter.signAndExecuteTransactionBlock({
        transactionBlock: tx as any,
        chain: "sui:testnet",
        account: accounts[0],
      });

      return digest;
    } catch (error) {
      return null;
    }
  },

  async delegate(
    operator: string,
    adapter?: NightlyConnectSuiAdapter
  ): Promise<string | null> {
    if (!adapter) return null;

    try {
      const accounts = await adapter.getAccounts();
      if (accounts.length === 0) return null;

      const tx = new Transaction();

      tx.moveCall({
        target: `${this.DeepLayer}::delegation_module::delegate`,
        arguments: [
          tx.object(this.StrategyManager),
          tx.object(this.AllocationManager),
          tx.object(this.DelegationManager),
          tx.pure.address(operator),
          tx.object(SUI_CLOCK_OBJECT_ID),
        ],
      });

      const { digest } = await adapter.signAndExecuteTransactionBlock({
        transactionBlock: tx as any,
        chain: "sui:testnet",
        account: accounts[0],
      });

      return digest;
    } catch (error) {
      return null;
    }
  },

  async undelegate(
    staker: string,
    adapter?: NightlyConnectSuiAdapter
  ): Promise<string | null> {
    if (!adapter) return null;

    try {
      const accounts = await adapter.getAccounts();
      if (accounts.length === 0) return null;

      const tx = new Transaction();

      tx.moveCall({
        target: `${this.DeepLayer}::delegation_module::undelegate`,
        arguments: [
          tx.object(this.StrategyManager),
          tx.object(this.AllocationManager),
          tx.object(this.DelegationManager),
          tx.pure.address(staker),
        ],
      });

      const { digest } = await adapter.signAndExecuteTransactionBlock({
        transactionBlock: tx as any,
        chain: "sui:testnet",
        account: accounts[0],
      });

      return digest;
    } catch (error) {
      return null;
    }
  },

  async redelegate(
    new_operator: string,
    adapter?: NightlyConnectSuiAdapter
  ): Promise<string | null> {
    if (!adapter) return null;

    try {
      const accounts = await adapter.getAccounts();
      if (accounts.length === 0) return null;

      const tx = new Transaction();

      tx.moveCall({
        target: `${this.DeepLayer}::delegation_module::redelegate`,
        arguments: [
          tx.object(this.StrategyManager),
          tx.object(this.AllocationManager),
          tx.object(this.DelegationManager),
          tx.pure.address(new_operator),
          tx.object(SUI_CLOCK_OBJECT_ID),
        ],
      });

      const { digest } = await adapter.signAndExecuteTransactionBlock({
        transactionBlock: tx as any,
        chain: "sui:testnet",
        account: accounts[0],
      });

      return digest;
    } catch (error) {
      return null;
    }
  },

  getAllTotalShares(strategyIds: string[]): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::strategy_manager_module::get_all_total_shares`,
      arguments: [
        tx.object(this.StrategyManager),
        tx.pure(bcs.vector(bcs.String).serialize(strategyIds)),
      ],
    });

    return tx;
  },

  getStakerShares(strategyId: string, staker: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::strategy_manager_module::get_staker_shares`,
      arguments: [
        tx.object(this.StrategyManager),
        tx.pure.string(strategyId),
        tx.pure.address(staker),
      ],
    });

    return tx;
  },

  getAllStakerShares(strategyIds: string[], staker: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::strategy_manager_module::get_all_staker_shares`,
      arguments: [
        tx.object(this.StrategyManager),
        tx.pure(bcs.vector(bcs.String).serialize(strategyIds)),
        tx.pure.address(staker),
      ],
    });

    return tx;
  },

  getDepositShares(staker: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::strategy_manager_module::deposit_shares`,
      arguments: [tx.object(this.StrategyManager), tx.pure.string(staker)],
    });

    return tx;
  },

  isDelegated(staker: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::delegation_module::is_delegated`,
      arguments: [tx.object(this.DelegationManager), tx.pure.address(staker)],
    });

    return tx;
  },

  isDelegatedTo(staker: string, operator: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::delegation_module::is_delegated_to`,
      arguments: [
        tx.object(this.DelegationManager),
        tx.pure.address(staker),
        tx.pure.address(operator),
      ],
    });

    return tx;
  },

  isOperator(account: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::delegation_module::is_operator`,
      arguments: [tx.object(this.DelegationManager), tx.pure.string(account)],
    });

    return tx;
  },

  getOperatorShares(strategyIds: string[], operator: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::delegation_module::get_operator_shares`,
      arguments: [
        tx.object(this.DelegationManager),
        tx.pure.address(operator),
        tx.pure(bcs.vector(bcs.String).serialize(strategyIds)),
      ],
    });

    return tx;
  },
};

export { Contract };
