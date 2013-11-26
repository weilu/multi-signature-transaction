require 'bitcoin'
require 'bitcoin/ffi/openssl'
require_relative 'bitcoin_rpc'

class MultiSignatureTransaction
  attr_reader :multi_sig_address
  attr_accessor :funding_tx_hex

  def initialize buyer_public_key, seller_public_key, escrow_public_key
    @buyer_public_key = buyer_public_key
    @buyer_address = Bitcoin.pubkey_to_address @buyer_public_key

    @seller_public_key = seller_public_key
    @seller_address = Bitcoin.pubkey_to_address @seller_public_key

    @escrow_public_key = escrow_public_key

    inner_p2sh_script = Bitcoin::Script.to_multisig_script(2, @buyer_public_key, @seller_public_key, @escrow_public_key)
    p2sh_hash = Bitcoin.hash160(inner_p2sh_script.unpack('H*')[0])
    hex = Bitcoin.p2sh_version + p2sh_hash
    @multi_sig_address = Bitcoin.encode_base58(hex + Bitcoin.checksum(hex))
    @redeem_script = inner_p2sh_script.unpack('H*')[0]
  end

  # done by escrow once funding transaction is verified
  # to be signed by seller
  def create_payment_tx
    create_spend_tx @seller_address
  end

  # done by seller
  def seller_sign_off_payment_tx tx_hex, seller_private_key
    tx = Bitcoin::Protocol::Tx.new tx_hex.htb
    tx.in[0].script_sig = Bitcoin::Script.to_multisig_script_sig(sign(tx, seller_private_key) + "\x01")
    tx.to_payload.unpack('H*')[0]
  end

  # done by escrow once buyer's feature wins
  def sign_off_and_send_payment_tx tx_hex, escrow_private_key
    tx = Bitcoin::Protocol::Tx.new tx_hex.htb
    tx.in[0].script_sig = Bitcoin::Script.to_multisig_script_sig(*Bitcoin::Script.new(tx.in[0].script_sig).chunks[1..-1],
                                                                 sign(tx, escrow_private_key) + "\x01",
                                                                 @redeem_script.htb)

    raise 'failed to sign tx' unless tx.verify_input_signature 0, Bitcoin::Protocol::Tx.new(@funding_tx_hex.htb)

    send_tx tx.to_payload.unpack('H*')[0]
  end

  # done by escrow once funding transaction is verified
  # to be signed by seller
  def create_refund_tx
    create_spend_tx @buyer_address
  end

  private

  def sign tx, private_key
    prev_tx = Bitcoin::Protocol::Tx.new @funding_tx_hex.htb

    key = Bitcoin.open_key Bitcoin::Key.from_base58(private_key).priv
    Bitcoin.sign_data(key, tx.signature_hash_for_input(0, prev_tx, nil, nil, nil, @redeem_script.htb))
  end

  def send_tx signed_tx_hex
    client = BitcoinRPC.new('http://bitcoinrpc:fb56840652f0196e911981e3993a158d@127.0.0.1:18332')
    tx_id = client.sendrawtransaction signed_tx_hex
    return tx_id
  rescue Exception => e
    puts "#{Time.now} | error: #{e.message}\n\n"
  end

  def create_spend_tx to_address
    tx = Bitcoin::Protocol::Tx.new
    prev_tx = Bitcoin::Protocol::Tx.new @funding_tx_hex.htb
    tx.add_in Bitcoin::Protocol::TxIn.new(prev_tx.binary_hash, 0, 0, '')
    tx.add_out Bitcoin::Protocol::TxOut.value_to_address(funding_tx_value, to_address)
    tx.to_payload.unpack('H*')[0]
  end

  def funding_tx_value
    Bitcoin::Protocol::Tx.new(@funding_tx_hex.htb).out.
      select{|o| o.to_hash['scriptPubKey'].include?(Bitcoin.hash160 @redeem_script)}.
      reduce(0){ |memo, o| memo += o.value }
  end
end

