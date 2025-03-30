// SPDX-License-Identifier: MIT
module deeplayer::coin_utils_module {
    use std::string;
    use std::ascii::into_bytes;
    use std::type_name::{get, into_string};

    public fun get_coin_type<COIN>(): string::String {
        let mut coin_type = string::utf8(b"");

        string::append_utf8(&mut coin_type, b"coin_type_");

        string::append_utf8(&mut coin_type, into_bytes(into_string(get<COIN>())));

        coin_type
    }
}