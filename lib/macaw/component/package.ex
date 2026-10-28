defmodule Macaw.Component.Package do
  @moduledoc """
  The package side of the registry (spec/03): what a package provides, read the same way
  by every host. A package is a module with `__members__/0`; its components are the
  members that use `Macaw.Component`, each registering through its static declarations.

  Enabling packages, the boot-time duplicate check across them and resolving names in
  documents are the host's.
  """

  @type component :: %{
          name: String.t(),
          module: module(),
          kinds: [Macaw.Component.kind(), ...],
          hooks: %{String.t() => String.t()},
          assets: [String.t()]
        }

  @doc """
  A package's components, in member order, each with its static declarations; members of
  other behaviors are skipped. Every fault at once: `:not_a_package`, `{:not_loaded,
  member}`, and `{:duplicate, name, [module, module]}` for two components of one name.
  """
  @spec components(module()) :: {:ok, [component()]} | {:error, [Macaw.Component.fault(), ...]}
  def components(package) when is_atom(package) do
    if Code.ensure_loaded?(package) and function_exported?(package, :__members__, 0) do
      members = package.__members__()
      unloaded = for m <- members, not Code.ensure_loaded?(m), do: {[], {:not_loaded, m}}

      components =
        for member <- members,
            Macaw.Component.component?(member),
            info = member.__component__(),
            do: Map.put(info, :module, member)

      duplicates =
        for {name, [_, _ | _] = same} <- Enum.group_by(components, & &1.name, & &1.module),
            do: {[], {:duplicate, name, same}}

      Macaw.Component.answer(unloaded ++ duplicates, components)
    else
      {:error, [{[], :not_a_package}]}
    end
  end

  @doc "`:ok` when `components/1` answers `{:ok, _}`, else its faults."
  @spec check(module()) :: :ok | {:error, [Macaw.Component.fault(), ...]}
  def check(package) do
    case components(package) do
      {:ok, _components} -> :ok
      error -> error
    end
  end

  @doc """
  Every hook of the components of the listed packages, `%{hook_name => {package, path}}`,
  from which a host generates the one module that registers them in its `LiveSocket`. Two
  hooks of one name are `{:duplicate_hook, name, [component, component]}`; a package's own
  faults are reported at `[package]`.
  """
  @spec hooks([module()]) ::
          {:ok, %{String.t() => {module(), String.t()}}}
          | {:error, [Macaw.Component.fault(), ...]}
  def hooks(packages) when is_list(packages) do
    {entries, faults} =
      Enum.reduce(packages, {[], []}, fn package, {entries, faults} ->
        case components(package) do
          {:ok, components} ->
            more =
              for c <- components, {hook, path} <- c.hooks, do: {hook, c.name, {package, path}}

            {entries ++ more, faults}

          {:error, own} ->
            {entries, faults ++ for({path, reason} <- own, do: {[package | path], reason})}
        end
      end)

    duplicates =
      for {hook, [_, _ | _] = same} <- Enum.group_by(entries, &elem(&1, 0), &elem(&1, 1)),
          do: {[], {:duplicate_hook, hook, same}}

    Macaw.Component.answer(
      faults ++ duplicates,
      Map.new(entries, fn {hook, _name, where} -> {hook, where} end)
    )
  end
end
