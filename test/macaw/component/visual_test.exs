defmodule Macaw.Component.VisualTest do
  # The visual check set (spec/04 §4).
  use ExUnit.Case, async: true

  alias Macaw.Component.Conformance
  alias Macaw.Component.Test.Chart
  alias Macaw.Data.Delivery

  @now ~U[2026-10-28 12:00:00Z]

  defp fixtures(settings \\ %{}) do
    [
      %{settings: settings, deliveries: %{"points" => Delivery.new([%{v: 3}, %{v: 7}])}},
      %{settings: settings, deliveries: %{"points" => Delivery.new([%{v: 5}])}}
    ]
  end

  defp visual(flaw),
    do:
      Conformance.check(Chart,
        fixtures: fixtures(%{"flaw" => flaw}),
        check_sets: [:visual],
        now: @now
      )

  defp whats(findings, check), do: for({^check, {_where, what}} <- findings, do: what)

  @tag verifies: "kit-visual"
  test "an honest visual passes every check and the visual set" do
    assert Conformance.check_sets() == [:visual]
    assert Conformance.checks(:visual) == [:image, :table, :tab_stop, :token, :svg]
    assert visual("none") == []
  end

  @tag verifies: "kit-visual"
  test "the visual set finds each visual rule broken" do
    assert :no_image in whats(visual("no_image"), :image)
    assert [{:unnamed, "svg" <> _} | _] = whats(visual("unnamed_image"), :image)
    assert [{:undescribed, "svg" <> _} | _] = whats(visual("undescribed"), :image)
    assert :no_table in whats(visual("no_table"), :table)
    assert [{:unnamed_table, _} | _] = whats(visual("unnamed_table"), :table)
    assert [{:unscoped_header, "th" <> _} | _] = whats(visual("unscoped"), :table)
    assert {:tab_stops, 2} in whats(visual("two_stops"), :tab_stop)
    assert [{:no_token, _} | _] = whats(visual("no_token"), :token)
    assert {:same_token, "fixture 2"} in whats(visual("constant_token"), :token)
    assert :canvas in whats(visual("canvas_everywhere"), :svg)
  end

  @tag verifies: "kit-visual"
  test "a token check with no two deliveries to tell apart is a no_probe finding" do
    one = [hd(fixtures())]

    assert Conformance.check(:token, Chart, fixtures: one, now: @now) ==
             [token: {{"fixture 1", nil, nil}, {:no_probe, :token}}]
  end
end
