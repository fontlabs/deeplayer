<script setup lang="ts">
import ChevronLeftIcon from '@/components/icons/ChevronLeftIcon.vue';
import OutIcon from '@/components/icons/OutIcon.vue';
import { notify } from '@/reactives/notify';
import { findStrategy } from '@/scripts/constant';

import { Contract } from '@/scripts/contract';
import { Converter } from '@/scripts/converter';
import { Clients } from '@/scripts/sui';
import type { Coin } from '@/scripts/types';
import { useBalanceStore } from '@/stores/balance';
import { useSignAndExecuteTransactionBlock, useCurrentAccount } from 'sui-dapp-kit-vue';
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const balanceStore = useBalanceStore();
const { currentAccount } = useCurrentAccount();
const amount = ref<number | undefined>(undefined);
const strategy = ref<Coin | undefined>(undefined);
const isDelegated = ref<boolean>(false);

const { signAndExecuteTransactionBlock } = useSignAndExecuteTransactionBlock();

const setAmount = (div: number = 1) => {
    if (!strategy.value) return;

    const bal = Converter.fromSUI(
        balanceStore.balances[strategy.value.type],
        strategy.value.decimals
    );
    if (bal === undefined) return;

    amount.value = bal / div;
};

const mint = async () => {
    if (!strategy.value) return;
    if (!strategy.value.faucet) return;

    if (!currentAccount.value) {
        return notify.push({
            title: "Connect your wallet!",
            description: "Wallet connection error.",
            category: "error"
        });
    }

    try {
        const value = Converter.toSUI(strategy.value.faucet.amount, strategy.value.decimals);
        if (!value) return;

        const transactionBlock = await Contract.mintCoin(
            currentAccount.value.address,
            strategy.value,
            value
        );
        if (!transactionBlock) return;

        const { digest } = await signAndExecuteTransactionBlock({
            transactionBlock: transactionBlock as any
        });

        await Clients.suiClient.waitForTransaction({ digest });

        balanceStore.getCoinBalances(currentAccount.value.address);

        notify.push({
            title: "Minting successful!",
            description: `You have minted ${strategy.value.faucet.amount} ${strategy.value.symbol}`,
            category: "success",
            linkTitle: "View on Sui Explorer",
            linkUrl: `https://suiscan.xyz/testnet/tx/${digest}?network=testnet`,
        });
    } catch (error) {
        notify.push({
            title: "Minting failed!",
            description: "Transaction error.",
            category: "error"
        });
    }
};

const restake = async () => {
    if (!strategy.value) return;

    if (!currentAccount.value) {
        return notify.push({
            title: "Connect your wallet!",
            description: "Wallet connection error.",
            category: "error"
        });
    }

    if (!amount.value) {
        return notify.push({
            title: "Enter a valid amount!",
            description: "Input validation error.",
            category: "error"
        });
    }

    try {
        const value = Converter.toSUI(amount.value, strategy.value.decimals);
        if (!value) return;

        const transactionBlock = await Contract.depositIntoStrategy(
            currentAccount.value.address,
            strategy.value,
            value
        );
        if (!transactionBlock) return;

        const { digest } = await signAndExecuteTransactionBlock({
            transactionBlock: transactionBlock as any
        });

        await Clients.suiClient.waitForTransaction({ digest });

        balanceStore.getBalances(currentAccount.value.address);

        notify.push({
            title: "Restaking successful!",
            description: `You have restaked ${Converter.toMoney(amount.value)} ${strategy.value.symbol}`,
            category: "success",
            linkTitle: "View on Sui Explorer",
            linkUrl: `https://suiscan.xyz/testnet/tx/${digest}?network=testnet`,
        });

        amount.value = undefined;
    } catch (error) {
        notify.push({
            title: "Restaking failed!",
            description: "Transaction error.",
            category: "error"
        });
    }
};

const getStrategy = (type: string) => {
    strategy.value = findStrategy(type);
};

onMounted(() => {
    getStrategy(route.params.id.toString());
});
</script>

