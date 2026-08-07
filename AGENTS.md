# Gapzilla iOS instructions

## Mandatory product semantic

- `EventKind.urge` is a raw observation that an urge occurred. It is not a successful outcome.
- Creation, editing, history, calendar legends, recent events, and raw counts must use `冲动 / Urge`.
- Never describe a newly recorded urge as `控制住冲动`, `被控制住的冲动`, or `Controlled urge`.
- The fact that an urge does not reset a gap does not prove it was controlled.
- “Controlled” is allowed only as a separately named retrospective derived status after its observation window and recomputation rules are explicitly confirmed. It must never replace or rename the underlying urge event.
- The confirmed observation window is one completed calendar day in the user's local time zone. An urge is retrospectively controlled only after that date has ended and no slip exists on the same date. The current date is unresolved. Backfills and deletions must recompute the result.
- Treat existing `controlledUrges` code and legacy “same-day” wording as derived/legacy behavior, not as the definition of `EventKind.urge`. Do not propagate that wording to raw-event UI.

The cross-platform source of truth is `/Users/jiangshen/www/gapzilla-design/PRODUCT_SEMANTICS.md`.

## iOS product constraints

- Gapzilla iOS is Chinese-only. Do not add a language switcher, persist an app-language preference, or choose English UI from the device locale unless the user explicitly changes this requirement.
- The in-app `GapzillaMark` must use the same current visual asset as `AppIcon`; do not maintain a separate legacy logo.
