defmodule Tai.Advisors.MarketQuotesTest do
  use ExUnit.Case, async: true
  alias Tai.Advisors.MarketQuotes
  alias Tai.Markets.Quote

  @market_quote_a struct(Quote, venue_id: :venue_a, product_symbol: :product_a)
  @market_quote_b struct(Quote, venue_id: :venue_b, product_symbol: :product_b)
  @market_quotes struct(MarketQuotes,
                   data: %{
                     {@market_quote_a.venue_id, @market_quote_a.product_symbol} =>
                       @market_quote_a,
                     {@market_quote_b.venue_id, @market_quote_b.product_symbol} => @market_quote_b
                   }
                 )

  describe ".for/3" do
    test "returns a matching market quote" do
      assert {:ok, market_quote} =
               MarketQuotes.for(
                 @market_quotes,
                 @market_quote_a.venue_id,
                 @market_quote_a.product_symbol
               )

      assert market_quote == @market_quote_a
    end

    test "returns an error when not found" do
      assert MarketQuotes.for(@market_quotes, :not_found_venue, :not_found_product) ==
               {:error, :not_found}
    end
  end

  test ".each/1 iterates each market quote" do
    assert MarketQuotes.each(@market_quotes, fn q -> send(self(), {:market_quote, q}) end)

    assert_receive {:market_quote, market_quote_1}
    assert market_quote_1 == @market_quote_a

    assert_receive {:market_quote, market_quote_2}
    assert market_quote_2 == @market_quote_b
  end

  test ".map/1 iterates each market quote an return a list of the return value of each function call" do
    assert result = MarketQuotes.map(@market_quotes, & &1)

    assert Enum.count(result) == 2
    assert Enum.at(result, 0) == @market_quote_a
    assert Enum.at(result, 1) == @market_quote_b
  end
end
