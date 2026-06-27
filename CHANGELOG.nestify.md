# Nestify Fork Changelog

This file tracks Nestify-specific releases of the `syncfusion_flutter_calendar` fork. See `CHANGELOG.md` for the upstream Syncfusion changelog and `PATCHES.md` for the patch list.

## v33.2.8+nestify.10 — SF-14 schedule current-time scroll API

Base: upstream `33.2.8`

- SF-14 (new): expose `SfCalendar.onScheduleScrollApiReady?` and
  `SfCalendarScheduleScrollApi.scrollScheduleCurrentTimeToFraction(fraction)`
  so the host can scroll the Schedule(list) view's existing SF-10 current-time
  indicator to a viewport fraction without reflecting Syncfusion internals.
  `_SfCalendarState` caches the indicator's absolute bidirectional
  `CustomScrollView` content offset while building today's row. Event rows use
  a new testable `scheduleCurrentTimeIndicatorYForAppointments` helper that
  mirrors the Schedule painter's appointment ordering and row-height rules;
  the no-events row caches the same bottom-aligned line position painted by
  SF-10. The command clamps to live scroll extents and returns `false` until
  layout is ready or after a `jumpTo`, allowing the host retry loop to settle.
  Fixes Nestify issue #2227 (Today in Schedule scrolls the red now line to
  roughly 1/3 down the viewport, matching detail view #1977).

## v33.2.8+nestify.9 — SF-13 day all-day overflow + pushed timeline coords

Base: upstream `33.2.8`

- SF-13: fixes Day(single)-view all-day overflow and 12AM ruler
  misalignment by fully sizing the Day all-day section to its rendered all-day
  rows and reporting the extra Day all-day band through SF-8 timeline
  coordinates. See `PATCHES.md` SF-13 for full details.

## v33.2.8+nestify.7 — SF-11 v2 chronological agenda sort + SF-12 all-day panel ordering

Base: upstream `33.2.8`

- SF-11 (v2, semantics change behind the existing flag): with
  `agendaSortAllDayAppointmentsFirst: true` the schedule(list) / month agenda
  per-day lists are now ordered **chronologically by the ORIGINAL (un-clipped)
  start instant** — matching Google Calendar's list view (Nestify issue #2031
  edge cases C/D): an all-day appointment anchors at its start-day midnight,
  so a multi-day timed appointment that started on an earlier day ranks above
  today's all-day appointments (its ending-day "Until …" segment included),
  while one that starts later the same day ranks below them. Equal instants
  order all-day first, then longer span first, then input order (explicit
  index tiebreak — deterministic beyond Dart's 32-element insertion-sort
  path). The previous group-based order (all-day → spanned → timed) is gone;
  `false` still reproduces upstream byte-identically. Tests rewritten in
  `test/sf11_agenda_sort_test.dart` (#2029 start-day case still holds under
  the chronological rule; continuation-day expectation flipped per #2031 C.1;
  dataset C fixtures incl. the Jun-12 "Until X is NOT always first" case).
- SF-12 (new): add `SfCalendar.allDayPanelChronologicalSort` (default `false`,
  upstream-identical). When `true`, the day/week/workWeek all-day panel stacks
  rows with the same chronological comparator as SF-11 v2
  (`AppointmentHelper.sortAllDayPanelChronologically`), replacing the upstream
  `window-clamped startIndex → raw duration desc (asymmetric 0/1 comparator)
  → data-source insertion order` keys. Fixes Nestify issue #2031 edge cases
  C.2 / D: the 1-day Day view no longer orders differently from the 3-day /
  week widths, and the panel matches the schedule list and Google's all-day
  section (dataset D: e, d, c, b). Unit coverage in
  `test/sf12_allday_panel_sort_test.dart`.
- SF-10 (tests only, no algorithm change): added chronologically-interleaved
  fixtures from dataset C pinning the red-line position under the SF-11 v2
  layout — 7:57 (line above the ongoing start-day segment, matching the
  Google reference screenshot), 1:00 AM (an ongoing ending-day "Until" row
  stays un-anchorable), and a banners-only day (line at the last banner's
  bottom edge).

## v33.2.8+nestify.6 — SF-10 fix: multi-day event anchors the current-time line on its start day

Base: upstream `33.2.8`

- SF-10 (refine): a multi-day (spanned) timed appointment now anchors the
  schedule(list) view current-time line on **its start day** instead of being
  skipped on every day. On the first day the appointment shows a real start
  clock time (e.g. "10 AM") and is treated like a regular timed event, so at
  4:31 with a 10 AM–start multi-day event the line sits *above* it (matching
  Google Calendar list view) rather than below it (Nestify issue #2031
  multi-day edge case). Non-start days (middle / end "Until …" segments) and
  all-day events still never anchor the line. Start-day detection uses
  `isSameDate(actualStartTime, now)`, valid because the line only draws on
  today's agenda. Unit coverage added in
  `test/sf10_current_time_indicator_test.dart` (start-day repro + clarified
  continuation-day skip).

