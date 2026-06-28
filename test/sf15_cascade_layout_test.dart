// [SF-15] Nestify patch unit tests — pure-logic coverage for the high-density
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
// Target render: A narrow + isolated on the left; B wide; C/D cascade-overlay
// on top of B (C wide, D narrow), all offset right and overlapping B.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_layout/appointment_layout.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/common/calendar_view_helper.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/common/enums.dart';

/// 2026-06-09 — arbitrary fixed day; only intra-day times matter.
final DateTime _day = DateTime(2026, 6, 9);

DateTime _at(int hour, [int minute = 0]) =>
    _day.add(Duration(hours: hour, minutes: minute));

CascadeItem _item(
  DateTime start,
  DateTime end, {
  required int position,
  required int maxPositions,
}) {
  return CascadeItem(
    start: start,
    end: end,
    position: position,
    maxPositions: maxPositions,
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
            ? RRect.fromLTRBR(left, top, right, bottom, const Radius.circular(4))
            : null;
}

void main() {
  group('SF-15 CascadeLayout.resolve', () {
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

      // Boxes stay inside the content band [0, 1].
      for (final CascadeBox box in <CascadeBox>[a, b, c, d]) {
        expect(box.leftFraction, greaterThanOrEqualTo(0));
        expect(_right(box), lessThanOrEqualTo(1.0 + 1e-9));
        expect(box.widthFraction, greaterThan(0));
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
  });

  group('SF-15 CascadeLayout.isEligibleTimedAppointment (entry filter)', () {
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

  group('SF-15 CascadeLayout.hitTest (draw-order hit testing)', () {
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
      );
      // Reverse scan picks the visually topmost = last in the collection.
      expect(identical(hit, views[1]), isTrue);
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
          CascadeLayout.hitTest(AppointmentOverlapMode.laneFill, views, 125, 50),
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
}
