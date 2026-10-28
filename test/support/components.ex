defmodule Macaw.Component.Test.Cards do
  @moduledoc false
  # A pure component of two kinds, with parameters, slots, events and a budget.
  use Macaw.Component,
    name: "test.cards",
    kinds: [:navigation, :content],
    hooks: %{"Cards" => "priv/static/cards.js"},
    assets: ["priv/static/cards.css"]

  @impl true
  def parameters do
    %{
      "columns" => %{type: :number, default: 3, values: [1, 2, 3, 4]},
      "label" => %{type: :text, default: "Cards"},
      "bins" => %{type: :number, default: 10, bindable: true}
    }
  end

  @impl true
  def declarations(settings) do
    {
      :ok,
      # A declaration that would follow a bindable parameter if declarations read it.
      slots: %{"items" => %{requires: %{"title" => %{type: :text}}}},
      events: ["open"],
      announces: ["opened"],
      reading: :scan,
      words: nil,
      access: if(settings["bins"] == 10, do: nil, else: "leaked")
    }
  end

  @impl true
  def budget("items", settings, {w, _h}), do: max(1, div(trunc(w), 40)) * settings["columns"]
  def budget(_slot, _settings, _size), do: nil

  @impl true
  def render(:navigation, _assigns),
    do: {:safe, ~s(<nav aria-label="Cards"><a href="/a">A</a></nav>)}

  def render(:content, _assigns), do: {:safe, ~s(<ul class="cards"></ul>)}
end

defmodule Macaw.Component.Test.Fixed do
  @moduledoc false
  # A component whose behavior is fixed: every default.
  use Macaw.Component, name: "test.fixed", kinds: [:content]

  @impl true
  def render(_kind, _assigns), do: {:safe, "<p>fixed</p>"}
end

defmodule Macaw.Component.Test.Scene do
  @moduledoc false
  # A contained component: a value with its four transitions.
  use Macaw.Component, name: "test.scene", kinds: [:content]

  @impl true
  def declarations(_settings), do: {:ok, isolation: :contained, writes: %{"camera" => :camera}}

  @impl true
  def init(settings, context),
    do: %{settings: settings, instance: context.instance, slots: %{}, size: context.size}

  @impl true
  def delivery(value, slot, delivery), do: put_in(value.slots[slot], delivery)
  @impl true
  def size(value, size), do: %{value | size: size}
  @impl true
  def bound(value, name, new), do: put_in(value.settings[name], new)

  @impl true
  def render(:content, _assigns), do: {:safe, "<div></div>"}
end

defmodule Macaw.Component.Test.Uncontained do
  @moduledoc false
  # Declares :contained without its transitions.
  use Macaw.Component, name: "test.uncontained", kinds: [:content]

  @impl true
  def declarations(_settings), do: {:ok, isolation: :contained}

  @impl true
  def render(:content, _assigns), do: {:safe, ""}
end

defmodule Macaw.Component.Test.Answers do
  @moduledoc false
  # Answers whatever the settings ask for, to reach every shape of a bad answer.
  use Macaw.Component, name: "test.answers", kinds: [:content]

  @impl true
  def parameters, do: %{"answer" => %{type: :term, default: :ok}}

  @impl true
  def declarations(%{"answer" => answer}), do: answer

  @impl true
  def budget(_slot, %{"answer" => answer}, _size), do: answer

  @impl true
  def render(:content, _assigns), do: {:safe, ""}
end

defmodule Macaw.Component.Test.BadParameters do
  @moduledoc false
  use Macaw.Component, name: "test.bad_parameters", kinds: [:content]

  @impl true
  def parameters,
    do: %{
      "" => %{type: :number},
      "open" => %{type: :number, bindable: true},
      "kind" => %{type: :nope}
    }

  @impl true
  def render(:content, _assigns), do: {:safe, ""}
end
