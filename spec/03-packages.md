# 03 — Packages {#packages}

## 1. The package side of the registry {#components-packages}

A host enables what pages may name **by package**, and the registry is explicit and closed by default ([macaw_compose 12 §1](https://gitlab.conet.yarina.org/dco-tek/macaw_compose/-/blob/main/spec/12-registry.md#registry-model)). Enabling packages, the boot-time duplicate check across them and resolving names in documents are the host's, `macaw`'s. **What a package provides is this library's**, so every package is read the same way by every host:
- **A package is a module with `__members__/0`,** the list of its member modules: the explicit list a runtime that can't introspect calls. One package may hold components, sources, transforms and aggregates together; each behavior's registry reads its own members. A package's author never maintains a second list (macaw_compose#22, R17).
- **A member is a component when it uses `Macaw.Component`** (01 §1), read from its own behavior declarations, as `macaw_data`'s registry reads transforms and aggregates. A member of another Macaw behavior is skipped here; its registry is the host's.
- **Each component registers through `info/1`**: its name, kinds, hooks and assets, read without calling it with settings.

`Macaw.Component.Package`:
- **`components(package)`** answers `{:ok, components}`, a list of `%{name, module, kinds, hooks, assets}` in member order, or `{:error, faults}`, every fault at once: `:not_a_package` for a module without `__members__/0`; `{:not_loaded, member}` for a member that can't be loaded; `{:duplicate, name, [module, module]}` for two components of one name in the package.
- **`check(package)`** is `:ok` when `components/1` answers `{:ok, _}`, else its faults.
- **`hooks(packages)`** is every hook of the components of the listed packages, `%{hook_name => {package, path}}`, from which a host generates the one module that registers them in its `LiveSocket` (`macaw_live` does). Two hooks of one name are `{:duplicate_hook, name, [component, component]}`, since a `LiveSocket` holds one hook per name.
- **Names are strings, matched by spelling.** No atom is made from a name in a document.

`macaw`'s built-in components are a package too, enabled like any other.

```test:packages-components
a package's components are its members that use Macaw.Component, in order, with their static declarations; members of other behaviors are skipped
```

```test:packages-faults
a module without __members__, a member that can't load and two components of one name are faults, every one at once; check/1 agrees with components/1
```

```test:packages-hooks
hooks/1 collects the hooks of the listed packages by name and refuses two of one name
```
