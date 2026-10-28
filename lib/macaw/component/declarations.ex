defmodule Macaw.Component.Declarations do
  @moduledoc """
  A component's configured declarations (spec/01 §1.2), built by `new/2` from its
  `declarations/1` answer, every key checked, every fault at once.

  No atom is made from a name: names are strings, and an observation spelled as a string
  is matched against the vocabulary's atoms.
  """

  alias Macaw.Component.{Proxy, Slot, State, Stylesheet}

  @keys [
    :slots,
    :writes,
    :local,
    :events,
    :announces,
    :observes,
    :shortcuts,
    :reading,
    :words,
    :stylesheets,
    :proxy_routes,
    :isolation,
    :access
  ]

  defstruct slots: %{},
            writes: %{},
            local: %{},
            events: [],
            announces: [],
            observes: [],
            shortcuts: [],
            reading: :glance,
            words: nil,
            stylesheets: [],
            proxy_routes: [],
            isolation: :pure,
            access: nil

  @type t :: %__MODULE__{
          slots: %{String.t() => Slot.t()},
          writes: %{String.t() => State.type()},
          local: %{String.t() => State.type()},
          events: [String.t()],
          announces: [String.t()],
          observes: [atom()],
          shortcuts: [%{key: String.t(), action: String.t(), description: String.t()}],
          reading: :glance | :scan | :read,
          words: non_neg_integer() | nil,
          stylesheets: [String.t()],
          proxy_routes: [Proxy.route()],
          isolation: :pure | :contained,
          access: String.t() | nil
        }

  @shortcut_keys [:key, :action, :description]
  @named_key ~r/\A[A-Z][A-Za-z0-9]+\z/

  @doc "The keys, in the order of spec/01 §1.2's table."
  @spec keys() :: [atom(), ...]
  def keys, do: @keys

  @doc """
  The declarations from an answer (a keyword list or a map with atom keys) for a component
  module, which `isolation: :contained` is checked against.

      iex> {:ok, d} = Macaw.Component.Declarations.new([events: ["open"], reading: :scan], nil)
      iex> {d.events, d.reading, d.isolation}
      {["open"], :scan, :pure}
  """
  @spec new(keyword() | map(), module() | nil) ::
          {:ok, t()} | {:error, [Macaw.Component.fault(), ...]}
  def new(answer, module) when is_list(answer) do
    if Keyword.keyword?(answer),
      do: new(Map.new(answer), module),
      else: {:error, [{[], {:not_a_keyword_list, answer}}]}
  end

  def new(%{} = answer, module) when not is_struct(answer) do
    unknown = for key <- Map.keys(answer), key not in @keys, do: {[key], :unknown_key}
    given = Map.take(answer, @keys)
    declarations = struct(__MODULE__, given)

    {slots, slot_faults} = slots(declarations.slots)
    {observes, observe_faults} = observes(declarations.observes)

    faults =
      unknown ++
        slot_faults ++
        State.writes_faults(declarations.writes) ++
        State.local_faults(declarations.local) ++
        names(:events, declarations.events) ++
        names(:announces, declarations.announces) ++
        observe_faults ++
        shortcuts(declarations.shortcuts) ++
        reading(declarations) ++
        stylesheets(declarations.stylesheets) ++
        Proxy.routes_faults(declarations.proxy_routes) ++
        isolation(declarations.isolation, module) ++
        access(declarations.access)

    Macaw.Component.answer(faults, %{declarations | slots: slots, observes: observes})
  end

  def new(other, _module), do: {:error, [{[], {:not_a_map, other}}]}

  @doc "Whether the declarations name an event."
  @spec emits?(t(), String.t()) :: boolean()
  def emits?(%__MODULE__{events: events}, name), do: name in events

  defp slots(%{} = slots) when not is_struct(slots) do
    Enum.reduce(slots, {%{}, []}, fn {name, slot}, {acc, faults} ->
      named = if is_binary(name) and name != "", do: [], else: [{[:slots, name], :bad_name}]

      case Slot.new(slot) do
        {:ok, built} ->
          {Map.put(acc, name, built), faults ++ named}

        {:error, more} ->
          {acc, faults ++ named ++ for({p, r} <- more, do: {[:slots, name | p], r})}
      end
    end)
  end

  defp slots(other), do: {%{}, [{[:slots], {:not_a_map, other}}]}

  defp names(key, names) when is_list(names) do
    bad =
      for {name, i} <- Enum.with_index(names),
          not (is_binary(name) and name != ""),
          do: {[key, i], :bad_name}

    dups = for name <- Enum.uniq(names -- Enum.uniq(names)), do: {[key], {:duplicate, name}}
    bad ++ dups
  end

  defp names(key, other), do: [{[key], {:not_a_list, other}}]

  defp observes(list) when is_list(list) do
    vocabulary = Macaw.Component.observations()

    {atoms, faults} =
      list
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {item, i}, {atoms, faults} ->
        case Enum.find(vocabulary, &(&1 == item or Atom.to_string(&1) == item)) do
          nil -> {atoms, [{[:observes, i], {:unknown_observation, item}} | faults]}
          atom -> {[atom | atoms], faults}
        end
      end)

    {Enum.uniq(Enum.reverse(atoms)), Enum.reverse(faults)}
  end

  defp observes(other), do: {[], [{[:observes], {:not_a_list, other}}]}

  defp shortcuts(list) when is_list(list) do
    each =
      list
      |> Enum.with_index()
      |> Enum.flat_map(fn
        {%{} = s, i} when not is_struct(s) ->
          path = [:shortcuts, i]
          unknown = for k <- Map.keys(s), k not in @shortcut_keys, do: {path ++ [k], :unknown_key}

          unknown ++
            for(
              {k, ok?} <- [
                key: key?(Map.get(s, :key)),
                action: nonempty?(Map.get(s, :action)),
                description: nonempty?(Map.get(s, :description))
              ],
              not ok?,
              do: {path ++ [k], :required}
            )

        {other, i} ->
          [{[:shortcuts, i], {:not_a_map, other}}]
      end)

    keys = for %{key: key} <- list, do: key

    dups =
      for key <- Enum.uniq(keys -- Enum.uniq(keys)), do: {[:shortcuts], {:duplicate_key, key}}

    each ++ dups
  end

  defp shortcuts(other), do: [{[:shortcuts], {:not_a_list, other}}]

  defp key?(key) when is_binary(key),
    do: String.length(key) == 1 or Regex.match?(@named_key, key)

  defp key?(_key), do: false

  defp nonempty?(value), do: is_binary(value) and value != ""

  defp reading(%{reading: reading, words: words}) do
    r =
      if reading in [:glance, :scan, :read],
        do: [],
        else: [{[:reading], {:unknown_reading, reading}}]

    w =
      cond do
        is_nil(words) -> []
        not (is_integer(words) and words >= 0) -> [{[:words], :not_a_count}]
        reading != :read -> [{[:words], :words_without_read}]
        true -> []
      end

    r ++ w
  end

  defp stylesheets(list) when is_list(list) do
    for {css, i} <- Enum.with_index(list),
        reason = Stylesheet.fault(css),
        reason != nil,
        do: {[:stylesheets, i], reason}
  end

  defp stylesheets(other), do: [{[:stylesheets], {:not_a_list, other}}]

  defp isolation(:pure, _module), do: []

  defp isolation(:contained, nil), do: []

  defp isolation(:contained, module) do
    Code.ensure_loaded(module)

    missing =
      for {name, arity} <- Macaw.Component.transitions(),
          not function_exported?(module, name, arity),
          do: "#{name}/#{arity}"

    if missing == [], do: [], else: [{[:isolation], {:missing, missing}}]
  end

  defp isolation(other, _module), do: [{[:isolation], {:unknown_isolation, other}}]

  defp access(nil), do: []
  defp access(name) when is_binary(name) and name != "", do: []
  defp access(_other), do: [{[:access], :bad_name}]
end
