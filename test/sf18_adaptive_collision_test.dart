import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_layout/appointment_layout.dart';

class _Source extends CalendarDataSource<Appointment> {
  _Source(List<Appointment> values) {
    appointments = values;
  }
}

void main() {
  DateTime at(int minute) => DateTime(2026, 10, 21, 11, minute);
  CascadeItem item(int start, int end, {int? effectiveEnd, int columns = 4}) =>
      CascadeItem(
        start: at(start),
        end: at(end),
        effectiveEnd: effectiveEnd == null ? null : at(effectiveEnd),
        position: 0,
        maxPositions: columns,
      );
  Iterable<List<int>> orders(List<int> rest) sync* {
    if (rest.isEmpty) {
      yield [];
      return;
    }
    for (final i in rest) {
      for (final tail in orders(rest.where((x) => x != i).toList())) {
        yield [i, ...tail];
      }
    }
  }

  test(
    'SF18 narrow clique stays bounded and half exposed in every paint order',
    () {
      final source = [item(0, 60), item(30, 120), item(30, 90), item(45, 105)];
      for (final order in orders([0, 1, 2, 3])) {
        for (final width in [40.0, 100.0, 220.0]) {
          final boxes = CascadeLayout.resolve(
            AppointmentOverlapMode.cascade,
            order.map((i) => source[i]).toList(),
            contentWidth: width,
          ).cast<CascadeBox>();
          for (var i = 0; i < boxes.length; i++) {
            final b = boxes[i];
            expect(b.leftFraction, greaterThanOrEqualTo(0));
            expect(
              b.leftFraction + b.widthFraction,
              lessThanOrEqualTo(1.000000001),
            );
            expect(b.widthFraction, greaterThan(.25));
            expect(b.widthFraction, lessThanOrEqualTo(.4));
            expect(b.widthFraction, closeTo(boxes.first.widthFraction, 1e-9));
            if (i < 3) {
              expect(
                boxes[i + 1].leftFraction - b.leftFraction,
                greaterThanOrEqualTo(b.widthFraction / 2 - 1e-9),
              );
            }
          }
        }
      }
    },
  );
  test(
    'SF18 narrow connected chains preserve lane recycling instead of budgeting serial events as simultaneous',
    () {
      final source = [
        item(0, 60),
        item(30, 120),
        item(30, 90),
        item(45, 105),
        item(100, 150),
      ];
      final old = CascadeLayout.resolve(AppointmentOverlapMode.cascade, source);
      final narrow = CascadeLayout.resolve(
        AppointmentOverlapMode.cascade,
        source,
        contentWidth: 40,
      );
      for (var i = 0; i < source.length; i++) {
        expect(narrow[i]!.leftFraction, old[i]!.leftFraction);
        expect(narrow[i]!.widthFraction, old[i]!.widthFraction);
      }
    },
  );
  test(
    'SF18 uses effective collision ends, preserves wide columns and ignores invalid widths',
    () {
      final source = [
        item(0, 10, effectiveEnd: 60),
        item(30, 120),
        item(30, 90),
        item(45, 105),
      ];
      final narrow = CascadeLayout.resolve(
        AppointmentOverlapMode.cascade,
        source,
        contentWidth: 40,
      );
      expect(
        narrow.every((b) => b != null && (b.widthFraction - .4).abs() < 1e-9),
        isTrue,
      );
      final old = CascadeLayout.resolve(AppointmentOverlapMode.cascade, source);
      for (final width in [
        256.0,
        800.0,
        0.0,
        -1.0,
        double.nan,
        double.infinity,
      ]) {
        final boxes = CascadeLayout.resolve(
          AppointmentOverlapMode.cascade,
          source,
          contentWidth: width,
        );
        for (var i = 0; i < source.length; i++) {
          expect(boxes[i]!.leftFraction, old[i]!.leftFraction);
          expect(boxes[i]!.widthFraction, old[i]!.widthFraction);
        }
      }
      expect(
        CascadeLayout.resolve(
          AppointmentOverlapMode.laneFill,
          source,
          contentWidth: 40,
        ),
        everyElement(isNull),
      );
      expect(
        CascadeLayout.resolve(AppointmentOverlapMode.cascade, [
          item(0, 60, columns: 3),
          item(0, 60, columns: 3),
          item(0, 60, columns: 3),
        ], contentWidth: 40),
        everyElement(isNull),
      );
    },
  );
  for (final size in [
    (360.0, 1, false),
    (360.0, 3, false),
    (360.0, 7, false),
    (1800.0, 7, false),
    (360.0, 3, true),
    (360.0, 7, true),
  ]) {
    final continuous = size.$3;
    for (final identical in continuous ? [false] : [false, true]) {
      for (final input in continuous ? ['ACBD'] : ['ABCD', 'ACBD']) {
        for (final rtl in [false, true]) {
          for (final builderTap in [false, true]) {
            testWidgets(
              'SF18 width-aware ${(size.$1, size.$2)} identical=$identical $input rtl=$rtl childTap=$builderTap${continuous ? " continuous-after-drag" : ""}',
              (tester) async {
                tester.view.physicalSize = Size(size.$1, 900);
                tester.view.devicePixelRatio = 1;
                addTearDown(tester.view.resetPhysicalSize);
                addTearDown(tester.view.resetDevicePixelRatio);
                final paintOrder = <String>[];
                final bounds = <String, Rect>{};
                List<DateTime>? visibleDates;
                String? tapped;
                final times = identical
                    ? [
                        [11, 0, 12, 0],
                        [11, 0, 12, 0],
                        [11, 0, 12, 0],
                        [11, 0, 12, 0],
                      ]
                    : [
                        [11, 0, 12, 0],
                        [11, 30, 13, 0],
                        [11, 30, 12, 30],
                        [11, 45, 12, 45],
                      ];
                final source = _Source(
                  input.split('').map((id) {
                    final t = times['ABCD'.indexOf(id)];
                    return Appointment(
                      id: id,
                      subject: id,
                      startTime: DateTime(
                        2026,
                        10,
                        continuous ? 22 : 21,
                        t[0],
                        t[1],
                      ),
                      endTime: DateTime(
                        2026,
                        10,
                        continuous ? 22 : 21,
                        t[2],
                        t[3],
                      ),
                    );
                  }).toList(),
                );
                await tester.pumpWidget(
                  MaterialApp(
                    home: Directionality(
                      textDirection: rtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: Scaffold(
                        body: SfCalendar(
                          view: size.$2 == 7
                              ? CalendarView.week
                              : CalendarView.day,
                          initialDisplayDate: DateTime(2026, 10, 21, 11),
                          dayWindowNavigation:
                              continuous
                                  ? DayWindowNavigation.continuous
                                  : DayWindowNavigation.paged,
                          dataSource: source,
                          onViewChanged: (details) {
                            visibleDates = details.visibleDates;
                          },
                          appointmentOverlapMode:
                              AppointmentOverlapMode.cascade,
                          timeSlotViewSettings: TimeSlotViewSettings(
                            numberOfDaysInView: size.$2,
                            startHour: 10,
                            endHour: 16,
                            timeIntervalHeight: 80,
                            timeRulerSize: 64,
                          ),
                          onTap: (d) {
                            tapped = (d.appointments?.single as Appointment?)
                                ?.subject;
                          },
                          appointmentBuilder: (context, d) {
                            final id =
                                (d.appointments.single as Appointment).subject;
                            if (!paintOrder.contains(id)) paintOrder.add(id);
                            bounds[id] = d.bounds;
                            final child = ColoredBox(
                              key: ValueKey(id),
                              color: Colors.blue,
                            );
                            return builderTap
                                ? GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      tapped = id;
                                    },
                                    child: child,
                                  )
                                : child;
                          },
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                // SF-18/SF-22: retained continuous date blocks must preserve
                // the narrow-clique geometry and both production hit paths.
                if (continuous) {
                  expect(visibleDates!.first, DateTime(2026, 10, 21));
                  final column = (size.$1 - 64) / size.$2;
                  final before = tester.getRect(
                    find.byKey(const ValueKey('A')),
                  );
                  final direction = rtl ? 1.0 : -1.0;
                  final drag = await tester.startGesture(
                    const Offset(180, 600),
                  );
                  await drag.moveBy(Offset(20 * direction, 0));
                  await tester.pump();
                  await drag.moveBy(Offset(column * .8 * direction, 0));
                  await tester.pump(const Duration(milliseconds: 500));
                  await drag.up();
                  await tester.pumpAndSettle();
                  expect(visibleDates!.first, DateTime(2026, 10, 22));
                  expect(visibleDates!.length, size.$2);
                  final after = tester.getRect(find.byKey(const ValueKey('A')));
                  expect(after.width, closeTo(before.width, 1e-6));
                  expect(
                    after.left - before.left,
                    closeTo(column * direction, 1e-6),
                  );
                }
                expect(paintOrder.length, 4);
                final rects = {
                  for (final id in paintOrder)
                    id: tester.getRect(find.byKey(ValueKey(id))),
                };
                final ordered = rects.values.toList()
                  ..sort((a, b) => a.left.compareTo(b.left));
                final span = ordered.last.right - ordered.first.left;
                final narrow = size.$2 > 1;
                for (final r in ordered) {
                  expect(r.width, closeTo(ordered.first.width, 1e-6));
                  expect(r.left, greaterThanOrEqualTo(rtl ? 0 : 64));
                  expect(
                    r.right,
                    lessThanOrEqualTo(rtl ? size.$1 - 64 : size.$1),
                  );
                  if (narrow) {
                    expect(
                      r.width,
                      greaterThan(span / 4),
                      reason:
                          'narrow columns must actually widen cards, not just divide four thin lanes',
                    );
                  }
                }
                if (narrow) {
                  for (var i = 0; i < 3; i++) {
                    final overlap = ordered[i].right - ordered[i + 1].left;
                    expect(overlap, greaterThan(0));
                    expect(
                      overlap,
                      lessThanOrEqualTo((ordered[i].width + 1) / 2),
                      reason: 'never cover more than half a card',
                    );
                  }
                } else {
                  for (var i = 0; i < 3; i++) {
                    expect(ordered[i].right, lessThan(ordered[i + 1].left));
                  }
                }
                // Verify at the shared intersection, not only at an unobscured
                // early header. Each card must retain a selectable visible strip.
                final y =
                    rects.values
                        .map((r) => r.top)
                        .reduce((a, b) => a > b ? a : b) +
                    8;
                for (var i = 0; i < paintOrder.length; i++) {
                  final id = paintOrder[i];
                  final r = rects[id]!;
                  Offset? visible;
                  for (var x = r.left + 2; x < r.right - 1; x += 1) {
                    final p = Offset(x, y);
                    if (!paintOrder
                        .skip(i + 1)
                        .any((later) => rects[later]!.contains(p))) {
                      visible = p;
                      break;
                    }
                  }
                  expect(
                    visible,
                    isNotNull,
                    reason: '$id must not disappear behind later-painted peers',
                  );
                  tapped = null;
                  await tester.tapAt(visible!);
                  await tester.pumpAndSettle();
                  expect(
                    tapped,
                    id,
                    reason:
                        'visible geometry and ${builderTap ? "child" : "calendar"} hit testing must agree',
                  );
                }
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pumpAndSettle();
              },
            );
          }
        }
      }
    }
  }
}
