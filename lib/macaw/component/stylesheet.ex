defmodule Macaw.Component.Stylesheet do
  @moduledoc """
  Generated stylesheets (spec/01 §1.8): CSS a document defines at runtime, served from
  `'self'` at a path addressed by its content, so the same document always yields the same
  file and base renders capture it.

      iex> Macaw.Component.Stylesheet.path(".a{opacity:1}")
      "/assets/" <> Base.encode16(:crypto.hash(:sha256, ".a{opacity:1}"), case: :lower) <> ".css"
  """

  @import ~r/@import\s+(?:url\(\s*)?["']?([^"')\s;]+)/i
  @url ~r/url\(\s*["']?([^"')\s]+)/i

  @doc "The stylesheet's path: `/assets/` and the lowercase SHA-256 of its bytes, `.css`."
  @spec path(String.t()) :: String.t()
  def path(css) when is_binary(css),
    do: "/assets/" <> Base.encode16(:crypto.hash(:sha256, css), case: :lower) <> ".css"

  @doc """
  Why a stylesheet can't be served, or `nil`: `:not_a_string`, or `:origin` for an
  `@import` or a `url(` that is not same-origin (a `data:` URL is allowed in `url(`).
  """
  @spec fault(term()) :: :not_a_string | :origin | nil
  def fault(css) when is_binary(css) do
    imports = for [_, target] <- Regex.scan(@import, css), do: target
    urls = for [_, target] <- Regex.scan(@url, css), do: target

    if Enum.all?(imports, &same_origin?/1) and
         Enum.all?(urls, &(same_origin?(&1) or String.starts_with?(&1, "data:"))),
       do: nil,
       else: :origin
  end

  def fault(_other), do: :not_a_string

  @doc false
  # A URL with no scheme and no authority: a path on this origin.
  @spec same_origin?(String.t()) :: boolean()
  def same_origin?(url) do
    not String.starts_with?(url, "//") and URI.parse(url).scheme == nil
  end
end
