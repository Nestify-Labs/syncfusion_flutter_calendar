# AGENTS.md — Nestify Fork of `syncfusion_flutter_calendar`

> Working file for AI agents (Claude Code / Codex / Cursor) and human maintainers entering this repo cold.
> The detailed patch list, upgrade procedure, and position-to-time inventory live in [`PATCHES.md`](./PATCHES.md). This file is the **operating contract** — read it before touching anything.

## 1. Repo Identity

- **What this is**: a Nestify-Labs fork of the upstream `syncfusion_flutter_calendar` pub.dev package carrying a small, curated patch set.
- **Why it exists**: enable Nestify-specific calendar behavior (long-press defer, day-view lane absorption, timeline coordinate push, etc.) that the upstream package does not support, while keeping a machine-diffable trail vs. upstream.
- **Consumer**: pinned from [`Nestify/mobile/pubspec.yaml`](https://github.com/Nestify-Labs/Nestify) via `dependency_overrides.syncfusion_flutter_calendar.git.ref` — a tag like `v33.2.8+nestify.<n>`.
- **License**: upstream Syncfusion commercial license applies. See [`LICENSE`](./LICENSE).

## 2. Patch Discipline

Every code change on `main` MUST satisfy all four:

1. **Belong to an `SF-<N>` patch**. Either extend an existing patch (refine SF-7, etc.) or claim the next free SF-N. Drive-by formatting, cleanups, or "upstream improvements" do **not** belong here — they go upstream to Syncfusion.
2. **Carry an inline `// SF-<N>: <one-line intent>` marker** at the patch site so a future `git grep "SF-7"` finds every byte added by that patch.
3. **Update [`PATCHES.md`](./PATCHES.md) `Patch List` table** in the same commit:
   - Add / modify the SF-N row with file path, purpose, and default-behavior guarantee.
   - If the patch introduces a new public API on `SfCalendar`, document the default that keeps upstream callers byte-identical.
4. **Update [`CHANGELOG.nestify.md`](./CHANGELOG.nestify.md)** under the next `v<upstream>+nestify.<n>` heading with a 1-line entry.

**Forbidden**:

- ❌ Renaming or removing existing `SF-<N>` markers without an explicit "deprecate SF-N" entry in PATCHES.md.
- ❌ Adding Nestify-specific class names, method names, or comments to upstream public API (e.g. `SfCalendar.nestifyXxx` — use generic names like `deferAppointmentDragOnLongPress`).
- ❌ Registering `example/` / `screenshots/` / docs as runtime assets — they must stay stripped on `main`.
- ❌ Editing `upstream/<ver>.x` branches. They are pristine mirrors.

## 3. Branch + Tag Invariants

**Branches**:

| Branch | Invariant | Update path |
|---|---|---|
| `upstream/<major>.<minor>.x` | Byte-identical to the pub.dev tarball for that version. **Zero Nestify patches, ever.** | Only via "import new upstream version" workflow (PATCHES.md §Upgrade). |
| `main` | Latest `upstream/<ver>.x` + every active SF-N patch applied in order. Excludes `example/`, `screenshots/`, `*.iml`. | Normal feature work / patch refinement. |

`upstream/<ver>.x` branches are **historical anchors** — they enable `git diff upstream/33.2.x..main` to produce a machine-readable patch diff for review and upgrade.

**Tags**:

| Pattern | Meaning | Mutability |
|---|---|---|
| `upstream-<version>` (e.g. `upstream-33.2.8`) | Pristine upstream import. Points at the tip of `upstream/<ver>.x` at import time. | **Immutable.** Never re-tag or force-push. |
| `v<upstream>+nestify.<n>` (e.g. `v33.2.8+nestify.2`) | Consumable Nestify release. `n` bumps every time `main` adds or modifies a patch. | **Immutable.** Bump `n`, do not retag. |

The mono-repo pins one `v<...>+nestify.<n>` tag. To roll out a new patch the contract is: push commit on `main` → push new `v<upstream>+nestify.<n+1>` tag → bump `mobile/pubspec.yaml` ref. **Never reuse a previously-pushed tag.**

## 4. Upgrade Workflow

When Syncfusion ships a new upstream version (e.g. `33.2.8 → 34.0.0`):

1. Read [`PATCHES.md` §Upgrade / Rebase Procedure](./PATCHES.md) — the canonical step-by-step.
2. Import new pristine version into a new `upstream/<ver>.x` branch + tag `upstream-<ver>`.
3. `git checkout main && git rebase upstream/<ver>.x`. Resolve each SF-N conflict referencing the Patch List table.
4. Re-run the **Position To Time Paths** inventory in PATCHES.md against the new `calendar_view.dart`. Upstream line numbers in PATCHES.md will be stale — update them.
5. Tag `v<newUpstream>+nestify.1` and push.
6. In Nestify mono-repo bump `mobile/pubspec.yaml` ref + run manual smoke on Day / 3-Day / Week (tap / drag / resize / long-press promote / preview overlay).

**Tip for cross-major upgrades** (like `32.1.23 → 33.2.8`): before rebasing, diff the SF-N patch regions in `lib/src/calendar/{sfcalendar.dart,views/calendar_view.dart,appointment_layout/appointment_layout.dart}` between the two upstream tags. Zero-overlap regions = clean rebase. If a patch region was touched upstream, plan a conflict resolution before starting `git rebase`.

## 5. Test / Verify

This fork carries:

- `test/sf8_coordinates_test.dart` — pure logic unit tests for SF-8 value-class equality + `yForTime`.
- `test/sf10_current_time_indicator_test.dart` / `test/sf11_agenda_sort_test.dart` / `test/sf12_allday_panel_sort_test.dart` — agenda/panel ordering + current-time boundary coverage.
- `test/sf17_navigation_mode_flip_test.dart` — widget tests reproducing the `viewNavigationMode` none→snap mid-drag flip crash (#2345); red on upstream, green with SF-17.

Run:

```bash
dart pub get
dart test
```

The fork does **not** carry full integration tests — Syncfusion's own example app + screenshots are stripped from `main`. End-to-end behavior verification happens in the Nestify mono-repo against a real device. Manual verification matrix lives in `mobile/packages/calendar/AGENTS.md` and `.feature/v1.*/calendar-*/smoke.md` in the consumer repo.

**Before tagging a new `v<...>+nestify.<n>`**:

- [ ] All SF-N markers in code match the PATCHES.md Patch List table (`git grep "SF-" lib/`).
- [ ] PATCHES.md and CHANGELOG.nestify.md updated.
- [ ] `dart test` green.
- [ ] Manually verified against the Nestify mono-repo via `pubspec_overrides.yaml` path override (see PATCHES.md §Local Development Workflow).
- [ ] Tag does not conflict with any existing `v<...>+nestify.<n>` (immutability invariant).

## Quick Links

| File | Purpose |
|---|---|
| [`PATCHES.md`](./PATCHES.md) | Canonical patch list (SF-1 … SF-8), upgrade procedure, position-to-time inventory. |
| [`CHANGELOG.nestify.md`](./CHANGELOG.nestify.md) | Release log per `v<...>+nestify.<n>` tag. |
| [`CHANGELOG.md`](./CHANGELOG.md) | Upstream Syncfusion changelog (do not edit). |
| [`UPSTREAM-README.md`](./UPSTREAM-README.md) | Original Syncfusion README (do not edit). |
| [`README.md`](./README.md) | One-page summary for casual visitors. |
