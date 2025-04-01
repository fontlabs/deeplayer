// SPDX-License-Identifier: MIT
#[allow(unused_use,unused_const,unused_variable,duplicate_alias,unused_type_parameter,unused_function)]
module deeplayer::coin_utils_module {
    use std::string;
    use std::ascii::into_bytes;
    use std::type_name::{get, into_string};

    public fun get_strategy_id<CoinType>(): string::String {
        string::utf8(into_bytes(into_string(get<CoinType>())))
    }
}