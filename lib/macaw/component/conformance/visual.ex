if Code.ensure_loaded?(LazyHTML) do
  defmodule Macaw.Component.Conformance.Visual do
    @moduledoc false
    # The visual check set (spec/04 §4), for components that draw data: the drawing is a
    # named, described image with a table beside it, one tab stop, a drawn token that
    # follows the data, and SVG, never canvas, outside live mode.

    alias Macaw.Component.Conformance.{Html, Render}

    @checks [:image, :table, :tab_stop, :token, :svg]

    @doc false
    @spec checks() :: [atom(), ...]
    def checks, do: @checks

    @doc false
    @spec run(atom(), module(), keyword()) :: [{{String.t(), atom() | nil, atom() | nil}, term()}]
    def run(:image, module, opts) do
      for {where, tree} <- Render.each(module, opts, [:live]),
          all = Html.elements(tree),
          reason <- image_rule(all),
          do: {where, reason}
    end

    def run(:table, module, opts) do
      for {where, tree} <- Render.each(module, opts, [:live]),
          all = Html.elements(tree),
          reason <- table_rule(all),
          do: {where, reason}
    end

    def run(:tab_stop, module, opts) do
      for {where, tree} <- Render.each(module, opts, [:live]),
          stops = tree |> Html.elements() |> Enum.count(&Html.tabbable?/1),
          stops != 1,
          do: {where, {:tab_stops, stops}}
    end

    def run(:token, module, opts) do
      renders = Render.each(module, opts, [:live, :socketless])
      again = Map.new(Render.each(module, opts, [:live, :socketless]))
      tokens = Map.new(renders, fn {where, tree} -> {where, tokens(tree)} end)

      missing =
        for {where, tree} <- renders,
            image <- images(Html.elements(tree)),
            Html.attr(image, "data-mw-token") == nil,
            do: {where, {:no_token, Html.describe(image)}}

      unstable =
        for {where, _tree} <- renders,
            Map.fetch!(tokens, where) != tokens(Map.fetch!(again, where)),
            do: {where, :unstable_token}

      missing ++ unstable ++ followed(module, opts, tokens)
    end

    def run(:svg, module, opts) do
      for {where, tree} <- Render.each(module, opts, [:socketless, :neutral, :print]),
          all = Html.elements(tree),
          reason <- svg_rule(all),
          do: {where, reason}
    end

    defp images(all), do: Enum.filter(all, &(Html.attr(&1, "role") == "img"))

    defp image_rule(all) do
      case images(all) do
        [] ->
          [:no_image]

        images ->
          Enum.flat_map(images, fn image ->
            d = Html.describe(image)
            named = if Html.named?(image, all), do: [], else: [{:unnamed, d}]
            described = if described?(image, all), do: [], else: [{:undescribed, d}]
            named ++ described
          end)
      end
    end

    defp described?(image, all) do
      by_reference =
        case Html.attr(image, "aria-describedby") do
          nil ->
            false

          ids ->
            ids
            |> String.split()
            |> Enum.all?(fn id ->
              Enum.any?(all, &(Html.attr(&1, "id") == id and Html.text(&1) != ""))
            end)
        end

      desc =
        Enum.any?(image.children, fn node ->
          match?({"desc", _, _}, node) and Html.text([node]) != ""
        end)

      by_reference or desc
    end

    defp table_rule(all) do
      case Enum.filter(all, &(&1.tag == "table")) do
        [] ->
          [:no_table]

        tables ->
          Enum.flat_map(tables, fn table ->
            d = Html.describe(table)
            inside = Html.descendants(table)

            named? =
              Html.present?(Html.attr(table, "aria-label")) or
                Html.present?(Html.attr(table, "aria-labelledby")) or
                Enum.any?(inside, &(&1.tag == "caption" and Html.text(&1) != ""))

            headers = Enum.filter(inside, &(&1.tag == "th"))
            named = if named?, do: [], else: [{:unnamed_table, d}]
            any = if headers == [], do: [{:no_headers, d}], else: []

            scoped =
              for th <- headers,
                  not Html.present?(Html.attr(th, "scope")),
                  do: {:unscoped_header, Html.describe(th)}

            named ++ any ++ scoped
          end)
      end
    end

    defp tokens(tree),
      do: for(image <- images(Html.elements(tree)), do: Html.attr(image, "data-mw-token"))

    # Two fixtures with equal settings and different deliveries must carry different tokens.
    defp followed(module, opts, tokens) do
      fixtures = Keyword.fetch!(opts, :fixtures)

      pairs =
        for {a, i} <- Enum.with_index(fixtures),
            {b, j} <- Enum.with_index(fixtures),
            i < j,
            a.settings == b.settings,
            a.deliveries != b.deliveries,
            do: {a, b}

      {:ok, info} = Macaw.Component.info(module)

      case pairs do
        [] ->
          [{{hd(fixtures).name, nil, nil}, {:no_probe, :token}}]

        pairs ->
          for {a, b} <- pairs,
              kind <- info.kinds,
              mode <- [:live, :socketless],
              ta = Map.get(tokens, {a.name, kind, mode}),
              tb = Map.get(tokens, {b.name, kind, mode}),
              ta != [] and ta == tb,
              do: {{a.name, kind, mode}, {:same_token, b.name}}
      end
    end

    defp svg_rule(all) do
      svg = if Enum.any?(all, &(&1.tag == "svg")), do: [], else: [:no_svg]
      canvas = if Enum.any?(all, &(&1.tag == "canvas")), do: [:canvas], else: []
      svg ++ canvas
    end
  end
end
