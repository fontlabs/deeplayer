<script setup lang="ts">
import ChevronLeftIcon from '@/components/icons/ChevronLeftIcon.vue';
import OutIcon from '@/components/icons/OutIcon.vue';
import { operators, findService } from '@/scripts/constant';
import { Converter } from '@/scripts/converter';
import type { AVS } from '@/scripts/types';
import { useBalanceStore } from '@/stores/balance';
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

const route = useRoute();
const router = useRouter();
const balanceStore = useBalanceStore();
const service = ref<AVS | undefined>(undefined);

const getService = (address: string) => {
    service.value = findService(address);
};

onMounted(() => {
    getService(route.params.id.toString());
});
</script>

<template>
    <section>
        <div class="app_width">
            <div class="avs" v-if="service">
                <div class="avs_info">
                    <div class="head">
                        <RouterLink to="/avs">
                            <div class="back">
                                <ChevronLeftIcon />
                                <p>AVS</p>
                            </div>
                        </RouterLink>
                    </div>

                    <div class="stats">
                        <div class="stat">
                            <p>SUI Restaked</p>
                            <div class="value">
                                <p>
                                    {{
                                        Converter.toMoney(Converter.fromSUI(balanceStore.sui_restaked[service.address]))
                                    }}
                                </p>
                                <span>SUI</span>
                            </div>
                        </div>

                        <div class="stat">
                            <p>Total Num. Operators</p>
                            <div class="value">
                                <p>
                                    {{
                                        balanceStore.total_num_operators[service.address] || "•••"
                                    }}
                                </p>
                            </div>
                        </div>

                        <div class="stat">
                            <p>Total Num. Stakers</p>
                            <div class="value">
                                <p>
                                    {{
                                        balanceStore.total_num_stakers[service.address] || "•••"
                                    }}
                                </p>
                            </div>
                        </div>

                        <div class="stat">
                            <p>Reward Coin</p>
                            <div class="value">
                                <p>{{ service.reward_coin.symbol }}</p>
                            </div>
                        </div>
                    </div>

                    <div class="service">
                        <div class="title">
                            <h3>About</h3>
                        </div>

                        <div class="service_info">
                            <img :src="service.image" alt="service">
                            <p>{{ service.name }}</p>
                        </div>

                        <div class="description">
                            {{ service.description }}
                        </div>

                        <a v-if="service.link" :href="service.link" target="_blank" class="link">
                            <p>Learn more</p>
                            <OutIcon />
                        </a>
                    </div>
                </div>

                <div class="avs_wrapper">
                    <div class="box">
                        <div class="label">Weekly Reward</div>

                        <div class="reward">
                            <div class="reward_coin_info">
                                <img :src="service.reward_coin.image" alt="reward">
                                <p>{{ service.reward_coin.symbol }}</p>
                            </div>

                            <p class="reward_amount">
                                {{
                                    Converter.toMoney(service.weekly_rewards)
                                }}
                            </p>
                        </div>
                    </div>
                </div>
            </div>

            <div class="operators">
                <div class="title">
                    <h3>Operators</h3>
                </div>
                <table>
                    <thead>
                        <tr>
                            <td>Operator</td>
                            <td>Total Restaked (SUI)</td>
                            <td>Total Shares</td>
                            <td>AVS Secured</td>
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
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </section>
</template>

<style scoped>
.avs {
    padding: 30px 0;
    display: grid;
    grid-template-columns: 1fr 0.6fr;
    gap: 20px;
    justify-content: center;
}

.avs_wrapper {
    background: var(--bg-light);
    border: 1px solid var(--bg-lighter);
    border-radius: 8px;
    padding: 16px;
    height: fit-content;
}

.label {
    font-size: 14px;
    color: var(--tx-dimmed);
}

.head {
    display: flex;
    align-items: center;
}

.back {
    display: flex;
    align-items: center;
    gap: 8px;
}

.back p {
    font-size: 14px;
    color: var(--tx-semi);
}

.avs_info {
    height: fit-content;
}

.stats {
    margin-top: 10px;
}

.stat {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 50px;
    border-bottom: 1px solid var(--bg-lighter);
}

.stat>p {
    font-size: 14px;
    color: var(--tx-semi);
    text-transform: uppercase;
}

.stat .value {
    display: flex;
    align-items: center;
    gap: 8px;
}

.stat .value p {
    font-size: 14px;
    color: var(--tx-normal);
}

.stat .value span {
    background: var(--bg-lighter);
    font-size: 12px;
    color: var(--tx-dimmed);
    padding: 4px 6px;
    border-radius: 4px;
}

.service {
    margin-top: 20px;
}

.service .title h3 {
    font-size: 16px;
    color: var(--tx-dimmed);
    font-weight: 500;
}

.service_info {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-top: 16px;
}

.service_info img {
    height: 28px;
    width: 28px;
    border-radius: 8px;
}

.service_info p {
    font-size: 16px;
    color: var(--tx-semi);
}

.service .description {
    margin: 10px 0;
    font-size: 14px;
    color: var(--tx-dimmed);
    line-height: 20px;
}

.link {
    width: fit-content;
    display: flex;
    align-items: center;
    gap: 8px;
}

.link p {
    font-size: 14px;
    color: var(--accent-green);
}

.reward {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 20px;
}

.reward_coin_info {
    display: flex;
    align-items: center;
    gap: 10px;
}

.reward_coin_info img {
    width: 24px;
    height: 24px;
}

.reward_coin_info p {
    font-size: 16px;
    color: var(--tx-normal);
}

.reward_amount {
    font-size: 16px;
    color: var(--tx-normal);
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

.operators {
    background: var(--bg-light);
    padding: 16px;
    border-radius: 8px;
    border: 1px solid var(--bg-lighter);
}

.operators .title h3 {
    font-size: 20px;
    color: var(--tx-dimmed);
    font-weight: 500;
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
</style>