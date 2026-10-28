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
