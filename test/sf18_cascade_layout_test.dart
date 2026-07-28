// [SF-18] Nestify patch unit tests — pure-logic coverage for the high-density
// cascade collision geometry (`CascadeLayout`).
//
// These tests assert the §0.3 *shape* with relational invariants (never exact
// pixels): the boxes are fractions of the day-column content width, and every
// invariant below (width ordering, x-interval intersection) is affine-invariant
// to the per-column pixel mapping, so verifying fractions verifies the rects.
//
// §0.3 baseline cluster (founder's hand-measured Google-parity target):
//   A 8:00–10:00 (pos 0), B 8:00–10:00 (pos 1),
//   C 9:00–11:00 (pos 2), D 9:00–9:30  (pos 3),  maxPositions = 4
// Target render: A narrow + isolated on the left; B wide; C/D form the row's
// single overlay layer (one z plane) sitting SIDE BY SIDE (C wide, D narrow,
// no mutual overlap), offset right as a whole and overlapping B.
// Tuned fractions pixel-measured from a Google Calendar screenshot of this
// exact cluster (T6): A [0,.25]  B [.25,.75]  C [.35,.40]  D [.75,.25].
//
// #2222 deep cluster (T6 v2 Google on-device comparison): ALL of a row's
// leaves share ONE overlay layer regardless of start slot — a per-slot
// z-cascade buried d entirely beneath f (identical right-edge strips), while
// Google renders c/d/e/f side by side: c wide, d/e/f one unit each.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_layout/appointment_layout.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/common/calendar_view_helper.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/common/enums.dart';

/// 2026-06-09 — arbitrary fixed day; only intra-day times matter.
final DateTime _day = DateTime(2026, 6, 9);

DateTime _at(int hour, [int minute = 0]) =>
    _day.add(Duration(hours: hour, minutes: minute));

class _AppointmentDataSource extends CalendarDataSource<Appointment> {
  _AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}

CascadeItem _item(
  DateTime start,
  DateTime end, {
  required int position,
  required int maxPositions,
  DateTime? effectiveEnd,
}) {
  return CascadeItem(
    start: start,
    end: end,
    position: position,
    maxPositions: maxPositions,
    effectiveEnd: effectiveEnd,
  );
}

/// §0.3 baseline cluster A/B/C/D in render order.
List<CascadeItem> _orig() => <CascadeItem>[
  _item(_at(8), _at(10), position: 0, maxPositions: 4), // A
  _item(_at(8), _at(10), position: 1, maxPositions: 4), // B
  _item(_at(9), _at(11), position: 2, maxPositions: 4), // C
  _item(_at(9), _at(9, 30), position: 3, maxPositions: 4), // D
];

double _right(CascadeBox b) => b.leftFraction + b.widthFraction;

/// Positive-measure x-interval intersection (touching edges do not intersect).
bool _intersects(CascadeBox a, CascadeBox b) =>
    a.leftFraction < _right(b) && b.leftFraction < _right(a);

CalendarAppointment _appt(
  DateTime start,
  DateTime end, {
  bool isAllDay = false,
  bool isSpanned = false,
}) {
  return CalendarAppointment(
    startTime: start,
    endTime: end,
    isAllDay: isAllDay,
    isSpanned: isSpanned,
  );
}

/// Builds an [AppointmentView] whose rect is `[left, top, right, bottom]`.
/// `hasAppointment: false` / `hasRect: false` exercise the null guards.
AppointmentView _hitView(
  double left,
  double top,
  double right,
  double bottom, {
  bool hasAppointment = true,
  bool hasRect = true,
}) {
  return AppointmentView()
    ..appointment = hasAppointment ? _appt(_at(8), _at(10)) : null
    ..appointmentRect =
        hasRect
            ? RRect.fromLTRBR(
              left,
              top,
              right,
              bottom,
              const Radius.circular(4),
            )
            : null;
}

