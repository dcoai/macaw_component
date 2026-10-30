defmodule Macaw.Component.Context do
  @moduledoc """
  The context a component renders in (spec/02 §2): its mode, instance, size, root font
  size, heading level, theme, the viewer's preferences, the holder's now, and the cell's
  resolved bindings.

  The host computes it: on a page the core, elsewhere the adopter. The component never
  knows which, and never reads a clock: `now` is the holder's. `bindings` is
  `%{slot => %{role => field | [field, ...]}}`, each slot's binding as
  `Macaw.Component.Slot.resolve/3` resolves it, so a component reads the field bound to a
  role with `field/3` and never repeats the defaulting rule.

      iex> {:ok, ctx} = Macaw.Component.Context.new(mode: :live, instance: "cards-1", size: {640, 400}, now: ~U[2026-10-28 12:00:00Z])
      iex> {Macaw.Component.Context.heading(ctx, 0), Macaw.Component.Context.heading(ctx, 1)}
      {"h2", "h3"}
      iex> Macaw.Component.Context.id(ctx, "item-3")
      "cards-1-item-3"
      iex> {:ok, ctx} = Macaw.Component.Context.new(mode: :live, instance: "chart-1", size: {640, 400}, now: ~U[2026-10-28 12:00:00Z], bindings: %{"points" => %{"x" => "t", "y" => ["in", "out"]}})
      iex> {Macaw.Component.Context.field(ctx, "points", "x"), Macaw.Component.Context.field(ctx, "points", "y"), Macaw.Component.Context.field(ctx, "points", "label")}
      {"t", ["in", "out"], nil}
  """

  alias Macaw.Component.Mode
  alias Macaw.Layers.Theme

  @fields [
    :mode,
    :instance,
    :size,
    :measured,
    :root_font_size,
    :heading_level,
    :theme,
    :preferences,
    :now,
    :bindings
  ]
  @required [:mode, :instance, :size, :now]
  @local ~r/\A[A-Za-z0-9_-]+\z/

  @enforce_keys @required
  defstruct mode: nil,
            instance: nil,
            size: nil,
            measured: false,
            root_font_size: 16,
            heading_level: 2,
            theme: nil,
            preferences: %{zone: "Etc/UTC", units: :as_posted, shortcuts: %{}},
            now: nil,
            bindings: %{}

  @type t :: %__MODULE__{
          mode: Mode.t(),
          instance: String.t(),
          size: {number(), number()},
          measured: boolean(),
          root_font_size: number(),
          heading_level: 1..6,
          theme: Theme.t(),
          preferences: %{zone: String.t(), units: atom(), shortcuts: map()},
          now: DateTime.t(),
          bindings: %{String.t() => %{String.t() => String.t() | [String.t(), ...]}}
        }

  @doc "The fields, in the order of spec/02 §2's table."
  @spec fields() :: [atom(), ...]
  def fields, do: @fields

  @doc """
  A context from a keyword list or a map: `{:ok, context}` or every fault at once, each
  `{[field], reason}`, an unknown field `:unknown_key` and a missing required one
  `:required`. The theme defaults to `Macaw.Layers.Theme.default()`. A bad binding is a
  fault at its path under `[:bindings]`: `:not_a_map`, `:bad_name` for a slot or role
  that is not a non-empty string, `:not_a_field` for a field that is neither a non-empty
  string nor a non-empty list of them.
  """
  @spec new(keyword() | map()) :: {:ok, t()} | {:error, [Macaw.Component.fault(), ...]}
  def new(attrs) when is_list(attrs) or is_map(attrs) do
    attrs = Map.new(attrs)
    unknown = for key <- Map.keys(attrs), key not in @fields, do: {[key], :unknown_key}
    missing = for key <- @required, not Map.has_key?(attrs, key), do: {[key], :required}

    context =
      struct(
        %__MODULE__{mode: nil, instance: nil, size: nil, now: nil, theme: Theme.default()},
        Map.take(attrs, @fields)
      )

    present =
      for key <- @fields,
          Map.has_key?(attrs, key),
          fault <- faults(key, Map.fetch!(attrs, key)),
          do: fault

    Macaw.Component.answer(unknown ++ missing ++ present, context)
  end

  defp faults(:bindings, bindings), do: binding_faults(bindings)

  defp faults(key, value) do
    case fault(key, value) do
      nil -> []
      reason -> [{[key], reason}]
    end
  end

  defp fault(:mode, mode), do: if(mode in Mode.all(), do: nil, else: {:unknown_mode, mode})

  defp fault(:instance, id),
    do: if(is_binary(id) and Regex.match?(@local, id), do: nil, else: :bad_id)

  defp fault(:size, {w, h}) when is_number(w) and is_number(h) and w > 0 and h > 0, do: nil
  defp fault(:size, _size), do: :not_a_size
  defp fault(:measured, m), do: if(is_boolean(m), do: nil, else: :not_a_boolean)

  defp fault(:root_font_size, s),
    do: if(is_number(s) and s > 0, do: nil, else: :not_positive)

  defp fault(:heading_level, l), do: if(l in 1..6, do: nil, else: :not_a_level)
  defp fault(:theme, %Theme{}), do: nil
  defp fault(:theme, _theme), do: :not_a_theme
  defp fault(:now, %DateTime{}), do: nil
  defp fault(:now, _now), do: :not_a_datetime

  defp fault(:preferences, %{zone: zone, units: units, shortcuts: shortcuts} = p)
       when map_size(p) == 3 do
    cond do
      not (is_binary(zone) and zone != "") -> {:zone, zone}
      units not in Macaw.Data.Quantity.systems() -> {:units, units}
      not (is_map(shortcuts) and not is_struct(shortcuts)) -> {:shortcuts, shortcuts}
      true -> nil
    end
  end

  defp fault(:preferences, _p), do: :not_preferences

  defp binding_faults(%{} = bindings) when not is_struct(bindings) do
    Enum.flat_map(bindings, fn {slot, roles} ->
      path = [:bindings, slot]
      name = if name?(slot), do: [], else: [{path, :bad_name}]
      name ++ role_faults(path, roles)
    end)
  end

  defp binding_faults(_bindings), do: [{[:bindings], :not_a_map}]

  defp role_faults(path, %{} = roles) when not is_struct(roles) do
    Enum.flat_map(roles, fn {role, field} ->
      name = if name?(role), do: [], else: [{path ++ [role], :bad_name}]
      name ++ if(field?(field), do: [], else: [{path ++ [role], :not_a_field}])
    end)
  end

  defp role_faults(path, _roles), do: [{path, :not_a_map}]

  defp name?(name), do: is_binary(name) and name != ""
  defp field?([_ | _] = fields), do: Enum.all?(fields, &name?/1)
  defp field?(field), do: name?(field)

  @doc """
  The heading element `depth` levels below the component's top (`0` for its top):
  `"h<level + depth>"`, never past `"h6"`.
  """
  @spec heading(t(), non_neg_integer()) :: String.t()
  def heading(%__MODULE__{heading_level: level}, depth) when is_integer(depth) and depth >= 0,
    do: "h#{min(level + depth, 6)}"

  @doc """
  The field bound to `role` of `slot`: a string for a one-field role, the list of fields
  for a `many` role, `nil` for a slot or role the context does not bind.
  """
  @spec field(t(), String.t(), String.t()) :: String.t() | [String.t(), ...] | nil
  def field(%__MODULE__{bindings: bindings}, slot, role),
    do: bindings |> Map.get(slot, %{}) |> Map.get(role)

  @doc """
  An element id unique to the instance, `"<instance>-<local>"`, stable across renders.
  `local` is a non-empty string of letters, digits, `-` and `_`; anything else raises
  `ArgumentError`, a programming error in the component.
  """
  @spec id(t(), String.t()) :: String.t()
  def id(%__MODULE__{instance: instance}, local) do
    (is_binary(local) and Regex.match?(@local, local)) ||
      raise ArgumentError, "an id's local part is letters, digits, - and _, got #{inspect(local)}"

    instance <> "-" <> local
  end
end
