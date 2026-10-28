defmodule Macaw.Component.Drawn do
  @moduledoc """
  Drawn states (spec/02 §6): every component is always in exactly one, in this precedence,
  each but `live` with a theme role, a glyph and words, and never blank.

      iex> Macaw.Component.Drawn.pick([:stale, :loading])
      :loading
      iex> Macaw.Component.Drawn.role(:no_data)
      :neutral
  """

  alias Macaw.Layers.Theme

  @states [:crashed, :down, :invalid, :loading, :no_data, :stale, :capped, :live]

  @roles %{
    crashed: :bad,
    down: :bad,
    invalid: :warning,
    stale: :warning,
    loading: :info,
    capped: :info,
    no_data: :neutral,
    live: nil
  }

  @words %{
    crashed: "Couldn't be drawn",
    down: "Source unavailable",
    invalid: "Invalid settings",
    loading: "Loading",
    no_data: "No data",
    stale: "Out of date",
    capped: "Showing part of the data",
    live: nil
  }

  @type t :: :crashed | :down | :invalid | :loading | :no_data | :stale | :capped | :live

  @doc "The eight states, in precedence order."
  @spec all() :: [t(), ...]
  def all, do: @states

  @doc "The state of highest precedence among a list, `:live` for `[]`."
  @spec pick([t()]) :: t()
  def pick(states) when is_list(states) do
    Enum.each(states, &state!/1)
    Enum.find(@states, :live, &(&1 in states))
  end

  @doc "The state's theme role, `nil` for `live`."
  @spec role(t()) :: atom() | nil
  def role(state), do: Map.fetch!(@roles, state!(state))

  @doc "The glyph of the state's role's cue (`Macaw.Layers.Theme.cue/1`), `nil` for `live`."
  @spec glyph(t()) :: atom() | nil
  def glyph(state) do
    case role(state) do
      nil -> nil
      role -> Theme.cue(role).glyph
    end
  end

  @doc "The state's words, `nil` for `live`."
  @spec words(t()) :: String.t() | nil
  def words(state), do: Map.fetch!(@words, state!(state))

  @doc """
  A static notice for a state other than `live`: a paragraph with the state's class and
  `data-mw-drawn`, a glyph element of the role's class hidden from assistive technology,
  then the words. It is not a live region, so it holds in every mode. `live` is empty.

      iex> Macaw.Component.Drawn.render(:no_data, nil) |> Phoenix.HTML.safe_to_string()
      ~s(<p class="mw-drawn mw-drawn-no-data" data-mw-drawn="no_data"><span class="mw-glyph mw-glyph-diamond mw-role-neutral" aria-hidden="true"></span> No data</p>)
  """
  @spec render(t(), Macaw.Component.Context.t() | nil) :: Phoenix.HTML.safe()
  def render(:live, _context), do: {:safe, ""}

  def render(state, _context) do
    class = state |> Atom.to_string() |> String.replace("_", "-")
    glyph = state |> glyph() |> Atom.to_string()
    role = state |> role() |> Atom.to_string()

    {:safe,
     [
       ~s(<p class="mw-drawn mw-drawn-#{class}" data-mw-drawn="#{state}">),
       ~s(<span class="mw-glyph mw-glyph-#{glyph} mw-role-#{role}" aria-hidden="true"></span> ),
       Phoenix.HTML.html_escape(words(state)) |> Phoenix.HTML.safe_to_string(),
       "</p>"
     ]}
  end

  defp state!(state) do
    state in @states ||
      raise ArgumentError,
            "#{inspect(state)} is not a drawn state; the states are #{inspect(@states)}"

    state
  end
end