void main() {
  group('SF-18 CascadeLayout.resolve', () {
    test('cascade + §0.3 baseline: one box each, A narrow & isolated, '
        'C/D overlay B', () {
      final List<CascadeBox?> boxes = CascadeLayout.resolve(
        AppointmentOverlapMode.cascade,
        _orig(),
      );

      // Exactly one box per appointment (single regular rect, single width).
      expect(boxes.length, 4);
      expect(boxes.every((CascadeBox? b) => b != null), isTrue);

      final CascadeBox a = boxes[0]!;
      final CascadeBox b = boxes[1]!;
      final CascadeBox c = boxes[2]!;
      final CascadeBox d = boxes[3]!;

      // Width by branch depth: A's branch is shallow (narrow), B hosts the
      // C+D overlay (wide); within the overlay C is wide, D is narrow.
      expect(a.widthFraction, lessThan(b.widthFraction));
      expect(d.widthFraction, lessThan(c.widthFraction));

      // A owns the clean left column: its x-interval does not intersect any of
      // B / C / D.
      expect(_intersects(a, b), isFalse);
      expect(_intersects(a, c), isFalse);
      expect(_intersects(a, d), isFalse);

      // C and D cascade on top of B (压盖): their x-intervals intersect B's.
      expect(_intersects(c, b), isTrue);
      expect(_intersects(d, b), isTrue);

      // C and D share the row's single overlay layer: side by side, adjacent,
      // never overlapping each other (§0.3 "同一 z 层内事件并排"; issue found
      // on-device when D got its own calendar color and visibly painted
      // over C).
      expect(_intersects(c, d), isFalse);
      expect(_right(c), closeTo(d.leftFraction, 1e-9));

      // Pinned Google-parity fractions (T6 pixel-measured screenshot of this
      // exact cluster; offset factor 0.4, trailing batch member = 1 unit).
      expect(a.leftFraction, closeTo(0.0, 1e-9));
      expect(a.widthFraction, closeTo(0.25, 1e-9));
      expect(b.leftFraction, closeTo(0.25, 1e-9));
      expect(b.widthFraction, closeTo(0.75, 1e-9));
      expect(c.leftFraction, closeTo(0.35, 1e-9));
      expect(c.widthFraction, closeTo(0.40, 1e-9));
      expect(d.leftFraction, closeTo(0.75, 1e-9));
      expect(d.widthFraction, closeTo(0.25, 1e-9));

      // Boxes stay inside the content band [0, 1].
      for (final CascadeBox box in <CascadeBox>[a, b, c, d]) {
        expect(box.leftFraction, greaterThanOrEqualTo(0));
        expect(_right(box), lessThanOrEqualTo(1.0 + 1e-9));
        expect(box.widthFraction, greaterThan(0));
      }
    });

    test('cascade + staggered leaves: different start slots still share one '
        'overlay layer side by side (no per-slot z-cascade)', () {
      // A/B 8–10 (container + row), C 9–10:30, E 9:45–10:15: C and E start in
      // different slots but both are leaves of row B → ONE overlay layer
      // (#2222 Google parity). C (earliest) absorbs the extra width, E takes
      // one unit flush to the column right edge; they never overlap each
      // other. Geometry identical to the same-slot baseline C/D pair.
      final List<CascadeItem> items = <CascadeItem>[
        _item(_at(8), _at(10), position: 0, maxPositions: 4), // A
        _item(_at(8), _at(10), position: 1, maxPositions: 4), // B
        _item(_at(9), _at(10, 30), position: 2, maxPositions: 4), // C
        _item(_at(9, 45), _at(10, 15), position: 3, maxPositions: 4), // E
      ];

      final List<CascadeBox?> boxes = CascadeLayout.resolve(
        AppointmentOverlapMode.cascade,
        items,
      );

      final CascadeBox b = boxes[1]!;
      final CascadeBox c = boxes[2]!;
      final CascadeBox e = boxes[3]!;

      // One layer: side by side, adjacent, E flush right, no mutual overlap.
      expect(_intersects(e, c), isFalse);
      expect(_right(c), closeTo(e.leftFraction, 1e-9));
      expect(_right(e), closeTo(1.0, 1e-9));
      // Both overlay the row beneath.
      expect(_intersects(c, b), isTrue);
      expect(_intersects(e, b), isTrue);
      // Same fractions as the baseline C/D pair (layer left = branchLo + step).
      expect(c.leftFraction, closeTo(0.35, 1e-9));
      expect(c.widthFraction, closeTo(0.40, 1e-9));
      expect(e.leftFraction, closeTo(0.75, 1e-9));
      expect(e.widthFraction, closeTo(0.25, 1e-9));
    });

    test('cascade + #2222 deep cluster (6-deep, two start slots): all four '
        'leaves share one overlay layer — c wide, d/e/f one unit each', () {
      // deep-a/b 8–10, deep-c/d 9–11, deep-e/f 9:30–10:30 (the dev_tools
      // "Collision Cases: Seed 23 Events" D+5 cluster). Tree: a = container,
      // b = row, c/d/e/f = leaves of b. branchDepth = 5 → unit = 1/6.
      // Google on-device comparison (T6 v2): c/d/e/f side by side in ONE z
      // plane — d must NOT be buried beneath f.
      final List<CascadeItem> items = <CascadeItem>[
        _item(_at(8), _at(10), position: 0, maxPositions: 6), // a
        _item(_at(8), _at(10), position: 1, maxPositions: 6), // b
        _item(_at(9), _at(11), position: 2, maxPositions: 6), // c
        _item(_at(9), _at(11), position: 3, maxPositions: 6), // d
        _item(_at(9, 30), _at(10, 30), position: 4, maxPositions: 6), // e
        _item(_at(9, 30), _at(10, 30), position: 5, maxPositions: 6), // f
      ];

      final List<CascadeBox?> boxes = CascadeLayout.resolve(
        AppointmentOverlapMode.cascade,
        items,
      );

      expect(boxes.every((CascadeBox? b) => b != null), isTrue);
      final CascadeBox a = boxes[0]!;
      final CascadeBox b = boxes[1]!;
      final List<CascadeBox> leaves = <CascadeBox>[
        boxes[2]!,
        boxes[3]!,
        boxes[4]!,
        boxes[5]!,
      ];

      // Pinned fractions (unit = 1/6, layer left = 1/6 + 0.4/6 = 7/30).
      expect(a.leftFraction, closeTo(0.0, 1e-9));
      expect(a.widthFraction, closeTo(1 / 6, 1e-9));
      expect(b.leftFraction, closeTo(1 / 6, 1e-9));
      expect(b.widthFraction, closeTo(5 / 6, 1e-9));
      expect(leaves[0].leftFraction, closeTo(7 / 30, 1e-9)); // c
      expect(leaves[0].widthFraction, closeTo(4 / 15, 1e-9));
      expect(leaves[1].leftFraction, closeTo(0.5, 1e-9)); // d
      expect(leaves[1].widthFraction, closeTo(1 / 6, 1e-9));
      expect(leaves[2].leftFraction, closeTo(2 / 3, 1e-9)); // e
      expect(leaves[2].widthFraction, closeTo(1 / 6, 1e-9));
      expect(leaves[3].leftFraction, closeTo(5 / 6, 1e-9)); // f
      expect(leaves[3].widthFraction, closeTo(1 / 6, 1e-9));

      // Shape invariants: leaves pairwise disjoint & adjacent, last flush to
      // the column right edge, every leaf overlays the row b.
      for (int i = 0; i < leaves.length; i++) {
        for (int j = i + 1; j < leaves.length; j++) {
          expect(
            _intersects(leaves[i], leaves[j]),
            isFalse,
            reason: 'leaf $i and leaf $j must not overlap (one z plane)',
          );
        }
        expect(_intersects(leaves[i], b), isTrue);
        if (i > 0) {
          expect(_right(leaves[i - 1]), closeTo(leaves[i].leftFraction, 1e-9));
        }
      }
      expect(_right(leaves[3]), closeTo(1.0, 1e-9));
      // A keeps its clean isolated left column.
      for (final CascadeBox leaf in leaves) {
        expect(_intersects(a, leaf), isFalse);
      }
    });

    test('laneFill + §0.3 baseline: no cascade boxes (SF-6 path untouched)', () {
      // In laneFill mode resolve yields all-null, so the render loop falls
      // through to the byte-identical SF-6 lane geometry for every appointment.
      final List<CascadeBox?> boxes = CascadeLayout.resolve(
        AppointmentOverlapMode.laneFill,
        _orig(),
      );

      expect(boxes.length, 4);
      expect(boxes, everyElement(isNull));
    });

    test('cascade + maxPositions == 3: below threshold, falls back to '
        'laneFill (no cascade boxes)', () {
      // Three mutually-overlapping events (same 8–10 slot) → maxPositions 3,
      // one short of kCascadeMinColumns (4): cascade must NOT engage.
      final List<CascadeItem> trio = <CascadeItem>[
        _item(_at(8), _at(10), position: 0, maxPositions: 3),
        _item(_at(8), _at(10), position: 1, maxPositions: 3),
        _item(_at(8), _at(10), position: 2, maxPositions: 3),
      ];

      final List<CascadeBox?> boxes = CascadeLayout.resolve(
        AppointmentOverlapMode.cascade,
        trio,
      );

      expect(boxes.length, 3);
      expect(boxes, everyElement(isNull));
      expect(CascadeLayout.kCascadeMinColumns, 4);
    });

    test('separate clusters resolve independently', () {
      // ORIG (4-deep cluster, 08–11) plus an isolated single event at 14:00:
      // the loner is its own cluster (maxPositions 1) → no cascade box, while
      // ORIG still cascades.
      final List<CascadeItem> items = <CascadeItem>[
        ..._orig(),
        _item(_at(14), _at(15), position: 0, maxPositions: 1),
      ];

      final List<CascadeBox?> boxes = CascadeLayout.resolve(
        AppointmentOverlapMode.cascade,
        items,
      );

      expect(boxes.take(4).every((CascadeBox? b) => b != null), isTrue);
      expect(boxes[4], isNull);
    });

    test(
      'disconnected items with allocator maxPositions four stay laneFill',
      () {
        // The lane allocator can leave maxPositions at four on views that were
        // once part of a larger group. Cascade must still require a real
        // overlapping cluster rather than treating each disconnected singleton
        // as a four-column cascade.
        final List<CascadeItem> items = <CascadeItem>[
          _item(_at(8), _at(8, 5), position: 0, maxPositions: 4),
          _item(_at(9), _at(9, 5), position: 1, maxPositions: 4),
          _item(_at(10), _at(10, 5), position: 2, maxPositions: 4),
          _item(_at(11), _at(11, 5), position: 3, maxPositions: 4),
        ];

        expect(
          CascadeLayout.resolve(AppointmentOverlapMode.cascade, items),
          everyElement(isNull),
        );
      },
    );

    test('minimum-duration effective ends form one cascade cluster at '
        'second precision', () {
      // The allocator expands each one-second appointment to its configured
      // minimum duration before assigning four lanes. The cascade resolver
      // must use that same effective interval, not the raw one-second end.
      final List<CascadeItem> items = <CascadeItem>[
        _item(
          _at(8).add(const Duration(seconds: 10)),
          _at(8).add(const Duration(seconds: 11)),
          effectiveEnd: _at(8, 30).add(const Duration(seconds: 10)),
          position: 0,
          maxPositions: 4,
        ),
        _item(
          _at(8, 5).add(const Duration(seconds: 20)),
          _at(8, 5).add(const Duration(seconds: 21)),
          effectiveEnd: _at(8, 35).add(const Duration(seconds: 20)),
          position: 1,
          maxPositions: 4,
        ),
        _item(
          _at(8, 10).add(const Duration(seconds: 30)),
          _at(8, 10).add(const Duration(seconds: 31)),
          effectiveEnd: _at(8, 40).add(const Duration(seconds: 30)),
          position: 2,
          maxPositions: 4,
        ),
        _item(
          _at(8, 15).add(const Duration(seconds: 40)),
          _at(8, 15).add(const Duration(seconds: 41)),
          effectiveEnd: _at(8, 45).add(const Duration(seconds: 40)),
          position: 3,
          maxPositions: 4,
        ),
      ];

      expect(
        CascadeLayout.resolve(AppointmentOverlapMode.cascade, items),
        everyElement(isNotNull),
      );
    });
  });

  group('SF-18 CascadeLayout.isEligibleTimedAppointment (entry filter)', () {
    test('timed single-day appointment in a visible column is eligible', () {
      expect(
        CascadeLayout.isEligibleTimedAppointment(_appt(_at(8), _at(10)), 0),
        isTrue,
      );
    });

    test('all-day, spanned, multi-day and off-screen appointments are '
        'excluded', () {
      // all-day
      expect(
        CascadeLayout.isEligibleTimedAppointment(
          _appt(_at(8), _at(10), isAllDay: true),
          0,
        ),
        isFalse,
      );
      // spanned
      expect(
        CascadeLayout.isEligibleTimedAppointment(
          _appt(_at(8), _at(10), isSpanned: true),
          0,
        ),
        isFalse,
      );
      // multi-day (difference in days > 0)
      expect(
        CascadeLayout.isEligibleTimedAppointment(
          _appt(_at(8), _day.add(const Duration(days: 1, hours: 8))),
          0,
        ),
        isFalse,
      );
      // not visible in any column
      expect(
        CascadeLayout.isEligibleTimedAppointment(_appt(_at(8), _at(10)), -1),
        isFalse,
      );
    });
  });

  group('SF-18 CascadeLayout.hitTest (draw-order hit testing)', () {
    // Two overlapping rects in render order (start-asc => last entry is drawn
    // on top): bottom [0,0,100,100], top [50,0,150,100]. The point (75, 50)
    // lands inside both — the §0.3 overlay "压盖" case.
    List<AppointmentView> overlapping() => <AppointmentView>[
      _hitView(0, 0, 100, 100), // index 0 — bottom layer (drawn first)
      _hitView(50, 0, 150, 100), // index 1 — top layer (drawn last)
    ];

    test('cascade: overlap hit returns the top (last-drawn) view', () {
      final List<AppointmentView> views = overlapping();
      final AppointmentView? hit = CascadeLayout.hitTest(
        AppointmentOverlapMode.cascade,
        views,
        75,
        50,
        activeCascadeViews: views.toSet(),
      );
      // Reverse scan picks the visually topmost = last in the collection.
      expect(identical(hit, views[1]), isTrue);
    });

    test(
      'cascade without active boxes keeps fallback views in forward order',
      () {
        final List<AppointmentView> views = overlapping();

        // A cascade host with no resolved CascadeBox (for example a <=3-lane
        // cluster) must retain the upstream forward-first hit-test order.
        expect(
          identical(
            CascadeLayout.hitTest(
              AppointmentOverlapMode.cascade,
              views,
              75,
              50,
            ),
            views[0],
          ),
          isTrue,
        );
      },
    );

    test('cascade scans fallback views forward after active boxes miss', () {
      final List<AppointmentView> views = <AppointmentView>[
        _hitView(0, 0, 100, 100),
        _hitView(200, 0, 300, 100),
      ];

      expect(
        identical(
          CascadeLayout.hitTest(
            AppointmentOverlapMode.cascade,
            views,
            50,
            50,
            activeCascadeViews: <AppointmentView>{views[1]},
          ),
          views[0],
        ),
        isTrue,
      );
    });

    test('laneFill: same overlap input returns the forward-first view '
        '(SF-6 order unchanged)', () {
      final List<AppointmentView> views = overlapping();
      final AppointmentView? hit = CascadeLayout.hitTest(
        AppointmentOverlapMode.laneFill,
        views,
        75,
        50,
      );
      // Forward scan picks the first match — byte-identical to the old loop.
      expect(identical(hit, views[0]), isTrue);
    });

    test('non-overlapping rects: both modes return the same single match', () {
      final List<AppointmentView> views = overlapping();

      // (25, 50) is inside index 0 only (index 1 starts at x=50).
      expect(
        identical(
          CascadeLayout.hitTest(AppointmentOverlapMode.cascade, views, 25, 50),
          views[0],
        ),
        isTrue,
      );
      expect(
        identical(
          CascadeLayout.hitTest(AppointmentOverlapMode.laneFill, views, 25, 50),
          views[0],
        ),
        isTrue,
      );

      // (125, 50) is inside index 1 only (index 0 ends at x=100).
      expect(
        identical(
          CascadeLayout.hitTest(AppointmentOverlapMode.cascade, views, 125, 50),
          views[1],
        ),
        isTrue,
      );
      expect(
        identical(
          CascadeLayout.hitTest(
            AppointmentOverlapMode.laneFill,
            views,
            125,
            50,
          ),
          views[1],
        ),
        isTrue,
      );
    });

    test('a point outside every rect returns null in both modes', () {
      final List<AppointmentView> views = overlapping();
      expect(
        CascadeLayout.hitTest(AppointmentOverlapMode.cascade, views, 500, 500),
        isNull,
      );
      expect(
        CascadeLayout.hitTest(AppointmentOverlapMode.laneFill, views, 500, 500),
        isNull,
      );
    });

    test('views with a null appointment or null rect are skipped', () {
      // The topmost (last) entry covers the point but has no appointment; the
      // next one down has a null rect. Only the bottom valid view must match,
      // in both modes.
      final List<AppointmentView> views = <AppointmentView>[
        _hitView(0, 0, 100, 100), // valid, contains (50, 50)
        _hitView(0, 0, 100, 100, hasRect: false), // null rect — skipped
        _hitView(0, 0, 100, 100, hasAppointment: false), // null appt — skipped
      ];

      for (final AppointmentOverlapMode mode in AppointmentOverlapMode.values) {
        expect(
          identical(CascadeLayout.hitTest(mode, views, 50, 50), views[0]),
          isTrue,
          reason: 'mode $mode must skip null-appointment/null-rect views',
        );
      }
    });

    test('empty collection returns null', () {
      expect(
        CascadeLayout.hitTest(
          AppointmentOverlapMode.cascade,
          <AppointmentView>[],
          10,
          10,
        ),
        isNull,
      );
    });
  });

  test('SfCalendar diagnostics expose appointmentOverlapMode', () {
    final SfCalendar calendar = SfCalendar(
      appointmentOverlapMode: AppointmentOverlapMode.cascade,
    );

    expect(
      calendar.toDiagnosticsNode().getProperties().map(
        (DiagnosticsNode node) => node.name,
      ),
      contains('appointmentOverlapMode'),
    );
  });

  testWidgets(
    'SF-18 uses the allocator\'s original non-divisible interval clamp',
    (WidgetTester tester) async {
      final List<Appointment> source = <Appointment>[
        for (int i = 0; i < 4; i++)
          Appointment(
            startTime: _at(8).add(const Duration(seconds: 10)),
            endTime: _at(8).add(const Duration(seconds: 11)),
            subject: 'overlap-$i',
          ),
        Appointment(
          startTime: _at(9, 5).add(const Duration(seconds: 10)),
          endTime: _at(9, 5).add(const Duration(seconds: 11)),
          subject: 'separate',
        ),
      ];
      final SfCalendar calendar = SfCalendar(
        view: CalendarView.day,
        initialDisplayDate: _day,
        dataSource: _AppointmentDataSource(source),
        appointmentOverlapMode: AppointmentOverlapMode.cascade,
        timeSlotViewSettings: const TimeSlotViewSettings(
          timeInterval: Duration(minutes: 61),
          minimumAppointmentDuration: Duration(minutes: 70),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: SizedBox(width: 800, height: 800, child: calendar)),
      );
      await tester.pumpAndSettle();

      final AppointmentLayout layout = tester
          .widgetList<AppointmentLayout>(find.byType(AppointmentLayout))
          .firstWhere(
            (AppointmentLayout candidate) =>
                candidate.view == CalendarView.day &&
                candidate.visibleDates.any(
                  (DateTime date) =>
                      date.year == _day.year &&
                      date.month == _day.month &&
                      date.day == _day.day,
                ),
          );
      final AppointmentView separate = layout
          .getAppointmentViewCollection()
          .firstWhere(
            (AppointmentView view) => view.appointment?.subject == 'separate',
          );

      // Upstream clamps 70 minutes first to the normalized 72-minute slot,
      // then again to the configured 61-minute interval. The 09:05 event is
      // therefore outside the 08:00 group's effective 08:00–09:01 lanes and
      // must retain its single-lane, full-width SF-6 rectangle.
      expect(separate.maxPositions, 1);
      final double contentWidth =
          (layout.width -
                  CalendarViewHelper.getTimeLabelWidth(
                    calendar.timeSlotViewSettings.timeRulerSize,
                    calendar.view,
                  )) /
              layout.visibleDates.length -
          CalendarViewHelper.getCellEndPadding(
            calendar.cellEndPadding,
            layout.isMobilePlatform,
          );
      expect(separate.appointmentRect!.width, closeTo(contentWidth - 1, 1e-6));
    },
  );

  testWidgets(
    'SF-18 appointmentBuilder tap hits the later-painted cascade child',
    (WidgetTester tester) async {
      final List<String> tappedSubjects = <String>[];
      final List<Appointment> source = <Appointment>[
        Appointment(
          startTime: _at(11),
          endTime: _at(17),
          subject: 'market',
        ),
        Appointment(
          startTime: _at(12),
          endTime: _at(16),
          subject: 'BBQ',
        ),
        Appointment(
          startTime: _at(14),
          endTime: _at(16, 30),
          subject: 'city',
        ),
        Appointment(
          startTime: _at(14),
          endTime: _at(17),
          subject: 'philosophy',
        ),
        Appointment(
          startTime: _at(14),
          endTime: _at(16, 30),
          subject: 'museum',
        ),
        Appointment(
          startTime: _at(14, 30),
          endTime: _at(16, 30),
          subject: 'art',
        ),
        Appointment(
          startTime: _at(15),
          endTime: _at(17),
          subject: 'film',
        ),
      ];
      final SfCalendar calendar = SfCalendar(
        initialDisplayDate: _day,
        dataSource: _AppointmentDataSource(source),
        appointmentOverlapMode: AppointmentOverlapMode.cascade,
        timeSlotViewSettings: const TimeSlotViewSettings(
          startHour: 11,
          endHour: 18,
        ),
        appointmentBuilder: (
          BuildContext context,
          CalendarAppointmentDetails details,
        ) {
          final Appointment appointment =
              details.appointments.single as Appointment;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => tappedSubjects.add(appointment.subject),
            child: const ColoredBox(color: Colors.lightBlue),
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(home: SizedBox(width: 800, height: 800, child: calendar)),
      );
      await tester.pumpAndSettle();

      final AppointmentLayout layout = tester
          .widgetList<AppointmentLayout>(find.byType(AppointmentLayout))
          .firstWhere(
            (AppointmentLayout candidate) =>
                candidate.view == CalendarView.day &&
                candidate.visibleDates.any(
                  (DateTime date) =>
                      date.year == _day.year &&
                      date.month == _day.month &&
                      date.day == _day.day,
                ),
          );
      final List<AppointmentView> views =
          layout.getAppointmentViewCollection();
      final AppointmentView bbq = views.firstWhere(
        (AppointmentView view) => view.appointment?.subject == 'BBQ',
      );
      final AppointmentView city = views.firstWhere(
        (AppointmentView view) => view.appointment?.subject == 'city',
      );
      final Offset cityCenter = city.appointmentRect!.outerRect.center;
      expect(
        bbq.appointmentRect!.outerRect.contains(cityCenter),
        isTrue,
        reason: 'the device regression requires city to visibly overlay BBQ',
      );

      final Finder layoutFinder = find.byWidgetPredicate(
        (Widget candidate) => identical(candidate, layout),
      );
      final RenderBox layoutBox = tester.renderObject<RenderBox>(layoutFinder);
      await tester.tapAt(layoutBox.localToGlobal(cityCenter));
      await tester.pump();

      expect(tappedSubjects, <String>['city']);
    },
  );
}
