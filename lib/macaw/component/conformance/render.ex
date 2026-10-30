if Code.ensure_loaded?(LazyHTML) do
  defmodule Macaw.Component.Conformance.Render do
    @moduledoc false
    # How the kit renders a component (spec/04 §1): for a fixture, a kind and a mode, a
    # context, validated settings, declarations and assigns, then the render read as a tree.

    alias Macaw.Component
    alias Macaw.Component.{Assigns, Context}
    alias Macaw.Component.Conformance.Html

    @fixture_keys [:name, :settings, :deliveries, :events, :bindings]

    @doc false
    # The fixtures with their defaults; an unknown key raises ArgumentError.
    @spec fixtures([map()]) :: [map()]
    def fixtures(fixtures) when is_list(fixtures) and fixtures != [] do
      fixtures
      |> Enum.with_index(1)
      |> Enum.map(fn {fixture, i} ->
        (is_map(fixture) and not is_struct(fixture)) ||
          raise ArgumentError, "a fixture is a map, got #{inspect(fixture)}"

        for key <- Map.keys(fixture), key not in @fixture_keys do
          raise ArgumentError,
                "#{inspect(key)} is not a fixture key; a fixture takes #{inspect(@fixture_keys)}"
        end

        Map.merge(
          %{name: "fixture #{i}", settings: %{}, deliveries: %{}, events: [], bindings: %{}},
          fixture
        )
      end)
    end

    def fixtures(other),
      do: raise(ArgumentError, "fixtures: is a non-empty list of maps, got #{inspect(other)}")

    @doc false
    # A fixture's validated settings and declarations, or the faults that stop rendering it.
    @spec setup(module(), map()) :: {:ok, map(), Component.Declarations.t()} | {:error, term()}
    def setup(module, fixture) do
      with {:ok, settings} <- Component.settings(module, fixture.settings),
           {:ok, declarations} <- Component.declarations(module, fixture.settings) do
        {:ok, settings, declarations}
      end
    end

    @doc false
    # A fixture's context, carrying its bindings; bindings the context refuses raise
    # ArgumentError, a fault in the fixture.
    @spec context(keyword(), map(), keyword()) :: Context.t()
    def context(opts, fixture, overrides \\ []) do
      attrs =
        Keyword.merge(
          [
            mode: :live,
            instance: "kit-a",
            size: Keyword.fetch!(opts, :size),
            heading_level: 2,
            theme: Keyword.fetch!(opts, :theme),
            now: Keyword.fetch!(opts, :now),
            bindings: fixture.bindings
          ],
          overrides
        )

      case Context.new(attrs) do
        {:ok, context} ->
          context

        {:error, faults} ->
          raise ArgumentError,
                "#{fixture.name} does not make a context: #{inspect(faults)}"
      end
    end

    @doc false
    # The assigns of a fixture rendered in a context, drawn as given or as the deliveries say.
    @spec assigns(module(), map(), map(), Component.Declarations.t(), Context.t(), atom() | nil) ::
            map()
    def assigns(module, fixture, settings, declarations, context, drawn \\ nil) do
      missing? =
        Enum.any?(Map.keys(declarations.slots), &(not Map.has_key?(fixture.deliveries, &1)))

      drawn = drawn || if(missing?, do: :loading, else: :live)

      {deliveries, value} =
        case declarations.isolation do
          :pure -> {fixture.deliveries, nil}
          :contained -> {%{}, value(module, fixture, settings, context)}
        end

      {:ok, assigns} =
        Assigns.new(
          context: context,
          settings: settings,
          declarations: declarations,
          drawn: drawn,
          deliveries: deliveries,
          value: value
        )

      assigns
    end

    @doc false
    # A contained component's value: init, then each delivered slot, then the size.
    @spec value(module(), map(), map(), Context.t()) :: term()
    def value(module, fixture, settings, context) do
      value = Component.init(module, settings, context)

      value =
        fixture.deliveries
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.reduce(value, fn {slot, delivery}, v ->
          Component.delivery(module, v, slot, delivery)
        end)

      Component.size(module, value, context.size)
    end

    @doc false
    # A render read as a tree.
    @spec render(module(), Component.kind(), map()) :: list()
    def render(module, kind, assigns), do: module |> markup(kind, assigns) |> Html.parse()

    @doc false
    # A render's markup, before it is read.
    @spec markup(module(), Component.kind(), map()) :: iodata()
    def markup(module, kind, assigns),
      do: module.render(kind, assigns) |> Phoenix.HTML.Safe.to_iodata()

    @doc false
    # Every fixture that sets up, each kind and the given modes, rendered: `{where, tree}`
    # with `where` the fixture's name, the kind and the mode; a fixture that can't be set
    # up is the declarations check's finding, and is skipped here.
    @spec each(module(), keyword(), [atom()], keyword()) :: [
            {{String.t(), atom(), atom()}, list()}
          ]
    def each(module, opts, modes, overrides \\ []) do
      {:ok, info} = Component.info(module)

      for fixture <- Keyword.fetch!(opts, :fixtures),
          {:ok, settings, declarations} <- [setup(module, fixture)],
          kind <- info.kinds,
          mode <- modes do
        context = context(opts, fixture, Keyword.put(overrides, :mode, mode))
        assigns = assigns(module, fixture, settings, declarations, context)
        {{fixture.name, kind, mode}, render(module, kind, assigns)}
      end
    end
  end
end
