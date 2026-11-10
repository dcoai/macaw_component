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
    :actions,
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
            actions: [],
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
          actions: [action()],
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

  @typedoc "A default action (spec/01 §1.6): an event sets one of the component's bindable parameters."
  @type action :: %{on: String.t(), set: String.t(), value: event_path()}

  @typedoc "A field of an event an action reads (spec/01 §1.6)."
  @type event_path ::
          {:event, :value | :identity | [:value | :identity | :row | String.t()]}

  @shortcut_keys [:key, :action, :description]
  @action_keys [:on, :set, :value]
  @named_key ~r/\A[A-Z][A-Za-z0-9]+\z/

  @doc "The keys, in the order of spec/01 §1.2's table."
  @spec keys() :: [atom(), ...]
  def keys, do: @keys

  @doc """
  The five event paths an action may read (spec/01 §1.6), `key` and `field` standing for
  any non-empty string.

      iex> length(Macaw.Component.Declarations.event_paths())
      5
  """
  @spec event_paths() :: [event_path(), ...]
  def event_paths,
    do: [
      {:event, :value},
      {:event, [:value, "key"]},
      {:event, :identity},
      {:event, [:identity, "field"]},
      {:event, [:row, "field"]}
    ]

  @doc """
  Whether a term is one of the five event paths.

      iex> Macaw.Component.Declarations.event_path?({:event, [:value, "sort"]})
      true
      iex> Macaw.Component.Declarations.event_path?({:event, [:value]})
      false
  """
  @spec event_path?(term()) :: boolean()
  def event_path?({:event, which}) when which in [:value, :identity], do: true

  def event_path?({:event, [which, name]}) when which in [:value, :identity, :row],
    do: is_binary(name) and name != ""

  def event_path?(_other), do: false

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
    {actions, action_faults} = actions(declarations.actions, declarations.events, module)

    faults =
      unknown ++
        slot_faults ++
        State.writes_faults(declarations.writes) ++
        State.local_faults(declarations.local) ++
        names(:events, declarations.events) ++
        action_faults ++
        names(:announces, declarations.announces) ++
        observe_faults ++
        shortcuts(declarations.shortcuts) ++
        reading(declarations) ++
        stylesheets(declarations.stylesheets) ++
        Proxy.routes_faults(declarations.proxy_routes) ++
        isolation(declarations.isolation, module) ++
        access(declarations.access)

    Macaw.Component.answer(faults, %{
      declarations
      | slots: slots,
        observes: observes,
        actions: actions
    })
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

  defp actions(list, events, module) when is_list(list) do
    bindables = bindables(module)

    {built, faults} =
      list
      |> Enum.with_index()
      |> Enum.map(fn {action, i} -> action(action, [:actions, i], events, bindables) end)
      |> Enum.unzip()

    {built, List.flatten(faults)}
  end

  defp actions(other, _events, _module), do: {[], [{[:actions], {:not_a_list, other}}]}

  defp action(%{} = action, path, events, bindables) when not is_struct(action) do
    unknown = for k <- Map.keys(action), k not in @action_keys, do: {path ++ [k], :unknown_key}
    missing = for k <- @action_keys, not Map.has_key?(action, k), do: {path ++ [k], :required}
    on = spelled(Map.get(action, :on))
    set = spelled(Map.get(action, :set))
    value = Map.get(action, :value)

    on_faults =
      cond do
        not Map.has_key?(action, :on) -> []
        not (is_binary(on) and on != "") -> [{path ++ [:on], :bad_name}]
        on not in List.wrap(events) -> [{path ++ [:on], {:undeclared, on}}]
        true -> []
      end

    set_faults =
      cond do
        not Map.has_key?(action, :set) -> []
        not (is_binary(set) and set != "") -> [{path ++ [:set], :bad_name}]
        bindables == :unchecked -> []
        not Map.has_key?(bindables, set) -> [{path ++ [:set], {:unknown_param, set}}]
        not bindables[set] -> [{path ++ [:set], {:not_bindable, set}}]
        true -> []
      end

    value_faults =
      if Map.has_key?(action, :value) and not event_path?(value),
        do: [{path ++ [:value], {:not_an_event_path, value}}],
        else: []

    {%{on: on, set: set, value: value},
     unknown ++ missing ++ on_faults ++ set_faults ++ value_faults}
  end

  defp action(other, path, _events, _bindables), do: {other, [{path, {:not_a_map, other}}]}

  # An atom name is read as its spelling; no atom is made.
  defp spelled(name) when is_atom(name) and name not in [nil, true, false],
    do: Atom.to_string(name)

  defp spelled(name), do: name

  # Each parameter of the module by name, whether it is bindable; with no module, as for
  # `isolation`, nothing is checked. A component's bad parameters are its own fault,
  # reported by `Macaw.Component.parameters/1`, so they check nothing here.
  defp bindables(nil), do: :unchecked

  defp bindables(module) do
    Code.ensure_loaded(module)

    with true <- function_exported?(module, :parameters, 0),
         %{} = parameters <- module.parameters() do
      for {name, parameter} <- parameters,
          into: %{},
          do: {name, is_map(parameter) and Map.get(parameter, :bindable) == true}
    else
      _ -> :unchecked
    end
  end

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
