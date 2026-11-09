# 00 — Overview {#component-overview}

## 1. What macaw_component holds {#component-holds}

`macaw_component` is the contract every Macaw component implements ([macaw_compose 00 §4](https://github.com/dcoai/macaw/blob/main/spec/00-overview.md#overview-packaging)):
- **the contract** ([01](01-contract.md)): the `Macaw.Component` behavior, its static declarations (name, kinds, parameters, hooks, assets) and its configured ones, built from settings by a pure function;
- **rendering** ([02](02-rendering.md)): the assigns and the context a component renders with, the rendering modes and each one's rules, the output rules of each kind, the rendering rules, the drawn states and the `:contained` value's transitions;
- **packages** ([03](03-packages.md)): the package side of the registry, `__members__/0` and the introspection a host's registry reads;
- **the conformance kit** ([04](04-conformance.md)): the contract as checks, which every component author runs, with check sets for families of components.

**It holds no process, no state source and no page.** A component and its value are pure; the process that holds a value is its host's: under Macaw, `macaw_live`'s contained cell; elsewhere, whatever the host uses (a LiveView's assigns, a test). Placing components on pages, state, the page DAG and the host side of the registry are the core's, `macaw` ([macaw_compose 05 §7](https://github.com/dcoai/macaw/blob/main/spec/05-components.md#components-libraries)). **A proposed addition that needs a process, a state source or a page belongs to the core.**

## 2. Dependencies {#component-dependencies}

- **`macaw_layers`**: themes, their roles and cues ([macaw_layers 04](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md)), which drawn states and the color rule use.
- **`macaw_data`**: the parameter shape, the schema a slot's requirements are checked against, deliveries and the interaction event ([macaw_data 01](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md)).
- **`phoenix_html`**: the safe-markup protocol a render answers in, so a component writes HEEx or plain safe iodata alike. Not Phoenix and not LiveView: a component that uses `~H` brings `phoenix_live_view` itself.
- **`lazy_html`, optional**: the HTML parser the conformance kit reads renders with. It is what LiveView's own test helpers use, so a component author testing with LiveView already has it; the kit compiles only when it is present, and nothing else needs it.
- Elixir 1.18 or newer. In dev and test only: `stream_data` and `surfex`.

## 3. Order of work and stability {#component-order}

Built as step 8.1 of the family's order of work ([macaw_compose 00 §5](https://github.com/dcoai/macaw/blob/main/spec/00-overview.md#overview-order)), before the core's surfaces, because visualize's visuals implement it (visualize#946) and the core's own components are written against it. Released by git tag until v0.1.1, and on Hex from v0.1.2, with the rest of the family at the owner's coordinated release (macaw#155).

**The contract is unstable until two implementers pass its kit:** the core's built-in table and visualize's visuals. Until then it is released at 0.x, every minor version may change it, and its documentation says so. Changes found by an implementer are proposals on dco-tek/macaw_compose.

## 4. Errors are values {#component-errors}

**A failure is answered as a value, and a raise is asked for by name** (#12, dco-tek/macaw/macaw#243, from v0.8.0), as in every Macaw library ([macaw_compose 00 §4.3](https://github.com/dcoai/macaw/blob/main/spec/00-overview.md#core-errors)):
- **Every public function that can fail on its input** (settings, a slot, a binding, a context's attrs, the kit's options) answers `{:ok, value}` or `{:error, faults}`, every fault by path, or `:ok`. The kit answers its misuse as findings ([04 §1](04-conformance.md#components-kit)).
- **A function raises only as the `!` twin** of a value-answering function of the same name and arity (`Slot.resolve!/3` beside `resolve/3`), so a caller who wants the raise asks for it by name.
- **Compile time is the compiler's.** `use Macaw.Component`'s options, its render clauses against its kinds, and `use Macaw.Component.Conformance`'s options are refused while the module compiles ([01 §1](01-contract.md#components-behavior)).
- **A function's own contract is not input.** An unknown mode, feature or drawn state is a guard's refusal, a `FunctionClauseError`, as any wrong call is. Two invariants stay explicit and named: `Context.id/2`'s local part is the component's own literal, and the transition dispatch is only called on a contained component ([02 §7](02-rendering.md#components-contained)). A wrong one is the component's or the core's bug.
- **A callback a component supplies may raise;** a host isolates components by process, and nothing here catches a raise with `try/rescue`.
- **Enforced in CI:** `ci/raises.exs`, the family's copy, finds every explicit `raise`, `throw` and `exit` in `lib/` and fails on one outside `ci/raises_allowlist.exs`, which names each by function with its class (`:bang`, `:compile`, `:mix_task`, `:invariant`) and reason, defaults to `[]`, and fails on a stale entry. Implicit raises are guarded by property tests.

```test:component-errors-values
over generated malformed settings, slots, fields and context attrs, settings/2, declarations/2, Slot.new/1, check/3, resolve/3 and Context.new/1 answer a value, every fault worded, never a raise
```
