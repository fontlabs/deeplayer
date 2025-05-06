<script setup lang="ts">
import OutIcon from '@/components/icons/OutIcon.vue';
import { useWalletStore } from '@/stores/wallet';

const walletStore = useWalletStore();
</script>

<template>
    <section>
        <div class="app_width">
            <div class="withdraws">
                <div class="title">
                    <h3>Withdraws</h3>
                </div>

                <div class="withdraws_wrapper">
                    <div class="toolbar">
                        <input type="text" placeholder="Search">

                        <div class="tabs">
                            <button class="tab tab_active">All</button>
                            <button class="tab">Completed only</button>
                        </div>
                    </div>

                    <table v-if="walletStore.address">
                        <thead>
                            <tr>
                                <td>Coin</td>
                                <td>Amount</td>
                                <td>Withdrawn on</td>
                                <td>Claimable on</td>
                                <td>Actions</td>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="withdraw, index in 1" :key="index">
                                <td>
                                    <div class="withdraw_info">
                                        <img :src="'/images/sui.png'" alt="withdraw">
                                        <p>{{ 'SUI' }}</p>
                                    </div>
                                </td>
                                <td>0</td>
                                <td>
                                    <p class="date">11th May, 2025</p>
                                </td>
                                <td>
                                    <p class="date">18th May, 2025</p>
                                </td>
                                <td>
                                    <div class="actions">
                                        <button>Claim</button>
                                    </div>
                                </td>
                            </tr>
                        </tbody>
                    </table>

                    <div v-else>
                        <div class="empty">
                            <img src="/images/empty.png" alt="empty">
                            <p>No withdraws</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
</template>

<style scoped>
.withdraws {
    padding: 30px 0;
}

.title h3 {
    font-size: 20px;
    color: var(--tx-dimmed);
    font-weight: 500;
}

.withdraws_wrapper {
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

.withdraw_info {
    display: flex;
    align-items: center;
    gap: 8px;
}

.withdraw_info img {
    height: 24px;
    width: 24px;
    border-radius: 8px;
}

.withdraw_info p {
    font-size: 14px;
    color: var(--tx-semi);
}

.actions {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 10px;
}

.withdraws .actions button {
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



.date {
    font-size: 14px;
    color: var(--tx-semi);
}
</style>