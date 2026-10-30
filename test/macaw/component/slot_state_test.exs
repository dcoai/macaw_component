defmodule Macaw.Component.SlotStateTest do
  # Slots and their binding check (spec/01 §1.3), and the state vocabulary (§1.5).
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Macaw.Component.{Declarations, Slot, State}
  alias Macaw.Data.Schema

  doctest Slot
  doctest State

  @schema Schema.new!(%{
            :t => %{type: :time},
            "host" => %{type: :category, identity: true},
            :latency => %{type: :number, unit: "ms", quantity: :duration},
            :note => %{type: :text}
          })

  defp slot(requires), do: elem(Slot.new(%{requires: requires}), 1)

  @tag verifies: "slots-shape"
  test "a slot of roles with every requirement key builds with defaults" do
    assert {:ok, slot} =
             Slot.new(%{
               doc: "the series",
               requires: %{
                 "x" => %{type: :time, window: true, doc: "when"},
                 "y" => %{type: [:number], quantity: :duration, many: true, optional: false},
                 "who" => %{type: [:category, :text], identity: true, optional: true}
               }
             })

    assert slot.doc == "the series"

    assert slot.requires["x"] == %{
             type: [:time],
             window: true,
             identity: false,
             quantity: nil,
             many: false,
             optional: false,
             doc: "when"
           }

    assert Slot.requirement_keys() == [
             :type,
             :window,
             :identity,
             :quantity,
             :many,
             :optional,
             :doc
           ]

    assert {:ok, %{requires: %{}}} = Slot.new(%{})
  end

  @tag verifies: "slots-shape"
  test "a bad requirement is a fault at its path" do
    assert {:error, faults} =
             Slot.new(%{
               requires: %{
                 "a" => %{type: :pixels},
                 "b" => %{type: :number, window: "yes", quantity: :mood, tint: 1},
                 "c" => %{},
                 "d" => :number
               },
               doc: 5,
               extra: true
             })

    assert Enum.sort(faults) ==
             Enum.sort([
               {[:doc], :not_a_string},
               {[:extra], :unknown_key},
               {[:requires, "a", :type], {:unknown_type, :pixels}},
               {[:requires, "b", :tint], :unknown_key},
               {[:requires, "b", :quantity], {:unknown_quantity, :mood}},
               {[:requires, "b", :window], :not_a_boolean},
               {[:requires, "c", :type], :required},
               {[:requires, "d"], {:not_a_map, :number}}
             ])

    assert {:error, [{[:slots, "s", :requires, "a", :type], _}]} =
             Declarations.new([slots: %{"s" => %{requires: %{"a" => %{type: :nope}}}}], nil)
  end

  @tag verifies: "slots-check"
  test "a binding passes when every role's field meets its requirements" do
    s =
      slot(%{
        "x" => %{type: :time, window: true},
        "y" => %{type: :number, quantity: :duration, many: true},
        "who" => %{type: :category, identity: true},
        "label" => %{type: :text, optional: true}
      })

    assert Slot.check(s, @schema, %{"y" => ["latency"], "who" => "host"}) == :ok

    assert Slot.check(s, @schema, %{
             "x" => :t,
             "y" => [:latency],
             "who" => :host,
             "label" => "note"
           }) == :ok

    # A slot with no roles reads whole rows.
    assert Slot.check(slot(%{}), @schema, %{}) == :ok
  end

  @tag verifies: "slots-check"
  test "every fault of a bad binding at its role, at once, by either spelling" do
    s =
      slot(%{
        "x" => %{type: :time, window: true},
        "y" => %{type: :number, quantity: :information},
        "who" => %{type: :category, identity: true},
        "z" => %{type: :number},
        "w" => %{type: :number}
      })

    assert {:error, faults} =
             Slot.check(s, @schema, %{
               "x" => "latency",
               "y" => "latency",
               "who" => "note",
               "w" => ["latency"],
               "extra" => "t"
             })

    assert faults == [
             {["extra"], :unknown_role},
             {["w"], :many},
             {["who"], {:type, [:category], :text}},
             {["who"], :not_identity},
             {["x"], {:type, [:time], :number}},
             {["x"], :not_window},
             {["y"], {:quantity, :information, :duration}},
             {["z"], :unbound}
           ]

    assert Slot.check(slot(%{"y" => %{type: :number}}), @schema, %{"y" => "nope"}) ==
             {:error, [{["y"], {:missing, "nope"}}]}

    assert Slot.check(slot(%{"y" => %{type: :number, many: true}}), @schema, %{"y" => []}) ==
             {:error, [{["y"], :many}]}

    # No window field: an unbound window role is unbound.
    no_window = Schema.new!(%{v: %{type: :number}})

    assert Slot.check(slot(%{"x" => %{type: :time, window: true}}), no_window, %{}) ==
             {:error, [{["x"], :unbound}]}
  end

  @tag verifies: "slot-resolve"
  test "resolve/3 fills an unbound window role, drops an unbound optional one, keeps many" do
    s =
      slot(%{
        "x" => %{type: :time, window: true},
        "y" => %{type: :number, quantity: :duration, many: true},
        "who" => %{type: :category, identity: true},
        "label" => %{type: :text, optional: true}
      })

    assert Slot.resolve(s, @schema, %{"y" => [:latency], "who" => :host}) ==
             %{"x" => "t", "y" => ["latency"], "who" => "host"}

    assert Slot.resolve(s, @schema, %{
             "x" => :t,
             "y" => ["latency"],
             "who" => "host",
             "label" => :note
           }) == %{"x" => "t", "y" => ["latency"], "who" => "host", "label" => "note"}

    # An optional window role with no window field to read is absent.
    no_window = Schema.new!(%{v: %{type: :number}})

    assert Slot.resolve(
             slot(%{"x" => %{type: :time, window: true, optional: true}}),
             no_window,
             %{}
           ) ==
             %{}

    # A slot with no roles reads whole rows.
    assert Slot.resolve(slot(%{}), @schema, %{}) == %{}
  end

  @tag verifies: "slot-resolve"
  test "resolve/3 raises on a binding check/3 refuses" do
    s = slot(%{"y" => %{type: :number}})

    assert_raise ArgumentError, ~r/does not pass Slot.check\/3.*:unbound/, fn ->
      Slot.resolve(s, @schema, %{})
    end

    assert_raise ArgumentError, ~r/:many/, fn ->
      Slot.resolve(s, @schema, %{"y" => ["latency"]})
    end
  end

  @tag verifies: "state-vocabulary"
  test "the vocabulary, and writes and local keys outside it" do
    assert State.standard() == %{
             "selection" => [:identity],
             "window" => [:window],
             "camera" => [:camera],
             "breakpoints" => [:breakpoints]
           }

    assert State.types() ==
             [
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

    assert State.local_types() == Enum.take(State.types(), 8)

    assert {:ok, _} =
             Declarations.new([writes: %{"selection" => :identity, "window" => :window}], nil)

    assert {:error, faults} =
             Declarations.new(
               [
                 writes: %{"theme" => :category, "window" => :identity},
                 local: %{"cam" => :camera}
               ],
               nil
             )

    assert faults == [
             {[:local, "cam"], {:not_a_domain_type, :camera}},
             {[:writes, "theme"], {:not_standard, "theme"}},
             {[:writes, "window"], {:type, "window", :identity}}
           ]
  end

  @tag verifies: "state-conforms"
  test "conforms?/2 accepts each type's values and refuses others" do
    now = ~U[2026-10-28 12:00:00Z]

    for {type, good, bad} <- [
          identity:
            {["a", 3, :host, %{"host" => "a", "port" => 80}],
             [nil, true, %{}, %{"a" => [1]}, [1]]},
          window:
            {[
               nil,
               %{last: 60},
               %{from: 1, to: 2},
               %{from: now, to: now, as_of: now},
               %{last: 1, as_of: now}
             ],
             [
               %{last: 0},
               %{from: 2, to: 1},
               %{from: now, to: 5},
               %{last: 1, as_of: 3},
               %{from: 1},
               [1, 2]
             ]},
          box:
            {[%{west: 170, south: -10, east: -170, north: 10}],
             [%{west: 0, south: 5, east: 1, north: 1}, %{west: 200, south: 0, east: 0, north: 1}]},
          camera: {[%{x: 1}], [[1]]},
          breakpoints: {[[], [1, 2]], [%{}]},
          time: {[now], [1]},
          point: {[{1, 2}], [{200, 0}]}
        ] do
      for v <- good, do: assert(State.conforms?(type, v), "#{type} should take #{inspect(v)}")
      for v <- bad, do: refute(State.conforms?(type, v), "#{type} should refuse #{inspect(v)}")
    end
  end

  @tag verifies: "state-conforms"
  property "number windows are windows exactly when from is not after to" do
    check all(a <- float(), b <- float(), seconds <- positive_integer()) do
      assert State.conforms?(:window, %{from: a, to: b}) == a <= b
      assert State.conforms?(:window, %{last: seconds})
      refute State.conforms?(:window, %{last: -seconds})
    end
  end
end
