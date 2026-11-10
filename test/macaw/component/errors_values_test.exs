defmodule Macaw.Component.ErrorsValuesTest do
  # Errors are values (#12, #34, #35, spec/00 §4): over generated malformed input, the
  # readers of settings, slots, bindings, contexts and the kit's options answer a value,
  # never a raise, and every fault they give is worded.
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Macaw.Component
  alias Macaw.Component.{Conformance, Context, Slot}
  alias Macaw.Component.Test.{Cards, Honest}
  alias Macaw.Data.Schema

  @schema Schema.new!(%{
            :t => %{type: :time},
            "host" => %{type: :category, identity: true},
            :latency => %{type: :number, unit: "ms"}
          })

  defp junk do
    leaf =
      one_of([
        constant(nil),
        boolean(),
        integer(),
        float(),
        atom(:alphanumeric),
        string(:printable, max_length: 6),
        member_of([
          "x",
          "y",
          :t,
          "t",
          "host",
          :latency,
          :time,
          :number,
          :category,
          :live,
          :print,
          {640, 400},
          [:latency],
          "kit-a"
        ])
      ])

    tree(leaf, fn child ->
      one_of([
        list_of(child, max_length: 3),
        map(list_of(tuple({leaf, child}), max_length: 3), &Map.new/1)
      ])
    end)
  end

  defp keys(keys), do: map(list_of(tuple({member_of(keys), junk()}), max_length: 4), &Map.new/1)

  defp fault_value?({:ok, _value}), do: true
  defp fault_value?(:ok), do: true

  defp fault_value?({:error, [_ | _] = faults}),
    do: Enum.all?(faults, &is_binary(Component.format_fault(&1)))

  defp fault_value?(_other), do: false

  @tag verifies: "component-errors-values"
  property "settings/2 and declarations/2 answer a value over any settings" do
    check all(
            given <-
              one_of([
                keys(["columns", "title", "x"]),
                map(list_of(tuple({junk(), junk()}), max_length: 3), &Map.new/1)
              ])
          ) do
      for component <- [Cards, Honest.Menu, Honest.Scene] do
        assert fault_value?(Component.settings(component, given))
        assert fault_value?(Component.declarations(component, given))
      end
    end
  end

  @tag verifies: "component-errors-values"
  property "a slot, its check and its resolution answer a value over any input" do
    requirement = keys([:type, :window, :many, :optional, :identity, :quantity, :unit, :doc])

    check all(
            given <-
              one_of([
                junk(),
                map(
                  list_of(tuple({member_of(["x", "y"]), requirement}), max_length: 2),
                  &%{requires: Map.new(&1)}
                )
              ]),
            fields <- one_of([keys(["x", "y"]), junk()])
          ) do
      result = Slot.new(given)
      assert fault_value?(result)

      with {:ok, slot} <- result, true <- is_map(fields) do
        assert fault_value?(Slot.check(slot, @schema, fields))
        assert fault_value?(Slot.resolve(slot, @schema, fields))
      end
    end
  end

  @tag verifies: "component-errors-values"
  property "a context answers a value over any attrs" do
    check all(
            attrs <-
              keys([:mode, :instance, :size, :heading_level, :theme, :now, :bindings, :schemas])
          ) do
      assert fault_value?(Context.new(attrs))
      assert fault_value?(Context.new(Map.to_list(attrs)))
    end
  end

  @tag verifies: "component-errors-values"
  property "the kit answers findings over any options, never a raise" do
    options = list_of(tuple({member_of([:fixtures, :check_sets, :speed]), junk()}), max_length: 2)

    check all(opts <- options, max_runs: 40) do
      findings = Conformance.check(:kinds, Honest.Menu, opts)
      assert is_list(findings)
      assert Enum.all?(findings, &is_binary(Conformance.format(&1)))
    end
  end
end
