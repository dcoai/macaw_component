defmodule Macaw.Component.Test.Kit do
  @moduledoc false
  # Shared markup for the kit's test components: the drawn notice for every state but live.
  alias Macaw.Component.Drawn

  def drawn_or(%{drawn: :live}, live), do: {:safe, live}
  def drawn_or(%{drawn: state, context: context}, _live), do: Drawn.render(state, context)
end

defmodule Macaw.Component.Test.Honest.Prose do
  @moduledoc false
  # Content with headings from the context, ids from the instance, a slot and a bindable
  # parameter it never reads in its declarations.
  use Macaw.Component, name: "test.honest.prose", kinds: [:content]
  alias Macaw.Component.{Context, Test.Kit}

  @impl true
  def parameters,
    do: %{
      "emphasis" => %{
        type: :category,
        values: ["none", "strong"],
        default: "none",
        bindable: true
      }
    }

  @impl true
  def declarations(_settings),
    do:
      {:ok,
       slots: %{"sections" => %{requires: %{"title" => %{type: :text}}}},
       reading: :read,
       words: 12,
       events: ["open"]}

  @impl true
  def budget("sections", _settings, {w, _h}), do: max(1, trunc(w / 100))

  @impl true
  def render(:content, assigns) do
    ctx = assigns.context
    h = Context.heading(ctx, 0)
    h2 = Context.heading(ctx, 1)

    Kit.drawn_or(
      assigns,
      ~s(<article id="#{Context.id(ctx, "body")}"><#{h}>Notes</#{h}><p>Some prose.</p>) <>
        ~s(<section id="#{Context.id(ctx, "s-1")}"><#{h2}>First</#{h2}><p>More.</p></section></article>)
    )
  end
end

defmodule Macaw.Component.Test.Honest.Menu do
  @moduledoc false
  use Macaw.Component, name: "test.honest.menu", kinds: [:navigation, :content]
  alias Macaw.Component.{Context, Test.Kit}

  @impl true
  def render(:navigation, assigns) do
    ctx = assigns.context

    Kit.drawn_or(
      assigns,
      ~s(<nav aria-label="Site"><ul><li><a href="/" aria-current="page">Home</a></li>) <>
        ~s(<li><button type="button" aria-expanded="false" aria-controls="#{Context.id(ctx, "more")}">More</button>) <>
        ~s(<ul id="#{Context.id(ctx, "more")}" hidden><li><a href="/about">About</a></li></ul></li></ul></nav>)
    )
  end

  def render(:content, assigns),
    do:
      Kit.drawn_or(
        assigns,
        ~s(<ul class="links"><li><a href="https://elsewhere.example/">Elsewhere</a></li></ul>)
      )
end

defmodule Macaw.Component.Test.Honest.Field do
  @moduledoc false
  use Macaw.Component, name: "test.honest.field", kinds: [:control]
  alias Macaw.Component.{Context, Test.Kit}

  @impl true
  def declarations(_settings), do: {:ok, events: ["submit"], observes: [:activate]}

  @impl true
  def render(:control, assigns) do
    id = Context.id(assigns.context, "name")

    Kit.drawn_or(
      assigns,
      ~s(<form action="/search"><label for="#{id}">Name</label><input id="#{id}" type="text" name="q">) <>
        ~s(<button type="submit" aria-pressed="false">Go</button></form>)
    )
  end
end

defmodule Macaw.Component.Test.Honest.Tabs do
  @moduledoc false
  use Macaw.Component, name: "test.honest.tabs", kinds: [:container]
  alias Macaw.Component.{Context, Test.Kit}

  @impl true
  def render(:container, assigns) do
    ctx = assigns.context
    tab = Context.id(ctx, "tab-1")
    panel = Context.id(ctx, "panel-1")

    Kit.drawn_or(
      assigns,
      ~s(<div role="tablist" aria-label="Views"><button role="tab" id="#{tab}" aria-controls="#{panel}" aria-selected="true">One</button>) <>
        ~s(<button role="tab" tabindex="-1" id="#{Context.id(ctx, "tab-2")}" aria-controls="#{panel}">Two</button></div>) <>
        ~s(<div role="tabpanel" id="#{panel}" aria-labelledby="#{tab}"><p>Pane</p></div>)
    )
  end
end

defmodule Macaw.Component.Test.Honest.Swatch do
  @moduledoc false
  # Data colors with a cue, drawing colors from roles.
  use Macaw.Component, name: "test.honest.swatch", kinds: [:content]
  alias Macaw.Component.Test.Kit

  @impl true
  def render(:content, assigns) do
    Kit.drawn_or(
      assigns,
      ~s(<svg role="img" aria-label="Legend" viewBox="0 0 20 10"><rect fill="#1f77b4" data-mw-cue="label" width="5" height="5"></rect>) <>
        ~s(<rect fill="var\(--mw-good\)" stroke="currentColor" width="5" height="5" x="10"></rect></svg><p>Blue: ours</p>)
    )
  end
end

defmodule Macaw.Component.Test.Honest.Scene do
  @moduledoc false
  use Macaw.Component, name: "test.honest.scene", kinds: [:content]
  alias Macaw.Component.Test.Kit

  @impl true
  def parameters, do: %{"zoom" => %{type: :number, default: 1, bindable: true}}

  @impl true
  def declarations(_settings), do: {:ok, isolation: :contained, writes: %{"camera" => :camera}}

  @impl true
  def init(settings, context), do: %{zoom: settings["zoom"], size: context.size, frames: 0}
  @impl true
  def delivery(value, _slot, _delivery), do: %{value | frames: value.frames + 1}
  @impl true
  def size(value, size), do: %{value | size: size}
  @impl true
  def bound(value, "zoom", zoom), do: %{value | zoom: zoom}

  @impl true
  def render(:content, assigns),
    do: Kit.drawn_or(assigns, "<p>Scene at zoom #{inspect(assigns.value.zoom)}</p>")
end

defmodule Macaw.Component.Test.Broken do
  @moduledoc false
  # Honest in every kind unless its "flaw" setting names a rule to break.
  use Macaw.Component, name: "test.broken", kinds: [:navigation, :content, :control, :container]
  alias Macaw.Component.{Context, Drawn}

  @flaws ~w(none impure reads_bindable no_nav unnamed_nav menu_role no_control no_container
            canvas hook_everywhere script_everywhere live_region token empty style_attribute
            style_element inline_script onclick javascript_url foreign_img foreign_srcset
            fixed_heading top_h3 img_no_alt unnamed_button bad_state dangling_reference
            unnamed_svg positive_tabindex composite_two_stops literal_fill bad_cue
            duplicate_id unstable_id unprefixed_id blank_drawn bad_budget)

  def flaws, do: @flaws

  @impl true
  def parameters do
    %{
      "flaw" => %{type: :category, values: @flaws, default: "none"},
      "mood" => %{type: :category, values: ["calm", "loud"], default: "calm", bindable: true}
    }
  end

  @impl true
  def declarations(%{"flaw" => "impure"}), do: {:ok, events: ["e#{System.unique_integer()}"]}
  def declarations(%{"flaw" => "reads_bindable", "mood" => mood}), do: {:ok, events: [mood]}
  def declarations(%{"flaw" => "bad_budget"}), do: {:ok, slots: %{"rows" => %{}}}
  def declarations(_settings), do: {:ok, []}

  @impl true
  def budget(_slot, %{"flaw" => "bad_budget"}, _size), do: 0
  def budget(_slot, _settings, _size), do: 10

  @impl true
  def render(kind, %{settings: %{"flaw" => flaw}, drawn: drawn, context: ctx} = assigns) do
    cond do
      flaw == "blank_drawn" and drawn != :live ->
        {:safe, ""}

      drawn != :live and
          flaw not in ~w(hook_everywhere script_everywhere live_region token canvas) ->
        Drawn.render(drawn, ctx)

      true ->
        {:safe, markup(kind, flaw, ctx, assigns)}
    end
  end

  defp markup(kind, flaw, ctx, _assigns) do
    case {kind, flaw} do
      {:navigation, "no_nav"} ->
        ~s(<div><a href="/">Home</a></div>)

      {:navigation, "unnamed_nav"} ->
        ~s(<nav><a href="/">Home</a></nav>)

      {:navigation, "menu_role"} ->
        ~s(<nav aria-label="Site"><ul role="menu"><li><a href="/">Home</a></li></ul></nav>)

      {:control, "no_control"} ->
        ~s(<p>Nothing to press</p>)

      {:container, "no_container"} ->
        ~s(<div><p>Pane</p></div>)

      {_kind, "empty"} ->
        ""

      {:content, "top_h3"} ->
        ~s(<#{Context.heading(ctx, 1)}>Title</#{Context.heading(ctx, 1)}><p>Text</p>)

      {kind, _} ->
        base(kind, ctx) <> extra(flaw, ctx)
    end
  end

  defp base(:navigation, _ctx), do: ~s(<nav aria-label="Site"><a href="/">Home</a></nav>)

  defp base(:control, ctx),
    do:
      ~s(<label for="#{Context.id(ctx, "q")}">Query</label><input id="#{Context.id(ctx, "q")}" type="text">)

  defp base(:container, _ctx), do: ~s(<details><summary>More</summary><p>Pane</p></details>)

  defp base(:content, ctx),
    do: ~s(<#{Context.heading(ctx, 0)}>Title</#{Context.heading(ctx, 0)}><p>Text</p>)

  defp extra("none", _ctx), do: ""

  defp extra(flaw, _ctx)
       when flaw in ~w(impure reads_bindable no_nav unnamed_nav menu_role no_control no_container bad_budget blank_drawn top_h3),
       do: ""

  defp extra("canvas", _ctx), do: "<canvas></canvas>"
  defp extra("hook_everywhere", _ctx), do: ~s(<div phx-hook="Chart"></div>)
  defp extra("script_everywhere", _ctx), do: ~s(<script src="/app.js"></script>)
  defp extra("live_region", _ctx), do: ~s(<div aria-live="polite"></div>)
  defp extra("token", _ctx), do: ~s(<div data-mw-token="t1"></div>)
  defp extra("style_attribute", _ctx), do: ~s(<p style="color: red">x</p>)
  defp extra("style_element", _ctx), do: "<style>p{}</style>"
  defp extra("inline_script", _ctx), do: "<script>alert(1)</script>"
  defp extra("onclick", _ctx), do: ~s|<p onclick="go()">x</p>|
  defp extra("javascript_url", _ctx), do: ~s|<a href="javascript:go()">x</a>|
  defp extra("foreign_img", _ctx), do: ~s(<img alt="x" src="https://cdn.example/x.png">)

  defp extra("foreign_srcset", _ctx),
    do: ~s(<img alt="x" src="/x.png" srcset="/x.png 1x, //cdn.example/x2.png 2x">)

  defp extra("fixed_heading", _ctx), do: "<h3>Fixed</h3>"
  defp extra("img_no_alt", _ctx), do: ~s(<img src="/x.png">)
  defp extra("unnamed_button", _ctx), do: ~s(<button type="button"></button>)
  defp extra("bad_state", _ctx), do: ~s(<button type="button" aria-pressed="yes">B</button>)

  defp extra("dangling_reference", _ctx),
    do: ~s(<button type="button" aria-controls="nowhere">B</button>)

  defp extra("unnamed_svg", _ctx), do: ~s(<svg role="img"></svg>)
  defp extra("positive_tabindex", _ctx), do: ~s(<p tabindex="2">x</p>)

  defp extra("composite_two_stops", _ctx),
    do: ~s(<div role="toolbar" aria-label="T"><button>A</button><button>B</button></div>)

  defp extra("literal_fill", _ctx),
    do: ~s(<svg role="img" aria-label="x"><rect fill="#ff0000"></rect></svg>)

  defp extra("bad_cue", _ctx),
    do: ~s(<svg role="img" aria-label="x"><rect fill="#ff0000" data-mw-cue="hue"></rect></svg>)

  defp extra("duplicate_id", ctx),
    do: ~s(<p id="#{Context.id(ctx, "d")}">a</p><p id="#{Context.id(ctx, "d")}">b</p>)

  defp extra("unstable_id", ctx),
    do: ~s(<p id="#{Context.id(ctx, "u#{System.unique_integer([:positive])}")}">a</p>)

  defp extra("unprefixed_id", _ctx), do: ~s(<p id="fixed">a</p>)
end

defmodule Macaw.Component.Test.Broken.Scene do
  @moduledoc false
  # A contained component whose value is impure: equal inputs, different values.
  use Macaw.Component, name: "test.broken.scene", kinds: [:content]

  @impl true
  def declarations(_settings), do: {:ok, isolation: :contained}

  @impl true
  def init(_settings, _context), do: %{seed: System.unique_integer()}
  @impl true
  def delivery(value, _slot, _delivery), do: value
  @impl true
  def size(value, _size), do: value
  @impl true
  def bound(value, _name, _new), do: value

  @impl true
  def render(:content, _assigns), do: {:safe, "<p>Scene</p>"}
end
