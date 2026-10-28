defmodule Macaw.Component.Slot do
  @moduledoc """
  A slot: a typed input, `%{requires: %{role => requirement}, doc: "…"}` (spec/01 §1.3).

  Each role is a field the component reads from the slot's source, with what it requires
  of that field. `check/3` checks a binding of the slot to a source's schema before any
  data flows, so a component author and every host check bindings the same way.
  """

  alias Macaw.Data.{Quantity, Schema}

  @types [:time, :number, :category, :text, :color, :point]
  @requirement_keys [:type, :window, :identity, :quantity, :many, :optional, :doc]
  @flags [:window, :identity, :many, :optional]

  @type requirement :: %{
          type: [atom(), ...],
          window: boolean(),
          identity: boolean(),
          quantity: atom() | nil,
          many: boolean(),
          optional: boolean(),
          doc: String.t() | nil
        }

  @type t :: %{requires: %{String.t() => requirement()}, doc: String.t() | nil}

  @doc "A requirement's keys, in order."
  @spec requirement_keys() :: [atom(), ...]
  def requirement_keys, do: @requirement_keys

  @doc """
  A slot built from its declaration, every requirement's defaults filled in and `type`
  always a list: `{:ok, slot}`, or `{:error, faults}` from the slot.
  """
  @spec new(term()) :: {:ok, t()} | {:error, [Macaw.Component.fault(), ...]}
  def new(%{} = slot) when not is_struct(slot) do
    unknown = for key <- Map.keys(slot), key not in [:requires, :doc], do: {[key], :unknown_key}
    doc = doc_faults(Map.get(slot, :doc), [:doc])

    {requires, role_faults} =
      case Map.get(slot, :requires, %{}) do
        %{} = requires when not is_struct(requires) ->
          Enum.reduce(requires, {%{}, []}, fn {role, requirement}, {acc, faults} ->
            {built, more} = requirement(role, requirement)
            {Map.put(acc, role, built), faults ++ more}
          end)

        other ->
          {%{}, [{[:requires], {:not_a_map, other}}]}
      end

    Macaw.Component.answer(unknown ++ doc ++ role_faults, %{
      requires: requires,
      doc: Map.get(slot, :doc)
    })
  end

  def new(other), do: {:error, [{[], {:not_a_map, other}}]}

  defp requirement(role, %{} = req) when not is_struct(req) do
    path = [:requires, role]
    name = if is_binary(role) and role != "", do: [], else: [{path, :bad_name}]

    unknown =
      for key <- Map.keys(req), key not in @requirement_keys, do: {path ++ [key], :unknown_key}

    types = List.wrap(Map.get(req, :type))

    type =
      cond do
        not Map.has_key?(req, :type) -> [{path ++ [:type], :required}]
        types != [] and Enum.all?(types, &(&1 in @types)) -> []
        true -> [{path ++ [:type], {:unknown_type, Map.get(req, :type)}}]
      end

    flags =
      for flag <- @flags,
          Map.has_key?(req, flag),
          not is_boolean(req[flag]),
          do: {path ++ [flag], :not_a_boolean}

    quantity =
      case Map.get(req, :quantity) do
        nil -> []
        q -> if q in Quantity.all(), do: [], else: [{path ++ [:quantity], {:unknown_quantity, q}}]
      end

    built = %{
      type: types,
      window: Map.get(req, :window, false),
      identity: Map.get(req, :identity, false),
      quantity: Map.get(req, :quantity),
      many: Map.get(req, :many, false),
      optional: Map.get(req, :optional, false),
      doc: Map.get(req, :doc)
    }

    {built,
     name ++
       unknown ++ type ++ flags ++ quantity ++ doc_faults(Map.get(req, :doc), path ++ [:doc])}
  end

  defp requirement(role, other), do: {%{}, [{[:requires, role], {:not_a_map, other}}]}

  defp doc_faults(nil, _path), do: []
  defp doc_faults(doc, _path) when is_binary(doc), do: []
  defp doc_faults(_doc, path), do: [{path, :not_a_string}]

  @doc """
  Checks a binding of a slot (as `new/1` builds it) to a source of `schema`, `fields`
  mapping each role to its field, or for a `many` role a non-empty list of fields. `:ok`
  or every fault at once, each at `[role]`. A `window` role left unbound reads the
  schema's window field.

      iex> {:ok, slot} = Macaw.Component.Slot.new(%{requires: %{"x" => %{type: :time, window: true}, "y" => %{type: :number}}})
      iex> schema = Macaw.Data.Schema.new!(%{t: %{type: :time}, v: %{type: :number}})
      iex> Macaw.Component.Slot.check(slot, schema, %{"y" => "v"})
      :ok
      iex> Macaw.Component.Slot.check(slot, schema, %{})
      {:error, [{["y"], :unbound}]}
  """
  @spec check(t(), Schema.t(), map()) :: :ok | {:error, [Macaw.Component.fault(), ...]}
  def check(%{requires: requires}, %Schema{} = schema, fields) when is_map(fields) do
    unknown =
      for role <- Map.keys(fields), not Map.has_key?(requires, role), do: {[role], :unknown_role}

    faults =
      Enum.flat_map(requires, fn {role, req} ->
        case bound(req, schema, Map.fetch(fields, role)) do
          :unbound -> if req.optional, do: [], else: [{[role], :unbound}]
          {:ok, names} -> for reason <- field_faults(req, schema, names), do: {[role], reason}
          {:error, reason} -> [{[role], reason}]
        end
      end)

    case Macaw.Component.answer(unknown ++ faults, :ok) do
      {:ok, :ok} -> :ok
      error -> error
    end
  end

  defp bound(%{window: true}, schema, :error) do
    case Schema.window_field(schema) do
      nil -> :unbound
      field -> {:ok, [field]}
    end
  end

  defp bound(_req, _schema, :error), do: :unbound
  defp bound(%{many: true}, _schema, {:ok, [_ | _] = names}), do: {:ok, names}
  defp bound(%{many: true}, _schema, {:ok, _other}), do: {:error, :many}
  defp bound(_req, _schema, {:ok, names}) when is_list(names), do: {:error, :many}
  defp bound(_req, _schema, {:ok, name}), do: {:ok, [name]}

  defp field_faults(req, schema, names) do
    window = Schema.window_field(schema)
    identity = Enum.map(Schema.identity(schema), &to_string/1)

    Enum.flat_map(names, fn name ->
      case Schema.fetch(schema, name) do
        :error ->
          [{:missing, name}]

        {:ok, description} ->
          got = description.type
          q = Map.get(description, :quantity)

          Enum.reject(
            [
              got not in req.type && {:type, req.type, got},
              (req.window and to_string(window) != to_string(name)) && :not_window,
              (req.identity and to_string(name) not in identity) && :not_identity,
              (req.quantity != nil and q != req.quantity) && {:quantity, req.quantity, q}
            ],
            &(&1 == false)
          )
      end
    end)
  end
end
