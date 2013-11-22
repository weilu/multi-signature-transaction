require 'bitcoin'
require_relative 'bitcoin_rpc'

require 'debugger'
require 'awesome_print'

class MultiSignatureTransaction
  attr_reader :multi_sig_address
  attr_accessor :funding_tx

  def initialize buyer_public_key, seller_public_key, escrow_public_key
    @buyer_public_key = buyer_public_key
    @buyer_address = Bitcoin.pubkey_to_address @buyer_public_key

    @seller_public_key = seller_public_key
    @seller_address = Bitcoin.pubkey_to_address @seller_public_key

    @escrow_public_key = escrow_public_key

    @client = BitcoinRPC.new('http://bitcoinrpc:fb56840652f0196e911981e3993a158d@127.0.0.1:18332')

    multi_sig = @client.createmultisig(2, [buyer_public_key, seller_public_key, escrow_public_key])
    @multi_sig_address = multi_sig["address"]
    @redeem_script = multi_sig["redeemScript"]
  end

  # done by buyer
  # escrow needs to verify transaction sent to multi_sig_address
  def create_and_send buyer_private_key, prev_tx_id, prev_vout, starting_amount, send_amount
    tx = @client.createrawtransaction [{txid: prev_tx_id, vout: prev_vout}],
      {@multi_sig_address => send_amount, @buyer_address => starting_amount - send_amount}
    # puts "#{Time.now} | raw tx: #{tx}"

    signed_tx = @client.signrawtransaction tx, [], [buyer_private_key]
    # puts "#{Time.now} | signed tx: #{signed_tx}"
    raise 'failed to sign tx' unless signed_tx['complete']

    @funding_tx = @client.decoderawtransaction(signed_tx['hex'])

    send_tx signed_tx['hex']
  end

  # done by escrow once funding transaction is verified
  # to be signed by seller
  def create_payment_tx
    create_spend_tx @seller_address
  end

  # done by seller
  # to be signed by escrow once buyer's feature wins
  def seller_sign_off_payment_tx tx, seller_private_key
    half_signed_tx = @client.signrawtransaction tx, [funding_tx_hash], [seller_private_key]
    puts "#{Time.now} | half signed spend tx: #{half_signed_tx}"
    half_signed_tx['hex']
  end

  # done by escrow
  def sign_off_and_send_payment_tx tx, escrow_private_key
    signed_tx = @client.signrawtransaction tx, [funding_tx_hash], [escrow_private_key]
    puts "#{Time.now} | signed spend tx: #{signed_tx}"
    raise 'failed to sign off tx' unless signed_tx['complete']

    send_tx signed_tx['hex']
  end

  # done by escrow once funding transaction is verified
  # to be signed by buyer
  def create_refund_tx
    create_spend_tx @buyer_address
  end

  private

  def send_tx signed_tx_hex
    tx_id = @client.sendrawtransaction signed_tx_hex
    # puts "#{Time.now} | sent tx_id: #{tx_id}\n\n"
    return tx_id
  rescue Exception => e
    puts "#{Time.now} | error: #{e.message}\n\n"
  end

  def funding_tx_hash
    funding_tx_hash = {
      txid: @funding_tx['txid'],
      vout: 0,
      scriptPubKey: script_pubkey,
      redeemScript: @redeem_script
    }
  end

  def script_pubkey
    script = Bitcoin::Script.from_string(vout_to_multi_sig_address['scriptPubKey']['asm'])
    script.to_binary.unpack("H*")[0]
  end

  def create_spend_tx to_address
    tx = @client.createrawtransaction [{txid: @funding_tx['txid'], vout: 0}], {to_address => vout_to_multi_sig_address['value']}
    puts "#{Time.now} | unsigned spend tx: #{tx}"
    tx
  end

  def vout_to_multi_sig_address
    address = @funding_tx['vout'].detect{|o| o['scriptPubKey']['addresses'].include?(@multi_sig_address)}
    raise 'multi signature address not found in funding tx' if address.nil?
    address
  end
end

