if Code.ensure_loaded?(LazyHTML) do
  defmodule Macaw.Component.Conformance.Checks do
    @moduledoc false
    # The twelve checks of spec/04 §2, each answering findings `{check, {where, what}}`:
    # `where` the fixture's name, and the kind and mode a render was made in, and `what`
    # the rule broken.

    alias Macaw.Component
    alias Macaw.Component.{Drawn, Mode}
    alias Macaw.Component.Conformance.{Html, Render}

    @composite_roles ~w(grid tree tablist listbox radiogroup toolbar)
    @color_attrs ~w(fill stroke color stop-color flood-color lighting-color)
    @not_literal ~w(none transparent inherit currentcolor)
    @cues ~w(glyph dash pattern label position)
    @states %{
      "aria-pressed" => ~w(true false mixed),
      "aria-expanded" => ~w(true false),
      "aria-current" => ~w(page step location date time true false),
      "aria-busy" => ~w(true false)
    }
    @references ~w(aria-labelledby aria-describedby aria-controls)
    @loads ~w(src poster action formaction)
    @named_tags ~w(button select textarea)
    @named_roles ~w(button link checkbox switch tab slider menuitem option radio)
    @budget_sizes [{320, 200}, {640, 400}, {1280, 800}]

    @doc false
    @spec run(atom(), module(), keyword()) :: [{atom(), term()}]
    def run(check, module, opts) do
      check |> what(module, opts) |> Enum.uniq() |> Enum.map(&{check, &1})
    end

    # :declarations — parameters, settings, declarations, purity, bindables, fixture events.
    defp what(:declarations, module, opts) do
      case Component.parameters(module) do
        {:error, faults} ->
          [{"parameters", {:parameters, faults}}]

        {:ok, parameters} ->
          Enum.flat_map(Keyword.fetch!(opts, :fixtures), &declarations(module, parameters, &1))
      end
    end

    defp what(:kinds, module, opts) do
      for {{_f, kind, _m} = where, tree} <- Render.each(module, opts, [:live]),
          all = Html.elements(tree),
          reason <- kind_rule(kind, all),
          do: {where, reason}
    end

    defp what(:modes, module, opts) do
      for {{_f, _k, mode} = where, tree} <- Render.each(module, opts, Mode.all()),
          all = Html.elements(tree),
          reason <- mode_rule(mode, tree, all),
          do: {where, reason}
    end

    defp what(:delivery, module, opts) do
      for {where, tree} <- Render.each(module, opts, [:live, :socketless]),
          element <- Html.elements(tree),
          reason <- delivery_rule(element),
          do: {where, reason}
    end

    defp what(:headings, module, opts) do
      at2 = Render.each(module, opts, [:live], heading_level: 2)
      at3 = Map.new(Render.each(module, opts, [:live], heading_level: 3))

      for {where, tree} <- at2,
          levels = levels(tree),
          levels != [],
          reason <- heading_rule(levels, levels(Map.fetch!(at3, where))),
          do: {where, reason}
    end

    defp what(:names, module, opts) do
      for {where, tree} <- Render.each(module, opts, [:live]),
          all = Html.elements(tree),
          element <- all,
          reason <- name_rule(element, all),
          do: {where, reason}
    end

    defp what(:keyboard, module, opts) do
      for {where, tree} <- Render.each(module, opts, [:live]),
          element <- Html.elements(tree),
          reason <- keyboard_rule(element),
          do: {where, reason}
    end

    defp what(:colors, module, opts) do
      for {where, tree} <- Render.each(module, opts, [:live, :socketless]),
          element <- Html.elements(tree),
          reason <- color_rule(element),
          do: {where, reason}
    end

    defp what(:ids, module, opts) do
      first = Render.each(module, opts, [:live])
      again = Map.new(Render.each(module, opts, [:live]))
      other = Map.new(Render.each(module, opts, [:live], instance: "kit-b"))

      for {where, tree} <- first,
          reason <-
            id_rule(ids(tree), ids(Map.fetch!(again, where)), ids(Map.fetch!(other, where))),
          do: {where, reason}
    end

    defp what(:drawn, module, opts) do
      {:ok, info} = Component.info(module)

      for fixture <- Keyword.fetch!(opts, :fixtures),
          {:ok, settings, declarations} <- [Render.setup(module, fixture)],
          state <- Drawn.all(),
          kind <- info.kinds,
          mode <- Mode.all() do
        context = Render.context(opts, mode: mode)
        assigns = Render.assigns(module, fixture, settings, declarations, context, state)
        tree = Render.render(module, kind, assigns)
        {{fixture.name, kind, mode}, tree, state}
      end
      |> Enum.reject(fn {_where, tree, _state} -> readable?(tree) end)
      |> Enum.map(fn {where, _tree, state} -> {where, {:blank, state}} end)
    end

    defp what(:budget, module, opts) do
      for fixture <- Keyword.fetch!(opts, :fixtures),
          {:ok, settings, declarations} <- [Render.setup(module, fixture)],
          slot <- Map.keys(declarations.slots),
          size <- @budget_sizes,
          {:error, {:bad_budget, answer}} <- [Component.budget(module, slot, settings, size)],
          do: {{fixture.name, nil, nil}, {:bad_budget, slot, size, answer}}
    end

    defp what(:contained, module, opts) do
      {:ok, info} = Component.info(module)

      for fixture <- Keyword.fetch!(opts, :fixtures),
          {:ok, settings, %{isolation: :contained} = declarations} <- [
            Render.setup(module, fixture)
          ],
          reason <- contained(module, info, fixture, settings, declarations, opts),
          do: {{fixture.name, nil, nil}, reason}
    end

    # -- declarations ---------------------------------------------------------------------

    defp declarations(module, parameters, fixture) do
      where = {fixture.name, nil, nil}

      with {:settings, {:ok, settings}} <-
             {:settings, Component.settings(module, fixture.settings)},
           {:declarations, {:ok, declarations}} <-
             {:declarations, Component.declarations(module, fixture.settings)} do
        impure =
          if Component.declarations(module, fixture.settings) == {:ok, declarations},
            do: [],
            else: [{where, :impure}]

        bindable =
          for {name, %{bindable: true} = parameter} <- parameters,
              other = other_value(parameter),
              other != :none,
              changed = Map.put(settings, name, other),
              unbuilt(module, changed) !=
                unbuilt(module, Map.put(settings, name, parameter.default)),
              do: {where, {:reads_bindable, name}}

        events =
          for event <- fixture.events,
              not Component.Declarations.emits?(declarations, event),
              do: {where, {:undeclared_event, event}}

        impure ++ bindable ++ events
      else
        {step, {:error, faults}} -> [{where, {step, faults}}]
      end
    end

    # The component's own answer, without declarations/2 fixing bindables at defaults.
    defp unbuilt(module, settings), do: module.declarations(settings)

    defp other_value(%{values: [_ | _] = values, default: default}),
      do: Enum.find(values, :none, &(&1 != default))

    defp other_value(%{type: :number, default: default}) when is_number(default), do: default + 1

    defp other_value(%{type: :text, default: default}) when is_binary(default),
      do: default <> "-x"

    defp other_value(%{type: :category, default: default}) when is_binary(default),
      do: default <> "-x"

    defp other_value(_parameter), do: :none

    # -- kinds ----------------------------------------------------------------------------

    defp kind_rule(:navigation, all) do
      navs = Enum.filter(all, &(&1.tag == "nav"))

      cond do
        navs == [] ->
          [:no_nav]

        true ->
          unnamed =
            for nav <- navs,
                not (Html.present?(Html.attr(nav, "aria-label")) or
                       Html.present?(Html.attr(nav, "aria-labelledby"))),
                do: {:unnamed_nav, Html.describe(nav)}

          hrefless =
            for nav <- navs,
                a <- Html.descendants(nav),
                a.tag == "a",
                not Map.has_key?(a.attrs, "href"),
                do: {:link_without_href, Html.describe(a)}

          unnamed ++ hrefless ++ menus(all)
      end
    end

    defp kind_rule(:control, all) do
      if Enum.any?(all, &(&1.tag in ~w(button input select textarea))),
        do: [],
        else: [:no_control]
    end

    defp kind_rule(:container, all) do
      if tabs?(all) or disclosure?(all) or dialog?(all), do: [], else: [:no_container_pattern]
    end

    defp kind_rule(:content, _all), do: []

    defp menus(all),
      do: for(e <- all, Html.attr(e, "role") == "menu", do: {:menu_role, Html.describe(e)})

    defp tabs?(all) do
      panels =
        for e <- all,
            Html.attr(e, "role") == "tabpanel",
            id = Html.attr(e, "id"),
            id != nil,
            do: id

      tabs = for e <- all, Html.attr(e, "role") == "tab", do: e

      Enum.any?(all, &(Html.attr(&1, "role") == "tablist")) and tabs != [] and
        Enum.all?(tabs, &(Html.attr(&1, "aria-controls") in panels))
    end

    defp disclosure?(all) do
      Enum.any?(all, fn e ->
        (e.tag == "details" and Enum.any?(Html.descendants(e), &(&1.tag == "summary"))) or
          (e.tag == "button" and Map.has_key?(e.attrs, "aria-expanded") and
             Html.present?(Html.attr(e, "aria-controls")))
      end)
    end

    defp dialog?(all) do
      Enum.any?(all, fn e ->
        e.tag == "dialog" or
          (Html.attr(e, "role") == "dialog" and Html.attr(e, "aria-modal") != nil and
             Html.named?(e, all))
      end)
    end

    # -- modes ----------------------------------------------------------------------------

    defp mode_rule(mode, tree, all) do
      empty = if all == [] and Html.text(tree) == "", do: [:empty], else: []

      canvas =
        if not Mode.allows?(mode, :canvas) and Enum.any?(all, &(&1.tag == "canvas")),
          do: [:canvas],
          else: []

      quiet =
        if Mode.allows?(mode, :hooks),
          do: [],
          else:
            Enum.flat_map(all, fn e ->
              Enum.reject(
                [
                  Map.has_key?(e.attrs, "phx-hook") && {:hook, Html.describe(e)},
                  e.tag == "script" && {:script, Html.describe(e)},
                  live_region?(e) && {:live_region, Html.describe(e)},
                  Map.has_key?(e.attrs, "data-mw-token") && {:token, Html.describe(e)},
                  csrf?(e) && {:csrf, Html.describe(e)}
                ],
                &(&1 == false)
              )
            end)

      empty ++ canvas ++ quiet
    end

    defp live_region?(e),
      do: Map.has_key?(e.attrs, "aria-live") or Html.attr(e, "role") in ~w(status alert log)

    defp csrf?(e),
      do:
        (e.tag == "meta" and Html.attr(e, "name") == "csrf-token") or
          (e.tag == "input" and Html.attr(e, "name") == "_csrf_token")

    # -- delivery -------------------------------------------------------------------------

    defp delivery_rule(e) do
      d = Html.describe(e)

      style = if Map.has_key?(e.attrs, "style"), do: [{:style_attribute, d}], else: []
      style_el = if e.tag == "style", do: [{:style_element, d}], else: []

      script =
        cond do
          e.tag != "script" -> []
          not Map.has_key?(e.attrs, "src") or Html.text(e) != "" -> [{:inline_script, d}]
          true -> []
        end

      handlers =
        for {name, _} <- e.attrs, String.starts_with?(name, "on"), do: {:event_attribute, d, name}

      urls =
        for {name, value} <- e.attrs,
            name in ["href", "xlink:href" | @loads],
            String.starts_with?(value |> String.trim() |> String.downcase(), "javascript:"),
            do: {:javascript_url, d, name}

      loads =
        for {name, value} <- e.attrs,
            load?(e, name),
            url <- urls_of(name, value),
            not Html.same_origin?(url),
            do: {:foreign_load, d, name}

      style ++ style_el ++ script ++ handlers ++ urls ++ loads
    end

    # A link's href is navigation, not a load; every other href, and every src, is a load.
    defp load?(e, name) when name in ["href", "xlink:href"], do: e.tag not in ["a", "area"]
    defp load?(_e, name), do: name in ["srcset" | @loads]

    defp urls_of("srcset", value),
      do:
        value
        |> String.split(",")
        |> Enum.map(&(&1 |> String.trim() |> String.split() |> List.first() || ""))

    defp urls_of(_name, value), do: [value]

    # -- headings -------------------------------------------------------------------------

    defp levels(tree) do
      for e <- Html.elements(tree), level = level(e), level != nil, do: level
    end

    defp level(%{tag: <<"h", d>>}) when d in ?1..?6, do: d - ?0

    defp level(e) do
      with "heading" <- Html.attr(e, "role"),
           {n, ""} <- Integer.parse(Html.attr(e, "aria-level") || "") do
        n
      else
        _ -> nil
      end
    end

    defp heading_rule(levels2, levels3) do
      top = if Enum.min(levels2) == 2, do: [], else: [{:top_heading, 2, Enum.min(levels2)}]

      shifted =
        if levels3 == Enum.map(levels2, &min(&1 + 1, 6)),
          do: [],
          else: [{:not_from_context, levels2, levels3}]

      top ++ shifted
    end

    # -- names ----------------------------------------------------------------------------

    defp name_rule(e, all) do
      d = Html.describe(e)

      image =
        cond do
          e.tag == "img" and not Map.has_key?(e.attrs, "alt") -> [{:unnamed, d}]
          Html.attr(e, "role") == "img" and not Html.named?(e, all) -> [{:unnamed, d}]
          true -> []
        end

      control =
        if needs_name?(e) and not Html.named?(e, all), do: [{:unnamed, d}], else: []

      states =
        for {attr, legal} <- @states,
            value = Html.attr(e, attr),
            value != nil,
            value not in legal,
            do: {:state, d, attr, value}

      ids = MapSet.new(for(x <- all, id = Html.attr(x, "id"), id != nil, do: id))

      references =
        for attr <- @references,
            value = Html.attr(e, attr),
            value != nil,
            id <- String.split(value),
            not MapSet.member?(ids, id),
            do: {:reference, d, attr, id}

      image ++ control ++ states ++ references
    end

    defp needs_name?(%{tag: "a"} = e), do: Map.has_key?(e.attrs, "href")
    defp needs_name?(%{tag: "input"} = e), do: Html.attr(e, "type") != "hidden"
    defp needs_name?(%{tag: tag}) when tag in @named_tags, do: true
    defp needs_name?(e), do: Html.attr(e, "role") in @named_roles

    # -- keyboard -------------------------------------------------------------------------

    defp keyboard_rule(e) do
      d = Html.describe(e)

      positive =
        case Integer.parse(Html.attr(e, "tabindex") || "") do
          {n, ""} when n > 0 -> [{:positive_tabindex, d}]
          _ -> []
        end

      composite =
        if Html.attr(e, "role") in @composite_roles or
             (Html.attr(e, "role") == "img" and Html.tabbable?(e)) do
          stops = Enum.count([e | Html.descendants(e)], &Html.tabbable?/1)
          if stops > 1, do: [{:tab_stops, d, stops}], else: []
        else
          []
        end

      menu = if Html.attr(e, "role") == "menu", do: [{:menu_role, d}], else: []
      positive ++ composite ++ menu
    end

    # -- colors ---------------------------------------------------------------------------

    defp color_rule(e) do
      d = Html.describe(e)
      cue = Html.attr(e, "data-mw-cue")
      bad_cue = if cue != nil and cue not in @cues, do: [{:bad_cue, d, cue}], else: []

      literals =
        for {name, value} <- e.attrs,
            name in @color_attrs,
            literal?(value),
            cue not in @cues,
            do: {:literal_color, d, name, value}

      bad_cue ++ literals
    end

    defp literal?(value) do
      v = value |> String.trim() |> String.downcase()
      not (v in @not_literal or String.starts_with?(v, "var(--mw-"))
    end

    # -- ids ------------------------------------------------------------------------------

    defp ids(tree), do: for(e <- Html.elements(tree), id = Html.attr(e, "id"), id != nil, do: id)

    defp id_rule(ids, again, other) do
      duplicates = for id <- Enum.uniq(ids -- Enum.uniq(ids)), do: {:duplicate_id, id}
      unstable = for id <- ids, id not in again, do: {:unstable, id}
      unprefixed = for id <- ids, not String.starts_with?(id, "kit-a-"), do: {:unprefixed, id}
      shared = for id <- ids, id in other, do: {:shared_across_instances, id}
      duplicates ++ unstable ++ unprefixed ++ shared
    end

    # -- drawn ----------------------------------------------------------------------------

    defp readable?(tree) do
      all = Html.elements(tree)

      Html.text(tree) != "" or
        Enum.any?(all, &(Html.attr(&1, "role") == "img" and Html.named?(&1, all)))
    end

    # -- contained ------------------------------------------------------------------------

    defp contained(module, info, fixture, settings, declarations, opts) do
      {:ok, parameters} = Component.parameters(module)
      context = Render.context(opts)

      run = fn ->
        value = Render.value(module, fixture, settings, context)

        for {name, %{bindable: true, default: default}} <- Enum.sort(parameters),
            reduce: value,
            do: (v -> Component.bound(module, v, name, default))
      end

      value = run.()

      for kind <- info.kinds do
        {:ok, assigns} =
          Macaw.Component.Assigns.new(
            context: context,
            settings: settings,
            declarations: declarations,
            drawn: :live,
            deliveries: %{},
            value: value
          )

        Render.render(module, kind, assigns)
      end

      if run.() == value, do: [], else: [:impure_value]
    end
  end
end
