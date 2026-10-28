defmodule Macaw.Component.Proxy do
  @moduledoc """
  Proxy routes (spec/01 §1.8): media a component needs from another origin, fetched by the
  host's one same-origin proxy, so a page holds same-origin URLs only.

      iex> route = %{name: "tiles", url: "https://tiles.example/{z}/{x}/{y}.png", types: ["image/png"]}
      iex> Macaw.Component.Proxy.path("geo.map", route, %{"z" => "1", "x" => "0", "y" => "0"})
      {:ok, "/macaw/proxy/geo.map/tiles?x=0&y=0&z=1"}
  """

  @keys [:name, :url, :types]
  @placeholder ~r/\{([a-z_][a-z0-9_]*)\}/
  @content_type ~r{\A[a-z]+/[a-z0-9.+-]+\z}

  @type route :: %{name: String.t(), url: String.t(), types: [String.t(), ...]}

  @doc false
  # The faults of a `proxy_routes` declaration, from its key.
  @spec routes_faults(term()) :: [Macaw.Component.fault()]
  def routes_faults(routes) when is_list(routes) do
    each =
      routes
      |> Enum.with_index()
      |> Enum.flat_map(fn
        {%{} = route, i} when not is_struct(route) -> route_faults(route, [:proxy_routes, i])
        {other, i} -> [{[:proxy_routes, i], {:not_a_map, other}}]
      end)

    names = for %{name: name} <- routes, do: name

    each ++
      for(name <- Enum.uniq(names -- Enum.uniq(names)), do: {[:proxy_routes], {:duplicate, name}})
  end

  def routes_faults(other), do: [{[:proxy_routes], {:not_a_list, other}}]

  defp route_faults(route, path) do
    unknown = for key <- Map.keys(route), key not in @keys, do: {path ++ [key], :unknown_key}
    name = Map.get(route, :name)
    url = Map.get(route, :url)
    types = Map.get(route, :types)

    unknown ++
      if(is_binary(name) and name != "", do: [], else: [{path ++ [:name], :bad_name}]) ++
      if(https?(url), do: [], else: [{path ++ [:url], :not_https}]) ++
      if(is_list(types) and types != [] and Enum.all?(types, &content_type?/1),
        do: [],
        else: [{path ++ [:types], :bad_types}]
      )
  end

  defp https?(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.scheme == "https" and is_binary(uri.host) and uri.host != ""
  end

  defp https?(_url), do: false

  defp content_type?(type), do: is_binary(type) and Regex.match?(@content_type, type)

  @doc "The placeholders a route's URL template names, in order of first appearance."
  @spec placeholders(route()) :: [String.t()]
  def placeholders(%{url: url}),
    do: @placeholder |> Regex.scan(url) |> Enum.map(&List.last/1) |> Enum.uniq()

  @doc """
  The same-origin path a render uses for a route of a component:
  `/macaw/proxy/<component>/<route>?<values>`, the values query-encoded in name order.
  Every placeholder needs a value: `{:error, {:placeholders, missing}}` otherwise.
  """
  @spec path(String.t(), route(), %{String.t() => String.t()}) ::
          {:ok, String.t()} | {:error, {:placeholders, [String.t(), ...]}}
  def path(component, %{name: name} = route, values)
      when is_binary(component) and is_map(values) do
    case Enum.reject(placeholders(route), &Map.has_key?(values, &1)) do
      [] ->
        query = values |> Enum.sort() |> URI.encode_query()
        {:ok, "/macaw/proxy/#{component}/#{name}?#{query}"}

      missing ->
        {:error, {:placeholders, missing}}
    end
  end
end
