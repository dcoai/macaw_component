defmodule Macaw.Component.ConformanceTest do
  # The conformance kit (spec/04 §1–3) and, through it, the kinds' output rules and the
  # rendering rules (spec/02 §4, §5).
  use ExUnit.Case, async: true

  alias Macaw.Component.Conformance
  alias Macaw.Component.Test.{Broken, Honest}
  alias Macaw.Data.Delivery

  @now ~U[2026-10-28 12:00:00Z]
  @sections Delivery.new([%{title: "One"}, %{title: "Two"}])
  @prose [fixtures: [%{deliveries: %{"sections" => @sections}, events: ["open"]}], now: @now]

  @honest [
    {Honest.Prose, @prose},
    {Honest.Menu, [now: @now]},
    {Honest.Field, [now: @now]},
    {Honest.Tabs, [now: @now]},
    {Honest.Swatch, [now: @now]},
    {Honest.Scene, [now: @now, fixtures: [%{deliveries: %{"frames" => @sections}}]]}
  ]

  defp broken(flaw, check),
    do: Conformance.check(check, Broken, fixtures: [%{settings: %{"flaw" => flaw}}], now: @now)

  defp whats(findings), do: for({_check, {_where, what}} <- findings, do: what)

  defp finds?(flaw, check, pattern) do
    findings = broken(flaw, check)

    assert Enum.any?(whats(findings), pattern),
           "#{flaw} should fail #{check}: #{inspect(findings)}"

    findings
  end

  @tag verifies: "kit-layers"
  test "honest components pass every check; check/3 is one check's, check/2 all of them" do
    assert Conformance.checks() ==
             [
               :declarations,
               :kinds,
               :modes,
               :delivery,
               :headings,
               :names,
               :keyboard,
               :colors,
               :ids,
               :drawn,
               :budget,
               :contained
             ]

    assert Conformance.check_sets() == [:visual]
    [set] = Enum.shuffle([:audio])
    assert_raise ArgumentError, ~r/not a check set/, fn -> Conformance.checks(set) end

    for {component, opts} <- @honest do
      assert Conformance.check(component, opts) == [], inspect(component)

      for check <- Conformance.checks(),
          do: assert(Conformance.check(check, component, opts) == [])
    end

    assert broken("none", :kinds) == []

    all =
      Conformance.check(Broken,
        fixtures: [%{settings: %{"flaw" => "style_attribute"}}],
        now: @now
      )

    assert all != [] and Enum.all?(all, &match?({:delivery, _}, &1))
  end

  @tag verifies: "kit-layers"
  test "every finding formats as a line naming its check and where" do
    for flaw <- Broken.flaws(),
        finding <-
          Conformance.check(Broken, fixtures: [%{settings: %{"flaw" => flaw}}], now: @now) do
      line = Conformance.format(finding)
      refute String.contains?(line, "\n")
      assert String.starts_with?(line, Atom.to_string(elem(finding, 0)) <> " (fixture 1")
    end

    assert Conformance.format(
             {:delivery, {{"fixture 1", :content, :live}, {:style_attribute, "p(3)"}}}
           ) ==
             "delivery (fixture 1, :content, live): p(3) has a style attribute"
  end

  @tag verifies: "kit-use"
  test "use writes one test per check into a describe block" do
    mod = Module.concat(__MODULE__, "Used#{System.unique_integer([:positive])}")

    Code.compile_quoted(
      quote do
        defmodule unquote(mod) do
          use ExUnit.Case, register: false

          use Macaw.Component.Conformance,
            component: Macaw.Component.Test.Honest.Menu,
            now: ~U[2026-10-28 12:00:00Z]
        end
      end
    )

    names =
      for %{name: name, tags: %{describe: describe}} <- mod.__ex_unit__().tests,
          do: {describe, name}

    assert Enum.sort(names) ==
             Enum.sort(
               for check <- Conformance.checks(),
                   do:
                     {"Macaw.Component.Test.Honest.Menu conforms",
                      :"test Macaw.Component.Test.Honest.Menu conforms #{check}"}
             )
  end

  @tag verifies: "kit-use"
  test "use refuses a missing component and an unknown option; check refuses unknowns" do
    assert_raise ArgumentError, ~r/needs component:/, fn ->
      Code.compile_string(
        "defmodule KitNoComponent do\n use Macaw.Component.Conformance, now: nil\nend"
      )
    end

    assert_raise ArgumentError, ~r/unknown option :speed/, fn ->
      Code.compile_string(
        "defmodule KitBadOption do\n use Macaw.Component.Conformance, component: X, speed: 1\nend"
      )
    end

    [check, option, set] =
      Enum.shuffle([:loudness]) ++ Enum.shuffle([:speed]) ++ Enum.shuffle([:audio])

    assert_raise ArgumentError, ~r/not a check/, fn ->
      Conformance.check(check, Honest.Menu, [])
    end

    assert_raise ArgumentError, ~r/unknown option/, fn ->
      Conformance.check(Honest.Menu, [{option, 1}])
    end

    assert_raise ArgumentError, ~r/not a check set/, fn ->
      Conformance.check(Honest.Menu, check_sets: [set])
    end

    assert_raise ArgumentError, ~r/not a component/, fn ->
      Conformance.check(:kinds, String, [])
    end
  end

  @tag verifies: "kit-checks"
  test "each check is failed by a component built to break it, naming the rule" do
    finds?("impure", :declarations, &(&1 == :impure))
    finds?("reads_bindable", :declarations, &match?({:reads_bindable, "mood"}, &1))
    finds?("canvas", :modes, &(&1 == :canvas))
    finds?("empty", :modes, &(&1 == :empty))
    finds?("hook_everywhere", :modes, &match?({:hook, _}, &1))
    finds?("script_everywhere", :modes, &match?({:script, _}, &1))
    finds?("live_region", :modes, &match?({:live_region, _}, &1))
    finds?("token", :modes, &match?({:token, _}, &1))
    finds?("fixed_heading", :headings, &match?({:not_from_context, _, _}, &1))
    finds?("top_h3", :headings, &match?({:top_heading, 2, 3}, &1))
    finds?("positive_tabindex", :keyboard, &match?({:positive_tabindex, _}, &1))
    finds?("composite_two_stops", :keyboard, &match?({:tab_stops, _, 2}, &1))
    finds?("menu_role", :keyboard, &match?({:menu_role, _}, &1))
    finds?("duplicate_id", :ids, &match?({:duplicate_id, "kit-a-d"}, &1))
    finds?("unstable_id", :ids, &match?({:unstable, _}, &1))
    finds?("unprefixed_id", :ids, &match?({:unprefixed, "fixed"}, &1))
    finds?("unprefixed_id", :ids, &match?({:shared_across_instances, "fixed"}, &1))

    assert Conformance.check(:contained, Broken.Scene, now: @now) ==
             [contained: {{"fixture 1", nil, nil}, :impure_value}]

    # Every check is failed by some flaw.
    for check <- Conformance.checks() do
      failed? =
        Conformance.check(check, Broken.Scene, now: @now) != [] or
          Enum.any?(Broken.flaws(), &(broken(&1, check) != []))

      assert failed?, "no broken component fails #{check}"
    end

    findings =
      Conformance.check(:declarations, Broken, fixtures: [%{events: ["ghost"]}], now: @now)

    assert {:undeclared_event, "ghost"} in whats(findings)

    findings =
      Conformance.check(:declarations, Broken,
        fixtures: [%{settings: %{"flaw" => "nope"}}],
        now: @now
      )

    assert [{:settings, _}] = whats(findings)
  end

  @tag verifies: "kit-drawn-budget-contained"
  test "drawn states in every mode, budgets per slot and size, and contained values" do
    findings = broken("blank_drawn", :drawn)
    blank = for {:blank, state} <- whats(findings), do: state
    assert Enum.sort(Enum.uniq(blank)) == Enum.sort(Macaw.Component.Drawn.all() -- [:live])

    assert {{"fixture 1", :navigation, :print}, {:blank, :crashed}} in for(
             {:drawn, f} <- findings,
             do: f
           )

    findings = broken("bad_budget", :budget)
    assert length(findings) == 3
    assert {:bad_budget, "rows", {320, 200}, 0} in whats(findings)

    assert Conformance.check(:contained, Broken, now: @now) == []
    assert Conformance.check(:contained, Honest.Scene, now: @now) == []
  end

  @tag verifies: "kit-fixtures"
  test "every fixture runs and names its findings; defaults fill a bare one; unknown keys are refused" do
    findings =
      Conformance.check(:delivery, Broken,
        fixtures: [
          %{settings: %{"flaw" => "none"}},
          %{name: "styled", settings: %{"flaw" => "style_attribute"}}
        ],
        now: @now
      )

    assert findings != [] and Enum.all?(findings, &match?({:delivery, {{"styled", _, _}, _}}, &1))

    assert Conformance.check(:kinds, Honest.Menu, fixtures: [%{}], now: @now) == []

    assert_raise ArgumentError, ~r/:setting is not a fixture key/, fn ->
      Conformance.check(:kinds, Honest.Menu, fixtures: [%{setting: %{}}])
    end

    assert_raise ArgumentError, ~r/non-empty list/, fn ->
      Conformance.check(:kinds, Honest.Menu, fixtures: [])
    end
  end

  @tag verifies: "kind-rules"
  test "each kind's rules: a labeled nav of links, a real control, a container pattern, no menu role" do
    finds?("no_nav", :kinds, &(&1 == :no_nav))
    finds?("unnamed_nav", :kinds, &match?({:unnamed_nav, _}, &1))
    finds?("menu_role", :kinds, &match?({:menu_role, _}, &1))
    finds?("no_control", :kinds, &(&1 == :no_control))
    finds?("no_container", :kinds, &(&1 == :no_container_pattern))
    assert broken("none", :kinds) == []
    assert Conformance.check(:kinds, Honest.Tabs, now: @now) == []
    assert Conformance.check(:kinds, Honest.Field, now: @now) == []
  end

  @tag verifies: "rendering-rules-checked"
  test "the kit finds each rendering rule broken, and nothing in a render that keeps them all" do
    for {flaw, pattern} <- [
          {"style_attribute", &match?({:style_attribute, _}, &1)},
          {"style_element", &match?({:style_element, _}, &1)},
          {"inline_script", &match?({:inline_script, _}, &1)},
          {"onclick", &match?({:event_attribute, _, "onclick"}, &1)},
          {"javascript_url", &match?({:javascript_url, _, "href"}, &1)},
          {"foreign_img", &match?({:foreign_load, _, "src"}, &1)},
          {"foreign_srcset", &match?({:foreign_load, _, "srcset"}, &1)}
        ] do
      finds?(flaw, :delivery, pattern)
    end

    finds?("img_no_alt", :names, &match?({:unnamed, "img" <> _}, &1))
    finds?("unnamed_button", :names, &match?({:unnamed, "button" <> _}, &1))
    finds?("unnamed_svg", :names, &match?({:unnamed, "svg" <> _}, &1))
    finds?("bad_state", :names, &match?({:state, _, "aria-pressed", "yes"}, &1))
    finds?("dangling_reference", :names, &match?({:reference, _, "aria-controls", "nowhere"}, &1))
    finds?("literal_fill", :colors, &match?({:literal_color, _, "fill", "#ff0000"}, &1))
    finds?("bad_cue", :colors, &match?({:bad_cue, _, "hue"}, &1))

    # A link may go to another origin; a data: image is same-origin.
    assert Conformance.check(:delivery, Honest.Menu, now: @now) == []

    for check <- [:delivery, :names, :keyboard, :colors, :headings, :ids, :modes],
        do: assert(broken("none", check) == [], "#{check}")
  end
end
