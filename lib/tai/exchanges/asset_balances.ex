defmodule Tai.Exchanges.AssetBalances do
  @moduledoc """
  Manages the balances of an account
  """

  @type balance_range :: Tai.Exchanges.AssetBalanceRange.t()
  @type balance_change_request :: Tai.Exchanges.AssetBalanceChangeRequest.t()

  use GenServer

  require Logger

  def start_link(exchange_id: exchange_id, account_id: account_id, balances: %{} = balances) do
    GenServer.start_link(
      __MODULE__,
      balances,
      name: to_name(exchange_id, account_id)
    )
  end

  def init(balances) do
    Tai.MetaLogger.init_tid()
    {:ok, balances}
  end

  def handle_call(:all, _from, state) do
    {:reply, state, state}
  end

  def handle_call(
        {:lock_range, %Tai.Exchanges.AssetBalanceRange{} = balance_range},
        _from,
        state
      ) do
    with %Tai.Exchanges.AssetBalance{} = balance <- Map.get(state, balance_range.asset),
         :ok <- Tai.Exchanges.AssetBalanceRange.validate(balance_range) do
      lock_result =
        cond do
          Decimal.cmp(balance_range.max, balance.free) != :gt -> balance_range.max
          Decimal.cmp(balance_range.min, balance.free) != :gt -> balance.free
          true -> nil
        end

      if lock_result == nil do
        continue = {
          :lock_range_insufficient_balance,
          balance_range.asset,
          balance.free,
          balance_range.min,
          balance_range.max
        }

        {:reply, {:error, :insufficient_balance}, state, {:continue, continue}}
      else
        new_free = Decimal.sub(balance.free, lock_result)
        new_locked = Decimal.add(balance.locked, lock_result)

        new_balance =
          balance
          |> Map.put(:free, new_free)
          |> Map.put(:locked, new_locked)

        new_state = Map.put(state, balance_range.asset, new_balance)

        continue = {
          :lock_range_ok,
          balance_range.asset,
          lock_result,
          balance_range.min,
          balance_range.max
        }

        {:reply, {:ok, lock_result}, new_state, {:continue, continue}}
      end
    else
      {:error, _} = error ->
        {:reply, error, state}

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(
        {:unlock, %Tai.Exchanges.AssetBalanceChangeRequest{asset: asset, amount: amount}},
        _from,
        state
      ) do
    if detail = Map.get(state, asset) do
      new_free = Decimal.add(detail.free, amount)
      new_locked = Decimal.sub(detail.locked, amount)

      new_detail =
        detail
        |> Map.put(:free, new_free)
        |> Map.put(:locked, new_locked)

      if Decimal.cmp(new_locked, Decimal.new(0)) == :lt do
        {:reply, {:error, :insufficient_balance}, state}
      else
        new_state = Map.put(state, asset, new_detail)
        {:reply, :ok, new_state}
      end
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_continue({:lock_range_ok, asset, qty, min, max}, state) do
    Logger.info("[lock_range_ok,#{asset},#{qty},#{min}..#{max}]")
    {:noreply, state}
  end

  def handle_continue({:lock_range_insufficient_balance, asset, free, min, max}, state) do
    Logger.info("[lock_range_insufficient_balance,#{asset},#{free},#{min}..#{max}]")
    {:noreply, state}
  end

  @spec all(atom, atom) :: map
  def all(exchange_id, account_id) do
    exchange_id
    |> to_name(account_id)
    |> GenServer.call(:all)
  end

  @spec lock_range(atom, atom, balance_range) ::
          {:ok, Decimal.t()}
          | {:error, :not_found | :insufficient_balance | :min_greater_than_max,
             :min_less_than_zero}
  def lock_range(exchange_id, account_id, range) do
    exchange_id
    |> to_name(account_id)
    |> GenServer.call({:lock_range, range})
  end

  @spec unlock(atom, atom, balance_change_request) ::
          :ok | {:error, :not_found | :insufficient_balance}
  def unlock(exchange_id, account_id, balance_change_request) do
    exchange_id
    |> to_name(account_id)
    |> GenServer.call({:unlock, balance_change_request})
  end

  @doc """
  Returns an atom which identifies the process for the given account id

  ## Examples

    iex> Tai.Exchanges.AssetBalances.to_name(:my_test_exchange, :my_test_account)
    :"Elixir.Tai.Exchanges.AssetBalances_my_test_exchange_my_test_account"
  """
  @spec to_name(atom, atom) :: atom
  def to_name(exchange_id, account_id) do
    :"#{__MODULE__}_#{exchange_id}_#{account_id}"
  end
end
