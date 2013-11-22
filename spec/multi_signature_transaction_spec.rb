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

  describe '#create_and_send', :cassette do
    it 'sends correct mount and change to multi sig address and buyer address' do
      funding_tx_id = tx.create_and_send buyer_private_key, 'c649d7d27107733ff4ae95d293f1edabd22aa30c56cf9f61a2cde3e43c7d686c', 1, 10, 0.5
      vouts = tx.funding_tx['vout']

      expect(vouts.count).to eq 2

      expect(vouts[0]['scriptPubKey']['addresses']).to eq [tx.multi_sig_address]
      expect(vouts[0]['value']).to eq(0.5)

      expect(vouts[1]['scriptPubKey']['addresses']).to eq [Bitcoin.pubkey_to_address(buyer_public_key)]
      expect(vouts[1]['value']).to eq(9.5)

      expect(funding_tx_id).to be
    end
  end

  describe '#create_payment_tx' do
    before do
      tx.funding_tx = JSON.parse File.read('spec/fixtures/funding_tx.json')
    end

    it 'pays the full amount to buyer address', :cassette do
      payment_tx_hex = tx.create_payment_tx
      payment_tx = Bitcoin::Protocol::Tx.new payment_tx_hex.htb
      expect(payment_tx.out[0].value/100000000.0).to eq 0.5

      script = Bitcoin::Script.new payment_tx.out[0].script
      expect(script.get_addresses).to eq [Bitcoin.pubkey_to_address(seller_public_key)]
    end
  end
end

