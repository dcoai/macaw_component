# macaw_component specification

`macaw_component` is Macaw's component contract: what a component declares, the kinds it renders as, the context it renders in, the rendering modes and their rules, its drawn states, the package side of the registry, and the component conformance kit. A component package (visualize's visuals, metresis's panels, `macaw_edit`, components built on ryutronic, and the core's own built-in components) implements it **without the core**, `macaw` (owner, 2026-10-27; [macaw_compose#137](https://gitlab.conet.yarina.org/dco-tek/macaw_compose/-/issues/137)).

Each Macaw library has its own spec in its own repository (dco-tek/macaw_compose#61); this is `macaw_component`'s. The family's overview, vocabulary and open questions, and the core's spec, are in [macaw_compose's spec](https://github.com/dcoai/macaw/blob/main/spec/README.md).

| File | Covers | Status |
|---|---|---|
| [00 — Overview](00-overview.md) | what `macaw_component` holds, what it depends on, the order it is built in, stability | |
| [01 — The contract](01-contract.md) | the behavior, names and kinds, parameters, declarations: slots, budget, state, events, announcements, observation, shortcuts, reading load, assets, hooks, proxy routes, isolation, access | implemented (v0.1.0, order-of-work step 8.1) |
| [02 — Rendering](02-rendering.md) | the assigns, the context, the rendering modes, kinds' output rules, the rendering rules, drawn states, the contained value | implemented (v0.1.0) |
| [03 — Packages](03-packages.md) | the package side of the registry: members, introspection, names | implemented (v0.1.0) |
| [04 — The conformance kit](04-conformance.md) | the component kit, its checks, fixtures and check sets, the visual check set | implemented (v0.1.0) |

Sections keep the anchors they had in the family spec (`components-*`, `web-modes`), so links into them stay stable; [macaw_compose 05](https://github.com/dcoai/macaw/blob/main/spec/05-components.md) keeps what is the core's (cells, containers as surfaces, the built-in components) and points here for the rest.
