defmodule Macaw.Component.Mode do
  @moduledoc """
  The rendering modes and what each allows (spec/02 §3).

      iex> Macaw.Component.Mode.allows?(:socketless, :hooks)
      true
      iex> Macaw.Component.Mode.allows?(:neutral, :live_regions)
      false
  """

  @modes [:live, :socketless, :neutral, :print]
  @features [:canvas, :hooks, :scripts, :tokens, :live_regions, :per_viewer]

  @allowed %{
    live: MapSet.new(@features),
    socketless: MapSet.new(@features -- [:canvas]),
    neutral: MapSet.new(),
    print: MapSet.new()
  }

  @type t :: :live | :socketless | :neutral | :print

  @doc "The four modes, in order."
  @spec all() :: [t(), ...]
  def all, do: @modes

  @doc "The features a mode may allow, in order."
  @spec features() :: [atom(), ...]
  def features, do: @features

  @doc """
  Whether a mode allows a feature. An unknown mode or feature raises `ArgumentError`: it is
  a programming error, not data.
  """
  @spec allows?(t(), atom()) :: boolean()
  def allows?(mode, feature) do
    mode in @modes ||
      raise ArgumentError, "#{inspect(mode)} is not a mode; the modes are #{inspect(@modes)}"

    feature in @features ||
      raise ArgumentError,
            "#{inspect(feature)} is not a feature; the features are #{inspect(@features)}"

    MapSet.member?(Map.fetch!(@allowed, mode), feature)
  end
end
