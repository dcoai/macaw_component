# Changelog

## Unreleased

- The shared client module for hooks, `priv/static/macaw_component/client.js`: the announcer (two regions found or created once per page; requests queued, merged and rate-limited, undeclared names dropped) and the client bus (`window.MacawBus`; undeclared keys refused, values passed through uninspected). One ES module, no build step, no dependencies; served with `Plug.Static, from: {:macaw_component, "priv/static"}` and imported from `/macaw_component/client.js`. `priv` ships in the package (dco-tek/macaw/macaw#142, spec/02 §8).
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
