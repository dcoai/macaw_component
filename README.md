# macaw_component

Macaw's component contract: what a component declares, the kinds it renders as, the context it renders in, the rendering modes and their rules, its drawn states, the package side of the registry, and the component conformance kit.

A component package (visualize's visuals, metresis's panels, the core's built-in components) implements this contract **without the Macaw core**: `macaw_component` holds no process, no state source and no page. Placing components on pages is the core's, `macaw`.

**Status:** in development toward v0.1.0 (dco-tek/macaw_compose#143). The contract is **unstable until two implementers pass its kit**, the core's table and visualize's visuals; until then every 0.x minor version may change it.

The specification is in [`spec/`](spec/README.md).
