defmodule Tai.AdvisorGroup do
  @type t :: %Tai.AdvisorGroup{
          id: atom,
          advisor: atom,
          factory: atom,
          products: String.t(),
          config: map
        }

  @enforce_keys ~w(id factory products config)a
  defstruct ~w(id advisor factory products config)a
end
