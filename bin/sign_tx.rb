#!/usr/bin/env ruby

require 'bitcoin'
require 'bitcoin/ffi/openssl'
require 'thor'

class SignTx < Thor
  desc "sign SPENDING_TX FUNDING_TX PRIVATE_KEY", "sign SPENDING_TX with PRIVATE_KEY"
  option :testnet3, type: :boolean, aliases: 't'
  def sign tx_hex, prev_tx_hex, private_key
    Bitcoin.network = :testnet3 if options[:testnet3]

    tx = Bitcoin::Protocol::Tx.new tx_hex.htb
    prev_tx = Bitcoin::Protocol::Tx.new prev_tx_hex.htb

    key = Bitcoin.open_key Bitcoin::Key.from_base58(private_key).priv
    sig = Bitcoin.sign_data(key, tx.signature_hash_for_input(0, prev_tx))

    script_sig = tx.in[0].script_sig
    tx.in[0].script_sig = Bitcoin::Script.to_signature_pubkey_script(sig, [key.public_key_hex].pack("H*"))

    puts tx.to_payload.unpack("H*")[0]
  end
end

SignTx.start(ARGV)
