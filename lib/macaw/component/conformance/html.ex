if Code.ensure_loaded?(LazyHTML) do
  defmodule Macaw.Component.Conformance.Html do
    @moduledoc false
    # A render read as a tree (LazyHTML parses it) and the questions the kit's checks ask
    # of it: elements in document order with their ancestors, attributes, text, names and
    # tab stops. Every check is plain Elixir over this tree.

    @typedoc "An element: its tag, attributes, children, document-order index and ancestors' tags."
    @type element :: %{
            tag: String.t(),
            attrs: %{String.t() => String.t()},
            children: list(),
            index: non_neg_integer(),
            ancestors: [String.t()]
          }

    @doc false
    @spec parse(iodata()) :: list()
    def parse(html),
      do: html |> IO.iodata_to_binary() |> LazyHTML.from_fragment() |> LazyHTML.to_tree()

    @doc false
    # Every element of a tree, in document order.
    @spec elements(list()) :: [element()]
    def elements(tree) do
      {acc, _n} = walk(tree, [], {[], 0})
      Enum.reverse(acc)
    end

    defp walk(nodes, ancestors, state) when is_list(nodes),
      do: Enum.reduce(nodes, state, &walk(&1, ancestors, &2))

    defp walk({tag, attrs, children}, ancestors, {acc, n}) when is_binary(tag) do
      element = %{
        tag: tag,
        attrs: Map.new(attrs),
        children: children,
        index: n,
        ancestors: ancestors
      }

      walk(children, [tag | ancestors], {[element | acc], n + 1})
    end

    defp walk(_text_or_comment, _ancestors, state), do: state

    @doc false
    # An element's descendants (itself excluded), in document order.
    @spec descendants(element()) :: [element()]
    def descendants(%{children: children}), do: elements(children)

    @doc false
    @spec attr(element(), String.t()) :: String.t() | nil
    def attr(%{attrs: attrs}, name), do: Map.get(attrs, name)

    @doc false
    # The text a person reads in a subtree, whitespace collapsed.
    @spec text(element() | list()) :: String.t()
    def text(%{children: children}), do: text(children)

    def text(nodes) when is_list(nodes) do
      nodes |> Enum.map_join(" ", &node_text/1) |> String.split() |> Enum.join(" ")
    end

    defp node_text(text) when is_binary(text), do: text
    defp node_text({tag, _attrs, children}) when is_binary(tag), do: text(children)
    defp node_text(_comment), do: ""

    @doc false
    # How a finding names an element: its tag and id, or its tag and document position.
    @spec describe(element()) :: String.t()
    def describe(%{tag: tag} = element) do
      case attr(element, "id") do
        nil -> "#{tag}(#{element.index})"
        id -> "#{tag}##{id}"
      end
    end

    @doc false
    # Whether an element has an accessible name, by `aria-label`, `aria-labelledby` naming
    # elements with text, `title`, an SVG `<title>`, its own text, an image's `alt`, a
    # control's `<label>`, or a button input's value.
    @spec named?(element(), [element()]) :: boolean()
    def named?(element, all) do
      present?(attr(element, "aria-label")) or labeled_by?(element, all) or
        present?(attr(element, "title")) or svg_title?(element) or
        own_text?(element) or alt_inside?(element) or label_for?(element, all) or
        (element.tag == "input" and attr(element, "type") in ["submit", "button", "reset"] and
           present?(attr(element, "value")))
    end

    defp labeled_by?(element, all) do
      case attr(element, "aria-labelledby") do
        nil ->
          false

        ids ->
          ids
          |> String.split()
          |> Enum.any?(fn id -> Enum.any?(all, &(attr(&1, "id") == id and text(&1) != "")) end)
      end
    end

    defp svg_title?(%{tag: "svg"} = element),
      do:
        Enum.any?(element.children, &match?({"title", _, [_ | _]}, &1)) and
          title_text(element) != ""

    defp svg_title?(_element), do: false

    defp title_text(element) do
      element.children
      |> Enum.filter(&match?({"title", _, _}, &1))
      |> Enum.map_join(" ", fn {_, _, c} -> text(c) end)
      |> String.trim()
    end

    defp own_text?(%{tag: tag} = element)
         when tag in ["button", "a", "summary", "label", "th", "td", "option"],
         do: text(element) != ""

    defp own_text?(element),
      do: attr(element, "role") in ["button", "link", "tab"] and text(element) != ""

    defp alt_inside?(%{tag: tag} = element) when tag in ["button", "a"],
      do: Enum.any?(descendants(element), &(&1.tag == "img" and present?(attr(&1, "alt"))))

    defp alt_inside?(_element), do: false

    defp label_for?(%{tag: tag} = element, all) when tag in ["input", "select", "textarea"] do
      id = attr(element, "id")

      (id != nil and
         Enum.any?(all, &(&1.tag == "label" and attr(&1, "for") == id and text(&1) != ""))) or
        "label" in element.ancestors
    end

    defp label_for?(_element, _all), do: false

    @doc false
    @spec present?(String.t() | nil) :: boolean()
    def present?(value), do: is_binary(value) and String.trim(value) != ""

    @doc false
    # Whether an element is a tab stop.
    @spec tabbable?(element()) :: boolean()
    def tabbable?(element) do
      tabindex = attr(element, "tabindex")

      cond do
        Map.has_key?(element.attrs, "disabled") -> false
        tabindex != nil -> match?({n, ""} when n >= 0, Integer.parse(tabindex))
        element.tag == "a" -> Map.has_key?(element.attrs, "href")
        element.tag == "input" -> attr(element, "type") != "hidden"
        element.tag in ["button", "select", "textarea", "summary"] -> true
        true -> false
      end
    end

    @doc false
    # Whether a URL loads from this origin: no scheme and no authority, or a data: URL.
    @spec same_origin?(String.t()) :: boolean()
    def same_origin?(url) do
      url = String.trim(url)
      String.starts_with?(url, "data:") or Macaw.Component.Stylesheet.same_origin?(url)
    end
  end
end
