if Code.ensure_loaded?(LazyHTML) do
  defmodule Macaw.Component.Conformance.Render do
    @moduledoc false
    # How the kit renders a component (spec/04 §1): for a fixture, a kind and a mode, a
    # context, validated settings, declarations and assigns, then the render read as a tree.

    alias Macaw.Component
    alias Macaw.Component.{Assigns, Context}
    alias Macaw.Component.Conformance.Html
    alias Macaw.Data.Schema

    @fixture_keys [:name, :settings, :deliveries, :events, :bindings, :schemas]

    @doc false
    # The fixtures with their defaults, and every fault by path under [:fixtures]: a
    # fixture that is no map, a key no fixture takes.
    @spec fixtures(term()) :: {[map()], [Macaw.Layers.Fault.t()]}
    def fixtures(fixtures) when is_list(fixtures) and fixtures != [] do
      fixtures
      |> Enum.with_index()
      |> Enum.map_reduce([], fn {fixture, i}, faults ->
        if is_map(fixture) and not is_struct(fixture) do
          unknown =
            for key <- Map.keys(fixture),
                key not in @fixture_keys,
                do: {[:fixtures, i, key], :unknown_key}

          defaults = %{
            name: "fixture #{i + 1}",
            settings: %{},
            deliveries: %{},
            events: [],
            bindings: %{},
            schemas: %{}
          }

          {schemas, schema_faults} = schemas(Map.get(fixture, :schemas, %{}), i)
          {%{Map.merge(defaults, fixture) | schemas: schemas}, faults ++ unknown ++ schema_faults}
        else
          {nil, faults ++ [{[:fixtures, i], {:type, :map}}]}
        end
      end)
    end

    def fixtures(_other), do: {[], [{[:fixtures], {:type, {:list, :map}}}]}

    # A fixture's schemas by slot, each a %Schema{} or the attrs Schema.new/1 builds one
    # from; a schema that doesn't build is its faults under the slot.
    defp schemas(schemas, i) when is_map(schemas) and not is_struct(schemas) do
      Enum.reduce(schemas, {%{}, []}, fn
        {slot, %Schema{} = schema}, {ok, faults} ->
          {Map.put(ok, slot, schema), faults}

        {slot, attrs}, {ok, faults} ->
          case Schema.new(attrs) do
            {:ok, schema} ->
              {Map.put(ok, slot, schema), faults}

            {:error, errors} ->
              {ok,
               faults ++
                 for({path, why} <- errors, do: {[:fixtures, i, :schemas, slot | path], why})}
          end
      end)
    end

    defp schemas(_schemas, i), do: {%{}, [{[:fixtures, i, :schemas], {:type, :map}}]}

    @doc false
    # The faults of every fixture's context, under its index: bindings the context refuses,
    # judged before anything renders, so `context/3` never meets one.
    @spec context_faults(keyword()) :: [Macaw.Layers.Fault.t()]
    def context_faults(opts) do
      for {fixture, i} <- Enum.with_index(Keyword.fetch!(opts, :fixtures)),
          {:error, faults} <- [Context.new(attrs(opts, fixture, []))],
          {path, reason} <- faults,
          do: {[:fixtures, i | path], reason}
    end

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
    # A fixture's context, carrying its bindings. The options judged them first
    # (`context_faults/1`), and a mode is any of the four, so the context always builds.
    @spec context(keyword(), map(), keyword()) :: Context.t()
    def context(opts, fixture, overrides \\ []) do
      {:ok, context} = Context.new(attrs(opts, fixture, overrides))
      context
    end

    defp attrs(opts, fixture, overrides) do
      Keyword.merge(
        [
          mode: :live,
          instance: "kit-a",
          size: Keyword.fetch!(opts, :size),
          heading_level: 2,
          theme: Keyword.fetch!(opts, :theme),
          now: Keyword.fetch!(opts, :now),
          bindings: fixture.bindings,
          schemas: fixture.schemas
        ],
        overrides
      )
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
