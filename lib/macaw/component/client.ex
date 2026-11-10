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
  given; in `:neutral` and `:print`, nothing. `value` is JSON data (a string, a number, a
  boolean, `nil`, or a list or string-keyed map of these) and `identity` a string-keyed
  map of scalars: anything else is a wrong call.

      iex> attrs = [instance: "status-table", size: {640, 400}, now: ~U[2026-11-10 12:00:00Z]]
      iex> {:ok, context} = Macaw.Component.Context.new([mode: :live] ++ attrs)
      iex> Macaw.Component.Client.event(context, "sort", value: %{"sort" => "p50", "order" => "desc"})
      [{"phx-click", "mw-event"}, {"phx-value-mw", ~s({"instance":"status-table","name":"sort","value":{"order":"desc","sort":"p50"}})}]
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

  defp put_given(payload, opts, key, judge) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> Map.put(payload, Atom.to_string(key), judge.(value))
      :error -> payload
    end
  end

  # JSON data, or no clause: the function's contract (spec/00 §4).
  defp data(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: value

  defp data(list) when is_list(list), do: Enum.map(list, &data/1)

  defp data(%{} = map) when not is_struct(map),
    do: Map.new(map, fn {key, value} when is_binary(key) -> {key, data(value)} end)

  defp identity(%{} = map) when not is_struct(map),
    do: Map.new(map, fn {key, value} when is_binary(key) -> {key, scalar(value)} end)

  defp scalar(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: value
end
