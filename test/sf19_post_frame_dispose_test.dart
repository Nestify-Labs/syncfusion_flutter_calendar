// [SF-19] Nestify patch regression test — a queued appointment refresh must
// not call setState after SfCalendar is removed from the widget tree.
//
// Nestify issue #2278: switching into Schedule while calendar data changes
// queues `_updateVisibleAppointmentCollection` for the end of the frame. If
// the host replaces that SfCalendar before the callback runs, the old State is
// disposed first and the queued callback used to call setState unconditionally.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class _AppointmentDataSource extends CalendarDataSource<Appointment> {
  _AppointmentDataSource() {
    appointments = <Appointment>[];
  }

  void add(Appointment appointment) {
    appointments!.add(appointment);
    notifyListeners(CalendarDataSourceAction.add, <Appointment>[appointment]);
  }
}

Widget _calendarHost(_AppointmentDataSource dataSource, CalendarView view) {
  return MaterialApp(
    home: Scaffold(
      body: SfCalendar(
        key: ValueKey<CalendarView>(view),
        view: view,
        initialDisplayDate: DateTime(2026, 7, 29),
        dataSource: dataSource,
      ),
    ),
  );
}

void main() {
  for (final CalendarView view in <CalendarView>[
    CalendarView.schedule,
    CalendarView.day,
  ]) {
    testWidgets(
      'SF-19 $view data refresh does not setState after calendar disposal',
      (WidgetTester tester) async {
        final _AppointmentDataSource dataSource = _AppointmentDataSource();
        await tester.pumpWidget(_calendarHost(dataSource, view));
        await tester.pumpAndSettle();

        final DateTime start = DateTime(2026, 7, 29, 10);
        dataSource.add(
          Appointment(
            startTime: start,
            endTime: start.add(const Duration(hours: 1)),
            subject: 'Queued refresh',
          ),
        );

        // Dispose the calendar in the frame that drains the queued refresh.
        await tester.pumpWidget(const SizedBox.shrink());

        expect(tester.takeException(), isNull);
      },
    );
  }
}
