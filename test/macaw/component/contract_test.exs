defmodule Macaw.Component.ContractTest do
  # The behavior, its static declarations and the dispatch functions (spec/01 §1, §1.1,
  # §1.4, §1.8, §2).
  use ExUnit.Case, async: true

  alias Macaw.Component
  alias Macaw.Component.Test.{Answers, BadParameters, Cards, Fixed}

  doctest Macaw.Component

  defp compile(source), do: Code.compile_string(source, "nofile")

  defp component(opts, body \\ ~s|def render(_kind, _assigns), do: {:safe, ""}|) do
    mod = "Macaw.Component.Test.Gen#{System.unique_integer([:positive])}"
    compile("defmodule #{mod} do\n use Macaw.Component, #{opts}\n #{body}\nend")
  end

  @tag verifies: "behavior-use"
  test "use defines __component__/0 from its options and the optional callbacks default" do
    assert Cards.__component__() == %{
             name: "test.cards",
             kinds: [:navigation, :content],
             hooks: %{"Cards" => "priv/static/cards.js"},
             assets: ["priv/static/cards.css"]
           }

    assert Fixed.__component__() == %{
             name: "test.fixed",
             kinds: [:content],
             hooks: %{},
             assets: []
           }

    assert Fixed.parameters() == %{}
    assert Fixed.declarations(%{}) == {:ok, []}
    refute function_exported?(Fixed, :budget, 3)
    refute function_exported?(Fixed, :init, 2)
  end

  @tag verifies: "behavior-use"
  test "use refuses a bad option at compile time, naming it" do
    for {opts, message} <- [
          {~s|kinds: [:content]|, ~r/needs name:/},
          {~s|name: "a"|, ~r/needs kinds:/},
          {~s|name: "a", kinds: [:content], tint: 1|, ~r/unknown option :tint/},
          {~s|name: "My.Cards", kinds: [:content]|, ~r/lower-case words joined by dots/},
          {~s|name: "a.", kinds: [:content]|, ~r/lower-case words joined by dots/},
          {~s|name: "a", kinds: []|, ~r/non-empty list/},
          {~s|name: "a", kinds: [:widget]|, ~r/:widget is not a kind/},
          {~s|name: "a", kinds: [:content, :content]|, ~r/lists a kind twice/}
        ] do
      assert_raise ArgumentError, message, fn -> component(opts) end
    end

    assert [{_mod, _}] = component(~s|name: "pkg.sub.cards_2", kinds: [:content]|)
  end

  @tag verifies: "kinds-clauses"
  test "every declared kind needs a render clause, and a clause for an undeclared kind fails" do
    assert Component.kinds() == [:navigation, :content, :control, :container]

    assert_raise CompileError, ~r/declares the kind :control but render\/2 has no clause/, fn ->
      component(~s|name: "a", kinds: [:content, :control]|, ~s|def render(:content, _a), do: ""|)
    end

    assert_raise CompileError, ~r/clause for :control, which .* doesn't declare/, fn ->
      component(
        ~s|name: "a", kinds: [:content]|,
        ~s|def render(:content, _a), do: ""\n def render(:control, _a), do: ""|
      )
    end

    assert_raise CompileError, ~r/defines no render\/2/, fn ->
      component(~s|name: "a", kinds: [:content]|, "")
    end

    # A catch-all clause covers every kind.
    assert [{_mod, _}] =
             component(~s|name: "a", kinds: [:content, :control]|, ~s|def render(_k, _a), do: ""|)
  end

  @tag verifies: "assets-static"
  test "hooks and assets are checked at compile time" do
    for {opts, message} <- [
          {~s|hooks: %{"cards" => "priv/static/c.js"}|, ~r/capitalized word/},
          {~s|hooks: %{"Cards" => "/priv/static/c.js"}|, ~r/relative path/},
          {~s|hooks: %{"Cards" => "priv/../c.js"}|, ~r/without \.\./},
          {~s|hooks: %{"Cards" => "priv/static/c.ts"}|, ~r/\.js/},
          {~s|hooks: ["Cards"]|, ~r/hooks: is a map/},
          {~s|assets: ["priv/static/c.exe"]|, ~r/\.css, \.svg/},
          {~s|assets: "priv/static/c.css"|, ~r/assets: is a list/}
        ] do
      assert_raise ArgumentError, message, fn ->
        component(~s|name: "a", kinds: [:content], | <> opts)
      end
    end

    assert [{_m, _}] =
             component(
               ~s|name: "a", kinds: [:content], hooks: %{"Map2" => "priv/static/js/map.js"}, | <>
                 ~s|assets: ["priv/static/a.css", "priv/fonts/a.woff2"]|
             )
  end

  @tag verifies: "behavior-dispatch"
  test "component?/1 and info/1 tell a component from another module" do
    assert Component.component?(Cards)
    refute Component.component?(String)
    refute Component.component?(NoSuchModule)
    assert {:ok, %{name: "test.cards"}} = Component.info(Cards)
    assert Component.info(String) == :error
  end

  @tag verifies: "behavior-dispatch"
  test "parameters/1 checks every parameter by name; settings/2 validates and fills defaults" do
    assert {:ok, %{"columns" => _}} = Component.parameters(Cards)

    assert {:error, faults} = Component.parameters(BadParameters)
    assert {[""], :bad_name} in faults
    assert {["open"], :bindable_without_default} in faults
    assert Enum.any?(faults, &match?({["kind", :type], _}, &1))
    assert faults == Enum.sort_by(faults, &elem(&1, 0))

    assert Component.settings(Cards, %{"columns" => 2}) ==
             {:ok, %{"columns" => 2, "label" => "Cards", "bins" => 10}}

    assert {:error, [{["columns"], {:enum, _}}, {["zoom"], :unknown_param}]} =
             Component.settings(Cards, %{"columns" => 9, "zoom" => 1})
  end

  @tag verifies: "budget-answers"
  test "budget/4 reaches budget/3, answers nil without it, and refuses a bad answer" do
    settings = %{"columns" => 2, "label" => "x", "bins" => 10}
    assert Component.budget(Cards, "items", settings, {400, 300}) == {:ok, 20}
    assert Component.budget(Cards, "other", settings, {400, 300}) == {:ok, nil}
    assert Component.budget(Fixed, "items", %{}, {400, 300}) == {:ok, nil}

    for bad <- [0, -1, 2.5, "10", :all] do
      assert Component.budget(Answers, "s", %{"answer" => bad}, {1, 1}) ==
               {:error, {:bad_budget, bad}}
    end
  end

  @tag verifies: "behavior-declarations"
  test "declarations/2 validates settings first, builds the answer, and refuses a bad shape" do
    assert {:ok, %Component.Declarations{events: ["open"], reading: :scan}} =
             Component.declarations(Cards, %{})

    assert {:error, [{["columns"], {:enum, _}}]} =
             Component.declarations(Cards, %{"columns" => 7})

    for bad <- [:ok, {:ok, "x"}, nil, {:error, []}] do
      assert Component.declarations(Answers, %{"answer" => bad}) ==
               {:error, [{[], {:bad_declarations, bad}}]}
    end

    assert Component.declarations(Answers, %{"answer" => {:error, [{[:x], :mine}]}}) ==
             {:error, [{[:x], :mine}]}

    assert {:error, [{[:reading], _}]} =
             Component.declarations(Answers, %{"answer" => {:ok, [reading: :skim]}})
  end

  @tag verifies: "behavior-declarations"
  test "faults format as lines a person reads" do
    assert Component.format_fault({[:slots, "items", :requires], :unknown_key}) ==
             "slots.items.requires: is not a key here"

    assert Component.format_fault({[], {:bad_declarations, :ok}}) == "declarations/1 answered :ok"

    assert Component.format_fault({[:events], {:duplicate, "open"}}) ==
             ~s|events: "open" is declared twice|

    assert is_binary(Component.format_fault({[:x, 1], {:anything, :else}}))
  end

  @tag verifies: "parameters-static"
  test "declarations/1 sees every bindable parameter at its default whatever the settings give" do
    # Cards answers access: "leaked" if it ever sees bins other than its default.
    assert {:ok, %{access: nil}} = Component.declarations(Cards, %{"bins" => 99})
    assert {:ok, %{access: nil}} = Component.declarations(Cards, %{})
  end
end
