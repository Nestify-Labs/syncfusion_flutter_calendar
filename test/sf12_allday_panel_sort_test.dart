// [SF-12] Nestify patch unit tests — pure-logic coverage for the
// day/week/workWeek all-day panel chronological ordering
// (`AppointmentHelper.sortAllDayPanelChronologically`).
//
// Regression anchor: Nestify issue #2031 edge cases C.2 / D — the all-day
// panel row stacking must match the schedule list (SF-11) and Google
// Calendar's all-day section, and must be identical for every visible-window
// width (1-day Day view, 3-day, week). Upstream ordered by window-clamped
// start-day index, then raw duration descending (via an asymmetric 0/1
// comparator), then data-source insertion order — which both diverges from
// Google and makes the Day view disagree with the 3-day/week views for the
// same data.

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_engine/appointment_helper.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/common/calendar_view_helper.dart';

CalendarAppointment _appt(
  String subject, {
  required DateTime start,
  required DateTime end,
  bool isAllDay = false,
  bool isSpanned = false,
}) {
  return CalendarAppointment(
    subject: subject,
    startTime: start,
    endTime: end,
    isAllDay: isAllDay,
    isSpanned: isSpanned,
  );
}

AppointmentView _view(CalendarAppointment? appointment) =>
    AppointmentView()..appointment = appointment;

List<String?> _subjects(List<AppointmentView> views) => views
    .map((AppointmentView v) => v.appointment?.subject)
    .toList();

void main() {
  group('SF-12 sortAllDayPanelChronologically', () {
    // Issue #2031 dataset D: e timed Jun 8 2AM -> Jun 10 2AM; d all-day
    // Jun 10-12; c timed Jun 10 6AM -> Jun 12 6AM; b timed
    // Jun 10 10AM -> Jun 14 10AM. Google stacks e, d, c, b in the day,
    // 4-day, and week widths alike.
    final DateTime jun8 = DateTime(2026, 6, 8);
    final DateTime jun10 = DateTime(2026, 6, 10);

    List<AppointmentView> datasetD() => <AppointmentView>[
          // Data-source insertion order from the repro: e, b, d, c.
          _view(_appt(
            'e',
            start: jun8.add(const Duration(hours: 2)),
            end: jun10.add(const Duration(hours: 2)),
            isSpanned: true,
          )),
          _view(_appt(
            'b',
            start: jun10.add(const Duration(hours: 10)),
            end: jun10.add(const Duration(hours: 106)),
            isSpanned: true,
          )),
          _view(_appt(
            'd',
            start: jun10,
            end: jun10.add(const Duration(days: 2)),
            isAllDay: true,
            isSpanned: true,
          )),
          _view(_appt(
            'c',
            start: jun10.add(const Duration(hours: 6)),
            end: jun10.add(const Duration(hours: 54)),
            isSpanned: true,
          )),
        ];

    test('issue #2031 dataset D stacks chronologically: e, d, c, b', () {
      final List<AppointmentView> views = datasetD();

      AppointmentHelper.sortAllDayPanelChronologically(views);

      expect(_subjects(views), <String?>['e', 'd', 'c', 'b']);
    });

    test('order is independent of input (data-source) order', () {
      final List<AppointmentView> reversed =
          datasetD().reversed.toList();

      AppointmentHelper.sortAllDayPanelChronologically(reversed);

      expect(_subjects(reversed), <String?>['e', 'd', 'c', 'b']);
    });

    test('pooled views without an appointment order after populated views, '
        'keeping their relative order', () {
      final List<AppointmentView> views = <AppointmentView>[
        _view(null),
        ...datasetD(),
        _view(null),
      ];

      AppointmentHelper.sortAllDayPanelChronologically(views);

      expect(
        _subjects(views),
        <String?>['e', 'd', 'c', 'b', null, null],
      );
    });

    test('equal start instants: all-day first, then longer span first, '
        'then input order', () {
      final List<AppointmentView> views = <AppointmentView>[
        _view(_appt(
          'timed-midnight',
          start: jun10,
          end: jun10.add(const Duration(hours: 30)),
          isSpanned: true,
        )),
        _view(_appt(
          'allday-short',
          start: jun10,
          end: jun10,
          isAllDay: true,
        )),
        _view(_appt(
          'allday-long',
          start: jun10,
          end: jun10.add(const Duration(days: 2)),
          isAllDay: true,
          isSpanned: true,
        )),
      ];

      AppointmentHelper.sortAllDayPanelChronologically(views);

      expect(
        _subjects(views),
        <String?>['allday-long', 'allday-short', 'timed-midnight'],
      );
    });
  });
}
