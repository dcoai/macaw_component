defmodule Macaw.Component.State do
  @moduledoc """
  The state vocabulary a component and every host agree on (spec/01 §1.5): the standard
  state sources a component may write, and the value and domain types.

      iex> Macaw.Component.State.conforms?(:window, %{last: 3600})
      true
      iex> Macaw.Component.State.conforms?(:identity, %{"host" => "a", "port" => 80})
      true
  """

  alias Macaw.Data.{Parameter, Window}

  @standard %{
    "selection" => [:identity],
    "window" => [:window],
    "camera" => [:camera],
    "breakpoints" => [:breakpoints]
  }

  @types [
    :time,
    :number,
    :category,
    :text,
    :point,
    :identity,
    :window,
    :box,
    :camera,
    :breakpoints
  ]
  @local_types Enum.take(@types, 8)

  @type type ::
          :time
          | :number
          | :category
          | :text
          | :point
          | :identity
          | :window
          | :box
          | :camera
          | :breakpoints

  @doc "The standard state sources, each with the value types it takes."
  @spec standard() :: %{String.t() => [type(), ...]}
  def standard, do: @standard

  @doc "The value and domain types, in order."
  @spec types() :: [type(), ...]
  def types, do: @types

  @doc "The domain types a `local` key may carry: the first eight of `types/0`."
  @spec local_types() :: [type(), ...]
  def local_types, do: @local_types

  @doc """
  Whether a value is of a type. `:identity` is a scalar or a non-empty map of field to
  scalar; `:window` is `nil`, `%{last: seconds}` or `%{from: a, to: b}`, either with an
  optional `as_of` instant; `:box` is `%{west, south, east, north}` in degrees; `:camera`
  a map and `:breakpoints` a list; the data-model types are `Macaw.Data.Parameter`'s.
  """
  @spec conforms?(type(), term()) :: boolean()
  def conforms?(:identity, value) when is_map(value) and not is_struct(value),
    do: map_size(value) > 0 and Enum.all?(value, fn {_field, v} -> scalar?(v) end)

  def conforms?(:identity, value), do: scalar?(value)

  def conforms?(:window, nil), do: true

  def conforms?(:window, %{} = window) when not is_struct(window) do
    {as_of, rest} = Map.pop(window, :as_of)

    (is_nil(as_of) or match?(%DateTime{}, as_of)) and
      case rest do
        %{last: seconds} when map_size(rest) == 1 -> is_number(seconds) and seconds > 0
        %{from: from, to: to} when map_size(rest) == 2 -> range?(from, to)
        _ -> false
      end
  end

  def conforms?(:window, _value), do: false

  def conforms?(:box, %{west: w, south: s, east: e, north: n} = box) when map_size(box) == 4 do
    Enum.all?([w, e], &(is_number(&1) and &1 >= -180 and &1 <= 180)) and
      Enum.all?([s, n], &(is_number(&1) and &1 >= -90 and &1 <= 90)) and s <= n
  end

  def conforms?(:box, _value), do: false
  def conforms?(:camera, value), do: is_map(value) and not is_struct(value)
  def conforms?(:breakpoints, value), do: is_list(value)

  def conforms?(type, value) when type in [:time, :number, :category, :text, :point],
    do: Parameter.conforms?(type, value)

  defp scalar?(value),
    do:
      is_binary(value) or is_number(value) or
        (is_atom(value) and not is_boolean(value) and not is_nil(value))

  defp range?(from, to) do
    both_numbers = is_number(from) and is_number(to)
    both_instants = Window.instant?(from) and Window.instant?(to) and same_kind?(from, to)
    (both_numbers or both_instants) and Window.compare(from, to) != :gt
  end

  defp same_kind?(%module{}, %module{}), do: true
  defp same_kind?(_a, _b), do: false

  @doc false
  # The faults of a `writes` declaration, from its key.
  @spec writes_faults(term()) :: [Macaw.Component.fault()]
  def writes_faults(writes) when is_map(writes) and not is_struct(writes) do
    Enum.flat_map(writes, fn {name, type} ->
      case Map.fetch(@standard, name) do
        :error -> [{[:writes, name], {:not_standard, name}}]
        {:ok, types} -> if type in types, do: [], else: [{[:writes, name], {:type, name, type}}]
      end
    end)
  end

  def writes_faults(other), do: [{[:writes], {:not_a_map, other}}]

  @doc false
  # The faults of a `local` declaration, from its key.
  @spec local_faults(term()) :: [Macaw.Component.fault()]
  def local_faults(local) when is_map(local) and not is_struct(local) do
    Enum.flat_map(local, fn {key, type} ->
      cond do
        not (is_binary(key) and key != "") -> [{[:local, key], :bad_name}]
        type in @local_types -> []
        true -> [{[:local, key], {:not_a_domain_type, type}}]
      end
    end)
  end

  def local_faults(other), do: [{[:local], {:not_a_map, other}}]
end
