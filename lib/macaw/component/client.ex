defmodule Macaw.Component.Client do
  @moduledoc """
  The client protocols every adopter shares (spec/02 §8): the announcer's two regions, the
  announce event, the client bus, and the event wire (§8.3). Each is found, not created per component, so
  components share one announcer and one bus on any page.

  The package ships a module implementing both for hooks, `module_path/0`, which a host
  serves and a hook imports at `module_url/0`. What a component declares reaches it as the
  data attributes `attributes/1` renders.
  """

  alias Macaw.Component.{Context, Declarations, Mode}
  alias Macaw.Layers.Color

  @doc "The announcer's region ids."
  @spec announcer_ids() :: %{polite: String.t(), assertive: String.t()}
  def announcer_ids, do: %{polite: "mw-announcer-polite", assertive: "mw-announcer-assertive"}

  @doc "The DOM event a hook dispatches to request an announcement."
  @spec announce_event() :: String.t()
  def announce_event, do: "macaw:announce"

  @doc "The property of `window` the client bus lives under."
  @spec bus_name() :: String.t()
  def bus_name, do: "MacawBus"

  @doc "The attribute carrying the announcement names a component declares (`announces`)."
  @spec announces_attribute() :: String.t()
  def announces_attribute, do: "data-mw-announces"

  @doc "The attribute carrying the bus keys a component declares (`local`)."
  @spec local_attribute() :: String.t()
  def local_attribute, do: "data-mw-local"

  @doc "The attribute carrying the instance id of a component's element, for `emit`."
  @spec instance_attribute() :: String.t()
  def instance_attribute, do: "data-mw-instance"

  @doc "The attribute carrying the event names a component declares (`events`)."
  @spec events_attribute() :: String.t()
  def events_attribute, do: "data-mw-events"

  @doc "The shared client module's file in this package, relative to its root."
  @spec module_path() :: String.t()
  def module_path, do: "priv/static/macaw_component/client.js"

  @doc """
  The same-origin path a hook imports the shared module from, where a host serves
  `priv/static` with `Plug.Static, at: "/", from: {:macaw_component, "priv/static"}`.
  """
  @spec module_url() :: String.t()
  def module_url, do: "/macaw_component/client.js"

  @doc """
  The data attributes that hand a component's declared announcement names and bus keys to
  the client: `announces` in declared order and `local`'s keys sorted, each a JSON list.
  A component puts them on the element its hook is attached to, or an ancestor of it
  within the component, for example `<div phx-hook="Cards" {Client.attributes(@declarations)}>`.
  Both are always present, so a component that declares nothing has nothing accepted.

      iex> {:ok, d} = Macaw.Component.Declarations.new([announces: ["matches"], local: %{"hover" => :time}], nil)
      iex> Macaw.Component.Client.attributes(d)
      [{"data-mw-announces", ~s(["matches"])}, {"data-mw-local", ~s(["hover"])}]
  """
  @spec attributes(Declarations.t()) :: [{String.t(), String.t()}, ...]
  def attributes(%Declarations{announces: announces, local: local}) do
    [
      {announces_attribute(), JSON.encode!(announces)},
      {local_attribute(), JSON.encode!(local |> Map.keys() |> Enum.sort())}
    ]
  end

  @doc """
  The data attributes a component's hook reads (spec/02 §8.1): `attributes/1`'s two, then
  the context's instance as `data-mw-instance` and the declared `events`, in declared
  order, as a JSON list in `data-mw-events`. The client module's `emit` reads the last two
  to send an event its hook works out in the browser (§8.2).

      iex> {:ok, d} = Macaw.Component.Declarations.new([events: ["brush"]], nil)
      iex> attrs = [instance: "status-chart", size: {640, 400}, now: ~U[2026-11-10 12:00:00Z]]
      iex> {:ok, context} = Macaw.Component.Context.new([mode: :live] ++ attrs)
      iex> Macaw.Component.Client.attributes(d, context)
      [{"data-mw-announces", "[]"}, {"data-mw-local", "[]"}, {"data-mw-instance", "status-chart"}, {"data-mw-events", ~s(["brush"])}]
  """
  @spec attributes(Declarations.t(), Context.t()) :: [{String.t(), String.t()}, ...]
  def attributes(%Declarations{events: events} = declarations, %Context{instance: instance}) do
    attributes(declarations) ++
      [{instance_attribute(), instance}, {events_attribute(), JSON.encode!(events)}]
  end

  @doc "The one LiveView event every component's events arrive as (spec/02 §8.3)."
  @spec event_name() :: String.t()
  def event_name, do: "mw-event"

  @doc "The attribute holding an event's JSON payload (spec/02 §8.3)."
  @spec event_attribute() :: String.t()
  def event_attribute, do: "phx-value-mw"

  @doc """
  The attributes that make an element emit an event (spec/02 §8.3), for HEEx to splice
  into its tag: `<button type="button" {Client.event(@context, "sort", value: "p50")}>`.

  In `:live` and `:socketless`, `phx-click` is `event_name/0` and `event_attribute/0` holds
  the event as JSON, the context's instance, the name, and `value:` and `identity:` when
  given; in `:neutral` and `:print`, nothing.

  This is the wire's outbound edge: a component hands it the terms it holds, and it
  encodes them. `value` is a string, a number, a boolean, `nil`, a `DateTime`, a point
  `{lon, lat}`, a literal `Macaw.Layers.Color`, or a list or string-keyed map of these;
  `identity` a string-keyed map of strings, numbers, booleans, `nil` and `DateTime`s. A
  `DateTime` is written as its ISO 8601 spelling in UTC, shifted there if it is in another
  zone; a point as the list `[lon, lat]`; a color as its CSS hex (`Color.to_css/1`);
  everything else as JSON has it. Anything else is a wrong call.

      iex> attrs = [instance: "status-table", size: {640, 400}, now: ~U[2026-11-10 12:00:00Z]]
      iex> {:ok, context} = Macaw.Component.Context.new([mode: :live] ++ attrs)
      iex> Macaw.Component.Client.event(context, "sort", value: %{"sort" => "p50", "order" => "desc"})
      [{"phx-click", "mw-event"}, {"phx-value-mw", ~s({"instance":"status-table","name":"sort","value":{"order":"desc","sort":"p50"}})}]
      iex> Macaw.Component.Client.event(context, "select", identity: %{"t" => ~U[2026-11-10 11:00:00Z]})
      [{"phx-click", "mw-event"}, {"phx-value-mw", ~s({"identity":{"t":"2026-11-10T11:00:00Z"},"instance":"status-table","name":"select"})}]
      iex> {:ok, print} = Macaw.Component.Context.new([mode: :print] ++ attrs)
      iex> Macaw.Component.Client.event(print, "sort", value: "p50")
      []
  """
  @spec event(Context.t(), String.t(), keyword()) :: [{String.t(), String.t()}]
  def event(%Context{mode: mode, instance: instance}, name, opts \\ [])
      when is_binary(name) and name != "" and is_list(opts) do
    opts = Keyword.validate!(opts, [:value, :identity])
    payload = %{"instance" => instance, "name" => name}

    payload =
      payload
      |> put_given(opts, :value, &data/1)
      |> put_given(opts, :identity, &identity/1)

    if Mode.allows?(mode, :events),
      do: [{"phx-click", event_name()}, {event_attribute(), JSON.encode!(payload)}],
      else: []
  end

  @typedoc "What a context's link builder is handed (spec/02 §8.4): the event, as terms."
  @type link_event :: %{instance: String.t(), name: String.t(), value: term(), identity: term()}

  @doc """
  The `href` an event would give (spec/02 §8.4), for a control that works with no socket:
  in `:socketless`, what the context's link builder answers for the event, the context's
  instance, the name, and `value:` and `identity:` as `event/3` takes them; `nil` in every
  other mode, and with no builder. A component that has one renders the control as
  `<a href>`, carrying no event wire; with `nil` it renders the control `event/3` makes.

  Only `:socketless` links: once the socket connects the page renders `:live`, where the
  control is the button again, so a link is the first render's and a socketless visit's
  alone. It carries no `phx-click`, since LiveView would both push the event and follow a
  real `href`. A builder answering anything but a string or `nil` is a wrong call.

      iex> attrs = [instance: "status-table", size: {640, 400}, now: ~U[2026-11-10 12:00:00Z]]
      iex> link = fn %{name: name, value: %{"sort" => sort}} -> "/status?" <> name <> "=" <> sort end
      iex> {:ok, socketless} = Macaw.Component.Context.new([mode: :socketless, link: link] ++ attrs)
      iex> Macaw.Component.Client.link(socketless, "sort", value: %{"sort" => "p50"})
      "/status?sort=p50"
      iex> {:ok, live} = Macaw.Component.Context.new([mode: :live, link: link] ++ attrs)
      iex> Macaw.Component.Client.link(live, "sort", value: %{"sort" => "p50"})
      nil
  """
  @spec link(Context.t(), String.t(), keyword()) :: String.t() | nil
  def link(%Context{} = context, name, opts \\ [])
      when is_binary(name) and name != "" and is_list(opts) do
    opts = Keyword.validate!(opts, [:value, :identity])

    case context do
      %Context{mode: :socketless, link: link} when is_function(link, 1) ->
        event = %{
          instance: context.instance,
          name: name,
          value: Keyword.get(opts, :value),
          identity: Keyword.get(opts, :identity)
        }

        href!(link.(event))

      _no_link ->
        nil
    end
  end

  defp href!(href) when is_binary(href) or is_nil(href), do: href

  defp put_given(payload, opts, key, judge) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> Map.put(payload, Atom.to_string(key), judge.(value))
      :error -> payload
    end
  end

  # JSON data, a time as its UTC ISO 8601 spelling, a point as [lon, lat], a literal color
  # as its CSS hex, or no clause: the function's contract (spec/00 §4).
  defp data(%DateTime{} = time), do: time(time)
  defp data(%Color{} = color), do: Color.to_css(color)
  defp data({lon, lat}) when is_number(lon) and is_number(lat), do: [lon, lat]

  defp data(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: value

  defp data(list) when is_list(list), do: Enum.map(list, &data/1)

  defp data(%{} = map) when not is_struct(map),
    do: Map.new(map, fn {key, value} when is_binary(key) -> {key, data(value)} end)

  defp identity(%{} = map) when not is_struct(map),
    do: Map.new(map, fn {key, value} when is_binary(key) -> {key, scalar(value)} end)

  defp scalar(%DateTime{} = time), do: time(time)

  defp scalar(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: value

  defp time(time), do: time |> DateTime.shift_zone!("Etc/UTC") |> DateTime.to_iso8601()
end
