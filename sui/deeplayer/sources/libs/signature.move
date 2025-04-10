// SPDX-License-Identifier: MIT
module deeplayer::signature_module {
    use sui::clock;
    use sui::address;
    use sui::ed25519;
    use sui::tx_context::{Self, TxContext};
    use sui::bcs;

    // Structs
    public struct SignatureWithSaltAndExpiry has copy, drop, store {
        signature: vector<u8>,
        salt: vector<u8>,
        expiry: u64,
    }

    public(package) fun salt(
        signature_with_salt_and_expiry: SignatureWithSaltAndExpiry,
    ): vector<u8> {
        signature_with_salt_and_expiry.salt
    }

    public(package) fun create(
        signature: vector<u8>,
        salt: vector<u8>,
        expiry: u64,
    ): SignatureWithSaltAndExpiry {
        SignatureWithSaltAndExpiry { signature, salt, expiry }
    }

    public(package) fun verify(
        signature_with_salt_and_expiry: SignatureWithSaltAndExpiry,
        signer: address,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ): bool {
        let timestamp = clock::timestamp_ms(the_clock);

        // Check if the signature is expired
        if (signature_with_salt_and_expiry.expiry < timestamp) {
            return false;
        };

        // Contruct signed message
        let mut msg = vector::empty<u8>();
        vector::append(&mut msg, signature_with_salt_and_expiry.salt);
        vector::append(&mut msg, bcs::to_bytes<u64>(&signature_with_salt_and_expiry.expiry));

        // verify
        ed25519::ed25519_verify(
            &signature_with_salt_and_expiry.signature, 
            &address::to_bytes(signer), 
            &msg
        )
    }
}