# macaw_component

> **This software is a very early release, and not ready for general use.**

Public home: [github.com/dcoai/macaw_component](https://github.com/dcoai/macaw_component) · Docs: [hexdocs.pm](https://hexdocs.pm/macaw_component)

Macaw's component contract: what a component declares, the kinds it renders as, the context it renders in, the rendering modes and their rules, its drawn states, the package side of the registry, and the component conformance kit.

A component package (visualize's visuals, metresis's panels, the core's built-in components) implements this contract **without the Macaw core**: `macaw_component` holds no process, no state source and no page. Placing components on pages is the core's, `macaw`.

**Status:** v0.1.0. The contract is **unstable until two implementers pass its kit**, the core's table and visualize's visuals; until then every 0.x minor version may change it, and changes found by an implementer are proposals on dco-tek/macaw_compose.

| Module | What it is | Spec |
|---|---|---|
| `Macaw.Component` | the behavior, `use` with its compile-time checks, and the dispatch functions | [01 §1](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-behavior) |
| `Macaw.Component.Declarations` | configured declarations, built and checked from `declarations/1`'s answer | [01 §1.2](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-declares) |
| `Macaw.Component.Slot` | slots, their requirements, and checking a binding against a schema | [01 §1.3](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-slots) |
| `Macaw.Component.State` | the standard state and the value and domain types | [01 §1.5](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-state) |
| `Macaw.Component.Announcement` | announcement requests for declared names | [01 §1.6](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-events) |
| `Macaw.Component.Stylesheet`, `Macaw.Component.Proxy` | content-addressed stylesheets and same-origin proxy paths | [01 §1.8](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-assets) |
| `Macaw.Component.Assigns`, `Macaw.Component.Context` | what a component renders with | [02 §1–2](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-assigns) |
| `Macaw.Component.Mode` | the four rendering modes and what each allows | [02 §3](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#web-modes) |
| `Macaw.Component.Drawn` | drawn states, their roles, glyphs, words and static notice | [02 §6](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-states) |
| `Macaw.Component.Client` | the fixed names of the client protocols | [02 §8](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-client) |
| `Macaw.Component.Package` | the package side of the registry | [03](https://github.com/dcoai/macaw_component/blob/main/spec/03-packages.md#components-packages) |
| `Macaw.Component.Conformance` | the conformance kit: twelve checks, fixtures and the visual check set (needs `lazy_html`) | [04](https://github.com/dcoai/macaw_component/blob/main/spec/04-conformance.md#components-kit) |

```elixir
defmodule MyApp.CardsConformanceTest do
  use ExUnit.Case, async: true
  use Macaw.Component.Conformance, component: MyApp.Cards
end
```

From Hex:

```elixir
{:macaw_component, "~> 0.1.2"}
```

The specification is in [`spec/`](https://github.com/dcoai/macaw_component/blob/main/spec/README.md).
