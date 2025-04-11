<script setup lang="ts">
import { operators } from '@/scripts/constant';
import { Converter } from '@/scripts/converter';
import { useBalanceStore } from '@/stores/balance';
import { useRouter } from 'vue-router';

const router = useRouter();
const balanceStore = useBalanceStore();
</script>

<template>
    <section>
        <div class="app_width">
            <div class="operators">
                <div class="title">
                    <h3>Delegate</h3>
                </div>

                <div class="operators_wrapper">
                    <div class="toolbar">
                        <input type="text" placeholder="Search">

                        <div class="tabs">
                            <button class="tab tab_active">All</button>
                            <button class="tab">Active only</button>
                        </div>
                    </div>

                    <table>
                        <thead>
                            <tr>
                                <td>Operator</td>
                                <td>Total Restaked (SUI)</td>
                                <td>Total Shares</td>
                                <td>AVS Secured</td>
                                <td>Actions</td>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="operator in operators" :key="operator.address"
                                @click="router.push(`/operator/${operator.address}`)">
                                <td>
                                    <div class="operator_info">
                                        <img :src="operator.image" alt="operator">
                                        <p>{{ operator.name }}</p>
                                    </div>
                                </td>
                                <td>
                                    {{
                                        Converter.toMoney(Converter.fromSUI(balanceStore.total_restaked_sui[operator.address]))
                                    }}
                                </td>
                                <td>
                                    {{
                                        Converter.toMoney(Converter.fromSUI(balanceStore.total_shares[operator.address]))
                                    }}
                                </td>
                                <td>
                                    {{
                                        balanceStore.avs_secured[operator.address] || "•••"
                                    }}
                                </td>
                                <td>
                                    <div class="actions">
                                        <RouterLink :to="`/operator/${operator.address}`">
                                            <button>Delegate</button>
                                        </RouterLink>
                                    </div>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </section>
</template>

<style scoped>
.operators {
    padding: 30px 0;
}

.title h3 {
    font-size: 20px;
    color: var(--tx-dimmed);
    font-weight: 500;
}

.operators_wrapper {
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
    width: 500px;
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
    border-bottom: 1px solid transparent;
}

tbody tr:hover {
    background: var(--bg-lighter);
}

tbody td {
    color: var(--tx-semi);
}

tbody tr:not(:last-child) {
    border-bottom: 1px solid var(--bg-lighter);
}

.operator_info {
    display: flex;
    align-items: center;
    gap: 8px;
}

.operator_info img {
    height: 24px;
    width: 24px;
    border-radius: 8px;
}

.operator_info p {
    font-size: 14px;
    color: var(--tx-semi);
}

.actions {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 10px;
}

.operators .actions button {
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
</style>