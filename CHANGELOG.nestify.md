# Nestify Fork Changelog

This file tracks Nestify-specific releases of the `syncfusion_flutter_calendar` fork. See `CHANGELOG.md` for the upstream Syncfusion changelog and `PATCHES.md` for the patch list.

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
