defmodule Macaw.Component.Client do
  @moduledoc """
  The client protocols every adopter shares (spec/02 §8): the announcer's two regions, the
  announce event, and the client bus. Each is found, not created per component, so
  components share one announcer and one bus on any page.

  The package ships a module implementing both for hooks, `module_path/0`, which a host
  serves and a hook imports at `module_url/0`. What a component declares reaches it as the
  data attributes `attributes/1` renders.
  """

  alias Macaw.Component.Declarations

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
end
