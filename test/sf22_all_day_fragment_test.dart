// SF-22: coordinate-only motion must preserve hit geometry and sizing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_layout/day_window_all_day_fragment.dart';

void main() {
  testWidgets(
    'all-day coordinates update child width and detach listeners',
    (tester) async {
      final changes = ChangeNotifier();
      addTearDown(changes.dispose);
      var bounds = const Rect.fromLTWH(0, 0, 200, 32);
      await tester.pumpWidget(_fragment(changes, () => bounds));
      changes.notifyListeners();
      await tester.pump();

      // Positive control: a new width must still reach the child.
      bounds = const Rect.fromLTWH(0, 0, 120, 32);
      changes.notifyListeners();
      await tester.pump();
      expect(tester.getSize(find.byKey(const ValueKey('card'))).width, 120);
      await tester.pumpWidget(const SizedBox.shrink());
      changes.notifyListeners();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all-day translation keeps paint and hits aligned', (
    tester,
  ) async {
    final changes = ChangeNotifier();
    addTearDown(changes.dispose);
    var bounds = const Rect.fromLTWH(10, 0, 80, 32);
    var taps = 0;
    await tester.pumpWidget(
      _fragment(changes, () => bounds, onTap: () => taps++),
    );
    final box = tester.renderObject<RenderBox>(
      find.byType(DayWindowAllDayFragment),
    );
    final origin = box.localToGlobal(Offset.zero);
    bounds = const Rect.fromLTWH(60, 0, 80, 32);
    changes.notifyListeners();
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('card'))),
      origin + const Offset(60, 0),
    );
    await tester.tapAt(origin + const Offset(20, 16));
    expect(taps, 0);
    await tester.tapAt(origin + const Offset(100, 16));
    expect(taps, 1);

    // A resize must update both the constraints and the hit region.
    bounds = const Rect.fromLTWH(60, 0, 30, 32);
    changes.notifyListeners();
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('card'))).width, 30);
    await tester.tapAt(origin + const Offset(100, 16));
    expect(taps, 1);
    await tester.tapAt(origin + const Offset(70, 16));
    expect(taps, 2);
  });
}

Widget _fragment(
  Listenable changes,
  Rect Function() bounds, {
  VoidCallback? onTap,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 200,
        height: 32,
        child: DayWindowAllDayFragment(
          changes: changes,
          cardBounds: bounds,
          child: GestureDetector(
            key: const ValueKey('card'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    ),
  );
}
