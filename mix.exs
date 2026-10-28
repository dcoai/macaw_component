defmodule Macaw.Component.MixProject do
  use Mix.Project

  @source_url "https://github.com/dcoai/macaw_component"
  @version "0.1.3"

  def project do
    [
      app: :macaw_component,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Macaw's component contract: declarations, kinds, the context, rendering modes, drawn states and the component conformance kit.",
      source_url: @source_url,
      package: package(),
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"],
        source_ref: "v#{@version}",
        logo: "brand/logo/macaw_scarlet.svg",
        assets: %{"brand/logo" => "brand/logo"}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  # `test/support` holds the test components the contract and the kit are checked with.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Published on Hex from its public home, mirrored from GitLab (dco-tek/macaw/macaw#155).
  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://hexdocs.pm/macaw_component/changelog.html"
      },
      files: ~w(lib spec mix.exs README.md LICENSE CHANGELOG.md .formatter.exs)
    ]
  end

  defp deps do
    [
      # Themes, their roles and cues (spec/00 §2).
      {:macaw_layers, "~> 0.2.2"},
      # Parameters, schemas, deliveries and the interaction event (spec/00 §2).
      {:macaw_data, "~> 0.5.3"},
      # The safe-markup protocol a render answers in (spec/00 §2); not Phoenix, not LiveView.
      {:phoenix_html, "~> 4.1"},
      # The conformance kit reads renders with it, and compiles only when it is present.
      {:lazy_html, "~> 0.1", optional: true},
      {:stream_data, "~> 1.1", only: :test},
      # Docs for Hex (macaw_compose#155); dev only.
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      # Spec, tests and code kept aligned (macaw_compose spec/00 §4.1); dev/test only.
      {:surfex, "~> 0.10.0", only: [:dev, :test], runtime: false}
    ]
  end
end
