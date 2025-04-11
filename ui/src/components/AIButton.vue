<template>
    <button>
        <img src="/images/colors.png" alt="AI Icon"  />
    </button>
</template>

<style scoped>
button {
    position: fixed;
    bottom: 30px;
    right: 50px;
    background-color: #4CAF50; /* Green */
    border: none;
    color: white;
    text-align: center;
    text-decoration: none;
    display: inline-block;
    font-size: 16px;
    padding: 15px 32px;
    margin: 4px 2px;
    cursor: pointer;
    border-radius: 50%;
}

button img {
    width: 50px;
    height: 50px;
    border-radius: 50%;
    transition: transform 0.2s; /* Animation */
}

button:hover {
    background-color: #45a049; /* Darker green */
}
</style>