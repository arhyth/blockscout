defmodule Explorer.Counters.TokenCounter do
  use GenServer

  @moduledoc """
  Counts the Token transfers and addresses involved.
  """

  alias Explorer.Chain
  alias Explorer.Chain.TokenTransfer

  @table :token_counts

  def table_name do
    @table
  end

  @doc """
  Starts a process to continually monitor the token counters.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## Server
  @impl true
  def init(args) do
    create_table()

    Task.start_link(&consolidate/0)

    Chain.subscribe_to_events(:token_transfers)

    {:ok, args}
  end

  def create_table do
    opts = [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ]

    :ets.new(table_name(), opts)
  end

  def consolidate do
    total_token_transfers = TokenTransfer.count_token_transfers()

    for {token_hash, total} <- total_token_transfers do
      insert_or_update_counter(token_hash, total)
    end
  end

  def fetch(token_hash) do
    do_fetch(:ets.lookup(table_name(), to_string(token_hash)))
  end

  defp do_fetch([{_, result} | _]), do: result
  defp do_fetch([]), do: 0

  @impl true
  def handle_info({:chain_event, :token_transfers, _type, token_transfers}, state) do
    token_transfers
    |> Enum.map(& &1.token_contract_address_hash)
    |> Enum.each(&insert_or_update_counter(&1, 1))

    {:noreply, state}
  end

  def insert_or_update_counter(token_hash, number) do
    default = {to_string(token_hash), 0}

    :ets.update_counter(table_name(), to_string(token_hash), number, default)
  end
end
