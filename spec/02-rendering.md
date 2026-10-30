# 02 — Rendering {#rendering}

How a component renders: with what (§1, §2), in which modes (§3), to which rules (§4, §5), in which drawn state (§6), and, for a `:contained` component, from what value (§7). The client-side protocols every adopter shares, and the module that implements them for hooks, are §8.

## 1. The assigns {#components-assigns}

`render(kind, assigns)` receives a map with these atom keys, built by `Macaw.Component.Assigns.new/1`, which refuses a missing key or one it doesn't know (`{:error, faults}`):

| Key | Value |
|---|---|
| `context` | the `%Macaw.Component.Context{}` it renders in (§2) |
| `settings` | its validated settings, bound parameters at their current values (01 §1.1) |
| `declarations` | its `%Macaw.Component.Declarations{}` for those settings |
| `drawn` | its drawn state (§6) |
| `deliveries` | for a `:pure` component, the latest `Macaw.Data.Delivery` of each bound slot, by slot name; a slot not delivered yet is absent |
| `value` | for a `:contained` component, its value (§7); `nil` for a pure one |

A HEEx render reads them as `@context`, `@settings` and so on. Nothing else reaches a component: not the viewer, not another component, not the page.

```test:assigns-keys
assigns are built from the six keys, a missing or unknown key is a fault, and a pure component's value is nil
```

## 2. The context {#components-context}

`%Macaw.Component.Context{}`, built by `Macaw.Component.Context.new/1` from a keyword list or a map, every fault at once:

| Field | Value | Default |
|---|---|---|
| `mode` | one of the four modes (§3) | required |
| `instance` | the instance's id ([macaw_compose 01](https://github.com/dcoai/macaw/blob/main/spec/01-vocabulary.md#vocab-structure)), a non-empty string of letters, digits, `-` and `_` | required |
| `size` | `{width, height}` in CSS pixels, positive numbers: the measured container, or the placement's declared size until the first measurement | required |
| `measured` | whether `size` was measured | `false` |
| `root_font_size` | the root font size in CSS pixels, a positive number | `16` |
| `heading_level` | the level of the component's own top headings, 1 to 6 | `2` |
| `theme` | a `%Macaw.Layers.Theme{}` | `Macaw.Layers.Theme.default()` |
| `preferences` | `%{zone, units, shortcuts}`: a time zone name, one of `Macaw.Data.Quantity.systems/0`, and which page shortcuts are on with their keys | `%{zone: "Etc/UTC", units: :as_posted, shortcuts: %{}}` |
| `now` | the holder's now, a `DateTime`, which events carry as their time | required |
| `bindings` | the cell's resolved bindings, `%{slot => %{role => field \| [field, …]}}`: slot and role names and fields are non-empty strings, a `many` role's fields a non-empty list | `%{}` |

- **The host computes it.** On a page, the core computes each instance's context; elsewhere (a visualize chart in a plain LiveView, a test) the adopter builds one. The component never knows which ([macaw_compose 05 §7](https://github.com/dcoai/macaw/blob/main/spec/05-components.md#components-libraries)).
- **`now` is never a clock read** by the component: a Macaw surface supplies its own clock, which tests and replays control. A standalone holder may default its now to the wall clock, injectably ([macaw_data 01 §8.1](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-event-rules)).
- **`Context.heading(context, depth)`** is the heading element for a heading `depth` levels below the component's top (`0` for its top), `"h<level + depth>"`, never past `"h6"`, so a component never hard-codes a level.
- **The binding arrives in the context.** The host computes `bindings` from the cell's binding of each slot, resolved by `Macaw.Component.Slot.resolve/3` (01 §1.3): an unbound `window` role holds the window field it reads, and an unbound optional role is absent, so a component never repeats the defaulting rule. A bad binding is a fault at its path under `[:bindings]`. **`Context.field(context, slot, role)`** answers the field bound to a role, the list of fields for a `many` role, or `nil` for a slot or role not bound. The rows keep the source's names; the component reads them by the bound field. This keeps §1 true: the binding reaches a component inside its context, and a contained component's `init/2` receives it too.
- **`Context.id(context, local)`** is an element id unique to the instance, `"<instance>-<local>"`, `local` a non-empty string of letters, digits, `-` and `_`; so two instances never share an id and an id is stable across renders (§5).

