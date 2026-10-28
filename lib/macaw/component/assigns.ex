defmodule Macaw.Component.Assigns do
  @moduledoc """
  The assigns a component renders with (spec/02 §1): `context`, `settings`,
  `declarations`, `drawn`, `deliveries` and `value`, and nothing else. Nothing else reaches
  a component: not the viewer, not another component, not the page.
  """

  alias Macaw.Component.{Context, Declarations, Drawn}

  @keys [:context, :settings, :declarations, :drawn, :deliveries, :value]

  @doc "The six keys, in order."
  @spec keys() :: [atom(), ...]
  def keys, do: @keys

  @doc """
  The assigns from a keyword list or a map: `{:ok, assigns}`, or every fault at once, a
  missing key `:required` and one it doesn't know `:unknown_key`. A pure component's
  `value` is `nil`; a contained one's `deliveries` is `%{}`.
  """
  @spec new(keyword() | map()) :: {:ok, map()} | {:error, [Macaw.Component.fault(), ...]}
  def new(attrs) when is_list(attrs) or is_map(attrs) do
    attrs = Map.new(attrs)
    unknown = for key <- Map.keys(attrs), key not in @keys, do: {[key], :unknown_key}
    missing = for key <- @keys, not Map.has_key?(attrs, key), do: {[key], :required}

    shapes =
      for {key, ok?} <- [
            context: match?(%Context{}, attrs[:context]),
            settings: is_map(attrs[:settings]),
            declarations: match?(%Declarations{}, attrs[:declarations]),
            drawn: attrs[:drawn] in Drawn.all(),
            deliveries: is_map(attrs[:deliveries])
          ],
          Map.has_key?(attrs, key),
          not ok?,
          do: {[key], :bad_value}

    pure =
      case attrs do
        %{declarations: %Declarations{isolation: :pure}, value: value} when value != nil ->
          [{[:value], :pure_has_no_value}]

        _ ->
          []
      end

    Macaw.Component.answer(unknown ++ missing ++ shapes ++ pure, Map.take(attrs, @keys))
  end
end
