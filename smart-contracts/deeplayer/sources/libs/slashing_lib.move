// SPDX-License-Identifier: BUSL-1.1
module deeplayer::slashing_lib_module {
    use deeplayer::math_module;

    const WAD: u64 = 1_000_000_000;

    const E_ONLY_UNDERLYING_COIN: u64 = 1;

    public struct DepositScalingFactor has copy, drop, store {
        scaling_factor: u64,
    }

    public fun create(): DepositScalingFactor {
        DepositScalingFactor {
            scaling_factor: WAD
        }
    }
    
    public fun default_scaling_factor(): u64 {
        WAD
    }

    public fun get_scaling_factor(dsf: &DepositScalingFactor): u64 {
        if (dsf.scaling_factor == 0) {
            WAD
        } else {
            dsf.scaling_factor
        }
    }

    public fun scale_for_queue_withdrawal(dsf: &DepositScalingFactor, deposit_shares_to_withdraw: u64): u64 {
        math_module::mul_div(deposit_shares_to_withdraw, get_scaling_factor(dsf), WAD)
    }

    public fun scale_for_complete_withdrawal(scaled_shares: u64, slashing_factor: u64): u64 {
        math_module::mul_div(scaled_shares, slashing_factor, WAD)
    }

    public fun scale_for_burning(scaled_shares: u64, prev_max: u64, new_max: u64): u64 {
        math_module::mul_div(scaled_shares, prev_max - new_max, WAD)
    }

    public fun calc_withdrawable(dsf: &DepositScalingFactor, deposit_shares: u64, slashing_factor: u64): u64 {
        let scaled = math_module::mul_div(deposit_shares, get_scaling_factor(dsf), WAD);
        math_module::mul_div(scaled, slashing_factor, WAD)
    }

    public fun calc_deposit_shares(dsf: &DepositScalingFactor, withdrawable_shares: u64, slashing_factor: u64): u64 {
        let unscaled = math_module::mul_div(withdrawable_shares, WAD, get_scaling_factor(dsf));
        math_module::mul_div(unscaled, WAD, slashing_factor)
    }

    public fun calc_slashed_amount(operator_shares: u64, prev_max: u64, new_max: u64): u64 {
        let slashed = math_module::mul_div(operator_shares, new_max, prev_max);
        operator_shares - slashed
    }

    public fun reset(dsf: &mut DepositScalingFactor) {
        dsf.scaling_factor = 0;
    }

    public fun set(dsf: &mut DepositScalingFactor, scaling_factor: u64) {
        dsf.scaling_factor = scaling_factor;
    }

    public fun update(
        dsf: &mut DepositScalingFactor,
        prev_deposit_shares: u64,
        added_shares: u64,
        slashing_factor: u64
    ): u64 {
        if (prev_deposit_shares == 0) {
            let new_deposit_scaling_factor = math_module::mul_div(get_scaling_factor(dsf), WAD, slashing_factor);
            dsf.scaling_factor = new_deposit_scaling_factor;
            return new_deposit_scaling_factor;
        };

        let current_shares = calc_withdrawable(dsf, prev_deposit_shares, slashing_factor);
        let new_shares = current_shares + added_shares;

        let denominator = math_module::mul_div(prev_deposit_shares + added_shares, slashing_factor, WAD);
        let new_deposit_scaling_factor = math_module::mul_div(new_shares, WAD, denominator);

        dsf.scaling_factor = new_deposit_scaling_factor;

        new_deposit_scaling_factor
    }
}