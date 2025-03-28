// SPDX-License-Identifier: MIT
module deeplayer::coin_utils {
    use std::string;
    use std::ascii::into_bytes;
    use std::type_name::{get, into_string};

    public fun get_coin_id<COIN>(): string::String {
        let mut coin_id = string::utf8(b"");

        string::append_utf8(&mut coin_id, b"coin_id_");

        string::append_utf8(&mut coin_id, into_bytes(into_string(get<COIN>())));

        coin_id
    }
}