## v33.2.8+nestify.5 — SF-10 fix: current-time line end-time anchor + SF-11 agenda all-day ordering

Base: upstream `33.2.8`

- SF-10 (refine): the schedule(list) view current-time indicator now anchors
  above the first timed appointment whose `actualEndTime` is after now —
  an ongoing event (start <= now < end) is treated as "current", not "past"
  (Nestify issue #2031, matching Google Calendar list view). All-day and
  multi-day appointments no longer anchor the line above them. Position
  decision extracted to testable `scheduleCurrentTimeIndicatorY` with unit
  coverage in `test/sf10_current_time_indicator_test.dart`.
- SF-11 (new): add `SfCalendar.agendaSortAllDayAppointmentsFirst` (default
  `false`, upstream-identical). When `true`, schedule(list) view and month
  agenda day lists order all-day appointments above spanned (multi-day)
  appointments — fixes a multi-day timed appointment's first day ranking
  above single-day all-day appointments (Nestify issue #2029). The five
  duplicated per-day triple-sort sites are consolidated into
  `AppointmentHelper.sortAgendaAppointments`. Unit coverage in
  `test/sf11_agenda_sort_test.dart`.

## v33.2.8+nestify.4 — SF-10 schedule view current-time line

Base: upstream `33.2.8`

- SF-10 (new): draw a current-time "Now" indicator line in the schedule(list)
  view, reusing SF-9's `currentTimeIndicatorColor` + `showCurrentTimeIndicator`.
  Also overlays the line on the "No events" today highlight row. Addresses
  Nestify issue #1977 schedule-view follow-up. (Tagged at commit `801698c`;
  entry backfilled in nestify.5.)

## v33.2.8+nestify.3 — SF-9 current-time indicator color & stroke width

Base: upstream `33.2.8`

- SF-9 (new): add `SfCalendar.currentTimeIndicatorColor` (default `null`) and
  `currentTimeIndicatorStrokeWidth` (default `1.0`) to decouple the
  current-time line from `todayHighlightColor`. Defaults are byte-identical to
  upstream. Fixes Nestify issue #1977. (Tagged at commit `fa577e9`; entry
  backfilled in nestify.5.)

## v33.2.8+nestify.2 — SF-8 timeline coordinate push + query API

Base: upstream `33.2.8`

Adds SF-8 patch to support Nestify v1.5.0 calendar-coordinate-unification
(`.feature/v1.5.0/calendar-coordinate-unification/`). SF-8 exposes timeline
layout truth to the host without reflecting Syncfusion's private widget
tree:

- New value types: `SfCalendarTimelineCoordinates`,
  `SfCalendarEmptySlotQueryResult`
- New mixin: `SfCalendarTimelineQueryApi on State<SfCalendar>` (3 query methods)
- New `SfCalendar.onTimelineCoordinatesChanged?` field (default null,
  byte-identical when unused)
- `_pushTimelineCoordinates` helper + 4 push call sites (`_updateAllDayHeight`
  end / `_scrollListener` end / `didUpdateWidget` end / `_heightAnimation`
  listener)
- Auto `addPostFrameCallback` wrapping when fired during build / layout
  phase, so host callback always runs in idle phase

Backward compatible: callback null and unused query API → no behavioral
change from v33.2.8+nestify.1.

## v33.2.8+nestify.1 — Upstream bump 32.1.23 → 33.2.8

Base: upstream `33.2.8` (was `32.1.23`)

Rebased all seven patches (SF-1 … SF-7) onto pristine `33.2.8`. Rebase was
clean — no upstream changes overlapped with patch regions. The cross-version
diff (`git diff upstream/32.1.x upstream/33.2.x -- lib/`) touches only 6
files (4 of them are patched files in this fork) and consists almost entirely
of a single mechanical replacement: `ResourceViewSettings.size` →
`ResourceViewSettings.width!` (the `size` property was deprecated upstream
in v33.1.47, FR29362). Nestify does not use ResourceView, so this has no
consumer impact.

Notable upstream fix carried into this baseline (not Nestify-related but worth
noting): v33.2.8 fixed duplicate appointments appearing in Month view when the
appointment count exceeds `appointmentDisplayCount` with `appointmentBuilder`.

Patch line refs updated for SF-7 anchors (`_handleLongPressStart` /
`_handleLongPressMove` / `_handleLongPressEnd`).

## v32.1.23+nestify.1 — Initial fork import

Base: upstream `32.1.23`

Imported the existing Nestify vendor copy from the `Nestify` mono-repo
(`mobile/third_party/syncfusion_flutter_calendar`) into this dedicated fork
repo. All seven patches (SF-1 … SF-7) listed in `PATCHES.md` are included.

This is a behavior-preserving migration: byte-identical to the prior vendor
copy. The mono-repo no longer carries the source; it pins this tag via a `git:`
dependency.
