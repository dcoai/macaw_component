# 04 — The conformance kit {#conformance}

## 1. One kit, two layers {#components-kit}

Every component runs **one kit**, `Macaw.Component.Conformance`: the contract of [01](01-contract.md) and the rules of [02](02-rendering.md) as checks, so a component author proves conformance by running it rather than by reading this spec. There is **one kit per contract** (the source kit in `macaw_data`, this one for components, the template and layer checks in `macaw`); adopters add checks as **check sets** (§4), never a kit of their own (macaw_compose#22, R19). It is shipped in `lib/`, so any component author runs it, the way `macaw_data`'s source kit works.

**Two layers**, as in the source kit ([macaw_data 01 §9](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-conformance)):
- `check(check, component, opts)` answers one check's **findings**, `{check, {where, what}}` terms, `[]` for a component that passes: `where` is the fixture's name and the kind and mode the render was made in (`nil` where none applies), and `what` the rule broken; `check(component, opts)` runs every check of `checks/0`, then those of each check set in `check_sets:`; `format/1` words a finding as a line a person reads.
- `use Macaw.Component.Conformance, component: …` inside a module that uses `ExUnit.Case` writes one test per check, in a `describe` block, failing with the findings. The kit references no ExUnit function itself (`describe`, `test` and `flunk` appear only in the code `use` writes), so it loads in production.
- `use` refuses a missing `component:` and an unknown option at compile time; `check/3` refuses an unknown check and an unknown option with `ArgumentError`.

**The kit reads renders as HTML** with `lazy_html`, an optional dependency (00 §2): the module is compiled only when `LazyHTML` is loaded.

**Options:**
- `fixtures:` the fixtures (§3), `[%{}]` by default: one, with no settings and no deliveries.
- `check_sets:` the check sets to run after the checks, `[]` by default.
- `theme:`, the theme the contexts carry, `Macaw.Layers.Theme.default()` by default; `size:`, `{640, 400}` by default; `now:`, the moment the check starts by default.

**How a check renders.** For each fixture, each kind and each mode, the kit builds a context (instance `"kit-a"`, heading level 2, the options' theme, size and now, and the fixture's bindings), validated settings, declarations and assigns (02 §1): a `:pure` component gets the fixture's deliveries; a `:contained` one gets the value of `init/2`, then `delivery/3` for each delivered slot, then `size/2`. It renders with `drawn: :live` (`:loading` when a slot the component declares has no delivery), and reads the result through `Phoenix.HTML.Safe.to_iodata/1`.

```test:kit-layers
an honest component passes every check; check/3 answers one check's findings and check/2 all of them; every finding formats as a line
```

```test:kit-use
use writes one test per check into a describe block, refuses a missing component and an unknown option at compile time, and an unknown check or option is refused
```

## 2. The checks {#components-kit-checks}

`checks/0` is these thirteen, in order:

| Check | Holds |
|---|---|
| `:declarations` | `parameters/1` answers `{:ok, _}`; each fixture's settings pass `settings/2`; `declarations/2` answers `{:ok, _}` for each; two calls with equal settings answer equal declarations; changing a bindable parameter changes no declaration (01 §1.1); every event a fixture names in `events:` is declared |
| `:kinds` | each declared kind renders, to its kind's rules (02 §4) |
| `:modes` | every mode renders something; no `<canvas>` outside live; no `phx-hook`, `<script>`, live region (`aria-live`, `role` `status`, `alert` or `log`), drawn token (`data-mw-token`) or CSRF token in neutral or print (02 §3) |
| `:delivery` | no `style` attribute, `<style>`, inline `<script>`, `on…` attribute or `javascript:` URL; every `src`, `srcset`, `poster`, `action` and SVG `href` same-origin (02 §5) |
| `:headings` | the component's top headings are at the context's level, and rendering at level 3 moves every heading one level down, stopping at `h6` |
| `:names` | every `<img>` has `alt`; every `role="img"` and `<svg role="img">` is named; every button, link and form control is named (text, `aria-label`, `aria-labelledby`, `title`, or for a control a `<label>`); `aria-pressed`, `aria-expanded`, `aria-current` and `aria-busy` take their legal values; every `aria-labelledby`, `aria-describedby` and `aria-controls` names an element of the render |
| `:keyboard` | no positive `tabindex`; each composite widget (`role` `grid`, `tree`, `tablist`, `listbox`, `radiogroup` or `toolbar`, or a focusable `role="img"`) holds at most one tab stop, itself included; no `role="menu"` |
| `:colors` | every literal color in a presentation attribute (`fill`, `stroke`, `color`, `stop-color`, `flood-color`, `lighting-color`) is on an element whose `data-mw-cue` names its cue; `var(--mw-…)`, `currentColor`, `none`, `transparent` and `inherit` are not literals |
| `:ids` | ids are unique within a render, the same in two renders of one assigns, every one starts with the instance's id, and two instances' renders share none |
| `:drawn` | each of the eight drawn states, assigned in turn, renders in each mode with text a person reads (text content, or a named `role="img"`); never blank |
| `:budget` | `budget/4` answers `{:ok, _}` for each slot of each fixture at `{320, 200}`, `{640, 400}` and `{1280, 800}` |
| `:contained` | for a `:contained` component: `init`, `delivery` for each delivered slot, `size`, and `bound` for each bindable parameter at its default, each answering a value that renders; equal inputs give equal values. A `:pure` component passes with no finding |
| `:bindings` | for each fixture with bindings, each kind, in live mode: the component reads each slot's fields from the context's bindings (02 §2). The kit renders once as given, then again with the fields bound in one slot renamed to fresh tokens (`mwbound0`, `mwbound1`, …) in that slot's delivery (row-map keys by either spelling, or `names:` for tuple rows, and `types:`) and in the context's bindings, a `:contained` component's value rebuilt from the renamed deliveries. Each token is mapped back to its field in the second render's markup, so a component that labels a header or an axis by field name still passes, and drawn-token values are not compared. The two must read the same, else `{:ignores_binding, slot}`. A fixture without bindings is not probed |

**Findings name where and what failed** (`{:kinds, {{"fixture 1", :navigation, :live}, {:unnamed_nav, "nav(0)"}}}`, `{:delivery, {where, {:style_attribute, "p#kit-a-x"}}}`, `{:ids, {where, {:unstable, id}}}`), an element as its tag and its id or document position, so a finding reads without the render at hand. `format/1` words one as `check (fixture, kind, mode): what`.

**Isolation.** A check runs a component's callbacks in the caller's process: a raise is the test's failure, with its stacktrace, which is what a component author needs. A host isolates components by process; the kit does not.

```test:kit-checks
every check is failed by a component built to break it, with the finding that names the rule, and every check is passed by the honest components
```

```test:kit-bindings
a component that reads its fields from the context's bindings passes the bindings check, whatever shape its rows take; one that hard-codes a field name is found ignoring the binding, naming the slot; a fixture without bindings is not probed; a contained component's value is rebuilt from the renamed deliveries
```

```test:kit-drawn-budget-contained
every drawn state is checked in every mode, a blank one is a finding; a bad budget is a finding per slot and size; a contained component's transitions are checked and must be pure
```

## 3. Fixtures {#components-kit-fixtures}

A component whose declarations depend on its settings ships **a fixture set**, one fixture for each distinct declaration shape (for visualize: one per mark, frame kind, backend and scene), and the kit runs over every one. A fixture is a map:
- `name`: how a finding names it, `"fixture <index>"` by default;
- `settings`: the settings, `%{}` by default;
- `deliveries`: a delivery per slot, `%{}` by default;
- `events`: the event names the fixture's interaction produces, checked as declared, `[]` by default;
- `bindings`: the cell's resolved bindings, in the shape of the context's `bindings` (02 §2), `%{}` by default. Every context the kit builds for the fixture carries them, so every check renders with them, and the `:bindings` check probes them.

An unknown key is refused with `ArgumentError`.

```test:kit-fixtures
the kit runs every fixture and names a finding by its fixture; defaults fill a bare fixture, and an unknown key is refused
```

## 4. Check sets {#components-kit-sets}

A **check set** adds checks for a family of components. `check_sets/0` lists the sets, and `checks(set)` a set's checks, in order; an unknown set raises `ArgumentError`. A set's checks run after the thirteen, for each fixture, and their findings are shaped like any other's.

**The visual check set**, `:visual`, for components that draw data (visualize's visuals):

| Check | Holds |
|---|---|
| `:image` | the drawing is a `role="img"` element (an `<svg role="img">` or another element), named, with a description: an `aria-describedby` naming an element of the render, or an SVG `<desc>` |
| `:table` | a `<table>` beside it in the render, named by a `<caption>` or `aria-label`, whose header cells are `<th>` with `scope` |
| `:tab_stop` | the render holds exactly one tab stop in live mode |
| `:token` | the drawing carries `data-mw-token` in live and socketless mode; two renders of one assigns carry one token, and two fixtures with equal settings and different deliveries carry different ones (the drawn-token rule, [macaw_data 01 §8.1](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-event-rules)). A fixture set with no such pair is `{:no_probe, :token}`: the set must give the check two deliveries to tell apart |
| `:svg` | socketless, neutral and print each render an `<svg>`, and no `<canvas>` |

**Adopters run it** in their own CI whenever `macaw_component` is present (visualize#946).

```test:kit-visual
the visual set finds a drawing without a role, name or description, no table or one without scoped headers, other than one tab stop, a token that doesn't follow the data, and a canvas outside live
```
