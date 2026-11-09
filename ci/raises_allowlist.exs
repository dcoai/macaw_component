# The raises macaw_component keeps, read by ci/raises.exs (#12, #34, dco-tek/macaw/macaw#243,
# spec/00 §4). Each entry names one function that raises, its class and why:
#
#   %{at: {Module, :fun, arity}, class: :bang | :compile | :mix_task | :invariant, reason: "..."}
#
# A raise outside the list fails the check, and so does an entry that matches no raise.
# Prefer answering a value.
[
  %{
    at: {Macaw.Component, :__using__, 1},
    class: :compile,
    reason: "use Macaw.Component's options are refused while the component compiles"
  },
  %{
    at: {Macaw.Component.Compile, :__before_compile__, 1},
    class: :compile,
    reason: "render/2's clauses are checked against the kinds while the component compiles"
  },
  %{
    at: {Macaw.Component.Conformance, :__using__, 1},
    class: :compile,
    reason:
      "use of the kit is refused while the test compiles: no component:, an unknown option or check set"
  },
  %{
    at: {Macaw.Component.Slot, :resolve!, 3},
    class: :bang,
    reason: "resolve/3's twin, for a binding the caller already checked"
  },
  %{
    at: {Macaw.Component.Context, :id, 2},
    class: :invariant,
    reason:
      "the local part is the component's own literal; a wrong one is the component's bug, which the kit's :ids check finds"
  },
  %{
    at: {Macaw.Component, :contained!, 1},
    class: :invariant,
    reason:
      "the core calls the transitions only on a module contained?/1 holds for; another is the caller's bug"
  }
]
