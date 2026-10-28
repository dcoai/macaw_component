if Code.ensure_loaded?(LazyHTML) do
  defmodule Macaw.Component.Conformance do
    @moduledoc """
    The component conformance kit (spec/04): the contract and the rendering rules as
    checks, so a component author proves conformance by running it.

        defmodule MyApp.CardsConformanceTest do
          use ExUnit.Case, async: true

          use Macaw.Component.Conformance,
            component: MyApp.Cards,
            fixtures: [%{settings: %{"columns" => 2}, deliveries: %{"items" => delivery}}]
        end

    **Two layers.** `check(check, component, opts)` answers one check's findings,
    `{check, {where, what}}` terms, `[]` for a component that passes; `check(component,
    opts)` runs every check, then each check set's; `format/1` words a finding. `use`
    writes one test per check. The kit references no ExUnit function itself, so it loads
    in production; it is compiled only when `lazy_html` is present.

    A check runs the component's callbacks in the caller's process: a raise is the test's
    failure, with its stacktrace.
    """

    alias Macaw.Component.Conformance.{Checks, Render}

    @checks [
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

    # Check sets by name, in order: `{set, checks}`.
    @sets []
    @options [:fixtures, :check_sets, :theme, :size, :now]

    @typedoc "A finding: the check, then where (the fixture, kind and mode) and what failed."
    @type finding :: {atom(), {{String.t(), atom() | nil, atom() | nil}, term()}}

    @doc "The twelve checks, in order."
    @spec checks() :: [atom(), ...]
    def checks, do: @checks

    @doc "The check sets, in order."
    @spec check_sets() :: [atom()]
    def check_sets, do: Enum.map(@sets, &elem(&1, 0))

    @doc "A check set's checks, in order."
    @spec checks(atom()) :: [atom(), ...]
    def checks(set) do
      case List.keyfind(@sets, set, 0) do
        {^set, checks} ->
          checks

        nil ->
          raise ArgumentError,
                "#{inspect(set)} is not a check set; the sets are #{inspect(check_sets())}"
      end
    end

    @doc "Every check, then each check set's in `check_sets:`, over a component."
    @spec check(module(), keyword()) :: [finding()]
    def check(component, opts) when is_atom(component) and is_list(opts) do
      opts = options!(opts)
      sets = Enum.flat_map(Keyword.fetch!(opts, :check_sets), &checks/1)
      Enum.flat_map(@checks ++ sets, &run(&1, component, opts))
    end

    @doc "One check's findings over a component."
    @spec check(atom(), module(), keyword()) :: [finding()]
    def check(check, component, opts) when is_atom(check) and is_list(opts) do
      (check in @checks or Enum.any?(@sets, fn {_set, checks} -> check in checks end)) ||
        raise ArgumentError,
              "#{inspect(check)} is not a check; the checks are #{inspect(@checks)}"

      run(check, component, options!(opts))
    end

    defp run(check, component, opts) do
      Macaw.Component.component?(component) ||
        raise ArgumentError, "#{inspect(component)} is not a component"

      Checks.run(check, component, opts)
    end

    defp options!(opts) do
      for {key, _} <- opts, key not in @options do
        raise ArgumentError, "unknown option #{inspect(key)}; the kit takes #{inspect(@options)}"
      end

      sets = Keyword.get(opts, :check_sets, [])
      Enum.each(sets, &checks/1)

      [
        fixtures: Render.fixtures(Keyword.get(opts, :fixtures, [%{}])),
        check_sets: sets,
        theme: Keyword.get_lazy(opts, :theme, &Macaw.Layers.Theme.default/0),
        size: Keyword.get(opts, :size, {640, 400}),
        now: Keyword.get_lazy(opts, :now, fn -> DateTime.utc_now() end)
      ]
    end

    @doc "A finding as a line a person reads."
    @spec format(finding()) :: String.t()
    def format({check, {{fixture, kind, mode}, what}}) do
      where =
        [fixture, kind && inspect(kind), mode && to_string(mode)]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(", ")

      "#{check} (#{where}): #{words(what)}"
    end

    defp words(:no_nav), do: "a navigation render has no <nav>"
    defp words({:unnamed_nav, el}), do: "#{el} has no aria-label or aria-labelledby"
    defp words({:link_without_href, el}), do: "#{el} is a link without href"

    defp words({:menu_role, el}),
      do: "#{el} has role=menu; navigation is a disclosure, never a menu"

    defp words(:no_control), do: "a control render has no real form control"

    defp words(:no_container_pattern),
      do: "a container render follows no tab, disclosure or dialog pattern"

    defp words(:empty), do: "renders nothing"
    defp words(:canvas), do: "draws a <canvas> outside live mode"
    defp words({:style_attribute, el}), do: "#{el} has a style attribute"
    defp words({:inline_script, el}), do: "#{el} is an inline script"
    defp words({:foreign_load, el, attr}), do: "#{el} loads #{attr} from another origin"
    defp words({:unnamed, el}), do: "#{el} has no accessible name"

    defp words({:unstable, id}),
      do: "the id #{inspect(id)} changes between two renders of one assigns"

    defp words({:blank, state}), do: "the #{state} drawn state renders blank"

    defp words({:bad_budget, slot, size, answer}),
      do: "budget for #{inspect(slot)} at #{inspect(size)} answered #{inspect(answer)}"

    defp words(other), do: inspect(other)

    @doc """
    Writes one test per check, then per check of each set in `check_sets:`, in a
    `describe` block, each failing with its findings. Takes `component:` (required) and the
    options of `check/2`.
    """
    defmacro __using__(opts) do
      {component, opts} = Keyword.pop(opts, :component)
      component || raise ArgumentError, "use Macaw.Component.Conformance needs component:"

      for {key, _} <- opts, key not in @options do
        raise ArgumentError,
              "unknown option #{inspect(key)}; the kit takes #{inspect([:component | @options])}"
      end

      quote bind_quoted: [component: component, opts: opts, checks: @checks] do
        sets = Keyword.get(opts, :check_sets, [])
        all = checks ++ Enum.flat_map(sets, &Macaw.Component.Conformance.checks/1)

        @macaw_component component
        @macaw_opts opts

        describe "#{inspect(component)} conforms" do
          for check <- all do
            @macaw_check check
            test "#{check}" do
              findings =
                Macaw.Component.Conformance.check(@macaw_check, @macaw_component, @macaw_opts)

              if findings != [] do
                flunk(Enum.map_join(findings, "\n", &Macaw.Component.Conformance.format/1))
              end
            end
          end
        end
      end
    end
  end
end
