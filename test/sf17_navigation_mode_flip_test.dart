// [SF-17] Nestify patch regression tests — `_scrollStartPosition` must not
// blow up when `viewNavigationMode` flips from `none` to `snap` while a view
// swipe drag is in flight.
//
// Production crash (Nestify issue #2345): the host locks page navigation
// during a pinch session (`viewNavigationMode: none`) and unlocks it on a
// timer 300ms after the pinch ends. A drag that STARTS inside the locked
// window skips the `_onHorizontalStart` / `_onVerticalStart` snap branch, so
// `_scrollStartPosition` is never assigned; when the unlock rebuilds the
// calendar mid-drag (same State, new widget), the next update handler takes
// the snap branch and read the previously-`late` field →
// `LateInitializationError` (fatal in production).
//
// SF-17 makes the field nullable and seeds it from the current pointer
// position on first read, so the flipped drag continues with difference == 0
// on that tick instead of crashing (and without triggering a bogus page
// turn from a stale or zero baseline).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

Widget _host({
  required CalendarView view,
  required ViewNavigationMode navigationMode,
  MonthNavigationDirection monthNavigationDirection =
      MonthNavigationDirection.horizontal,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SfCalendar(
        view: view,
        viewNavigationMode: navigationMode,
        monthViewSettings: MonthViewSettings(
          navigationDirection: monthNavigationDirection,
        ),
      ),
    ),
  );
}

Future<void> _dragAcrossModeFlip(
  WidgetTester tester, {
  required CalendarView view,
  required Offset step,
  MonthNavigationDirection monthNavigationDirection =
      MonthNavigationDirection.horizontal,
}) async {
  await tester.pumpWidget(
    _host(
      view: view,
      navigationMode: ViewNavigationMode.none,
      monthNavigationDirection: monthNavigationDirection,
    ),
  );
  await tester.pumpAndSettle();

  // Start the drag while navigation is locked: the start handler's
  // `ViewNavigationMode.none` branch returns without recording a start
  // position.
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(find.byType(SfCalendar)),
  );
  await gesture.moveBy(step);
  await tester.pump();

  // Host unlocks navigation mid-drag (same State — no key change).
  await tester.pumpWidget(
    _host(
      view: view,
      navigationMode: ViewNavigationMode.snap,
      monthNavigationDirection: monthNavigationDirection,
    ),
  );
  await tester.pump();

  // The same in-flight drag now takes the snap branch in the update
  // handler. Without SF-17 this read the uninitialized `late` field.
  await gesture.moveBy(step);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'SF-17 horizontal: none→snap flip mid-drag does not throw (day view)',
    (WidgetTester tester) async {
      await _dragAcrossModeFlip(
        tester,
        view: CalendarView.day,
        step: const Offset(-40, 0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SF-17 vertical: none→snap flip mid-drag does not throw '
    '(month view, vertical navigation)',
    (WidgetTester tester) async {
      await _dragAcrossModeFlip(
        tester,
        view: CalendarView.month,
        step: const Offset(0, -40),
        monthNavigationDirection: MonthNavigationDirection.vertical,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SF-17 regression guard: a normal snap-only drag still pans and settles',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          view: CalendarView.day,
          navigationMode: ViewNavigationMode.snap,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(SfCalendar), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
