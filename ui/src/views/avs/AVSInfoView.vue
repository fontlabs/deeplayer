<script setup lang="ts">
import ChevronLeftIcon from '@/components/icons/ChevronLeftIcon.vue';
import OutIcon from '@/components/icons/OutIcon.vue';

</script>

<template>
    <section>
        <div class="app_width">
            <div class="avs">
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
                                <p>0</p> <span>SUI</span>
                            </div>
                        </div>

                        <div class="stat">
                            <p>Total Num. Operators</p>
                            <div class="value">
                                <p>45</p>
                            </div>
                        </div>

                        <div class="stat">
                            <p>Total Num. Stakers</p>
                            <div class="value">
                                <p>12.4K</p>
                            </div>
                        </div>

                        <div class="stat">
                            <p>Reward Coin</p>
                            <div class="value">
                                <p>SUI</p>
                            </div>
                        </div>
                    </div>

                    <div class="service">
                        <div class="title">
                            <h3>About</h3>
                        </div>

                        <div class="service_info">
                            <img src="/images/colors.png" alt="service">
                            <p>SUI zkBridge</p>
                        </div>

                        <div class="description">
                            Lorem ipsum dolor sit amet consectetur adipisicing elit. Enim placeat harum ex rem minima
                            error illo magni repellat excepturi rerum, voluptatibus, possimus maiores accusamus, atque
                            totam voluptatem vitae qui sint!
                        </div>

                        <a href="" target="_blank" class="link">
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
                                <img src="/images/sui.png" alt="sui">
                                <p>SUI</p>
                            </div>

                            <p class="reward_amount">1.3K</p>
                        </div>
                    </div>
                </div>

            </div>
        </div>
    </section>
</template>

<style scoped>
.avs {
    padding: 20px 0;
    display: grid;
    grid-template-columns: 1fr 500px;
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
    border-radius: 20px;
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
    font-size: 11px;
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
</style>