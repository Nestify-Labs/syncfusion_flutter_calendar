// SF-18 (#3461): a later dense row must not hide an earlier three-card row.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_layout/appointment_layout.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/common/calendar_view_helper.dart';

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 9, 2, hour, minute);

List<Appointment> _source({int bridgeMinutes = 1}) => <Appointment>[
  Appointment(
    startTime: _at(18),
    endTime: _at(19, bridgeMinutes),
    subject: 'Go to',
  ),
  Appointment(startTime: _at(18), endTime: _at(19), subject: 'Hiking todo'),
  Appointment(startTime: _at(18), endTime: _at(19), subject: 'Hospital'),
  Appointment(startTime: _at(19), endTime: _at(19, 45), subject: 'Standup'),
  Appointment(startTime: _at(19), endTime: _at(19, 30), subject: 'Meeting A'),
  Appointment(startTime: _at(19), endTime: _at(19, 30), subject: 'Meeting B'),
];

class _Source extends CalendarDataSource<Appointment> {
  _Source(List<Appointment> source) {
    appointments = source;
  }
}

void main() {
  for (final int bridgeMinutes in <int>[1, 15]) {
    for (final bool reversed in <bool>[false, true]) {
      test(
        'three-card row stays side by side: bridge=$bridgeMinutes reversed=$reversed',
        () {
          final List<Appointment> source = _source(
            bridgeMinutes: bridgeMinutes,
          );
          final List<Appointment> ordered =
              reversed ? source.reversed.toList() : source;
          final List<CascadeBox?> boxes = CascadeLayout.resolve(
            AppointmentOverlapMode.cascade,
            <CascadeItem>[
              for (final Appointment appointment in ordered)
                CascadeItem(
                  start: appointment.startTime,
                  end: appointment.endTime,
                  position: 0,
                  maxPositions: 4,
                ),
            ],
          );
          CascadeBox box(String subject) =>
              boxes[ordered.indexWhere(
                (Appointment appointment) => appointment.subject == subject,
              )]!;
          final List<CascadeBox> early = <CascadeBox>[
            box('Go to'),
            box('Hiking todo'),
            box('Hospital'),
          ]..sort(
            (CascadeBox a, CascadeBox b) =>
                a.leftFraction.compareTo(b.leftFraction),
          );
          for (int i = 0; i < early.length - 1; i++) {
            expect(
              early[i].leftFraction + early[i].widthFraction,
              lessThanOrEqualTo(early[i + 1].leftFraction + 1e-9),
            );
          }
          // The later four-way overlap still uses the established overlay.
          expect(
            <CascadeBox>[box('Meeting A'), box('Meeting B')].any(
              (CascadeBox meeting) =>
                  meeting.leftFraction <
                  box('Standup').leftFraction + box('Standup').widthFraction,
            ),
            isTrue,
          );
          for (final CascadeBox? value in boxes) {
            expect(value!.widthFraction, greaterThan(0));
            expect(value.leftFraction, greaterThanOrEqualTo(0));
            expect(
              value.leftFraction + value.widthFraction,
              lessThanOrEqualTo(1 + 1e-9),
            );
          }
        },
      );
    }
  }

  test('sparse row reuses one leaf lane across back-to-back appointments', () {
    final List<CascadeBox?> boxes = CascadeLayout.resolve(
      AppointmentOverlapMode.cascade,
      <CascadeItem>[
        for (final (DateTime start, DateTime end) in <(DateTime, DateTime)>[
          (_at(18), _at(20)), // container
          (_at(18), _at(19)), // sparse row
          (_at(18), _at(18, 30)), // reusable leaf lane
          (_at(18, 30), _at(19)),
          (_at(19), _at(20)), // dense row and two leaves
          (_at(19), _at(20)),
          (_at(19), _at(20)),
        ])
          CascadeItem(start: start, end: end, position: 0, maxPositions: 4),
      ],
    );
    expect(
      boxes[1]!.leftFraction + boxes[1]!.widthFraction,
      closeTo(boxes[2]!.leftFraction, 1e-9),
    );
    expect(boxes[2]!.leftFraction, closeTo(boxes[3]!.leftFraction, 1e-9));
    expect(boxes[2]!.widthFraction, closeTo(boxes[3]!.widthFraction, 1e-9));
  });

  // Exercise the real lane allocator, custom builder and hit testing at both
  // host widths; the unit fixture above deliberately does not emulate them.
  for (final double width in <double>[390, 1280]) {
    for (final TextDirection direction in TextDirection.values) {
      testWidgets('week three-card row geometry/taps width=$width $direction', (
        WidgetTester tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final List<String> taps = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: SfCalendar(
                view: CalendarView.week,
                initialDisplayDate: _at(18),
                dataSource: _Source(_source()),
                appointmentOverlapMode: AppointmentOverlapMode.cascade,
                timeSlotViewSettings: const TimeSlotViewSettings(
                  startHour: 17,
                  endHour: 21,
                  timeIntervalHeight: 160,
                ),
                appointmentBuilder: (
                  BuildContext context,
                  CalendarAppointmentDetails details,
                ) {
                  final Appointment appointment =
                      details.appointments.single as Appointment;
                  return GestureDetector(
                    key: ValueKey<String>(appointment.subject),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps.add(appointment.subject),
                    child: Text(appointment.subject),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final AppointmentLayout layout = tester
            .widgetList<AppointmentLayout>(find.byType(AppointmentLayout))
            .firstWhere(
              (AppointmentLayout candidate) =>
                  candidate.visibleDates.any((DateTime date) => date == _at(0)),
            );
        final List<AppointmentView> views =
            layout.getAppointmentViewCollection();
        AppointmentView view(String subject) => views.firstWhere(
          (AppointmentView view) => view.appointment?.subject == subject,
        );
        expect(view('Go to').maxPositions, 4);
        final List<Rect> early =
            <String>['Go to', 'Hiking todo', 'Hospital']
                .map(
                  (String subject) => view(subject).appointmentRect!.outerRect,
                )
                .toList()
              ..sort((Rect a, Rect b) => a.left.compareTo(b.left));
        for (int i = 0; i < early.length - 1; i++) {
          expect(early[i].right, lessThanOrEqualTo(early[i + 1].left + 1e-6));
        }
        for (final String subject in <String>[
          'Go to',
          'Hiking todo',
          'Hospital',
        ]) {
          await tester.tap(find.byKey(ValueKey<String>(subject)));
          expect(taps.last, subject);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
