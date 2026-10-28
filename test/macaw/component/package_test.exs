defmodule Macaw.Component.PackageTest do
  # The package side of the registry (spec/03).
  use ExUnit.Case, async: true

  alias Macaw.Component.Package
  alias Macaw.Component.Test.{Cards, Clash, ClashPackage, Fixed, OtherPackage}

  @tag verifies: "packages-components"
  test "a package's components are its members that use Macaw.Component, in order" do
    assert {:ok, [cards, fixed]} = Package.components(Macaw.Component.Test.Package)
    assert cards == Map.put(Cards.__component__(), :module, Cards)
    assert fixed.module == Fixed and fixed.name == "test.fixed" and fixed.kinds == [:content]
  end

  @tag verifies: "packages-faults"
  test "not a package, an unloadable member and two components of one name are faults at once" do
    assert Package.components(String) == {:error, [{[], :not_a_package}]}
    assert Package.components(NoSuchPackage) == {:error, [{[], :not_a_package}]}

    assert {:error, faults} = Package.components(ClashPackage)

    assert Enum.sort(faults) ==
             Enum.sort([
               {[], {:not_loaded, NoSuchMember}},
               {[], {:duplicate, "test.cards", [Cards, Clash]}}
             ])

    assert Package.check(Macaw.Component.Test.Package) == :ok
    assert Package.check(ClashPackage) == Package.components(ClashPackage)
  end

  @tag verifies: "packages-hooks"
  test "hooks/1 collects the listed packages' hooks by name and refuses two of one name" do
    assert Package.hooks([Macaw.Component.Test.Package]) ==
             {:ok, %{"Cards" => {Macaw.Component.Test.Package, "priv/static/cards.js"}}}

    assert Package.hooks([]) == {:ok, %{}}

    assert Package.hooks([Macaw.Component.Test.Package, OtherPackage]) ==
             {:error, [{[], {:duplicate_hook, "Cards", ["test.cards", "test.cards"]}}]}

    assert {:error, [{[String], :not_a_package}]} = Package.hooks([String])
  end
end
