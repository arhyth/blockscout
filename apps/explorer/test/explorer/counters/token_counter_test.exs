defmodule Explorer.Counters.TokenCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.TokenCounter

  describe "consolidate/0" do
    test "loads the token's transfers consolidate info" do
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      TokenCounter.consolidate()

      assert TokenCounter.fetch(token.contract_address_hash) == 2
    end
  end

  describe "fetch/1" do
    test "fetchs the total token transfers by token contract address hash" do
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address)

      assert TokenCounter.fetch(token.contract_address_hash) == 0

      TokenCounter.insert_or_update_counter(token.contract_address_hash, 15)

      assert TokenCounter.fetch(token.contract_address_hash) == 15
    end
  end
end
