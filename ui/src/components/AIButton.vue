<template>
    <button>
        <img src="/images/colors.png" alt="AI Icon" />
    </button>
</template>

<style scoped>
button {
    position: fixed;
    bottom: 30px;
    right: 50px;
    width: 60px;
    height: 60px;
    border-radius: 50%;
    z-index: 99;
    box-shadow: 0 10px 10px rgba(0, 0, 0, 0.2);
    background: var(--tx-normal);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    padding: 4px;
}

button:hover {
    transform: scale(0.7, 0.7);
    transition: all 0.5s ease-in-out;
}

button:hover img {
    transform: scale(1.8, 1.8);
    transition: all 0.2s ease-in-out;
}

button img {
    width: 100%;
    height: 100%;
    border-radius: 50%;
}
</style>