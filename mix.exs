defmodule Macaw.Component.MixProject do
  use Mix.Project

  @version "0.1.0-dev"

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
      package: [licenses: ["MIT"]],
      docs: [main: "readme", extras: ["README.md"]]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  # `test/support` holds the test components the contract and the kit are checked with.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # The safe-markup protocol a render answers in (spec/00 §2); not Phoenix, not LiveView.
      {:phoenix_html, "~> 4.1"},
      # The conformance kit reads renders with it, and compiles only when it is present.
      {:lazy_html, "~> 0.1", optional: true},
      {:stream_data, "~> 1.1", only: :test},
      # Spec, tests and code kept aligned (macaw_compose spec/00 §4.1); dev/test only.
      {:surfex, "~> 0.10.0", only: [:dev, :test], runtime: false}
    ]
  end
end
