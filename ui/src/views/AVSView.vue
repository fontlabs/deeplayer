<script setup lang="ts">
import { services } from '@/scripts/constant';
import { Converter } from '@/scripts/converter';
import { useBalanceStore } from '@/stores/balance';

const balanceStore = useBalanceStore();
</script>

<template>
    <section>
        <div class="app_width">
            <div class="avs">
                <div class="title">
                    <p>Discover</p>
                    <h3>Actively Validated Services</h3>
                </div>

                <div class="toolbar">
                    <input type="text" placeholder="Search by address/name/website">

                    <select>
                        <option value="tvl_asc">Sort by: TVL Asc.</option>
                        <option value="tvl_desc">Sort by: TVL Desc.</option>
                    </select>
                </div>

                <div class="services">
                    <RouterLink v-for="service in services" :key="service.address" :to="`/avs/${service.address}`">
                        <div class="service">
                            <div class="service_info">
                                <img src="/images/colors.png" alt="service">
                                <div class="service_info_text">
                                    <h3>{{ service.name }}</h3>
                                    <p>{{ Converter.trimAddress(service.address) }}</p>
                                </div>
                            </div>

                            <p class="description">
                                {{ service.description }}
                            </p>

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
                        </div>
                    </RouterLink>
                </div>
            </div>
        </div>
    </section>
</template>

<style scoped>
.avs {
    padding: 30px 0;
}

.title p {
    font-size: 16px;
    color: var(--tx-semi);
}

.title h3 {
    font-size: 20px;
    color: var(--tx-dimmed);
    font-weight: 500;
    margin-top: 4px;
}

.toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 16px;
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

.toolbar select {
    padding: 0 16px;
    height: 36px;
    border-radius: 20px;
    border: none;
    outline: none;
    font-size: 14px;
    color: var(--tx-semi);
    cursor: pointer;
    background: var(--bg-lighter);
}

.services {
    margin-top: 20px;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 20px;
}

.service {
    background: var(--bg-light);
    border: 1px solid var(--bg-lighter);
    border-radius: 8px;
    padding: 16px;
    cursor: pointer;
}

.service:hover {
    border: 1px solid var(--bg-lightest);
}

.service_info {
    display: flex;
    align-items: center;
    gap: 10px;
    padding-bottom: 16px;
    border-bottom: 1px solid var(--bg-lighter);
}

.service_info img {
    height: 50px;
    width: 50px;
    border-radius: 8px;
}

.service_info_text h3 {
    font-size: 16px;
    color: var(--tx-normal);
    font-weight: 400;
}

.service_info_text p {
    font-size: 14px;
    color: var(--tx-dimmed);
    margin-top: 4px;
}

.description {
    margin: 16px 0;
    height: 100px;
    overflow: hidden;
    text-overflow: ellipsis;
    line-clamp: 5;
    font-size: 14px;
    color: var(--tx-dimmed);
    line-height: 20px;
}

.stats {
    border-top: 1px solid var(--bg-lighter);
    margin-top: 10px;
}

.stat {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 50px;
}

.stat:not(:last-child) {
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
</style>