<template>
    <section>
        <div class="app_width">
            <div class="stake" v-if="strategy">
                <div class="stake_wrapper">
                    <div class="head">
                        <RouterLink to="/">
                            <div class="back">
                                <ChevronLeftIcon />
                                <p>Coins</p>
                            </div>
                        </RouterLink>
                    </div>

                    <div class="box">
                        <div class="label">
                            You're restaking
                        </div>

                        <div class="input">
                            <input type="number" v-model="amount" placeholder="0.00">
                            <div class="helper">
                                <p>{{ Converter.toMoney(
                                    Converter.fromSUI(balanceStore.balances[strategy.type], strategy.decimals)
                                ) }} {{ strategy.symbol }}</p>
                                <div class="buttons">
                                    <button @click="setAmount(4)">25%</button>
                                    <button @click="setAmount(2)">50%</button>
                                    <button @click="setAmount()">Max</button>
                                </div>
                            </div>
                        </div>

                        <button class="restake" @click="restake">Restake</button>
                    </div>
                </div>

                <div class="stake_info">
                    <div class="stats">
                        <div class="stat">
                            <p>Wallet Balance</p>
                            <div class="value">
                                <p>
                                    {{ Converter.toMoney(
                                        Converter.fromSUI(balanceStore.balances[strategy.type], strategy.decimals)
                                    ) }}
                                </p>
                                <span>{{ strategy.symbol }}</span>
                            </div>
                        </div>

                        <div class="stat">
                            <p>Value Restaked</p>
                            <div class="value">
                                <p>
                                    {{ Converter.toMoney(
                                        Converter.fromSUI(balanceStore.value_restaked[strategy.type],
                                            strategy.decimals)
                                    ) }}
                                </p>
                            </div>
                        </div>

                        <div class="stat">
                            <p>Total Value Restaked </p>
                            <div class="value">
                                <p>
                                    {{ Converter.toMoney(
                                        Converter.fromSUI(balanceStore.total_value_restaked[strategy.type],
                                            strategy.decimals)
                                    ) }}
                                </p>
                            </div>
                        </div>
                    </div>

                    <div class="coin">
                        <div class="title">
                            <h3>About</h3>
                        </div>

                        <div class="coin_info">
                            <img :src="strategy.image" alt="btc">
                            <p>{{ strategy.name }} <span>{{ strategy.symbol }}</span></p>
                        </div>

                        <div class="description">
                            {{ strategy.about }}
                        </div>

                        <a v-if="strategy.link" :href="strategy.link" target="_blank" class="link">
                            <p>Learn more</p>
                            <OutIcon />
                        </a>
                    </div>

                    <div class="faucet">
                        <div class="title">
                            <h3>Faucet</h3>
                        </div>

                        <a href="https://faucet.sui.io" target="_blank" v-if="strategy.isNative">
                            <button class="mint">Request Testnet SUI</button>
                        </a>

                        <button class="mint" @click="mint" v-else-if="strategy.faucet">
                            Mint {{ strategy.faucet.amount }} {{ strategy.symbol }}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </section>
</template>

<style scoped>
.stake {
    padding: 30px 0;
    display: grid;
    grid-template-columns: 1000px 700px;
    gap: 20px;
    justify-content: center;
}

.stake_wrapper {
    background: var(--bg-light);
    border: 1px solid var(--bg-lighter);
    border-radius: 8px;
    padding: 16px;
    cursor: pointer;
    height: fit-content;
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

.label {
    font-size: 14px;
    color: var(--tx-dimmed);
    margin-top: 20px;
}

.input {
    margin-top: 10px;
    background: var(--bg-lighter);
    border: 1px solid var(--bg-lightest);
    padding: 16px;
    border-radius: 8px;
}

.input input {
    font-size: 30px;
    font-weight: 500;
    background: none;
    outline: none;
    border: none;
    color: var(--tx-normal);
}

.helper {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 10px;
}

.helper>p {
    font-size: 14px;
    color: var(--tx-dimmed);
}

.helper .buttons {
    display: flex;
    align-items: center;
    gap: 10px;
}

.helper .buttons button {
    height: 30px;
    padding: 0 16px;
    border-radius: 4px;
    border: none;
    background: var(--bg-lightest);
    color: var(--tx-semi);
    cursor: pointer;
}

.restake {
    margin-top: 20px;
    width: 100%;
    height: 50px;
    border: none;
    background: var(--primary-light);
    font-weight: 500;
    font-size: 16px;
    cursor: pointer;
    color: var(--bg);
    border-radius: 30px;
}

.stake_info {
    height: fit-content;
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


.coin {
    margin-top: 20px;
}

.coin .title h3 {
    font-size: 16px;
    color: var(--tx-dimmed);
    font-weight: 500;
}

.coin_info {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-top: 16px;
}

.coin_info img {
    height: 28px;
    width: 28px;
    border-radius: 20px;
}

.coin_info p {
    font-size: 16px;
    color: var(--tx-semi);
}

.coin_info p span {
    margin-left: 8px;
    color: var(--tx-dimmed);
}

.coin .description {
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
    font-size: 11px;
    color: var(--accent-green);
}

.faucet {
    margin-top: 20px;
}

.faucet .title h3 {
    font-size: 16px;
    color: var(--tx-dimmed);
    font-weight: 500;
}

.mint {
    margin-top: 20px;
    width: 100%;
    height: 45px;
    border: none;
    background: var(--accent-red);
    font-size: 14px;
    cursor: pointer;
    color: var(--tx-normal);
    border-radius: 8px;
}
</style>