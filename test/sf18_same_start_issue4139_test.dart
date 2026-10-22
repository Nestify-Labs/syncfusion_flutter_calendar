import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/common/calendar_view_helper.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_engine/appointment_helper.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_layout/appointment_layout.dart';

Iterable<List<int>> permutations(List<int> xs) sync* {
  if (xs.isEmpty) {
    yield [];
    return;
  }
  for (final x in xs) {
    for (final tail in permutations(xs.where((y) => y != x).toList())) {
      yield [x, ...tail];
    }
  }
}

void main() {
  const scenarios = <String, List<List<int>>>{
    'user_approx_1100_1130_1130_1145': [
      [11, 0, 12, 0],
      [11, 30, 13, 0],
      [11, 30, 12, 30],
      [11, 45, 12, 45],
    ],
    'same_minute_different_seconds': [
      [14, 0, 15, 0],
      [14, 0, 15, 0],
      [14, 0, 15, 0],
      [14, 0, 15, 0],
    ],
    'all_identical': [
      [14, 0, 15, 0],
      [14, 0, 15, 0],
      [14, 0, 15, 0],
      [14, 0, 15, 0],
    ],
    'same_start_different_ends': [
      [14, 0, 16, 0],
      [14, 0, 15, 45],
      [14, 0, 15, 30],
      [14, 0, 15, 0],
    ],
  };
  for (final entry in scenarios.entries) {
    test('SF18 #4139 ${entry.key} shares width across 24 input orders', () {
      for (final order in permutations([0, 1, 2, 3])) {
        final appointments = order.map((i) {
          final t = entry.value[i];
          return CalendarAppointment(
            id: 'ABCD'[i],
            startTime: DateTime(
              2026,
              10,
              21,
              t[0],
              t[1],
              entry.key == 'same_minute_different_seconds' ? i * 10 : 0,
            ),
            endTime: DateTime(2026, 10, 21, t[2], t[3]),
          );
        }).toList();
        final views = <AppointmentView>[];
        final calendar = SfCalendar(
          appointmentOverlapMode: AppointmentOverlapMode.cascade,
        );
        AppointmentHelper.setAppointmentPositionAndMaxPosition(
          views,
          calendar,
          CalendarView.day,
          appointments,
          false,
        );
        expect(views.length, 4);
        final items = views
            .map(
              (v) => CascadeItem(
                start: v.appointment!.actualStartTime,
                end: v.appointment!.actualEndTime,
                position: v.position,
                maxPositions: v.maxPositions,
              ),
            )
            .toList();
        final boxes = CascadeLayout.resolve(
          AppointmentOverlapMode.cascade,
          items,
        );
        for (var i = 0; i < views.length; i++) {
          final v = views[i];
          final box = boxes[i];
          expect(box, isNotNull);
          expect(
            box!.widthFraction,
            closeTo(0.25, 1e-9),
            reason: '${entry.key}, ${order}, ${v.appointment!.id}',
          );
        }
        final sorted = boxes.cast<CascadeBox>().toList()
          ..sort((a, b) => a.leftFraction.compareTo(b.leftFraction));
        for (var i = 0; i < 4; i++) {
          expect(sorted[i].leftFraction, closeTo(i / 4, 1e-9));
        }
      }
    });
  }
}
