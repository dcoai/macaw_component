defmodule Macaw.Component.Mode do
  @moduledoc """
  The rendering modes and what each allows (spec/02 §3).

      iex> Macaw.Component.Mode.allows?(:socketless, :hooks)
      true
      iex> Macaw.Component.Mode.allows?(:neutral, :live_regions)
      false
  """

  @modes [:live, :socketless, :neutral, :print]
  @features [:canvas, :hooks, :scripts, :tokens, :live_regions, :per_viewer, :events]

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
  Whether a mode allows a feature. The mode and the feature are the function's contract,
  so an unknown one fails as any wrong call does, a `FunctionClauseError`: a programming
  error, not data.
  """
  @spec allows?(t(), atom()) :: boolean()
  def allows?(mode, feature) when mode in @modes and feature in @features,
    do: MapSet.member?(Map.fetch!(@allowed, mode), feature)
end
