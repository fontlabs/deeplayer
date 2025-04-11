// SPDX-License-Identifier: MIT
module deeplayer::utils_module {
    use std::string;
    use std::ascii::into_bytes;
    use std::type_name::{get, TypeName, into_string};

    public fun get_strategy_id<CoinType>(): string::String {
        string::utf8(into_bytes(into_string(get<CoinType>())))
    }
}