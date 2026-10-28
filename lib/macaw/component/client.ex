defmodule Macaw.Component.Client do
  @moduledoc """
  The fixed names of the client protocols every adopter shares (spec/02 §8): the
  announcer's two regions, the announce event, and the client bus. Each is found, not
  created per component, so components share one announcer and one bus on any page.
  """

  @doc "The announcer's region ids."
  @spec announcer_ids() :: %{polite: String.t(), assertive: String.t()}
  def announcer_ids, do: %{polite: "mw-announcer-polite", assertive: "mw-announcer-assertive"}

  @doc "The DOM event a hook dispatches to request an announcement."
  @spec announce_event() :: String.t()
  def announce_event, do: "macaw:announce"

  @doc "The property of `window` the client bus lives under."
  @spec bus_name() :: String.t()
  def bus_name, do: "MacawBus"
end
