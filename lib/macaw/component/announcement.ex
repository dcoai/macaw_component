defmodule Macaw.Component.Announcement do
  @moduledoc """
  An announcement request (spec/01 §1.6): `%{name, text, politeness}`, for a name the
  component declares in `announces`. Components never render a live region; the announcer
  is the host's.

      iex> {:ok, d} = Macaw.Component.Declarations.new([announces: ["matches"]], nil)
      iex> Macaw.Component.Announcement.new(d, name: "matches", text: "12 projects match")
      {:ok, %{name: "matches", text: "12 projects match", politeness: :polite}}
  """

  alias Macaw.Component.Declarations

  @type t :: %{name: String.t(), text: String.t(), politeness: :polite | :assertive}

  @doc """
  A request from attributes (a keyword list or a map): `name`, `text`, and `politeness`,
  `:polite` by default. Every fault at once: an undeclared name is `{:undeclared, name}`,
  empty text `:empty`, a politeness other than the two `{:politeness, value}`.
  """
  @spec new(Declarations.t(), keyword() | map()) ::
          {:ok, t()} | {:error, [Macaw.Component.fault(), ...]}
  def new(%Declarations{announces: announces}, attrs) do
    attrs = Map.new(attrs)
    name = Map.get(attrs, :name)
    text = Map.get(attrs, :text)
    politeness = Map.get(attrs, :politeness, :polite)

    faults =
      for {path, ok?, reason} <- [
            {[:name], name in announces, {:undeclared, name}},
            {[:text], is_binary(text) and String.trim(text) != "", :empty},
            {[:politeness], politeness in [:polite, :assertive], {:politeness, politeness}}
          ],
          not ok?,
          do: {path, reason}

    unknown =
      for key <- Map.keys(attrs),
          key not in [:name, :text, :politeness],
          do: {[key], :unknown_key}

    Macaw.Component.answer(faults ++ unknown, %{name: name, text: text, politeness: politeness})
  end
end
