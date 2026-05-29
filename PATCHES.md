# Nestify Syncfusion Calendar Patches

This repository is a Nestify-Labs fork of [`syncfusion_flutter_calendar`](https://pub.dev/packages/syncfusion_flutter_calendar) carrying a curated set of patches against the upstream pub.dev package.

## Branch / Tag Model

| Branch | Contents |
|---|---|
| `upstream/<major>.<minor>.x` (e.g. `upstream/32.1.x`) | Pristine mirror of the pub.dev package for that upstream version. Byte-identical to the upstream tarball. Never carries Nestify patches. |
| `main` | Default development branch. Based on the latest `upstream/<major>.<minor>.x` plus the Nestify patches listed below (SF-1 … SF-7). Excludes upstream `example/`, `screenshots/`, and `*.iml`. |

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
| SF-7 | `lib/src/calendar/sfcalendar.dart` + `lib/src/calendar/views/calendar_view.dart` | Add a host-controlled `SfCalendar.deferAppointmentDragOnLongPress` boolean flag. When `true`, `_handleLongPressStart` (33.2.8 line 961 base / 968 patched) suspends the cloned `AppointmentView` into new private fields `_pendingLongPressAppointmentView` / `_pendingLongPressDownPosition` instead of immediately calling `_handleAppointmentDragStart`. `_handleLongPressMove` (33.2.8 line 1004 base / 1021 patched) checks the suspension on entry — if pointer travel `< kTouchSlop` (Flutter default 18px), it returns early; once travel `>= kTouchSlop`, it lazily fires `_handleAppointmentDragStart` and falls through to the normal move logic. `_handleLongPressEnd` (33.2.8 line 2176 base / 2222 patched) clears the suspension and returns early when drag never started — `onDragEnd` is NOT raised, leaving the host's `onLongPress` callback as the only signal. Mouse / Web `_handlePointerMove`, `_handleMouseDown`, timeline resource, and resize handle paths are all unchanged — they never invoke `_handleLongPressStart`. Fixes Nestify issue: long-press on an appointment caused Syncfusion's internal `_dragDetails.value.appointmentView` assignment to immediately trigger an appointment-layout collision-graph recompute for the entire visible window; with adjacent / overlapping appointments present, the visible event tiles (including the long-pressed one rendered as drag-ghost) visually re-arranged into different columns, making the host's edit-preview overlay appear "offset" from the original tile and other events appear to "swap columns" before snapping back on release. | When `deferAppointmentDragOnLongPress = false` (default), all three handlers execute byte-identical upstream behavior; the new fields stay `null` and the inserted patch blocks short-circuit. Real drag-to-reschedule remains functional under `true` — it activates lazily when the user actually drags past `kTouchSlop`. Emergency rollback is a one-line flag flip at the host call site. |

(SF-8 explored but withdrawn — `_allDayHeight` is internal to Syncfusion's drag-math and is not a viable timeline-base-Y offset. The host instead measures the timeline content viewport directly via render-tree traversal in `_measureExternalPanelDirect` and uses the same viewport for `_scrollOffset` in `_syncMetricsFromRenderTree`, keeping the coordinate system consistent.)

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
   # Resolve SF-1 through SF-7 conflicts referencing the patch table above
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
