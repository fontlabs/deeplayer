// SPDX-License-Identifier: MIT
module deeplayer::math_module {
    // Error codes
    const E_ONLY_UNDERLYING_COIN: u64 = 1;

    // Public functions
    public fun mul_div(a: u64, b: u64, c: u64): u64 {
        assert!(c != 0, E_ONLY_UNDERLYING_COIN);
        let numerator: u128 = (a as u128) * (b as u128);
        let denominator: u128 = c as u128;
        (numerator / denominator) as u64
    }

    public fun mul_div_u128(a: u128, b: u128, c: u128): u64 {
        assert!(c != 0, E_ONLY_UNDERLYING_COIN);
        ((a * b) / c) as u64
    }

    public fun div(a: u128, b: u64): u64 {
        assert!(b != 0, E_ONLY_UNDERLYING_COIN);
        (a / (b as u128)) as u64
    }

    public fun div_u128(a: u128, b: u128): u64 {
        assert!(b != 0, E_ONLY_UNDERLYING_COIN);
        (a / b) as u64
    }
}