<script setup lang="ts">
import { strategy_ids } from '@/scripts/constant';
import { Converter } from '@/scripts/converter';
import { onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useCurrentAccount } from 'sui-dapp-kit-vue';
import type { Strategy } from '@/scripts/types';
import { useBalanceStore } from '@/stores/balance';

const router = useRouter();
const balanceStore = useBalanceStore();
const { currentAccount } = useCurrentAccount();
const search = ref<string | undefined>(undefined);
const allStrategy = ref<Strategy[]>(strategy_ids);
const type = ref<'all' | 'sui_lst' | 'others'>('all');

const getStrategies = () => {
  allStrategy.value = strategy_ids.filter(
    s => {
      if (type.value == 'all') {
        return search.value ? s.coin.name.toLowerCase().includes(search.value.toLowerCase()) :
          true;
      }
      else if (type.value == 'sui_lst') {
        return search.value ?
          s.coin.name.toLowerCase().includes(search.value.toLowerCase()) && (s.coin.isLst || s.coin.isNative) :
          (s.coin.isLst || s.coin.isNative);
      } else {
        return search.value ?
          s.coin.name.toLowerCase().includes(search.value.toLowerCase()) && !(s.coin.isLst || s.coin.isNative) :
          !(s.coin.isLst || s.coin.isNative);
      }
    }
  );
};

watch(type, () => {
  getStrategies();
});

watch(search, () => {
  getStrategies();
});



onMounted(() => {
  balanceStore.getBalances(currentAccount.value?.address);
});
</script>

<template>
  <section>
    <div class="app_width">
      <div class="restake">
        <div class="dashboard">
          <div class="title">
            <h3>Dashboard</h3>
          </div>

          <div class="stats">
            <div class="stat">
              <p class="name">Total Restaked
              </p>
              <p class="value">0 <span>SUI</span></p>

              <div class="actions">
                <button>Unstake</button>
                <button>Withdraw</button>
              </div>
            </div>

            <div class="stat">
              <p class="name">Claimable Rewards</p>
              <p class="value">0 <span>SUI</span></p>

              <div class="actions">
                <button>Claim Rewards</button>
              </div>
            </div>
          </div>
        </div>

        <div class="coins">
          <div class="title">
            <h3>Coins</h3>
          </div>

          <div class="coins_wrapper">
            <div class="toolbar">
              <div class="tabs">
                <button :class="type == 'all' ? 'tab tab_active' : 'tab'" @click="type = 'all'">All</button>
                <button :class="type == 'sui_lst' ? 'tab tab_active' : 'tab'" @click="type = 'sui_lst'">SUI &
                  LSTs</button>
                <button :class="type == 'others' ? 'tab tab_active' : 'tab'" @click="type = 'others'">Others</button>
              </div>

              <input type="text" v-model="search" placeholder="Search">
            </div>

            <table>
              <thead>
                <tr>
                  <td>Name</td>
                  <td>Wallet Balance</td>
                  <td>Restaked Balance</td>
                  <td>Total Value Restaked</td>
                  <td>Actions</td>
                </tr>
              </thead>
              <tbody>
                <tr v-for="strategy in allStrategy" :key="strategy.address">
                  <td @click="router.push(`/restake/${strategy.address}`)">
                    <div class="coin_info">
                      <img :src="strategy.coin.image" alt="btc">
                      <p>{{ strategy.coin.name }} <span>{{ strategy.coin.symbol }}</span></p>
                    </div>
                  </td>
                  <td>
                    {{ Converter.toMoney(Converter.fromSUI(balanceStore.balances[strategy.coin.type],
                      strategy.coin.decimals))
                    }}
                  </td>
                  <td>
                    {{ Converter.toMoney(Converter.fromSUI(balanceStore.restaked_balances[strategy.coin.type],
                      strategy.coin.decimals))
                    }}
                  </td>
                  <td>
                    {{ Converter.toMoney(Converter.fromSUI(balanceStore.total_value_restaked[strategy.coin.type],
                      strategy.coin.decimals))
                    }}
                  </td>
                  <td>
                    <div class="actions">
                      <RouterLink :to="`/restake/${strategy.address}`">
                        <button>Restake</button>
                      </RouterLink>
                      <RouterLink :to="`/restake/${strategy.address}/unstake`">
                        <button>Unstake</button>
                      </RouterLink>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.restake {
  padding: 20px 0;
}

.title h3 {
  font-size: 20px;
  color: var(--tx-dimmed);
  font-weight: 500;
}

.stats {
  margin-top: 2%;
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20px;
}

.stat {
  background: var(--bg-light);
  border: 1px solid var(--bg-lighter);
  border-radius: 8px;
  padding: 16px;
}

.stat .name {
  font-size: 14px;
  color: var(--tx-semi);
}

.stat .value {
  font-size: 30px;
  color: var(--tx-normal);
  margin-top: 10px;
}

.stat .value span {
  color: var(--tx-dimmed);
}

.stat .actions {
  margin-top: 80px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
}

.stat .actions button {
  height: 40px;
  width: 100%;
  border-radius: 20px;
  background: none;
  border: 1px solid var(--bg-lightest);
  font-size: 14px;
  color: var(--tx-dimmed);
  cursor: pointer;
}

.coins {
  margin-top: 40px;
}

.coins_wrapper {
  margin-top: 20px;
  background: var(--bg-light);
  border: 1px solid var(--bg-lighter);
  border-radius: 8px;
  padding: 16px;
}

.tabs {
  display: flex;
  align-items: center;
  gap: 8px;
}

.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.toolbar input {
  height: 36px;
  width: 300px;
  padding: 0 16px;
  background: none;
  border: 1px solid var(--bg-lightest);
  border-radius: 20px;
  outline: none;
  color: var(--tx-normal);
}

.tab {
  padding: 0 16px;
  height: 36px;
  border-radius: 20px;
  background: none;
  border: none;
  font-size: 14px;
  color: var(--tx-semi);
  cursor: pointer;
}

.tab_active {
  background: var(--bg-lighter);
}

table {
  margin-top: 10px;
  border-collapse: collapse;
  width: 100%;
}

td:first-child {
  width: 40%;
}

td:not(:first-child) {
  text-align: right;
}

thead tr {
  height: 40px;
  border-bottom: 1px solid var(--bg-lighter);
}

thead td {
  font-size: 12px;
  color: var(--tx-dimmed);
  text-transform: uppercase;
}

tbody tr {
  height: 60px;
  cursor: pointer;
}

tbody td {
  color: var(--tx-semi);
}

tbody tr:not(:last-child) {
  border-bottom: 1px solid var(--bg-lighter);
}

.coin_info {
  display: flex;
  align-items: center;
  gap: 8px;
}

.coin_info img {
  height: 24px;
  width: 24px;
  border-radius: 12px;
}

.coin_info p {
  font-size: 14px;
  color: var(--tx-semi);
}

.coin_info p span {
  margin-left: 8px;
  color: var(--tx-dimmed);
}

.actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
}

.coins .actions button {
  padding: 0 10px;
  height: 30px;
  border-radius: 20px;
  background: var(--primary-light);
  border: none;
  font-size: 12px;
  color: var(--bg);
  cursor: pointer;
  font-weight: 500;
}

.coins .actions a:last-child button {
  background: var(--bg-lightest);
  color: var(--tx-semi);
}
</style>