defmodule Macaw.Component.DeclarationsTest do
  # Configured declarations (spec/01 §1.2, §1.6–§1.9).
  use ExUnit.Case, async: true

  alias Macaw.Component
  alias Macaw.Component.{Announcement, Declarations, Proxy, Stylesheet}
  alias Macaw.Component.Test.{Scene, Uncontained}

  doctest Declarations
  doctest Announcement
  doctest Stylesheet
  doctest Proxy

  defp new(answer), do: Declarations.new(answer, nil)

  @tag verifies: "declares-defaults"
  test "an empty answer builds every default; keyword lists and maps agree" do
    assert Declarations.keys() == [
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

    assert {:ok, d} = new([])

    assert Map.from_struct(d) == %{
             slots: %{},
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
           }

    answer = [events: ["a"], reading: :read, words: 120, local: %{"hover" => :time}]
    assert new(answer) == new(Map.new(answer))
  end

  @tag verifies: "declares-faults"
  test "every bad key is a fault at its path, every one at once, ordered by path" do
    assert {:error, faults} =
             new(%{
               tint: 1,
               slots: %{"" => %{requires: %{}}},
               writes: %{"zoom" => :number},
               local: %{"hover" => :pixels},
               events: ["a", "", "a"],
               announces: :none,
               observes: ["view", :peek],
               shortcuts: [%{key: "g"}],
               reading: :skim,
               words: -1,
               stylesheets: [7],
               proxy_routes: [%{name: "t", url: "http://x", types: []}],
               isolation: :shared,
               access: ""
             })

    expected = [
      {[:access], :bad_name},
      {[:announces], {:not_a_list, :none}},
      {[:tint], :unknown_key},
      {[:events], {:duplicate, "a"}},
      {[:events, 1], :bad_name},
      {[:isolation], {:unknown_isolation, :shared}},
      {[:local, "hover"], {:not_a_domain_type, :pixels}},
      {[:observes, 1], {:unknown_observation, :peek}},
      {[:proxy_routes, 0, :url], :not_https},
      {[:proxy_routes, 0, :types], :bad_types},
      {[:reading], {:unknown_reading, :skim}},
      {[:shortcuts, 0, :action], :required},
      {[:shortcuts, 0, :description], :required},
      {[:slots, ""], :bad_name},
      {[:stylesheets, 0], :not_a_string},
      {[:words], :not_a_count},
      {[:writes, "zoom"], {:not_standard, "zoom"}}
    ]

    assert Enum.sort(faults) == Enum.sort(expected)
    assert faults == Enum.sort_by(faults, &elem(&1, 0))
    assert new([:not_a_pair]) == {:error, [{[], {:not_a_keyword_list, [:not_a_pair]}}]}
    assert new("x") == {:error, [{[], {:not_a_map, "x"}}]}
  end

  @tag verifies: "declares-faults"
  test "no atom is made from a name" do
    name = "never_an_atom_#{System.unique_integer([:positive])}"
    assert {:ok, _} = new(events: [name], slots: %{name => %{}}, local: %{name => :time})
    assert {:error, _} = new(observes: [name])
    assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
  end

  @tag verifies: "events-unique"
  test "event names are unique, emits?/2 answers declared names, and announcements need one" do
    assert {:error, [{[:events], {:duplicate, "brush"}}]} =
             new(events: ["brush", "pick", "brush"])

    {:ok, d} = new(events: ["brush", "pick"], announces: ["readout"])
    assert Declarations.emits?(d, "brush")
    refute Declarations.emits?(d, "select")

    assert {:ok, %{politeness: :assertive}} =
             Announcement.new(d, %{name: "readout", text: "3 of 9", politeness: :assertive})

    assert {:error, faults} =
             Announcement.new(d, name: "other", text: " ", politeness: :loud, x: 1)

    assert faults == [
             {[:name], {:undeclared, "other"}},
             {[:politeness], {:politeness, :loud}},
             {[:text], :empty},
             {[:x], :unknown_key}
           ]
  end

  @tag verifies: "events-observation-shortcuts"
  test "observes takes the vocabulary by atom or spelling; shortcuts need a key, action and description" do
    assert Component.observations() ==
             [
               :view,
               :dwell,
               :hover_item,
               :focus_item,
               :activate,
               :select,
               :brush,
               :copy,
               :scroll_into_view
             ]

    assert {:ok, %{observes: [:view, :brush]}} = new(observes: ["view", :brush, "view"])

    good = [
      %{key: "?", action: "help", description: "Show shortcuts"},
      %{key: "ArrowUp", action: "up", description: "Move up"}
    ]

    assert {:ok, %{shortcuts: ^good}} = new(shortcuts: good)

    assert {:error, faults} =
             new(
               shortcuts: [
                 %{key: "gg", action: "a", description: "b"},
                 %{key: "k", action: "a", description: "b", extra: 1},
                 %{key: "k", action: "c", description: "d"},
                 :help
               ]
             )

    assert {[:shortcuts, 0, :key], :required} in faults
    assert {[:shortcuts, 1, :extra], :unknown_key} in faults
    assert {[:shortcuts], {:duplicate_key, "k"}} in faults
    assert {[:shortcuts, 3], {:not_a_map, :help}} in faults
  end

  @tag verifies: "reading-load"
  test "reading is one of three, glance by default; words only with read" do
    assert {:ok, %{reading: :glance}} = new([])
    for r <- [:glance, :scan, :read], do: assert({:ok, %{reading: ^r}} = new(reading: r))
    assert {:ok, %{words: 300}} = new(reading: :read, words: 300)
    assert {:error, [{[:words], :words_without_read}]} = new(reading: :scan, words: 300)
    assert {:error, [{[:words], :not_a_count}]} = new(reading: :read, words: 1.5)
  end

  @tag verifies: "assets-configured"
  test "a stylesheet's path is its digest; another origin is refused; proxy routes are checked" do
    css = ".mw-fade{transition:opacity 200ms}"
    assert Stylesheet.path(css) == Stylesheet.path(css)
    assert Stylesheet.path(css) != Stylesheet.path(css <> " ")
    assert Stylesheet.path(css) =~ ~r"\A/assets/[0-9a-f]{64}\.css\z"

    assert {:ok, _} =
             new(
               stylesheets: [
                 css,
                 ~s|.a{background:url("/i.png")}|,
                 ".b{mask:url(data:image/svg+xml,x)}"
               ]
             )

    for bad <- [
          ~s|@import "https://cdn.example/x.css";|,
          ~s|@import url(//cdn.example/x.css);|,
          ~s|.a{background:url(https://cdn.example/i.png)}|
        ] do
      assert {:error, [{[:stylesheets, 0], :origin}]} = new(stylesheets: [bad])
    end

    route = %{name: "tiles", url: "https://tiles.example/{z}/{x}/{y}.png", types: ["image/png"]}
    assert {:ok, %{proxy_routes: [^route]}} = new(proxy_routes: [route])

    assert {:error, [{[:proxy_routes], {:duplicate, "tiles"}}]} =
             new(proxy_routes: [route, route])

    assert Proxy.placeholders(route) == ["z", "x", "y"]
    assert Proxy.path("geo.map", route, %{"z" => "1"}) == {:error, {:placeholders, ["x", "y"]}}

    assert {:ok, "/macaw/proxy/geo.map/tiles?" <> _} =
             Proxy.path("geo.map", route, %{"x" => "1", "y" => "2", "z" => "3"})
  end

  @tag verifies: "isolation-access"
  test "contained isolation needs the four transitions; access is a capability or nil" do
    assert {:ok, %{isolation: :contained}} = Component.declarations(Scene, %{})
    assert Component.contained?(Scene)
    refute Component.contained?(Uncontained)
    assert Component.transitions() == [init: 2, delivery: 3, size: 2, bound: 3]

    assert Component.declarations(Uncontained, %{}) ==
             {:error, [{[:isolation], {:missing, ["init/2", "delivery/3", "size/2", "bound/3"]}}]}

    assert {:ok, %{access: "metrics.read"}} = new(access: "metrics.read")
    assert {:error, [{[:access], :bad_name}]} = new(access: :admin)
  end
end