```test:context-new
a context defaults its font size, level, theme and preferences; every bad field is a fault at once; an unknown field is a fault
```

```test:context-bindings
bindings default to %{}, carry each slot's resolved role-to-field map, and a bad slot, role or field is a fault at its path under bindings; field/3 answers a role's field, a many role's list, or nil
```

```test:context-helpers
heading/2 counts from the context's level and stops at h6; id/2 prefixes the instance and refuses a bad local part
```

## 3. Rendering modes {#web-modes}

The modes and each mode's rules are `macaw_component`'s (macaw_compose#137): a component renders socketless, neutral and print without a page. Choosing a page's mode is the core's and `macaw_live`'s.

| Mode | Use | Notes |
|---|---|---|
| live | a connected LiveView | hooks attached; a visual may draw marks on a canvas |
| socketless | bots, black holes, no JS, the first render | complete HTML and SVG, never canvas; native behaviors only; the first render from the deliveries |
| neutral | base renders for records, before any delivery ([macaw_compose 08](https://github.com/dcoai/macaw/blob/main/spec/08-records.md#records-content)); print | as socketless, with no hooks, scripts, tokens, live regions or per-viewer markup |
| print | print and PDF output | as neutral, in the print theme and the automatic print layer, laid out in the print box |

`Macaw.Component.Mode.all/0` is the four in this order. `allows?(mode, feature)` answers whether a mode allows a feature, from this table:

| Feature | live | socketless | neutral | print |
|---|---|---|---|---|
| `:canvas` | yes | no | no | no |
| `:hooks` (`phx-hook`) | yes | yes | no | no |
| `:scripts` (a static `<script src>` from `'self'`) | yes | yes | no | no |
| `:tokens` (drawn tokens, [macaw_data 01 §8.1](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-event-rules); CSRF tokens) | yes | yes | no | no |
| `:live_regions` | yes | yes | no | no |
| `:per_viewer` (markup that differs by viewer) | yes | yes | no | no |

A socketless render keeps its hooks because it is also the first render of a live page: the hooks attach when the socket connects, and do nothing until then. An unknown mode or feature raises `ArgumentError`: it is a programming error, not data.

```test:modes-table
all/0 is the four modes in order and allows?/2 answers the table for every mode and feature, raising for an unknown one
```

## 4. Kinds' output rules {#components-kind-rules}

Each kind (01 §2) carries rules its output is checked against by the kit (04 §2):
- **`:navigation`** renders a `<nav>` named by `aria-label` or `aria-labelledby`, whose links are `<a href>`. A menu is a **disclosure navigation**: buttons with `aria-expanded` and `aria-controls`, nested lists, `aria-current="page"`; never `role="menu"`.
- **`:control`** renders real form controls (`<button>`, `<input>`, `<select>`, `<textarea>`), each named.
- **`:container`** renders an accessible pattern, one of: a tab list (`role="tablist"` of `role="tab"` elements with `aria-controls` naming `role="tabpanel"` elements); a disclosure (`<details>` with a `<summary>`, or a button with `aria-expanded` and `aria-controls`); a dialog (`<dialog>`, or `role="dialog"` with `aria-modal` and a name). Its panes are the markup its host hands it in `@settings["panes"]`, each a safe value; making them surfaces, rendering them lazily and computing what depends on them are the core's ([macaw_compose 05 §5](https://github.com/dcoai/macaw/blob/main/spec/05-components.md#components-containers)).
- **`:content`** carries the rules every component does (§5) and no rule of its own.

```test:kind-rules
each kind's rules are checked on its output: a labeled nav of links, named real controls, one of the container patterns, and role=menu refused
```

## 5. Rendering rules {#components-rendering}

- **Server first, complete without a socket.** Native HTML wherever it gives behavior: `<details>`, `popover`, `<dialog>`. (dcotek_web.md C3.)
- **Size by container queries, never by viewport,** so one component works in any region ([macaw_compose 10](https://github.com/dcoai/macaw/blob/main/spec/10-web.md#web-responsive)). A component that lays out on the server (a chart computing scales and ticks) reads the **size and root font size** in its context. Until the first measurement, it lays out at the size its placement declares.
- **Colors by the theme's rules** ([macaw_layers 04](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes-rules)): drawing colors from roles, as `var(--mw-…)` properties or the theme's classes; **data colors** as typed content **with a cue**: an element carrying a literal color says which non-color cue it carries, `data-mw-cue` one of `glyph`, `dash`, `pattern`, `label` or `position`, so color is never the only signal. Literal colors are refused otherwise, under the `:roles` profile every Macaw page validates against.
- **Headings at the level given by context,** through `Context.heading/2`, never hard-coded ([macaw_compose 10 §4](https://github.com/dcoai/macaw/blob/main/spec/10-web.md#web-a11y)).
- **Names and states.** Every control and image is named; states are exposed (`aria-pressed`, `aria-expanded`, `aria-current`, `aria-busy`) with their legal values; every `aria-labelledby`, `aria-describedby` and `aria-controls` names an element of the render.
- **Keyboard.** No positive `tabindex`. **A composite widget is one tab stop** with arrows inside (charts, grids, trees, tab sets, list boxes, toolbars). Key handling is focus-scoped unless declared as a page shortcut (01 §1.6).
- **Element ids** come from `Context.id/2`: unique within the render, the same for the same assigns, derived from content structure (a section's position, an item's declared identity), never from a counter or a clock, so attention aggregates across builds (dcotek_web.md C3).
- **Links and navigation as events or host link helpers.** A component never navigates by itself; its placement maps events to actions ([macaw_compose 06](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-actions)).
- **Announcements are requested, never owned.** A component never renders a live region (01 §1.6).
- **Styles and loads by the delivery rule** ([macaw_compose 10 §1](https://github.com/dcoai/macaw/blob/main/spec/10-web.md#web-csp)): no `style` attribute, no `<style>` element, no inline script, no `on…` attribute, no `javascript:` URL, and nothing loaded from another origin (every `src`, `srcset`, `poster`, `action` and SVG `href` same-origin; a link's `href` may go anywhere, since following it is navigation, not a load). A component's part is to declare what the rule needs (01 §1.8) and to give every first render a static form.
- **Each mode's rules** are §3's: canvas only in live mode, complete SVG and HTML otherwise, no hooks, scripts, tokens or live regions in neutral and print.
- **The budget holds in every mode** (macaw_compose#29). Each slot's budget (01 §1.4) is evaluated at **that mode's size**, never the viewer's window: socketless, neutral and the first live render at the size the placement declares, since no measurement exists yet; live, after the first measurement, at the measured container; print at the print box. The host ceiling applies in every mode, and no mode hands a component unbudgeted rows.
- **Every drawn state has a static render** (§6), so neutral and print show it without hooks.

These are checked by the kit (04 §2), each rule a check.

```test:rendering-rules-checked
the kit finds each rule broken by a render that breaks it, and nothing in a render that keeps them all
```

## 6. Drawn states {#components-states}

**Every component is always in exactly one drawn state:** `crashed`, `down`, `invalid`, `loading`, `no_data`, `stale`, `capped` or `live`, in that precedence. `capped` says the rows drawn are fewer than the data: the source capped them, the runtime reduced them, or the component drew fewer than it was handed. Each has a theme role, a glyph and words, and is never blank. (visualize.md C3.)

`Macaw.Component.Drawn`:
- `all/0` is the eight in precedence order. `pick(states)` is the one of highest precedence among a list, `:live` for `[]`: a host with a slot loading and another stale shows `loading`, and a component that draws fewer rows than it was handed picks `capped` over its assigned `live`.
- `role/1` is the state's theme role ([macaw_layers 04](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md)): `crashed` and `down` `:bad`, `invalid` and `stale` `:warning`, `loading` and `capped` `:info`, `no_data` `:neutral`, and `live` `nil`. `glyph/1` is that role's cue glyph (`Macaw.Layers.Theme.cue/1`), `nil` for `live`.
- `words/1` is the state's words: "Couldn't be drawn", "Source unavailable", "Invalid settings", "Loading", "No data", "Out of date", "Showing part of the data", and `nil` for `live`.
- `render(state, context)` is a static notice for a state other than `live`, which a component may draw as its own: `<p class="mw-drawn mw-drawn-<state>" data-mw-drawn="<state>">`, a glyph element with the role's class and `aria-hidden="true"`, then the words. It is not a live region, so it holds in every mode. `render(:live, context)` is empty.

How a host computes the state from deliveries and faults (a delivery's `capped` and `reduced_by`, its age against the source's continuity, a crashed process) is the host's.

```test:drawn-states
all/0 is the eight in precedence order and pick/1 the highest of a list; every state but live has a role, a glyph and words; the static notice is never blank and is not a live region
```

## 7. The contained value {#components-contained}

**A `:contained` component, one with server work, is a pure value with transitions** (macaw_compose#22, R6):

```
init(settings, context)          → value
delivery(value, slot, delivery)  → value
size(value, size)                → value
bound(value, name, new)          → value      # a bound parameter or state source changed
render(kind, assigns)            → markup     # assigns.value is the value
```

- **The value is pure.** Equal inputs give equal values; a transition does no I/O, reads no clock and starts no process. Server work (a scene's simulation, a layout that takes time) is what the value computes, and its host decides where that runs.
- **The process around the value is the host's:** under Macaw, `macaw_live`'s contained cell, heap-limited and restarted with a backoff, shown as `crashed` meanwhile; in an adopter's own host, whatever it uses (a LiveView's assigns, a test). The value never knows which. (visualize.md C13; dcotek_web.md C13.)
- **The dispatch functions** `Macaw.Component.init/3`, `delivery/4`, `size/3` and `bound/4` call a contained component's transitions, refusing a `:pure` component with `ArgumentError`.

```test:contained-transitions
a contained component's value moves through init, delivery, size and bound, and the dispatch functions refuse a pure component
```

## 8. The client protocols {#components-client}

Two things on the client are **found, not created per component**, so a component behaves the same on a Macaw page and off one, and two standalone components, or one beside a Macaw surface, share them ([macaw_compose 10 §4, §6](https://github.com/dcoai/macaw/blob/main/spec/10-web.md#web-a11y)). Their fixed names are `Macaw.Component.Client`'s:
- **the announcer:** `announcer_ids/0` is `%{polite: "mw-announcer-polite", assertive: "mw-announcer-assertive"}`. The first hook to mount on a page without them creates the two regions at the end of the body; every later one reuses them. A hook requests an announcement by dispatching `announce_event/0`, `"macaw:announce"`, on its element, bubbling, with detail `{name, text, politeness}`; a server request is an event carrying 01 §1.6's request;
- **the client bus:** `bus_name/0` is `"MacawBus"`, the property of `window` it lives under. A hook publishes and subscribes only to the `local` keys its component declares, domain values only, never pixels; nothing on it reaches the server.

```test:client-names
the announcer's ids, the announce event's name and the bus's name are the fixed values every adopter uses
```

### 8.1 What a component declares, on the client {#components-client-attributes}

The client learns a component's names **from its declarations, rendered**, never from a list of its own (macaw#142). `Client.attributes(declarations)` is two data attributes, each a JSON list of strings:
- **`data-mw-announces`** (`announces_attribute/0`): the `announces` names, in declared order;
- **`data-mw-local`** (`local_attribute/0`): the `local` keys, sorted.

Both are always present, `[]` when nothing is declared, so a component that declares nothing has nothing accepted. A component puts them on the element its hook is attached to, or on an ancestor of it within the component: `<div phx-hook="Cards" {Client.attributes(@declarations)}>`. The client reads them from the **nearest** element carrying them, the hook's element or an ancestor, at each request, so declarations that follow settings are read as rendered. JSON is this attribute's encoding at the edge; the declarations themselves are terms (macaw#188).

```test:client-attributes
the two attributes are rendered from the declarations: exactly the declared announcement names and local keys, escaped and read back, and empty lists when nothing is declared
```

### 8.2 The shared client module {#components-client-module}

The package ships **one ES module implementing both for hooks**, `Client.module_path/0`, `priv/static/macaw_component/client.js`: no build step, no import of anything, no third-party code (macaw#142). `priv` is among the package's files.
- **Served** from `'self'` by the host, as the rest of `priv/static`:

  ```elixir
  plug Plug.Static, at: "/", from: {:macaw_component, "priv/static"}, only: ~w(macaw_component)
  ```

- **Imported** by a hook from `Client.module_url/0`, `"/macaw_component/client.js"`: `import { announce, bus } from "/macaw_component/client.js"` (01 §1.8). A page holds one instance of it however many hooks import it.

**Its exports:**
- **`findAnnouncer()`** answers `{polite, assertive}`, the two regions, found by their ids. On a page without them, the first call creates them at the end of the body (`aria-live` of their politeness, `aria-atomic="true"`, visually hidden through the CSSOM, never a `style` attribute, §5) and becomes **their announcer**: it alone listens for the announce event. Where the regions were found, their creator announces (`macaw_live`, or the hook that made them), so a page has one queue.
- **`announce(el, {name, text, politeness})`** finds the announcer and dispatches the announce event on `el`, bubbling. The announcer:
  - **drops** a request whose `name` the component doesn't declare in `announces` (by §8.1's attribute nearest the event's target), whose `text` is empty, or whose `politeness` is neither `"polite"` nor `"assertive"`, `"polite"` when absent; as `Announcement.new/2` refuses on the server (01 §1.6);
  - **queues** each politeness's requests on its own region, and **merges** a request whose name is already waiting: the newer text replaces the older, in the older's place;
  - **rate-limits** each region to one announcement per `names.intervalMs`, 500 ms: an idle region is written at once, and the next waits out the interval. The same words twice in a row are written with a trailing no-break space, so a screen reader reads the repeat.
- **`bus()`** answers `window.MacawBus`, created by the first call on a page without one (`macaw_live` provides it when present). It is two functions, the protocol any bus under that name keeps:
  - **`publish(el, key, value)`** hands `value`, as given, to every subscriber of `key`, the publisher's own included, as `callback(value, el)`, so a hook skips its own echo by the source;
  - **`subscribe(el, key, callback)`** answers the function that unsubscribes;
  - each **refuses** a key `el`'s component doesn't declare in `local` (§8.1) by throwing an `Error` naming it, and nothing is delivered then: an undeclared key is the hook's bug, surfaced where it is made.
- **`names`**, the fixed names above, frozen, the ones `Macaw.Component.Client` answers.

**Values pass through uninspected** (macaw#188). The bus checks keys, never values: a `local` key's type is its domain type (01 §1.5), and how a value of a local type is written on the client (a time as epoch milliseconds, a window as a pair) is **that component's adapter**, agreed between the components sharing the key's name. The bus neither encodes nor validates it.

```test:client-module
the module is at its path in the package's priv/static, served at its url, holds each fixed name, imports nothing, and refuses undeclared names and keys
```

```test:client-package
the package's files include priv, so the module ships on Hex
```

**Gap:** the module's behavior in a browser (finding and creating the regions, queuing, merging, rate-limiting, dropping, the bus's delivery and refusals) is **untested** until the example app's keyboard and axe-core CI exists ([macaw_compose 10 §4](https://github.com/dcoai/macaw/blob/main/spec/10-web.md#web-a11y)). The tests here read the module as text: its place, its names and the presence of its refusals.
