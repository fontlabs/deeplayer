// SPDX-License-Identifier: MIT
module deeplayer::math_module {
    // Error codes
    const E_ONLY_UNDERLYING_COIN: u64 = 1;

    // Public functions
    public fun mul(a: u64, b: u64): u64 {
        a * b
    }

    public fun div(a: u64, b: u64): u64 {
        a / b
    }

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

    public fun mul_div_u128_u128(a: u128, b: u128, c: u128): u128 {
        assert!(c != 0, E_ONLY_UNDERLYING_COIN);
        ((a * b) / c)
    }

    public fun div_u128(a: u128, b: u128): u64 {
        assert!(b != 0, E_ONLY_UNDERLYING_COIN);
        (a / b) as u64
    }

    public fun scale(value: u64, decimals: u8, decimals_target: u8): u64 {
        assert!(decimals_target != 0, E_ONLY_UNDERLYING_COIN);
        if (decimals == decimals_target) {
            value
        } else if (decimals > decimals_target) {
            div(value, pow10(decimals - decimals_target))
        } else {
            mul(value, pow10(decimals_target - decimals))
        }
    }

    fun pow10(exp: u8): u64 {
        let mut result = 1;
        let mut i = 0;
        while (i < exp) {
            result = result * 10;
            i = i + 1;
        };
        result
    }
}