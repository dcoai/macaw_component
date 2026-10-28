defmodule Macaw.Component do
  @moduledoc """
  The component contract (spec/01): the behavior every Macaw component implements, and
  the dispatch functions a host reaches a component through.

      defmodule MyApp.Cards do
        use Macaw.Component, name: "my_app.cards", kinds: [:content]

        @impl true
        def declarations(_settings), do: {:ok, reading: :scan}

        @impl true
        def render(:content, _assigns), do: {:safe, ~s(<ul class="cards"></ul>)}
      end

  **Static declarations** are `use`'s options (`name:`, `kinds:`, `hooks:`, `assets:`)
  and `parameters/0`; **configured declarations** are `declarations/1`'s answer, built by
  `Macaw.Component.Declarations.new/2`. The dispatch functions answer values: a
  component's bad answer is an error, never a raise. A component's own raise in `render/2`
  or a transition is its host's process's to take (spec/02 §6).

  The contract is unstable until two implementers pass its kit (spec/00 §3).
  """

  alias Macaw.Component.Declarations
  alias Macaw.Data.Parameter

  @kinds [:navigation, :content, :control, :container]

  @observations [
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

  @transitions [init: 2, delivery: 3, size: 2, bound: 3]

  @typedoc "A kind a component renders as (spec/01 §2)."
  @type kind :: :navigation | :content | :control | :container

  @typedoc "A fault: the path to the value, and why."
  @type fault :: {list(), term()}

  @typedoc "A contained component's value (spec/02 §7)."
  @type value :: term()

  @callback parameters() :: %{String.t() => Parameter.t()}
  @callback declarations(settings :: %{String.t() => term()}) ::
              {:ok, keyword() | map()} | {:error, [fault()]}
  @callback render(kind(), assigns :: map()) :: Phoenix.HTML.Safe.t()
  @callback budget(slot :: String.t(), settings :: map(), size :: {number(), number()}) ::
              pos_integer() | nil
  @callback init(settings :: map(), Macaw.Component.Context.t()) :: value()
  @callback delivery(value(), slot :: String.t(), Macaw.Data.Delivery.t()) :: value()
  @callback size(value(), {number(), number()}) :: value()
  @callback bound(value(), name :: String.t(), new :: term()) :: value()

  @optional_callbacks budget: 3, init: 2, delivery: 3, size: 2, bound: 3

  defmacro __using__(opts) do
    info = Macaw.Component.Compile.options!(opts, __CALLER__)

    quote do
      @behaviour Macaw.Component
      @before_compile Macaw.Component.Compile
      @__macaw_kinds__ unquote(info.kinds)

      @doc false
      def __component__, do: unquote(Macro.escape(info))

      @impl Macaw.Component
      def parameters, do: %{}

      @impl Macaw.Component
      def declarations(_settings), do: {:ok, []}

      defoverridable parameters: 0, declarations: 1
    end
  end

  @doc "The kinds a component may render as, in order."
  @spec kinds() :: [kind(), ...]
  def kinds, do: @kinds

  @doc "The closed observation vocabulary, in order (spec/01 §1.6)."
  @spec observations() :: [atom(), ...]
  def observations, do: @observations

  @doc "A contained component's four transitions, as `{name, arity}`."
  @spec transitions() :: keyword(non_neg_integer())
  def transitions, do: @transitions

  @doc "Whether a module is loaded and uses `Macaw.Component`."
  @spec component?(module()) :: boolean()
  def component?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__component__, 0)
  end

  @doc """
  A component's static declarations, `%{name, kinds, hooks, assets}`, or `:error` for a
  module that is not a component.
  """
  @spec info(module()) :: {:ok, map()} | :error
  def info(module) when is_atom(module) do
    if component?(module), do: {:ok, module.__component__()}, else: :error
  end

  @doc """
  A component's parameters, each checked by `Macaw.Data.Parameter.check/1`, named by a
  non-empty string, and, when bindable, with a default (spec/01 §1.1). Every fault at once,
  its path from the parameter's name.
  """
  @spec parameters(module()) :: {:ok, map()} | {:error, [fault(), ...]}
  def parameters(module) do
    case module.parameters() do
      parameters when is_map(parameters) ->
        parameters |> Enum.flat_map(&parameter_faults/1) |> answer(parameters)

      other ->
        {:error, [{[], {:bad_parameters, other}}]}
    end
  end

  defp parameter_faults({name, parameter}) do
    named = if is_binary(name) and name != "", do: [], else: [{[name], :bad_name}]

    checked =
      case Parameter.check(parameter) do
        :ok -> []
        {:error, faults} -> for {path, reason} <- faults, do: {[name | path], reason}
      end

    bindable =
      if is_map(parameter) and Map.get(parameter, :bindable) == true and
           not Map.has_key?(parameter, :default),
         do: [{[name], :bindable_without_default}],
         else: []

    named ++ checked ++ bindable
  end

  @doc """
  Given settings checked against the component's parameters, defaults filled in
  (`Macaw.Data.Parameter.validate/2`).
  """
  @spec settings(module(), map()) :: {:ok, map()} | {:error, [fault(), ...]}
  def settings(module, given) when is_map(given) do
    with {:ok, parameters} <- parameters(module) do
      Parameter.validate(parameters, given)
    end
  end

  @doc """
  The component's configured declarations for given settings: the settings validated, then
  `declarations/1` called with every bindable parameter at its default (spec/01 §1.1), and
  its answer built by `Macaw.Component.Declarations.new/2`.
  """
  @spec declarations(module(), map()) :: {:ok, Declarations.t()} | {:error, [fault(), ...]}
  def declarations(module, given) when is_map(given) do
    with {:ok, parameters} <- parameters(module),
         {:ok, settings} <- Parameter.validate(parameters, given) do
      fixed =
        for {name, %{bindable: true, default: default}} <- parameters,
            into: settings,
            do: {name, default}

      case module.declarations(fixed) do
        {:ok, answer} when is_list(answer) or is_map(answer) -> Declarations.new(answer, module)
        {:error, [_ | _] = faults} -> {:error, faults}
        other -> {:error, [{[], {:bad_declarations, other}}]}
      end
    end
  end

  @doc """
  A slot's row budget at a size: `{:ok, nil}` for a component without `budget/3`, else
  `{:ok, rows}` for a positive integer or `nil`, and `{:error, {:bad_budget, answer}}`
  otherwise (spec/01 §1.4).
  """
  @spec budget(module(), String.t(), map(), {number(), number()}) ::
          {:ok, pos_integer() | nil} | {:error, {:bad_budget, term()}}
  def budget(module, slot, settings, {_w, _h} = size) when is_binary(slot) do
    Code.ensure_loaded(module)

    if function_exported?(module, :budget, 3) do
      case module.budget(slot, settings, size) do
        rows when (is_integer(rows) and rows > 0) or is_nil(rows) -> {:ok, rows}
        other -> {:error, {:bad_budget, other}}
      end
    else
      {:ok, nil}
    end
  end

  @doc "Whether a module exports every contained transition."
  @spec contained?(module()) :: boolean()
  def contained?(module) do
    Code.ensure_loaded(module)
    Enum.all?(@transitions, fn {name, arity} -> function_exported?(module, name, arity) end)
  end

  @doc "A contained component's `init/2` (spec/02 §7)."
  @spec init(module(), map(), Macaw.Component.Context.t()) :: value()
  def init(module, settings, %Macaw.Component.Context{} = context),
    do: contained!(module).init(settings, context)

  @doc "A contained component's `delivery/3` (spec/02 §7)."
  @spec delivery(module(), value(), String.t(), Macaw.Data.Delivery.t()) :: value()
  def delivery(module, value, slot, delivery),
    do: contained!(module).delivery(value, slot, delivery)

  @doc "A contained component's `size/2` (spec/02 §7)."
  @spec size(module(), value(), {number(), number()}) :: value()
  def size(module, value, size), do: contained!(module).size(value, size)

  @doc "A contained component's `bound/3` (spec/02 §7)."
  @spec bound(module(), value(), String.t(), term()) :: value()
  def bound(module, value, name, new), do: contained!(module).bound(value, name, new)

  defp contained!(module) do
    contained?(module) ||
      raise ArgumentError,
            "#{inspect(module)} is not a contained component: it lacks the transitions " <>
              "init/2, delivery/3, size/2 and bound/3 (spec/02 §7)"

    module
  end

  @doc "A fault as a line a person reads."
  @spec format_fault(fault()) :: String.t()
  def format_fault({[], reason}), do: words(reason)
  def format_fault({path, reason}), do: "#{Enum.map_join(path, ".", &step/1)}: #{words(reason)}"

  defp step(key) when is_binary(key), do: key
  defp step(key) when is_atom(key), do: Atom.to_string(key)
  defp step(key), do: inspect(key)

  defp words(:unknown_key), do: "is not a key here"
  defp words(:bad_name), do: "is not a non-empty string"
  defp words(:required), do: "is required"
  defp words(:bindable_without_default), do: "is bindable, so it needs a default"
  defp words({:duplicate, name}), do: "#{inspect(name)} is declared twice"
  defp words({:missing, list}) when is_list(list), do: "lacks #{inspect(list)}"
  defp words({:bad_declarations, other}), do: "declarations/1 answered #{inspect(other)}"
  defp words({:bad_parameters, other}), do: "parameters/0 answered #{inspect(other)}"
  defp words(reason), do: inspect(reason)

  @doc false
  # Every fault at once, ordered by path, or the value.
  @spec answer([fault()], term()) :: {:ok, term()} | {:error, [fault(), ...]}
  def answer([], value), do: {:ok, value}
  def answer(faults, _value), do: {:error, Enum.sort_by(faults, &elem(&1, 0))}
end
