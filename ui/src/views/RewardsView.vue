<script setup lang="ts">
import OutIcon from '@/components/icons/OutIcon.vue';
import { useWalletStore } from '@/stores/wallet';

const walletStore = useWalletStore();
</script>

<template>
    <section>
        <div class="app_width">
            <div class="rewards">
                <div class="title">
                    <h3>Rewards</h3>
                </div>

                <div class="rewards_wrapper">
                    <div class="toolbar">
                        <input type="text" placeholder="Search">

                        <div class="tabs">
                            <button class="tab tab_active">All</button>
                            <button class="tab">Claimed only</button>
                        </div>
                    </div>

                    <table v-if="walletStore.address">
                        <thead>
                            <tr>
                                <td>AVS</td>
                                <td>Allocation</td>
                                <td>Coin</td>
                                <td>Expiry on</td>
                                <td>Actions</td>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="reward, index in 1" :key="index">
                                <td>
                                    <RouterLink
                                        :to="'/avs/0x7b941196e87bbf0f0ee85717c68f49ad88ef598b81943ff4bde11dfea5e1b9a4'">
                                        <div class="avs">
                                            <img :src="'/images/colors.png'" alt="reward">
                                            <p>Nebula</p>
                                            <OutIcon />
                                        </div>
                                    </RouterLink>
                                </td>
                                <td>0</td>
                                <td>
                                    <div class="reward_info">
                                        <img :src="'/images/sui.png'" alt="reward">
                                        <p>{{ 'SUI' }}</p>
                                    </div>
                                </td>
                                <td>
                                    <p class="date">31st May, 2025</p>
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
                            <p>No rewards</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
</template>

<style scoped>
.rewards {
    padding: 30px 0;
}

.title h3 {
    font-size: 20px;
    color: var(--tx-dimmed);
    font-weight: 500;
}

.rewards_wrapper {
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

.reward_info {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 8px;
}

.reward_info img {
    height: 24px;
    width: 24px;
    border-radius: 8px;
}

.reward_info p {
    font-size: 14px;
    color: var(--tx-semi);
}

.actions {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 10px;
}

.rewards .actions button {
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

.avs {
    display: flex;
    align-items: center;
    gap: 8px;
}

.avs img {
    width: 18px;
    height: 18px;
}

.avs p {
    font-size: 14px;
    color: var(--tx-semi);
}

.date {
    font-size: 14px;
    color: var(--tx-semi);
}
</style>