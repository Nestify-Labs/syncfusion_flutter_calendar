# Nestify Syncfusion Calendar Patches

This repository is a Nestify-Labs fork of [`syncfusion_flutter_calendar`](https://pub.dev/packages/syncfusion_flutter_calendar) carrying a curated set of patches against the upstream pub.dev package.

## Branch / Tag Model

| Branch | Contents |
|---|---|
| `upstream/<major>.<minor>.x` (e.g. `upstream/32.1.x`) | Pristine mirror of the pub.dev package for that upstream version. Byte-identical to the upstream tarball. Never carries Nestify patches. |
| `main` | Default development branch. Based on the latest `upstream/<major>.<minor>.x` plus the Nestify patches listed below (SF-1 … SF-8). Excludes upstream `example/`, `screenshots/`, and `*.iml`. |

| Tag pattern | Meaning |
|---|---|
| `upstream-<version>` | A pristine upstream import (e.g. `upstream-32.1.23`). |
| `v<upstreamVersion>+nestify.<n>` | A consumable Nestify release. `n` increments each time `main` adds or modifies a patch. |

The consumer (`Nestify` mono-repo) pins to a `v<...>+nestify.<n>` tag via a `git:` dependency in `mobile/pubspec.yaml`.

## Baseline (current)

- Upstream package: `syncfusion_flutter_calendar`
- Base version: `33.2.8`
- Source: pub.dev (`https://pub.dev/api/archives/syncfusion_flutter_calendar-33.2.8.tar.gz`)
- Hosted package SHA-256: `4c024f2184e9caeeb3b676e90cc0e6be4b6b1390f69c4c285c0fbfe35dafc402`
- Scope excluded from `main`: `example/`, `screenshots/`, `syncfusion_flutter_calendar.iml`
  (These remain present on `upstream/<version>.x` branches for reference but are stripped on the consumable `main` branch so Nestify does not register them as Flutter app assets.)

### Previous baselines

- `v32.1.23+nestify.1` (tag) — upstream `32.1.23`, initial fork import.

## Patch Rules

- Do **not** modify `.pub-cache`. All patch work happens on `main`.
- Keep this fork at the current baseline (`33.2.8`) unless a Syncfusion upgrade is being explicitly rebased.
- Keep patch scope limited to time-slot scroll-end padding, position-to-time invalid-zone guards, recurring-appointment drag/resize null-guards, day-view appointment lane expansion, and deferred long-press drag-start activation.
- Do not add Nestify/Bird-specific names to Syncfusion public API.
- Do not register vendor `example`, docs, screenshots, or other non-runtime resources as Flutter app assets.
- `scrollEndPadding = 0` must preserve the original Syncfusion behavior.

## Patch List

| ID | File | Purpose | Default behavior |
|---|---|---|---|
| SF-1 | `lib/src/calendar/settings/time_slot_view_settings.dart` | Add `TimeSlotViewSettings.scrollEndPadding` and `scrollEndPaddingDecoration` with equality/hash/debug coverage. | Default `0` / `null` preserves existing callers. |
| SF-2 | `lib/src/calendar/views/calendar_view.dart` | Append a passive decorated tail spacer after the 24-hour day/week timeslot `Stack`. | No spacer when `scrollEndPadding == 0`; no decoration when `scrollEndPaddingDecoration == null`. |
| SF-3 | `lib/src/calendar/views/calendar_view.dart` | Guard day/week hit testing with `scrollOffset + localY < 24hContentHeight`. | Original hit testing remains for 0-24h content. |
| SF-4 | `lib/src/calendar/views/calendar_view.dart` | Treat drag/resize positions in the tail spacer as invalid zones. | Valid drops/resizes inside 0-24h remain unchanged. |
| SF-5 | `lib/src/calendar/views/calendar_view.dart` | Guard `parentAppointment!` force-unwraps in three recurring-appointment paths (`_handleLongPressEnd` drag-end, `_onHorizontalEnd` timeline resize-end, `_onVerticalEnd` day/week resize-end) before recurrence-collection computation. When the host refreshes the data source mid-gesture, the dragged/resized `Appointment.id` may no longer exist in the rebuilt `_updateCalendarStateDetails.appointments`; previously this NPE'd. Now mirrors each function's existing early-return on invalid drop: re-emit the host callback with the original start/end so its `onDragEnd` / `onAppointmentResizeEnd` can refresh & rollback, then reset the painter and return. Fixes Nestify issue #1582. | Master found in collection — original behavior is byte-identical. Only the previously unreachable null branch executes the new early-return. |
| SF-6 | `lib/src/calendar/appointment_layout/appointment_layout.dart` | In `_AppointmentLayoutState._updateDayAppointmentDetails`, expand each `CalendarView.day` / `week` / `workWeek` timed appointment's rendered rect to cover adjacent free lanes `[pLeft, pRight]` whose neighbours in the same column do not time-overlap with the current appointment. Adds private helpers `_computeDayAppointmentLaneExtent` (lane-extent scan, O(N²) within a window, N small) and `_overlapsStrictForLaneExtent` (standard half-open interval overlap `aStart.isBefore(bEnd) && bStart.isBefore(aEnd)`, which matches the coverage of `AppointmentHelper._isIntersectingAppointmentInDayView` — including the `isSameTimeSlot` boundary check for events that share an exact start or end minute — while still treating back-to-back appointments where `A.end == B.start` as non-overlapping). The lane allocator `AppointmentHelper.setAppointmentPositionAndMaxPosition` is untouched. Fixes Nestify issue #1699 (3-Day / Day / Week views leave dead whitespace beside short events that share an overlap group with a long event). | When `appointmentView.maxPositions <= 1` the lane scan is skipped and the rect math reduces to the original `(cellWidth - cellEndPadding) / maxPositions` × `position * unitWidth` expression — byte-identical to upstream. For `maxPositions > 1`, only lanes with no time-overlapping rendered appointment are absorbed; lanes occupied by an overlapping appointment block expansion, preserving collision-free rendering (events sharing an exact start or end minute are detected as overlapping and never expand into each other). RTL anchors on the right-most expanded lane to mirror the LTR layout. Height computation, viewport clipping (`yPosition + height <= 0` / `> widget.height` branches), corner radius, `minimumAppointmentDuration` handling, and `cellEndPadding` are all unchanged. |
| SF-8 | `lib/src/calendar/sfcalendar.dart` + `lib/src/calendar/views/calendar_view.dart` | Expose timeline coordinate truth to the host without reflecting Syncfusion's private widget tree. Adds three public types: `SfCalendarTimelineCoordinates` (value class with `viewportTopInBody` / `scrollOffset` / `intervalHeight` / `pinnedAllDayHeight` / `visibleDates` / `viewportWidth` / `viewportHeight` / `maxScrollExtent` + `yForTime(DateTime)` + `equalsWithTolerance`); `SfCalendarEmptySlotQueryResult` (long-press hit-test result with `time` / `date` / `localPosition` / `isOnAppointment`); `SfCalendarTimelineQueryApi` mixin on `State<SfCalendar>` exposing `queryTimeForGlobalY` / `queryDateForGlobalX` / `queryEmptySlotAt`. Adds `SfCalendar.onTimelineCoordinatesChanged?` callback (default `null`). `_CalendarViewState._pushTimelineCoordinates(isCurrentView)` invoked at 5 layout-mutation points: end of `_updateAllDayHeight`, end of `_scrollListener`, end of `didUpdateWidget` (after view / intervalH change), inside `_heightAnimation` listener, and inside both `_allDayExpanderAnimation` listeners (all-day panel expand/collapse, #2148). The pushed `pinnedAllDayHeight` / `viewportTopInBody` reflect the live all-day overlay height via `_resolvePinnedAllDayHeight()`: collapsed → capped `_allDayHeight`; expanded (incl. mid-animation) → `_allDayHeight + (allDayPanelHeight - _allDayHeight) * _allDayExpanderAnimation.value`, mirroring the build-time `allDayExpanderHeight` and the drag-math `_isExpanded` branch. Before #2148 the push used the bare capped `_allDayHeight` (≤60), under-reporting the expanded overlay so the host's self-painted 12AM time ruler landed inside the all-day overlay (occluded by all-day events and the collapse/expander arrow). Only the current view instance fires (non-current paged instances short-circuit). `_SfCalendarState._dispatchTimelineCoordinatesToHost` checks `SchedulerBinding.schedulerPhase` and wraps the host callback in `addPostFrameCallback` automatically when fired during `persistentCallbacks` / `midFrameMicrotasks` — so the host callback always runs in idle phase and can `setState` directly. Query API is implemented via cross-library forward: `_SfCalendarState` (with mixin) → dynamic-cast forward to `_customScrollViewKey.currentState` → `_CustomCalendarScrollViewState` (public methods) → `_currentViewKey.currentState` (same-library private access) → `_CalendarViewState` 3 public methods that compute `RenderBox.globalToLocal` + delegate to `_getDateFromPosition`. | Default `onTimelineCoordinatesChanged: null` short-circuits the push — `_pushTimelineCoordinates` returns immediately after reading the null callback. Query API methods always exist but return `null` for non-timeslot views (month / schedule / year / timeline-month) and for unmounted states. Upstream behavior is byte-identical when both the callback is null and the host never invokes the query API. |
| SF-7 | `lib/src/calendar/sfcalendar.dart` + `lib/src/calendar/views/calendar_view.dart` | Add a host-controlled `SfCalendar.deferAppointmentDragOnLongPress` boolean flag. When `true`, `_handleLongPressStart` (33.2.8 line 961 base / 968 patched) suspends the cloned `AppointmentView` into new private fields `_pendingLongPressAppointmentView` / `_pendingLongPressDownPosition` instead of immediately calling `_handleAppointmentDragStart`. `_handleLongPressMove` (33.2.8 line 1004 base / 1021 patched) checks the suspension on entry — if pointer travel `< kTouchSlop` (Flutter default 18px), it returns early; once travel `>= kTouchSlop`, it lazily fires `_handleAppointmentDragStart` and falls through to the normal move logic. `_handleLongPressEnd` (33.2.8 line 2176 base / 2222 patched) clears the suspension and returns early when drag never started — `onDragEnd` is NOT raised, leaving the host's `onLongPress` callback as the only signal. Mouse / Web `_handlePointerMove`, `_handleMouseDown`, timeline resource, and resize handle paths are all unchanged — they never invoke `_handleLongPressStart`. Fixes Nestify issue: long-press on an appointment caused Syncfusion's internal `_dragDetails.value.appointmentView` assignment to immediately trigger an appointment-layout collision-graph recompute for the entire visible window; with adjacent / overlapping appointments present, the visible event tiles (including the long-pressed one rendered as drag-ghost) visually re-arranged into different columns, making the host's edit-preview overlay appear "offset" from the original tile and other events appear to "swap columns" before snapping back on release. | When `deferAppointmentDragOnLongPress = false` (default), all three handlers execute byte-identical upstream behavior; the new fields stay `null` and the inserted patch blocks short-circuit. Real drag-to-reschedule remains functional under `true` — it activates lazily when the user actually drags past `kTouchSlop`. Emergency rollback is a one-line flag flip at the host call site. |
| SF-9 | `lib/src/calendar/sfcalendar.dart` + `lib/src/calendar/views/calendar_view.dart` | Decouple the current-time indicator's color and stroke width from `todayHighlightColor`. Adds two public `SfCalendar` properties: `currentTimeIndicatorColor` (`Color?`, default `null`) and `currentTimeIndicatorStrokeWidth` (`double`, default `1.0`). `_getCurrentTimeIndicator` resolves the line color as `currentTimeIndicatorColor ?? todayHighlightColor ?? calendarTheme.todayHighlightColor` and forwards `currentTimeIndicatorStrokeWidth` as a new trailing positional arg into `_CurrentTimeIndicator`. `_CurrentTimeIndicator` gains a `currentTimeStrokeWidth` field; its `paint()` replaces the hard-coded `..strokeWidth = 1` with the field. Fixes Nestify issue #1977 (current-time line needs to be red + thicker, while the month-view "today" circle and schedule today marker stay on `todayHighlightColor`). | When `currentTimeIndicatorColor == null` and `currentTimeIndicatorStrokeWidth == 1.0` (both defaults), behavior is byte-identical to upstream — the line color falls back to `todayHighlightColor` and the stroke width matches the previous hard-coded `1`. The current-time dot radius (`drawCircle(..., 5, ...)`) is unchanged; only the line stroke is parameterized. All other `todayHighlightColor` consumers (month-view today circle, schedule today marker) are untouched. |
| SF-10 | `lib/src/calendar/appointment_layout/agenda_view_layout.dart` | Draw a current-time "Now" indicator line in the Schedule (agenda/list) view, reusing SF-9's `currentTimeIndicatorColor` + `showCurrentTimeIndicator`. `_AgendaViewRenderObject` gains a nullable `currentTimeIndicatorColor` field (markNeedsPaint setter); its `paint()` calls a new `_paintCurrentTimeIndicator` that — only when the color is non-null and `selectedDate == today` — draws a horizontal line + left dot at the Y returned by the testable top-level `scheduleCurrentTimeIndicatorY`: the top edge of the first **timed** appointment whose `actualEndTime` is after now (an ongoing event counts as "current", line above it — issue #2031, matching Google Calendar list view), or the bottom edge of the last appointment if every timed appointment has already ended. All-day appointments are skipped and never anchor the line. A multi-day (spanned) appointment is treated as a banner — and skipped — on every day **except its start day**: on its first day it carries a real start clock time (the list shows e.g. "10 AM") and anchors the line like a timed event, so at 4:31 with a 10 AM–start multi-day event the line sits above it instead of below (issue #2031 multi-day edge case). Start-day detection uses `isSameDate(actualStartTime, now)` — valid because the line only ever draws on today's agenda. Unit coverage: `test/sf10_current_time_indicator_test.dart`. `AgendaViewLayout.build` computes the color as `scheduleViewSettings != null && calendar.showCurrentTimeIndicator ? (calendar.currentTimeIndicatorColor ?? calendarTheme.todayHighlightColor) : null` (month-view agenda is excluded) and forwards it through `_AgendaViewRenderWidget` via a new optional named `currentTimeIndicatorColor`. Additionally, when today has no appointments, Syncfusion renders a "No events" highlight row via `_getDisplayDateView` (not AgendaViewLayout); that row now overlays the same red line (red dot + horizontal line, gated on `showCurrentTimeIndicator` + `isSameDate(currentDisplayDate, today)`) so the current-time indicator still appears — matching Google list view. Addresses Nestify issue #1977 schedule-view follow-up (list view previously had no current-time indication). | Default (color resolves to null when the host doesn't set `currentTimeIndicatorColor` and theme has no `todayHighlightColor`, or in non-schedule agenda) short-circuits `_paintCurrentTimeIndicator` immediately — no line drawn, upstream behavior byte-identical. Only the today-dated agenda inside schedule view ever draws the line. |
| SF-11 | `lib/src/calendar/sfcalendar.dart` + `lib/src/calendar/appointment_engine/appointment_helper.dart` + `lib/src/calendar/appointment_layout/agenda_view_layout.dart` | Add a host-controlled `SfCalendar.agendaSortAllDayAppointmentsFirst` boolean flag (default `false`). Upstream orders each schedule/agenda day list with three sequential sorts — `actualStartTime`, then `isAllDay`, then `isSpanned` — making `isSpanned` the highest-priority key, so a multi-day **timed** appointment's first day ranked above single-day all-day appointments (Nestify issue #2029). The five duplicated triple-sort sites (`_getScheduleViewDetails` schedule hit-test, `_getItem` schedule item builder, `_getSelectedAppointments` month-agenda tap, `_addAgendaView` month-agenda render in `sfcalendar.dart`; `AgendaViewLayout._updateAppointmentDetails` render order in `agenda_view_layout.dart`) are replaced by a shared `AppointmentHelper.sortAgendaAppointments(appointments, allDayFirst:)` helper. With `allDayFirst: true` (**v2 semantics since v33.2.8+nestify.7**) the list is ordered chronologically by the appointment's ORIGINAL (un-clipped) start instant — matching Google Calendar's list view (Nestify issue #2031 edge cases C/D): key sequence `actualStartTime asc → isAllDay first on equal instants → longer span (actualEndTime desc) → original index` (explicit stability for any list size; no reliance on Dart's 32-element insertion-sort path). An all-day appointment anchors at its start-day midnight, so an appointment that started on an earlier day — including a multi-day timed event's ending-day "Until …" segment — ranks above today's all-day appointments, while a same-day later start ranks below them; day-relative rendering (start time / banner / "Until X") never influences the order. The v1 group-based order (all-day → spanned timed → regular timed, shipped in nestify.5 for issue #2029) is superseded; the #2029 start-day case still holds under the chronological rule (midnight anchor precedes any same-day timed start). Unit coverage: `test/sf11_agenda_sort_test.dart`. | When `agendaSortAllDayAppointmentsFirst = false` (default), `sortAgendaAppointments` executes the exact upstream sort sequence (startTime → isAllDay → isSpanned) — ordering is byte-identical to upstream at all five sites. Day/week/timeline `setAppointmentPositionAndMaxPosition` lane ordering is untouched; the day/week all-day **panel** ordering is governed separately by SF-12. Emergency rollback is a one-line flag flip at the host call site. |
| SF-12 | `lib/src/calendar/sfcalendar.dart` + `lib/src/calendar/appointment_engine/appointment_helper.dart` | Add a host-controlled `SfCalendar.allDayPanelChronologicalSort` boolean flag (default `false`). Upstream orders the day/week/workWeek all-day panel rows in `_SfCalendarState._updateAllDayAppointment` with two sequential sorts — raw duration descending via an asymmetric comparator that returns only `{0,1}` (order unspecified beyond Dart's 32-element insertion-sort path), then visible-window-clamped `startIndex` ascending — leaving final ties to data-source insertion order. The clamped `startIndex` makes the row order depend on the visible-window width: in a 1-day Day view every earlier-started appointment clamps to index 0 and falls through to duration, ordering differently from the 3-day / week widths for the same data (Nestify issue #2031 edge cases C.2 / D). With the flag `true` both sorts are replaced by `AppointmentHelper.sortAllDayPanelChronologically` — the same chronological key sequence as SF-11 v2 (original `actualStartTime` asc → all-day first → longer span first → original index) applied to the panel's `AppointmentView` pool, with appointment-less pooled views ordered to the tail keeping their relative order. The greedy lowest-free-row packing (`_updateAppointmentPositionAndMaxPosition`) is untouched — with chronological input it reproduces Google's observed stacking in all widths. Unit coverage: `test/sf12_allday_panel_sort_test.dart`. | When `allDayPanelChronologicalSort = false` (default), the two upstream panel sorts execute byte-identically. Emergency rollback is a one-line flag flip at the host call site. |

(Historical note: an early SF-8 exploration tried using the bare `_allDayHeight` as the timeline-base-Y offset and found it insufficient — `_allDayHeight` is the collapsed-capped value (≤60) used by Syncfusion's drag-math and does not reflect the expanded all-day overlay. The shipped SF-8 (above) instead exposes coordinates through the `onTimelineCoordinatesChanged` callback. #2148 closed the remaining gap: `_pushTimelineCoordinates` now reports the live expanded overlay height via `_resolvePinnedAllDayHeight()` instead of the bare capped `_allDayHeight`, and fires on the all-day expander animation so the host ruler tracks expand/collapse.)

## Position To Time Paths

| Function / call site | View family | Input coordinate | Output | Spacer guard |
|---|---|---|---|---|
| `_getDateFromPosition` | day / week / workWeek, including `CalendarView.day` with `numberOfDaysInView = 3` | local `x`, local `y`, `timeLabelWidth`; week helper adds `_scrollController.offset` | `DateTime?` | Must return `null` when `_scrollController.offset + y >= 24hContentHeight`. |
| `_updateAppointmentDragUpdateCallback` | day / week / workWeek drag update | dragged appointment local `x/y` after header/all-day normalization | `draggingTime` in `_dragDetails` and `onDragUpdate` payload | If the day/week `_getDateFromPosition` result is `null`, keep dragging time invalid and do not force unwrap. |
| `_handleLongPressEnd` drag end path | day / week / workWeek drag end | final drop `x/y` after header/all-day normalization | `dropTime` and `onDragEnd` payload | If the day/week `_getDateFromPosition` result is `null`, raise drag end with the original appointment time and reset painter. |
| `_onHorizontalUpdate` | day / week / workWeek resize update | resize handle `x/y` | resize update time | Guard null before forcing `!`; spacer updates should not report a new valid resize time. |
| `_onHorizontalEnd` | day / week / workWeek resize end | final resize handle `x/y` | resize end start/end | If the day/week `_getDateFromPosition` result is `null`, raise resize end with original start/end and reset painter. |
| `_onVerticalUpdate` / `_onVerticalEnd` | timeline views, not Nestify's current vertical day/week timeline | vertical resize `y` converted through `_timeFromPosition` | resize update/end time | Not part of Nestify day/week path; re-check during Syncfusion upgrades. |
| `_handleTouchOnDayView` / tap / long press / hover / selection | day / week / workWeek surface interaction | local pointer `x/y`, sometimes adjusted by header/all-day panel | `CalendarDetails`, selection, hover date | Covered by `_getDateFromPosition` returning `null` for tail spacer. |

## Day / Week All-Day Panel Baseline

Source constants in Syncfusion `32.1.23`:

- `_kAllDayLayoutHeight = 60`
- `kAllDayAppointmentHeight` is used by Syncfusion's all-day layout delegates.
- Expanded all-day panel height is reported through `_updateCalendarStateDetails.allDayPanelHeight`.

Calendar-side sanity bounds should be verified manually against an expanded Single Day view with many all-day events before release.

## Upgrade / Rebase Procedure

When upstream Syncfusion ships a new version (e.g. 32.2.0):

1. Add the new pristine version to the upstream lineage:
   ```bash
   git checkout upstream/32.1.x
   git checkout -b upstream/32.2.x
   # Replace the working tree with the new pristine tarball contents
   rm -rf lib pubspec.yaml example screenshots CHANGELOG.md README.md LICENSE analysis_options.yaml *.iml
   tar -xzf syncfusion_flutter_calendar-32.2.0.tar.gz --strip-components=1
   git add -A
   git commit -m "upstream: syncfusion_flutter_calendar 32.2.0 (pristine)"
   git tag upstream-32.2.0
   git push origin upstream/32.2.x upstream-32.2.0
   ```
2. Rebase the patch set:
   ```bash
   git checkout main
   git rebase upstream/32.2.x
   # Resolve SF-1 through SF-8 conflicts referencing the patch table above
   ```
3. Re-run the Position To Time inventory against the new `calendar_view.dart`.
4. Tag and push the new consumable release:
   ```bash
   git tag v32.2.0+nestify.1
   git push origin main v32.2.0+nestify.1
   ```
5. In the Nestify main repo, bump `mobile/pubspec.yaml`:
   ```yaml
   syncfusion_flutter_calendar:
     git:
       url: https://github.com/Nestify-Labs/syncfusion_flutter_calendar.git
       ref: v32.2.0+nestify.1
   ```
6. Manually verify Day / 3-Day / Week bottom scroll, tap, drag, resize, preview overlay, time ruler behavior, and long-press promote (with `deferAppointmentDragOnLongPress: true`) on adjacent / overlapping appointments.
7. Confirm app assets do not include this vendor package's example/docs/screenshots.

## Adding / Modifying a Patch

To add a new SF-N patch or modify an existing one:

1. Develop on `main` (use a feature branch + PR if desired).
2. Update the Patch List table above with the new SF-N entry.
3. Increment the nestify suffix: `v<baseVersion>+nestify.<N+1>`.
4. Push the tag.
5. In the Nestify main repo, bump the `ref:` in `mobile/pubspec.yaml`.

## Local Development Workflow

In the Nestify mono-repo, copy `mobile/pubspec_overrides.example.yaml` to `mobile/pubspec_overrides.yaml` (gitignored) and point it at your local clone of this fork:

```yaml
dependency_overrides:
  syncfusion_flutter_calendar:
    path: ../../syncfusion_flutter_calendar
```

This lets you iterate on patches locally without bumping the published tag. Once verified, push to this fork, tag a new `v<...>+nestify.<n>`, and bump `pubspec.yaml` ref.
