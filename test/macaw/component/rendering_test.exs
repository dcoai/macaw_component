defmodule Macaw.Component.RenderingTest do
  # The assigns, the context, the modes, drawn states, the contained value and the client
  # names (spec/02 §1–3, §6–8).
  use ExUnit.Case, async: true

  alias Macaw.Component
  alias Macaw.Component.{Assigns, Client, Context, Declarations, Drawn, Mode}
  alias Macaw.Component.Test.{Cards, Scene}
  alias Macaw.Data.Delivery

  doctest Context
  doctest Mode
  doctest Drawn

  @now ~U[2026-10-28 12:00:00Z]

  defp context(attrs \\ []),
    do:
      elem(
        Context.new(
          Keyword.merge([mode: :live, instance: "c1", size: {640, 400}, now: @now], attrs)
        ),
        1
      )

  @tag verifies: "assigns-keys"
  test "assigns are the six keys; a missing or unknown key is a fault; a pure value is nil" do
    assert Assigns.keys() == [:context, :settings, :declarations, :drawn, :deliveries, :value]
    {:ok, pure} = Declarations.new([], nil)
    {:ok, contained} = Declarations.new([isolation: :contained], nil)

    base = [
      context: context(),
      settings: %{},
      declarations: pure,
      drawn: :live,
      deliveries: %{},
      value: nil
    ]

    assert {:ok, assigns} = Assigns.new(base)
    assert Map.keys(assigns) |> Enum.sort() == Enum.sort(Assigns.keys())

    assert {:ok, _} =
             Assigns.new(Keyword.merge(base, declarations: contained, value: %{state: 1}))

    assert {:error, faults} =
             Assigns.new(
               Keyword.merge(Keyword.delete(base, :deliveries),
                 viewer: "u1",
                 drawn: :busy,
                 value: 1
               )
             )

    assert faults == [
             {[:deliveries], :required},
             {[:drawn], :bad_value},
             {[:value], :pure_has_no_value},
             {[:viewer], :unknown_key}
           ]
  end

  @tag verifies: "context-new"
  test "a context defaults its font size, level, theme and preferences; every bad field at once" do
    ctx = context()
    assert %{root_font_size: 16, heading_level: 2, measured: false} = ctx
    assert ctx.theme == Macaw.Layers.Theme.default()
    assert ctx.preferences == %{zone: "Etc/UTC", units: :as_posted, shortcuts: %{}}

    assert Context.fields() ==
             [
               :mode,
               :instance,
               :size,
               :measured,
               :root_font_size,
               :heading_level,
               :theme,
               :preferences,
               :now
             ]

    assert {:error, faults} =
             Context.new(
               mode: :paper,
               instance: "a b",
               size: {0, 10},
               measured: 1,
               root_font_size: -1,
               heading_level: 7,
               theme: :dark,
               preferences: %{zone: "", units: :as_posted, shortcuts: %{}},
               now: "now",
               viewer: "u"
             )

    assert faults == [
             {[:heading_level], :not_a_level},
             {[:instance], :bad_id},
             {[:measured], :not_a_boolean},
             {[:mode], {:unknown_mode, :paper}},
             {[:now], :not_a_datetime},
             {[:preferences], {:zone, ""}},
             {[:root_font_size], :not_positive},
             {[:size], :not_a_size},
             {[:theme], :not_a_theme},
             {[:viewer], :unknown_key}
           ]

    assert {:error, [{[:instance], :required}, {[:now], :required}]} =
             Context.new(mode: :live, size: {1, 1})

    assert {:error, [{[:preferences], {:units, :imperial_ish}}]} =
             Context.new(
               mode: :live,
               instance: "a",
               size: {1, 1},
               now: @now,
               preferences: %{zone: "UTC", units: :imperial_ish, shortcuts: %{}}
             )
  end

  @tag verifies: "context-helpers"
  test "heading/2 counts from the context's level and stops at h6; id/2 prefixes the instance" do
    assert Context.heading(context(heading_level: 1), 0) == "h1"
    assert Context.heading(context(heading_level: 3), 2) == "h5"
    assert Context.heading(context(heading_level: 5), 4) == "h6"
    assert Context.id(context(), "row-7") == "c1-row-7"
    assert Context.id(context(instance: "c2"), "row-7") == "c2-row-7"
    assert_raise ArgumentError, fn -> Context.id(context(), "a b") end
    assert_raise ArgumentError, fn -> Context.id(context(), "") end
  end

  @tag verifies: "modes-table"
  test "all/0 is the four in order, and allows?/2 answers the table" do
    assert Mode.all() == [:live, :socketless, :neutral, :print]
    assert Mode.features() == [:canvas, :hooks, :scripts, :tokens, :live_regions, :per_viewer]

    for feature <- Mode.features() do
      assert Mode.allows?(:live, feature)
      assert Mode.allows?(:socketless, feature) == (feature != :canvas)
      refute Mode.allows?(:neutral, feature)
      refute Mode.allows?(:print, feature)
    end

    # Unknown values arrive at runtime, from data the type checker can't see.
    [paper, sound] = Enum.shuffle([:paper]) ++ Enum.shuffle([:sound])
    assert_raise ArgumentError, ~r/not a mode/, fn -> Mode.allows?(paper, :hooks) end
    assert_raise ArgumentError, ~r/not a feature/, fn -> Mode.allows?(:live, sound) end
  end

  @tag verifies: "drawn-states"
  test "the eight states in precedence; every state but live has a role, a glyph and words" do
    assert Drawn.all() == [:crashed, :down, :invalid, :loading, :no_data, :stale, :capped, :live]
    assert Drawn.pick([]) == :live
    assert Drawn.pick([:live, :capped]) == :capped
    assert Drawn.pick([:stale, :loading, :no_data]) == :loading
    assert Drawn.pick([:capped, :crashed]) == :crashed
    assert_raise ArgumentError, fn -> Drawn.pick([:busy]) end

    roles = for s <- Drawn.all(), into: %{}, do: {s, Drawn.role(s)}

    assert roles == %{
             crashed: :bad,
             down: :bad,
             invalid: :warning,
             stale: :warning,
             loading: :info,
             capped: :info,
             no_data: :neutral,
             live: nil
           }

    for state <- Drawn.all() -- [:live] do
      assert Drawn.glyph(state) == Macaw.Layers.Theme.cue(Drawn.role(state)).glyph
      assert is_binary(Drawn.words(state)) and Drawn.words(state) != ""

      html = state |> Drawn.render(context()) |> Phoenix.HTML.safe_to_string()

      assert html =~
               state
               |> Drawn.words()
               |> Phoenix.HTML.html_escape()
               |> Phoenix.HTML.safe_to_string()

      assert html =~ ~s(data-mw-drawn="#{state}")
      refute html =~ "aria-live"
      refute html =~ ~r/role="(status|alert|log)"/
    end

    assert {Drawn.glyph(:live), Drawn.words(:live)} == {nil, nil}
    assert Phoenix.HTML.safe_to_string(Drawn.render(:live, context())) == ""
  end

  @tag verifies: "contained-transitions"
  test "a contained value moves through its transitions; the dispatchers refuse a pure component" do
    delivery = Delivery.new([%{t: 1}])
    value = Component.init(Scene, %{"zoom" => 1}, context())
    assert value.instance == "c1"
    value = Component.delivery(Scene, value, "frames", delivery)
    assert value.slots == %{"frames" => delivery}
    value = Component.size(Scene, value, {320, 200})
    assert value.size == {320, 200}
    value = Component.bound(Scene, value, "zoom", 2)
    assert value.settings == %{"zoom" => 2}

    # Pure: equal inputs, equal values.
    assert Component.init(Scene, %{"zoom" => 1}, context()) ==
             Component.init(Scene, %{"zoom" => 1}, context())

    for call <- [
          fn -> Component.init(Cards, %{}, context()) end,
          fn -> Component.delivery(Cards, %{}, "items", delivery) end,
          fn -> Component.size(Cards, %{}, {1, 1}) end,
          fn -> Component.bound(Cards, %{}, "bins", 2) end
        ] do
      assert_raise ArgumentError, ~r/not a contained component/, call
    end
  end

  @tag verifies: "client-names"
  test "the client protocols' fixed names" do
    assert Client.announcer_ids() == %{
             polite: "mw-announcer-polite",
             assertive: "mw-announcer-assertive"
           }

    assert Client.announce_event() == "macaw:announce"
    assert Client.bus_name() == "MacawBus"
  end
end
