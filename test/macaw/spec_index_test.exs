defmodule Macaw.Component.SpecIndexTest do
  # The spec's index lists every spec file, so none is left without a reader's way in.
  use ExUnit.Case, async: true

  test "spec/README.md links every spec file" do
    index = File.read!("spec/README.md")

    for path <- Path.wildcard("spec/*.md"), Path.basename(path) != "README.md" do
      assert index =~ "](#{Path.basename(path)})", "#{path} is not in spec/README.md"
    end
  end
end
