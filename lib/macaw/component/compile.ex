defmodule Macaw.Component.Compile do
  @moduledoc false
  # The compile-time half of `use Macaw.Component` (spec/01 §1, §2, §1.8): the options are
  # checked when `use` expands, and the render clauses against the kinds before the module
  # is compiled, so a missing clause never fails at runtime. The checks answer values; the
  # refusal is raised by the macros themselves (`Macaw.Component.__using__/1`,
  # `__before_compile__/1`), while the caller compiles (spec/00, #12).

  @options [:name, :kinds, :hooks, :assets]
  @name ~r/\A[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*\z/
  @hook_name ~r/\A[A-Z][A-Za-z0-9]*\z/
  @asset_extensions ~w(.css .svg .png .webp .woff2 .json)

  @doc false
  # The static declarations from `use`'s options, or the message naming the first fault.
  @spec options(keyword(), Macro.Env.t()) :: {:ok, map()} | {:error, String.t()}
  def options(opts, caller) do
    # The options are literals (strings, atoms, lists and maps) or module attributes; they
    # are evaluated once, here, in the caller's context.
    {opts, _binding} = Code.eval_quoted(opts, [], caller)

    with :ok <- keyword(opts),
         :ok <- known(opts),
         {:ok, name} <- name(Keyword.get(opts, :name)),
         {:ok, kinds} <- kinds(Keyword.get(opts, :kinds)),
         {:ok, hooks} <- hooks(Keyword.get(opts, :hooks, %{})),
         {:ok, assets} <- assets(Keyword.get(opts, :assets, [])) do
      {:ok, %{name: name, kinds: kinds, hooks: hooks, assets: assets}}
    end
  end

  defp keyword(opts) do
    if Keyword.keyword?(opts),
      do: :ok,
      else: {:error, "use Macaw.Component takes a keyword list, got #{inspect(opts)}"}
  end

  defp known(opts) do
    case for({key, _} <- opts, key not in @options, do: key) do
      [] ->
        :ok

      [key | _] ->
        {:error, "unknown option #{inspect(key)}; use Macaw.Component takes #{inspect(@options)}"}
    end
  end

  defp name(nil), do: {:error, "use Macaw.Component needs name:"}

  defp name(name) do
    if is_binary(name) and Regex.match?(@name, name),
      do: {:ok, name},
      else:
        {:error, "a component's name is lower-case words joined by dots, got #{inspect(name)}"}
  end

  defp kinds(nil), do: {:error, "use Macaw.Component needs kinds:"}

  defp kinds(kinds) when is_list(kinds) and kinds != [] do
    cond do
      unknown = Enum.find(kinds, &(&1 not in Macaw.Component.kinds())) ->
        {:error,
         "#{inspect(unknown)} is not a kind; the kinds are #{inspect(Macaw.Component.kinds())}"}

      kinds != Enum.uniq(kinds) ->
        {:error, "kinds: lists a kind twice: #{inspect(kinds)}"}

      true ->
        {:ok, kinds}
    end
  end

  defp kinds(kinds),
    do:
      {:error,
       "kinds: is a non-empty list of #{inspect(Macaw.Component.kinds())}, got #{inspect(kinds)}"}

  defp hooks(hooks) when is_map(hooks) do
    Enum.reduce_while(hooks, {:ok, hooks}, fn {name, path}, ok ->
      cond do
        not (is_binary(name) and Regex.match?(@hook_name, name)) ->
          {:halt,
           {:error,
            "a hook's name is a capitalized word of letters and digits, got #{inspect(name)}"}}

        path(path, [".js"]) != :ok ->
          {:halt, path(path, [".js"])}

        true ->
          {:cont, ok}
      end
    end)
  end

  defp hooks(hooks),
    do: {:error, "hooks: is a map of hook name to path, got #{inspect(hooks)}"}

  defp assets(assets) when is_list(assets) do
    case Enum.find(assets, &(path(&1, @asset_extensions) != :ok)) do
      nil -> {:ok, assets}
      bad -> path(bad, @asset_extensions)
    end
  end

  defp assets(assets), do: {:error, "assets: is a list of paths, got #{inspect(assets)}"}

  defp path(path, extensions) do
    if is_binary(path) and path != "" and not String.starts_with?(path, "/") and
         ".." not in Path.split(path) and Path.extname(path) in extensions,
       do: :ok,
       else:
         {:error,
          "#{inspect(path)} is not a relative path in the package, without .., " <>
            "ending in one of #{Enum.join(extensions, ", ")}"}
  end

  defmacro __before_compile__(env) do
    case render_clauses(env) do
      {:ok, clauses} ->
        case clause_fault(env, clauses) do
          nil ->
            :ok

          {line, description} ->
            raise CompileError, file: env.file, line: line, description: description
        end

      {:error, description} ->
        raise CompileError, file: env.file, line: env.line, description: description
    end
  end

  # The first render/2 clause that names an undeclared kind, else the first declared kind
  # with no clause: `{line, description}`, or nil.
  defp clause_fault(env, clauses) do
    kinds = Module.get_attribute(env.module, :__macaw_kinds__)
    literals = for {:literal, kind, _line} <- clauses, do: kind
    catch_all? = Enum.any?(clauses, &match?({:any, _line}, &1))

    undeclared =
      for {:literal, kind, line} <- clauses,
          kind not in kinds,
          do:
            {line,
             "render/2 has a clause for #{inspect(kind)}, which #{inspect(env.module)} " <>
               "doesn't declare in kinds: #{inspect(kinds)}"}

    unrendered =
      for kind <- kinds,
          not catch_all?,
          kind not in literals,
          do:
            {env.line,
             "#{inspect(env.module)} declares the kind #{inspect(kind)} but render/2 has no " <>
               "clause for it (spec/01 §2)"}

    List.first(undeclared ++ unrendered)
  end

  # Each render/2 clause's first argument: a literal kind, or a pattern that matches any.
  defp render_clauses(env) do
    case Module.get_definition(env.module, {:render, 2}) do
      {:v1, :def, _meta, clauses} ->
        {:ok,
         for {meta, [first, _assigns], _guards, _body} <- clauses do
           case first do
             kind when is_atom(kind) -> {:literal, kind, meta[:line]}
             _pattern -> {:any, meta[:line]}
           end
         end}

      _ ->
        {:error, "#{inspect(env.module)} uses Macaw.Component but defines no render/2"}
    end
  end
end
