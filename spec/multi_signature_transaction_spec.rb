require 'multi_signature_transaction'
require 'spec_helper'

describe MultiSignatureTransaction do

  before do
    Bitcoin.network = :testnet3
  end

  let(:buyer_public_key) { "0441d662fb5fdfc12299114e1592c93fc5e94d4d53eaaee6079db94ea5c92fd50842fa77c554727dcd570f73db95ee2f353d870959a80f3c0c1b6d170b6dbd0542" }
  let(:buyer_private_key) { "92JeQ13MYMWMRbqaf6LFLDm4JzR4qc3q4Rw97EPNU6wDnNGdfin" }
  let(:seller_public_key) { "0465c1574a9124e1aacd6be794a7c023f86cffd3ade6015115f1b306061fe805dd3b741fb111f35a2b0bb90bba590704b2accaa02fd348aeec0482cc0f36dc7d80" }
  let(:seller_private_key) { "92JRWtHGA6nLGJMkCxmbHxHHqzV9nLhcbkfNg3nZAi5FXr7QxV7" }
  let(:escrow_public_key) { "043dbf4e2210a190aeddbe80778647a7348ba1cbe5b4405a0145d02037d454ad2879900580d7842c106fffc6ff6e71266a1137c8e8ed81962920cb1f42906354f3" }
  let(:escrow_private_key) { "92RaYtNmVrVhCYmGDLaFEUc5t3itx4f5XooUdb1p5j3kG4UXJYa" }
  let(:tx) { MultiSignatureTransaction.new buyer_public_key, seller_public_key, escrow_public_key }

  describe '#initialize' do
    it 'creates a multi-signature address', :cassette do
      expect(Bitcoin.address_type tx.multi_sig_address).to eq :p2sh
    end
  end

  describe '#create_payment_tx' do
    before do
      tx.funding_tx_hex = File.read('spec/fixtures/funding_tx_hex').strip
    end

    it 'pays the full amount to buyer address', :cassette do
      payment_tx_hex = tx.create_payment_tx
      payment_tx = Bitcoin::Protocol::Tx.new payment_tx_hex.htb
      expect(payment_tx.out[0].value/100000000.0).to eq 0.5

      script = Bitcoin::Script.new payment_tx.out[0].script
      expect(script.get_addresses).to eq [Bitcoin.pubkey_to_address(seller_public_key)]
    end
  end

  describe '#seller_sign_off_spending_tx' do
    before do
      tx.funding_tx_hex = File.read('spec/fixtures/funding_tx_hex').strip
    end

    let(:unsigned_payment_tx_hex) { File.read('spec/fixtures/unsigned_payment_tx_hex').strip }

    it 'partially signs the tx', :cassette do
      half_signed_tx_hex = tx.seller_sign_off_spending_tx unsigned_payment_tx_hex, seller_private_key
      expect(half_signed_tx_hex.length).to be > unsigned_payment_tx_hex.length
    end
  end

  describe '#sign_off_and_send_payment_tx' do
    before do
      tx.funding_tx_hex = File.read('spec/fixtures/funding_tx_hex').strip
    end

    let(:half_signed_payment_tx_hex) { File.read('spec/fixtures/half_signed_payment_tx_hex').strip }

    it 'signs and sends the tx', :cassette do
      signed_tx_id = tx.sign_off_and_send_payment_tx half_signed_payment_tx_hex, escrow_private_key
      expect(signed_tx_id).to be
    end
  end
end

