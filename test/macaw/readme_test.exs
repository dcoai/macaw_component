defmodule Macaw.Component.ReadmeTest do
  # The README tells a reader what to install, so its pin is the release's (#26): 0.5.0
  # shipped telling readers to install 0.4. Its status line names no version, which only
  # this pin may say.
  use ExUnit.Case, async: true

  test "the README's install pin is mix.exs's version, and the status line names none" do
    readme = File.read!("README.md")
    version = Version.parse!(Mix.Project.config()[:version])

    assert [[pin]] =
             Regex.scan(~r/\{:macaw_component, "~> ([0-9.]+)"\}/, readme, capture: :all_but_first),
           "README.md has no single {:macaw_component, \"~> ...\"} pin"

    assert pin == "#{version.major}.#{version.minor}.0",
           "README.md pins ~> #{pin}; mix.exs is #{version}"

    [status] = Regex.run(~r/^\*\*Status:\*\*.*$/m, readme)
    refute status =~ ~r/\bv?\d+\.\d+\.\d+\b/, "the status line names a version: #{status}"
  end
end
