# Changelog

## Unreleased

- **Breaking:** `Slot.resolve/3` answers `{:ok, resolved}`, and for a binding `check/3` refuses, its faults, where it raised (#33, #12); `Slot.resolve!/3` raises there. A host resolving checked bindings matches `{:ok, resolved}` or moves to `resolve!/3`.
- An unknown mode or feature (`Mode.allows?/2`) and an unknown drawn state (`Drawn.pick/1`, `role/1`, `words/1`) are guards now, so a wrong call is a `FunctionClauseError` where it was an `ArgumentError` (#33). `use Macaw.Component`'s checks answer values and the macros raise them, unchanged for a component author.
- **Breaking:** the conformance kit answers its misuse as findings, never a raise (#32, #12). `check/2` and `check/3` judge their arguments before anything renders and answer every misuse as `{:kit, {{"options", nil, nil}, fault}}`, a fault by path: an unknown check (`{:enum, checks}` at `[:check]`), a module that isn't a component (`:not_a_component` at `[:component]`), an unknown option (`:unknown_key`), an unknown check set (`{:enum, sets}` at `[:check_sets, i]`), fixtures that aren't a non-empty list of maps of fixture keys, and bindings the context refuses (under `[:fixtures, i]`), where each raised `ArgumentError`. A test using the kit fails with every one named; `format/1` words them. `checks/1` answers `{:ok, checks}`, an unknown set `{:error, [{[], {:enum, sets}}]}`: a caller of `checks(set)` matches `{:ok, checks}`. `use` still refuses a missing `component:`, an unknown option and an unknown check set while the test compiles.

## v0.7.0 (2026-11-05)

**On macaw_data 0.13** (#30, #31). This release is breaking only for an adopter pinning macaw_data `~> 0.12`. macaw_component's own API is unchanged, and one kit check finds more.

### Upgrading from 0.6.x

1. **Depend on `macaw_data ~> 0.13.0`** and follow its "Upgrading from 0.12.x" for any call you make into it directly. The ones to look for are `Macaw.Data.Reduce.lttb/3` and `m4/3`, and `Macaw.Data.FFT.magnitudes/1` and `window/2`, which now answer `{:ok, value}` or `{:error, reason}`.
2. **A component whose declarations read a bindable parameter with a nil default now has a finding,** `{:reads_bindable, name}`, from the kit's `:declarations` check. Have it stop reading the parameter there.

### Changes

- **Breaking:** on `macaw_data ~> 0.13.0` (was `~> 0.12.0`) (#30, #31).
- The conformance kit's `:declarations` check probes a bindable `:number`, `:text` or `:category` parameter with a nil default (macaw_data 0.12.1), so a component whose declarations read one is the finding `{:reads_bindable, name}`. It was skipped. `:time`, `:color` and `:point` stay unprobed, with a nil default as with a real one (#28, #29).

## v0.6.0 (2026-11-04)

**On macaw_data 0.12, and an order key can name a role** (#20, #21). This release is breaking for an adopter pinning macaw_data `~> 0.11`. macaw_component's own API only grows: a component, a host and a fixture that use no role key change nothing else.

### Upgrading from 0.5.x

1. **Depend on `macaw_data ~> 0.12.0`** and follow its "Upgrading from 0.11.x" for any call you make into it directly. In a component and in a test the one to look for is `Delivery.rows/1`, now `{:ok, rows}`: call `Delivery.rows!/1` for rows a delivery holds, or match the value. A served map built by hand adds `stale`.
2. **A host resolves a slot's order before its request.** Call `Macaw.Component.resolve_order(module, slot, settings, bindings)` where it called `Macaw.Component.order/3`, with `bindings` the slot's `Slot.resolve/3` map, and put its answer in the request and the pooling key. The errors are the same `{:error, {:bad_order, answer}}`, and a field-keyed order answers as it did. A host left on `order/3` passes a role key on to `Macaw.Data.Source.Order`, which refuses it.
3. **A component may ask for an order by role:** `def order("rows", _settings), do: [{{:role, "t"}, :desc}]`. It needs nothing else, but `budget/3` doesn't see bindings: if an optional role is left unbound its key drops, and a budget still caps the rows in the source's own order.
4. **A fixture's `bindings` must be resolved for a role in the order.** The kit's `:order` check resolves a role-keyed order through a fixture's bindings for the slot, so a required role in the order, a `window` role's field included, must be there, else `{:unresolved_order, slot, answer}`. A fixture without bindings for the slot isn't resolved.

### Changes

- **Breaking:** on `macaw_data ~> 0.12.0` (was `~> 0.11.0`) (#20, #23).
- The conformance kit's `:bindings` check reads a table delivery's rows through `Table.rows/1`'s value: rows it refuses (a hand-built delivery's) are the finding `{:unrenamable, slot, faults}`, never a raise. The rename keeps `served`, with `stale`, unchanged (#20, #23).
- **New:** an order key can name a role (#21, #24, spec/01 §1.4). `order/2` may answer `{{:role, name}, direction}`, beside field keys, so a component can ask for the newest rows by its `t` role whichever field a document binds. `Macaw.Component.order/3` checks each against the slot's declarations: an undeclared role, one named twice, a `many` role and a role with a type that has no order are `{:bad_order, answer}`. The new `Macaw.Component.resolve_order/4` answers the order in fields for the slot's resolved bindings, for the request; a host calls it in place of `order/3`. The conformance kit's `:order` check runs both, its new finding `{:unresolved_order, slot, answer}` a fixture's bindings that lack a required role in the order.
- `Macaw.Component.order/3` answers `{:bad_order, answer}` for an improper list, where it raised from `Macaw.Data.Source.Order.shape/1` (#24, macaw_data#169).
- Spec 02 §6 names the `stale` state's fact, a delivery's `served.stale` (#20, #23).

## v0.5.0 (2026-11-03)

**On macaw_data 0.11** (#17, #16). This release is breaking only for an adopter pinning macaw_data `~> 0.10`: follow macaw_data's "Upgrading from 0.10.x". macaw_component's own API is unchanged.

- **Breaking:** on `macaw_data ~> 0.11.0` (was `~> 0.10.0`) (#17, #16). macaw_data 0.11 answers `Window.position/1` in integer Unix µs for every kind of time, compares windows of mixed kinds by instant (`{:window, :mixed}` is gone) and reduces a Date or NaiveDateTime series as a UTC one; macaw_component calls none of these, and its behavior is unchanged. An application on macaw_data 0.10 follows its "Upgrading from 0.10.x".
- The kit's checks are stated from `Conformance.checks/0` rather than as a count: its doc, the README and spec 04 §2 said thirteen after 0.3.0 added `:order`, the fourteenth, and spec 04's table now has the `:order` row. A doctest holds the list (#18, #13).

## v0.4.0 (2026-11-02)

**On macaw_data 0.10** (#15, #14). macaw_data 0.10.0 answers errors as values: `Delivery.new/2` answers `{:ok, delivery}` or `{:error, faults}`, with `new!/2` its raising twin, and so do `Finish`, `Order.sort/3` and others (see its "Upgrading from 0.9.x"). This release is breaking for an adopter pinning macaw_data `~> 0.9`; macaw_component's own API is unchanged.

- **Breaking:** on `macaw_data ~> 0.10.0` (was `~> 0.9.0`).
- The conformance kit's `:bindings` check rebuilds a fixture's renamed delivery through `Delivery.new/2`'s value: one it can't rebuild is the finding `{:unrenamable, slot, faults}`, never a raise (spec/04).

## v0.3.0 (2026-11-01)

**On macaw_layers 0.4 and macaw_data 0.9, and a slot may ask for a row order** (#11, macaw#241). This release is breaking for an adopter pinning macaw_layers `~> 0.3` or macaw_data `~> 0.7`: follow their upgrade notes (macaw_layers 0.4.0's `Form.read/3` refuses every URL without `urls:`, and a theme refuses untrusted text; macaw_data 0.8.0's tables are chunked and opaque, 0.9.0's request carries an order). macaw_component's own API only grows.

- **Breaking:** on `macaw_layers ~> 0.4.0` and `macaw_data ~> 0.9.0` (were `~> 0.3.0` and `~> 0.7.0`).
- **New:** an optional callback `order(slot, settings)`, the row order a slot asks its source for, and `Macaw.Component.order/3`, `[]` without it and `{:error, {:bad_order, answer}}` for an answer of no order's shape; the conformance kit checks it (spec/01 §1.4).

## v0.2.2 (2026-11-01)

- `Slot.check/3` refuses a field a `many` role lists twice, `{:duplicate, field}` at `[role]`: a table showed the column twice, a chart would draw the series twice (#10, macaw#237).

## v0.2.1 (2026-10-31)

- The drawn states' notices have a static stylesheet, `priv/static/macaw_component/drawn.css` (`Drawn.stylesheet_path/0`, served at `Drawn.stylesheet_url/0`): a rule for every class a notice emits, every color a theme custom property with the default theme's fallback, and the glyph kept visible in forced-colors mode (#6, macaw#196, spec/02 §6).
- The context carries each bound slot's schema (`schemas`, `%{slot => %Macaw.Data.Schema{}}`), and `Context.label/3` and `Context.unit/3` read a field's label and unit from it, falling back to the field's name and `nil`, so a component heads a field in the schema's words (#5, macaw#196, spec/02 §2).
- CI runs the family's dependency advisories guard (`ci/advisories.exs`, with a reasoned allowlist that defaults empty), so a locked package with a security advisory, or a retired one, fails the pipeline; phoenix_html is locked at 4.4.0 (EEF-CVE-2026-117645) (#4, macaw#214).

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
