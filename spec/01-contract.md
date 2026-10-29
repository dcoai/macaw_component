# 01 — The contract {#contract}

A **component** is a registered implementation of one public contract, `Macaw.Component`. Built-in and third-party components use the same contract ([macaw_compose 00](https://github.com/dcoai/macaw/blob/main/spec/00-overview.md#overview-goals) goal 8). Each declaration buys a composition effect (goal 1, rule 1): a proposed addition to the contract states which effect it enables, or it doesn't belong.

## 1. The behavior {#components-behavior}

A component is a module that uses `Macaw.Component`:

```elixir
defmodule MyApp.Cards do
  use Macaw.Component,
    name: "my_app.cards",
    kinds: [:navigation, :content],
    hooks: %{"Cards" => "priv/static/cards.js"},
    assets: ["priv/static/cards.css"]

  @impl true
  def parameters, do: %{"columns" => %{type: :number, default: 3, values: [1, 2, 3, 4]}}

  @impl true
  def declarations(settings) do
    {:ok, slots: %{"items" => %{requires: %{"title" => %{type: :text}}}},
          events: ["open"], reading: :scan}
  end

  @impl true
  def render(:navigation, assigns), do: ~H"<nav aria-label={@settings[\"label\"]}>…</nav>"
  def render(:content, assigns), do: ~H"<ul class=\"cards\">…</ul>"
end
```

**Two sorts of declaration** (macaw_compose#22, R2):
- **Static declarations** are the module's, the same for every use: its **name**, its **kinds** (§2), its **parameters** (§1.1), its **client hooks** and its **static assets** (§1.8). The registry and a host read them without calling the component with settings: kinds to place it, parameters to validate its settings, hooks and assets to serve and import them before any page exists.
- **Configured declarations** are everything else: the value of the pure function `declarations(settings)`, called with the component's validated settings when a document is validated ([macaw_compose 07](https://github.com/dcoai/macaw/blob/main/spec/07-documents.md#documents-validation-time)). A component whose behavior is fixed returns the same value for any settings; a component whose behavior is data computes it: a visualize visual's slots, events and state writes follow from its design.

**`use Macaw.Component`** takes `name:` and `kinds:`, both required, and `hooks:` and `assets:`, both optional, and nothing else; a missing or unknown option is refused at compile time with an `ArgumentError` naming it. It declares the behavior, defines `__component__/0`, which answers `%{name: name, kinds: kinds, hooks: hooks, assets: assets}`, and defines overridable defaults for the optional callbacks below. The values are checked when the module compiles:
- **`name`** is the component's name in documents: a string of lower-case words (`[a-z][a-z0-9_]*`) joined by dots, so a package prefixes its components' names with its own (`visualize.visual`). Names are matched by spelling; **no atom is ever made from one**.
- **`kinds`** is a non-empty list of distinct kinds (§2).
- **`hooks`** and **`assets`** are §1.8's.

**The callbacks:**

```elixir
@callback parameters() :: %{String.t() => Macaw.Data.Parameter.t()}
@callback declarations(settings :: %{String.t() => term()}) ::
            {:ok, keyword() | map()} | {:error, [fault]}
@callback render(kind, assigns :: map()) :: Phoenix.HTML.safe()      # any Phoenix.HTML.Safe value
@callback budget(slot :: String.t(), settings :: map(), size :: {number(), number()}) ::
            pos_integer() | nil                                       # optional, §1.4
# a :contained component's transitions, §7 of 02:
@callback init(settings :: map(), Macaw.Component.Context.t()) :: value
@callback delivery(value, slot :: String.t(), Macaw.Data.Delivery.t()) :: value
@callback size(value, {number(), number()}) :: value
@callback bound(value, name :: String.t(), new :: term()) :: value
```

- **`parameters/0`** defaults to `%{}`, and **`declarations/1`** to `{:ok, []}`; `budget/3` and the transitions are optional callbacks with no default.
- **`render/2`** answers any value of the `Phoenix.HTML.Safe` protocol: a HEEx render, `{:safe, iodata}`, or a string, escaped.

**The dispatch functions** in `Macaw.Component` are how a host reaches a component. Each answers a value and never raises for a component's bad answer:
- **`component?/1`**: whether a module is loaded and uses `Macaw.Component`. **`info/1`** answers its `__component__/0`, or `:error` for a module that is not a component.
- **`parameters/1`**: `{:ok, parameters}` when every parameter passes `Macaw.Data.Parameter.check/1`, every name is a non-empty string and every bindable parameter has a default (§1.1), else `{:error, faults}`, each fault's path starting at the parameter's name.
- **`settings/2`**: given settings checked against the parameters by `Macaw.Data.Parameter.validate/2`, defaults filled in: `{:ok, settings}` or `{:error, faults}`.
- **`declarations/2`**: settings validated by `settings/2` first, then `declarations/1` called and its answer built by `Macaw.Component.Declarations.new/2` (§1.2): `{:ok, %Declarations{}}` or `{:error, faults}`. An answer of neither shape is `{:error, [{[], {:bad_declarations, answer}}]}`.
- **`budget/4`**: `{:ok, nil}` for a component without `budget/3`; otherwise `{:ok, rows}` for a positive integer or `nil`, and `{:error, {:bad_budget, answer}}` for anything else.

**Faults** are `{path, reason}` pairs, the path a list of keys from the declaration's root, every fault at once, ordered by path (as in [macaw_data 01 §1.8](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-schema-faults)). `Macaw.Component.format_fault/1` words one as a line a person reads.

**Errors are values; renders are not guarded.** A component's raise in `render/2` or a transition is a crash its host's process takes, shown as the `crashed` drawn state (02 §6). Nothing in this library catches it.

```test:behavior-use
use defines __component__/0 from its options, refuses a missing name or kinds, an unknown option, a name that is not dotted lower-case words, an empty or unknown or duplicated kind, at compile time; the optional callbacks default
```

```test:behavior-dispatch
component?/1 and info/1 tell a component from another module; parameters/1 checks every parameter by name; settings/2 validates and fills defaults; budget/4 answers nil without budget/3 and refuses a bad answer
```

```test:behavior-declarations
declarations/2 validates settings before calling the component, builds its answer, and answers a bad_declarations fault for an answer of neither shape; faults format as lines
```

### 1.1 Parameters {#components-parameters}

A component's settings schema is a map of **parameters**, one shape for every component, so the registry, the page validator, builder forms and an AI author read one form (macaw_compose#15). **The shape, `conforms?/2` and its validation are `Macaw.Data.Parameter`'s**, specified in [macaw_data 01 §2.2](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-parameters): sources take parameters before any component exists, so macaw_data owns the shape and components use it (the owner's decision, 2026-10-27, macaw_compose#109). What follows is how components use it.

**Parameters are static** (macaw_compose#137): `parameters/0` takes no settings, because settings are validated against it before `declarations/1` is called. A parameter whose legal values depend on data says so with `legal_for: {slot, field, fact}`, which the host that binds the slot resolves; the parameter itself doesn't change.

**Types.** A parameter's `type` is one of:
- a **data-model type** (`:time`, `:number`, `:category`, `:text`, `:color`, `:point`, [macaw_data 01](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-data));
- **`{:document, type}`**, a nested document of a document type, validated by its own kernel rules: how a whole visualize design is a cell's settings;
- **`:term`**, any value the component validates itself in `declarations/1`, allowed only for documents migrated from untyped forms (visualize's old variables), never for new parameters.

A parameter's value in a document is a literal, or, when the parameter is `bindable`, a **binding to a state source**: `bins: {:state, "bins"}` ([macaw_compose 03](https://github.com/dcoai/macaw/blob/main/spec/03-state.md#state-sources)). Binding is closed by default: a parameter is bindable only when its component says so. Resolving a binding is the host's: a component always receives values.

- **A bindable parameter has a default** (`:bindable_without_default`), which is its value until its state source has one.
- **Declarations never read a bindable parameter,** so a binding can never change the page's shape after validation. `declarations/2` calls `declarations/1` with every bindable parameter at its **default**, whatever the settings give, and the kit checks that changing one changes no declaration (04 §2). The budget is the one exception (§1.4): it is a function evaluated at runtime, under a ceiling fixed at validation.
- **A change to a bound parameter re-applies the component:** the host passes the new value through `bound/3` (02 §7), or, for a `:pure` component, renders it with the new settings. It re-fetches only when the slot's budget changes.
- A design variable in visualize is a parameter (visualize#889); old untyped variables migrate as type `:term`.

```test:parameters-static
declarations/2 calls declarations/1 with every bindable parameter at its default whatever the settings give, and a parameter with a bad declaration or name is a fault at its name
```

### 1.2 Declarations {#components-declares}

`Macaw.Component.Declarations.new(answer, module)` builds the configured declarations from `declarations/1`'s answer, a keyword list or a map with atom keys, into `%Macaw.Component.Declarations{}`, checking every key, every fault at once; a key not in this table is `:unknown_key` at its path. `keys/0` is the keys in this table's order.

| Key | Value | Default | Buys |
|---|---|---|---|
| **`slots`** | typed inputs, by name, each with its requirements (§1.3) | `%{}` | any source works; faults found at validation (visualize.md C1) |
| **`writes`** | the **standard** state sources it writes, each with the value type it writes (§1.5) | `%{}` | interaction without wiring ([macaw_compose 03](https://github.com/dcoai/macaw/blob/main/spec/03-state.md)) |
| **`local`** | the `:local` keys it shares on the client bus, each with its domain type (§1.5) | `%{}` | shared hover and brush without the server |
| **`events`** | the names of the events it emits (§1.6) | `[]` | accurate view paths; cell actions |
| **`announces`** | the names of the announcements it may request (§1.6) | `[]` | one coordinated announcer |
| **`observes`** | what it can observe, a subset of the closed vocabulary (§1.6) | `[]` | disclosure that matches (dcotek_web.md C3, C12) |
| **`shortcuts`** | the page shortcuts it offers (§1.6) | `[]` | page-wide keys under the viewer's control (WCAG 2.1.4) |
| **`reading`** | its reading load (§1.7) | `:glance` | reading vs skimming vs glancing (dcotek_web.md C3) |
| **`words`** | a word count, only with `reading: :read` | `nil` | attention over prose |
| **`stylesheets`** | generated stylesheets, each a CSS string, content-addressed (§1.8) | `[]` | self-contained base renders under a strict CSP |
| **`proxy_routes`** | media it needs from another origin (§1.8) | `[]` | nothing from another origin |
| **`isolation`** | `:pure` or `:contained` (§1.9) | `:pure` | a crash never takes down the page |
| **`access`** | the capability a viewer needs to see it, or `nil` (§1.9) | `nil` | consistent gating |

The static declarations (§1) and the render (02) complete what a component declares: **kinds**, **parameters**, **client hooks** and **static assets** are the module's; **element ids**, stable and derived from content structure, and **renders** in each mode are rules on its output (02 §5), checked by the kit; **drawn states** are every component's (02 §6).

**Names** throughout (of slots, roles, state, local keys, events, announcements, shortcut actions, hooks and proxy routes) are non-empty strings. `Declarations.new/2` makes no atom from any of them.

**`declarations/1` is pure:** no I/O, no clock, no process. Equal settings give equal declarations. Because it runs at validation, the page DAG, the CSP plan, the observation plan and every budget ceiling exist before anything renders. The kit checks purity by calling it twice per fixture (04 §2).

```test:declares-defaults
an empty answer builds the defaults of every key, keys/0 is the thirteen in order, and a keyword list and a map build the same declarations
```

```test:declares-faults
an unknown key, and a bad value under each key, are each a fault at its path, every one at once, ordered by path; no atom is made from a name
```

### 1.3 Slots {#components-slots}

A **slot** is a typed input: `%{requires: %{role => requirement}, doc: "…"}`. Each **role** is a field the component reads from the slot's source, with what it requires of that field:

| Requirement key | Value | Default | Meaning |
|---|---|---|---|
| `type` | one of the six data-model types, or a non-empty list of them | required | the field's type |
| `window` | a boolean | `false` | the field must be the source's window field ([macaw_data 01 §1.5](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-schema-window)) |
| `identity` | a boolean | `false` | the field must be declared identity ([§1.4 of the schema](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-schema-identity)) |
| `quantity` | one of `Macaw.Data.Quantity.all/0` | `nil` | the field must measure it |
| `many` | a boolean | `false` | the role takes one or more fields (a chart's series) |
| `optional` | a boolean | `false` | the role may be left unbound |
| `doc` | a string | `nil` | the role's meaning for a person |

A slot's `doc` is optional; a slot with no roles reads whole rows (a table showing every field).

**Checking a binding before data flows.** `Macaw.Component.Slot.check(slot, schema, fields)` checks a binding of the slot to a source of a `Macaw.Data.Schema`, `fields` mapping each role to the field (or, for a `many` role, the non-empty list of fields) it reads. It answers `:ok` or `{:error, faults}`, each at `[role]`, every one at once:
- `:unbound`: a required role with no field. **A `window` role left unbound reads the schema's window field**, so a time series binds by its data alone;
- `{:missing, field}`: no such field in the schema, compared by either spelling;
- `{:type, wanted, got}`, `:not_window`, `:not_identity`, `{:quantity, wanted, got}`: the field fails a requirement;
- `:many`: a list given for a role that takes one field, or an empty list;
- `:unknown_role`: a role the slot doesn't require.

Binding a slot (choosing its source and fields in a document) is the core's ([macaw_compose 06](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md)); the check is here, so a component author and every host check bindings the same way.

```test:slots-shape
a slot of roles with every requirement key builds; a bad type, a non-boolean flag, an unknown quantity or key is a fault at its path
```

```test:slots-check
a binding passes when every role's field meets its requirements; an unbound window role reads the window field; every fault of a bad binding is reported at its role, every one at once, by either spelling
```

### 1.4 Budget per slot {#components-budget}

A component that draws rows declares, for each slot, a **row budget** as a function of its settings and its measured size: `budget(slot, settings, size) → rows`, through the optional `budget/3` callback (§1). visualize's derivation (plot width by mark type, with a design override, its D-226, D-227 and D-230) is one implementation. It is called at runtime, so it may read bindable parameters' current values.

- **A component without `budget/3`,** and a slot it answers `nil` for, reads at the host ceiling.
- **The host ceiling clamps every slot.** A slot whose budget exceeds the ceiling reads at the ceiling, reported as `reduced_by: :runtime` ([macaw_data 01](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-delivery)), and draws those rows. A component is never handed nothing because it asked for too much.
- **Sources are pooled at the largest budget** among their readers, and each reader is reduced to its own, reporting how (`reduced_by`). Clamping and pooling are the host's ([macaw_data 01 §6](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-budgets)); the budget is the component's.
- **The budget holds in every mode** (macaw_compose#29), evaluated at that mode's size, never the viewer's window (02 §5).

```test:budget-answers
a component's budget is reached through budget/4 for each slot and size, nil without budget/3, and an answer that is not a positive integer or nil is a bad_budget error
```

### 1.5 State a component writes and reads {#components-state}

- **`writes`** names the **standard** state sources a component writes and the value type it writes to each: `writes: %{"selection" => :identity, "window" => :window}`. Their meaning is built into the component. It writes them **only by emitting events**; the host applies the event. Any other state source is the page author's, written through a cell action ([macaw_compose 06](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-actions)).
- **`local`** names keys in the `:local` scope it shares through the client bus (02 §8), with the domain type each carries: `local: %{"hover" => :time, "brush_band" => :window}`. Pixels never travel on the bus.
- **Exports** are not a component's declaration: the placement document declares them ([macaw_compose 03](https://github.com/dcoai/macaw/blob/main/spec/03-state.md#state-exports)).
- **A component reads state it doesn't write** through a parameter binding (§1.1) or a slot bound to the state source. It never reads another component.

**The vocabulary is `Macaw.Component.State`'s,** so a component and every host agree on it by construction:
- `standard/0`, the standard state sources and the value types each takes: `"selection"` takes `:identity`; `"window"` takes `:window`; a scene's `"camera"` takes `:camera` and its `"breakpoints"` take `:breakpoints`. A name not among them in `writes` is `{:not_standard, name}`; a type it doesn't take, `{:type, name, type}`.
- `types/0`, the value and domain types: `:time`, `:number`, `:category`, `:text`, `:point`, `:identity`, `:window`, `:box`, `:camera` and `:breakpoints`. A `local` key's type is one of the first eight.
- `conforms?(type, value)`: whether a value is of a type. `:identity` is a scalar (a string, a number or an atom other than a boolean) or a non-empty map of field to scalar; `:window` is `nil`, `%{last: seconds}` with positive seconds, or `%{from: a, to: b}` with both instants or both numbers, `a` not after `b`, either form with an optional `as_of` instant; `:box` is `%{west, south, east, north}` in degrees ([macaw_data's box](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-request)); `:camera` is a map and `:breakpoints` a list, whose meaning is the scene's; the data-model types are `Macaw.Data.Parameter.conforms?/2`'s.

The preferences (`theme`, `zone`, `units`, `shortcuts`) are state sources too, but a component never writes them: they reach it in its context (02 §2), and a theme chooser sets one through a cell action.

```test:state-vocabulary
standard/0 and types/0 are the vocabulary; writes outside it or of a type a source doesn't take are faults; a local key of a type that isn't a domain type is a fault
```

```test:state-conforms
conforms?/2 accepts each type's values and refuses others: identities scalar or map, windows of both forms with as_of, boxes in degrees, for generated values
```

### 1.6 Events, announcements, observation and shortcuts {#components-events}

**Events.** `events` names every event the component emits, in the shared struct, `Macaw.Data.Event` ([macaw_data 01 §8](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-event)); each emission carries its initiator.
- **Event names are unique within one component's declarations** (`{:duplicate, name}`). The events a component declares are every event it emits, including those its runtime raises when its configuration enables them (a visual's `brush`, `select` and `pick`). So a configuration that declares one of those names beside the runtime's is a fault naming both. A component kind's runtime names are reserved by being declared, for that kind only: another kind may use the same name for its own event. There is no namespace and no separate field: `initiator` already separates visitor from system, and one list of names is what view paths and records key on (macaw_compose#73, #91; visualize#955).
- `Declarations.emits?(declarations, name)` says whether a name is declared. A host drops an event whose name is not, and the kit checks that every event a component's fixtures produce is declared (04 §2).

**Announcements.** `announces` names the announcements the component may request. A request is `%{name, text, politeness}`, `politeness` `:polite` or `:assertive`, built by `Macaw.Component.Announcement.new(declarations, attrs)`, which answers `{:ok, request}` or `{:error, faults}`: an undeclared name is `{:undeclared, name}`, empty text `:empty`. Components never render a live region; the announcer is the host's ([macaw_compose 10 §4](https://github.com/dcoai/macaw/blob/main/spec/10-web.md#web-a11y)), and the client form of the request is 02 §8's.

**Observation.** `observes` is a subset of the closed vocabulary, `Macaw.Component.observations/0`: `view`, `dwell`, `hover_item`, `focus_item`, `activate`, `select`, `brush`, `copy` and `scroll_into_view`, in that order, given as atoms or their spellings and kept as atoms from the vocabulary. **Nothing is emitted unless the host enables it**, so a component used without a host plan reports nothing ([macaw_compose 10 §5](https://github.com/dcoai/macaw/blob/main/spec/10-web.md#web-observation)).

**Shortcuts.** `shortcuts` lists the page-wide shortcuts the component offers, each `%{key, action, description}`: `key` a `KeyboardEvent.key` value (a single printable character, or a named key such as `"ArrowUp"`), `action` a name, `description` a non-empty string for the help dialog. Two shortcuts on one key in one component are `{:duplicate_key, key}`. The page accepts or drops each, refuses two on one key across a page, and lets the viewer turn off or remap every single-character one; that registry is the host's. **Key bindings that aren't page-wide are focus-scoped** and need no declaration.

```test:events-unique
a duplicated event name is a fault naming it, emits?/2 answers declared names, and announcement requests are built only for declared names with text and a politeness
```

```test:events-observation-shortcuts
observes takes the vocabulary by atom or spelling and refuses anything else; shortcuts need a key, an action and a description, one per key
```

### 1.7 Reading load {#components-reading}

Every component declares its reading load, so attention analysis ([macaw_compose 08](https://github.com/dcoai/macaw/blob/main/spec/08-records.md#records-attention)) treats a chart differently from an article:
- **`:glance`:** a value, a chart's shape. The default.
- **`:scan`:** a table, a list, a visual over many items.
- **`:read`:** prose sections, which may also give a word count in `words`, a non-negative integer. `words` with any other reading load is `:words_without_read`.

It may depend on settings, never on delivered data, since it is a declaration: visualize derives `:scan` from a design that draws a table or many series, `:glance` otherwise.

```test:reading-load
reading is one of the three, glance by default; words is a count only with read
```

### 1.8 Assets, hooks, stylesheets and proxy routes {#components-assets}

Everything a component loads comes from `'self'` under the strict policy ([macaw_compose 10 §1](https://github.com/dcoai/macaw/blob/main/spec/10-web.md#web-csp)). A component declares what that needs, and the host serves it.
- **Client hooks** (static, `hooks:` on `use`): a map from a hook's name, as a LiveView hook is named (`"Cards"`, a capitalized word of letters and digits), to the path of its static file in the component's package, relative (`"priv/static/cards.js"`), ending in `.js`, without `..`. A hook may import sibling files of its package, and the shared client module, `"/macaw_component/client.js"` (02 §8.2), which the host serves from `macaw_component`'s `priv/static`. Macaw adds no build step and no third-party JS; a host imports the enabled packages' hooks in its own JS, which `macaw_live` generates from the registry.
- **Static assets** (static, `assets:` on `use`): paths of the same form, ending in `.css`, `.svg`, `.png`, `.webp`, `.woff2` or `.json`.
- **Generated stylesheets** (configured, `stylesheets`): CSS a document defines at runtime, such as a design's motion, under the delivery rule's third case. Each is content-addressed: `Macaw.Component.Stylesheet.path(css)` is `"/assets/" <> hex <> ".css"`, `hex` the lowercase SHA-256 of its bytes, so the same document always yields the same file and base renders capture it. A stylesheet with an `@import` or a `url(` that is not same-origin (a `data:` URL is allowed in `url(`) is an `:origin` fault at `[:stylesheets, index]`.
- **Proxy routes** (configured, `proxy_routes`): each `%{name, url, types}`: `url` an `https://` URL template whose `{name}` placeholders the component fills, and `types` the non-empty list of content types it accepts (`"image/png"`). The host mounts the one proxy, enables origins explicitly and refuses everything else ([macaw_compose 10 §1.1](https://github.com/dcoai/macaw/blob/main/spec/10-web.md#web-proxy)); `Macaw.Component.Proxy.path(component, route, values)` answers `{:ok, path}`, the same-origin path a render uses, `"/macaw/proxy/<component>/<route>?<values>"`, the values query-encoded in name order; a placeholder of the route's template without a value is `{:error, {:placeholders, missing}}`. So a page holds same-origin URLs only.

```test:assets-static
hooks and assets on use are checked at compile time: names, relative paths without .., known extensions
```

```test:assets-configured
a stylesheet's path is its SHA-256, the same CSS the same path; a stylesheet importing another origin is a fault; proxy routes need an https template and content types, and their paths are same-origin
```

### 1.9 Isolation and access {#components-isolation}

- **`isolation`**: `:pure` components (Markdown, cards) render in the page's process from their settings and deliveries. A **`:contained`** component, one with server work, is a pure value with transitions (02 §7), held by its host in a process of its own. Declaring `:contained` without exporting all four transitions is `{:missing, callbacks}` at `[:isolation]`.
- **`access`**: the name of the capability a viewer needs to see the component, a non-empty string, or `nil`. The host gates it before rendering, the same way for every component; the component never checks the viewer itself.

```test:isolation-access
contained isolation requires the four transitions, naming the missing ones; access is a capability name or nil
```

## 2. Kinds {#components-kinds}

A component offers one or more **kinds**, one `render/2` clause per kind:

```elixir
use Macaw.Component, name: "site.menu", kinds: [:navigation, :content]

def render(:navigation, assigns), do: ~H"<nav aria-label={@label}><ul>…</ul></nav>"
def render(:content, assigns),    do: ~H"<ul class=\"cards\">…</ul>"
```

- **The kinds** are `Macaw.Component.kinds/0`: `:navigation`, `:content`, `:control` and `:container`.
- **Kinds are checked against the clauses at compile time:** every declared kind has a `render/2` clause whose first argument is that kind or matches any value, and a clause for a kind the component doesn't declare is an error, so a missing clause never fails at runtime. A component without `render/2` doesn't compile.
- **A cell names its kind,** defaulting from where it sits; validating that the kind is offered and allowed there is the core's ([macaw_compose 05 §5](https://github.com/dcoai/macaw/blob/main/spec/05-components.md#components-containers)).
- **Each kind carries rules its output is checked against** (02 §4).
- **Kind and mode are separate axes.** Kind is the argument; mode comes in the context (02 §2). Most components render the same markup in every mode, and the host changes what it wraps around it.

(macaw_compose#8, question 2.)

```test:kinds-clauses
every declared kind needs a render clause, a catch-all covers them all, a clause for an undeclared kind or a missing render is a compile error, and kinds/0 is the four
```
