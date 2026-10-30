# Changelog

## Unreleased

## v0.2.0 (2026-10-30)

### Upgrading from 0.1.5

macaw_component's own functions are unchanged; what changes is the dependencies' terms that pass through them, to a component and to a host.

1. **Depend on macaw_layers `~> 0.3.0` and macaw_data `~> 0.7.0`.** Their upgrade guides ("Upgrading from 0.2.4" and "Upgrading from 0.6.1") apply to any call you make into them directly.
2. **The context's theme holds color terms and string names.** `context.theme`, and the theme the conformance kit's `theme:` option takes, is macaw_layers 0.3's `%Macaw.Layers.Theme{}`: its series, furniture and literal colors are `%Macaw.Layers.Color{}`, never CSS text, and its names are strings (`Theme.default().name == "default"`, slots and role names `"info"`). A component that writes a theme's literal into markup writes `Macaw.Layers.Color.to_css/1` of it; code that matches `:default` or a slot atom in a theme's fields matches strings. A theme built with a CSS string as a color raises at `Theme.new/1`: write `~RGB"#3b6fa8"` or `Color.parse!/1`. `Macaw.Component.Drawn.role/1` and `glyph/1` answer as before, and `Theme.cue/1` takes either spelling.
3. **A `:color` value is a color term.** A `:color` parameter's default and value (`Macaw.Data.Parameter`), and a `:color` field's values in a delivery, are a `%Macaw.Layers.Color{}` literal or a theme-relative typed color (`{:color, "good"}`); a string, `"#2e7d32"` or `"red"`, is refused. Declare defaults with `~RGB`, parse CSS text at your input edge with `Color.parse!/1`, and draw with `Color.to_css/1`. The rendered markup is unchanged: the drawing rules and the `:colors` check still read literal colors as CSS text in presentation attributes (spec/02 §5, spec/04 §2).
4. **Category values read back as strings.** A `:category` column of a packed delivery (`Delivery.table/2`, then `Table.rows/1`, `get/2` or `column/2`) answers `"ok"` for `:ok`; `nil`, `true` and `false` are kept. Compare with strings, or with `Macaw.Data.Operations.same?/2`. A delivery's rows read with `Delivery.rows/1` are as the source gave them, as before.
5. **A schema's names are strings, and its version changes.** A `%Macaw.Data.Schema{}` a slot is checked against holds its field names as strings; `Slot.check/3` and `Slot.resolve/3` take either spelling and answer as before. Every `Schema.version`, and the operations registry's digest, differs from macaw_data 0.6's: regenerate any stored version or cache key. A stylesheet's path (`Macaw.Component.Stylesheet.path/1`, the SHA-256 of its bytes) is unchanged.

### Changes

- **Breaking:** on `macaw_layers ~> 0.3.0` and `macaw_data ~> 0.7.0` (#3, dco-tek/macaw/macaw#188): colors are terms, a theme's names are strings, category values read back as strings, and every digest and schema version changes. No code of macaw_component's changed; the guide above lists what reaches a component or a host.

## v0.1.5 (2026-10-30)

- The shared client module for hooks, `priv/static/macaw_component/client.js`: the announcer (two regions found or created once per page; requests queued, merged and rate-limited, undeclared names dropped) and the client bus (`window.MacawBus`; undeclared keys refused, values passed through uninspected). One ES module, no build step, no dependencies; served with `Plug.Static, from: {:macaw_component, "priv/static"}` and imported from `/macaw_component/client.js`. `priv` ships in the package (dco-tek/macaw/macaw#142, spec/02 §8).
- `%Macaw.Component.Context{}` gains `bindings`, the cell's resolved bindings, `%{slot => %{role => field | [field, …]}}`, `%{}` by default and checked by `Context.new/1` at paths under `[:bindings]`; `Context.field/3` answers the field bound to a role, a `many` role's list, or `nil`. A slot's binding now reaches the component, inside its context (dco-tek/macaw/macaw#194, #2, spec/02 §2).
- `Macaw.Component.Slot.resolve/3`: the resolved role → field map of a binding `check/3` passes, an unbound `window` role holding the window field and an unbound optional role absent; the one source of the defaulting rule for the core and adopters (dco-tek/macaw/macaw#194, #2, spec/01 §1.3).
- The conformance kit: a `bindings:` fixture key, `%{}` by default, carried by every context the kit builds; and a thirteenth check, `:bindings`, which renames each slot's bound fields to fresh tokens and finds `{:ignores_binding, slot}` when the render doesn't follow them. Fixtures without bindings are not probed (dco-tek/macaw/macaw#194, #2, spec/04 §2, §3).
- `Macaw.Component.Client.attributes/1`: the `data-mw-announces` and `data-mw-local` attributes that hand a component's declared announcement names and bus keys to the client, with `announces_attribute/0`, `local_attribute/0`, `module_path/0` and `module_url/0`.

## v0.1.4 (2026-10-29)

- `macaw_data ~> 0.6.0`: a delivery keeps the rows its source gave (dco-tek/macaw/macaw#185, #186).

## v0.1.3 (2026-10-28)

- The macaw logo in the docs and the README (macaw#175).

## v0.1.2 (2026-10-28)

- On Hex: depends on `macaw_layers ~> 0.2.2` and `macaw_data ~> 0.5.3` from Hex instead of their git tags; the README installs from Hex (macaw#155).
- The README opens with the early-release notice (macaw#174).

## v0.1.1 (2026-10-28)

- Dependencies named by their `dco-tek/macaw` group paths, on macaw_data v0.5.2 (macaw#152).
- Package metadata for Hex: the public home, the changelog link, the files shipped, and docs with `ex_doc` (macaw_compose#155).

## v0.1.0 (2026-10-28)

- macaw_component v0.1.0: the component contract, rendering, packages and the conformance kit (macaw_compose#143)
