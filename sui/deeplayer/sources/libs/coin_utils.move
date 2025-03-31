// SPDX-License-Identifier: MIT
#[allow(unused_use,unused_const,unused_variable,duplicate_alias,unused_type_parameter,unused_function)]
module deeplayer::coin_utils_module {
    use std::string;
    use std::ascii::into_bytes;
    use std::type_name::{get, into_string};

    public fun get_strategy_id<COIN>(): string::String {
        let mut strategy_id = string::utf8(b"");

        string::append_utf8(&mut strategy_id, b"coin_type_");

        string::append_utf8(&mut strategy_id, into_bytes(into_string(get<COIN>())));

        strategy_id
    }
}