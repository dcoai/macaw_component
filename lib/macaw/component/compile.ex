defmodule Macaw.Component.Compile do
  @moduledoc false
  # The compile-time half of `use Macaw.Component` (spec/01 §1, §2, §1.8): the options are
  # checked when `use` expands, and the render clauses against the kinds before the module
  # is compiled, so a missing clause never fails at runtime.

  @options [:name, :kinds, :hooks, :assets]
  @name ~r/\A[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*\z/
  @hook_name ~r/\A[A-Z][A-Za-z0-9]*\z/
  @asset_extensions ~w(.css .svg .png .webp .woff2 .json)

  @doc false
  # The static declarations from `use`'s options, or an `ArgumentError` naming the fault.
  @spec options!(keyword(), Macro.Env.t()) :: map()
  def options!(opts, caller) do
    # The options are literals (strings, atoms, lists and maps) or module attributes; they
    # are evaluated once, here, in the caller's context.
    {opts, _binding} = Code.eval_quoted(opts, [], caller)

    Keyword.keyword?(opts) ||
      fail("use Macaw.Component takes a keyword list, got #{inspect(opts)}")

    for {key, _} <- opts, key not in @options do
      fail("unknown option #{inspect(key)}; use Macaw.Component takes #{inspect(@options)}")
    end

    %{
      name: name!(Keyword.get(opts, :name)),
      kinds: kinds!(Keyword.get(opts, :kinds)),
      hooks: hooks!(Keyword.get(opts, :hooks, %{})),
      assets: assets!(Keyword.get(opts, :assets, []))
    }
  end

  defp name!(nil), do: fail("use Macaw.Component needs name:")

  defp name!(name) do
    (is_binary(name) and Regex.match?(@name, name)) ||
      fail("a component's name is lower-case words joined by dots, got #{inspect(name)}")

    name
  end

  defp kinds!(nil), do: fail("use Macaw.Component needs kinds:")

  defp kinds!(kinds) do
    (is_list(kinds) and kinds != []) ||
      fail(
        "kinds: is a non-empty list of #{inspect(Macaw.Component.kinds())}, got #{inspect(kinds)}"
      )

    for kind <- kinds, kind not in Macaw.Component.kinds() do
      fail("#{inspect(kind)} is not a kind; the kinds are #{inspect(Macaw.Component.kinds())}")
    end

    kinds == Enum.uniq(kinds) || fail("kinds: lists a kind twice: #{inspect(kinds)}")
    kinds
  end

  defp hooks!(hooks) do
    is_map(hooks) || fail("hooks: is a map of hook name to path, got #{inspect(hooks)}")

    for {name, path} <- hooks do
      (is_binary(name) and Regex.match?(@hook_name, name)) ||
        fail("a hook's name is a capitalized word of letters and digits, got #{inspect(name)}")

      path!(path, [".js"])
    end

    hooks
  end

  defp assets!(assets) do
    is_list(assets) || fail("assets: is a list of paths, got #{inspect(assets)}")
    Enum.each(assets, &path!(&1, @asset_extensions))
    assets
  end

  defp path!(path, extensions) do
    (is_binary(path) and path != "" and not String.starts_with?(path, "/") and
       ".." not in Path.split(path) and Path.extname(path) in extensions) ||
      fail(
        "#{inspect(path)} is not a relative path in the package, without .., " <>
          "ending in one of #{Enum.join(extensions, ", ")}"
      )
  end

  defp fail(message), do: raise(ArgumentError, message)

  defmacro __before_compile__(env) do
    kinds = Module.get_attribute(env.module, :__macaw_kinds__)
    clauses = render_clauses!(env)

    literals = for {:literal, kind, _line} <- clauses, do: kind
    catch_all? = Enum.any?(clauses, &match?({:any, _line}, &1))

    for {:literal, kind, line} <- clauses, kind not in kinds do
      raise CompileError,
        file: env.file,
        line: line,
        description:
          "render/2 has a clause for #{inspect(kind)}, which #{inspect(env.module)} " <>
            "doesn't declare in kinds: #{inspect(kinds)}"
    end

    for kind <- kinds, not catch_all?, kind not in literals do
      raise CompileError,
        file: env.file,
        line: env.line,
        description:
          "#{inspect(env.module)} declares the kind #{inspect(kind)} but render/2 has no " <>
            "clause for it (spec/01 §2)"
    end

    :ok
  end

  # Each render/2 clause's first argument: a literal kind, or a pattern that matches any.
  defp render_clauses!(env) do
    case Module.get_definition(env.module, {:render, 2}) do
      {:v1, :def, _meta, clauses} ->
        for {meta, [first, _assigns], _guards, _body} <- clauses do
          case first do
            kind when is_atom(kind) -> {:literal, kind, meta[:line]}
            _pattern -> {:any, meta[:line]}
          end
        end

      _ ->
        raise CompileError,
          file: env.file,
          line: env.line,
          description: "#{inspect(env.module)} uses Macaw.Component but defines no render/2"
    end
  end
end
