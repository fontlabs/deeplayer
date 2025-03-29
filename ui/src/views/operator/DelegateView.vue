<script setup lang="ts">
import ChevronLeftIcon from '@/components/icons/ChevronLeftIcon.vue';
import OutIcon from '@/components/icons/OutIcon.vue';

</script>

<template>
    <section>
        <div class="app_width">
            <div class="delegate">
                <div class="delegate_info">
                    <div class="head">
                        <RouterLink to="/operator">
                            <div class="back">
                                <ChevronLeftIcon />
                                <p>Operators</p>
                            </div>
                        </RouterLink>
                    </div>

                    <div class="stats">
                        <div class="stat">
                            <p>Total Restaked</p>
                            <div class="value">
                                <p>0</p> <span>SUI</span>
                            </div>
                        </div>

                        <div class="stat">
                            <p>Your Shares</p>
                            <div class="value">
                                <p>0</p>
                            </div>
                        </div>

                        <div class="stat">
                            <p>Total Shares</p>
                            <div class="value">
                                <p>10K</p>
                            </div>
                        </div>

                        <div class="stat">
                            <p>AVS Secured</p>
                            <div class="value">
                                <p>14</p>
                            </div>
                        </div>
                    </div>

                    <div class="operator">
                        <div class="title">
                            <h3>About</h3>
                        </div>

                        <div class="operator_info">
                            <img src="/images/colors.png" alt="operator">
                            <p>Mysten Labs</p>
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

                <div class="delegate_wrapper">
                    <div class="box">
                        <div class="label">You're delegating</div>

                        <div class="input">
                            <input type="number" placeholder="0.00" disabled>
                        </div>

                        <button class="redelegate">Delegate</button>
                    </div>
                </div>
            </div>
        </div>
    </section>
</template>

<style scoped>
.delegate {
    padding: 20px 0;
    display: grid;
    grid-template-columns: 1fr 500px;
    gap: 20px;
    justify-content: center;
}

.delegate_wrapper {
    background: var(--bg-light);
    border: 1px solid var(--bg-lighter);
    border-radius: 8px;
    padding: 16px;
    cursor: pointer;
    height: fit-content;
}

.label {
    font-size: 14px;
    color: var(--tx-dimmed);
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

.redelegate {
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

.delegate_info {
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


.operator {
    margin-top: 20px;
}

.operator .title h3 {
    font-size: 16px;
    color: var(--tx-dimmed);
    font-weight: 500;
}

.operator_info {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-top: 16px;
}

.operator_info img {
    height: 28px;
    width: 28px;
    border-radius: 20px;
}

.operator_info p {
    font-size: 16px;
    color: var(--tx-semi);
}

.operator .description {
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
</style>