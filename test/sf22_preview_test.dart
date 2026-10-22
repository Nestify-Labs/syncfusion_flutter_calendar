// SF-22: exercise the standalone native preview through its public controls.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../tool/day_window_spike.dart';

void main() {
  testWidgets('preview switches windows and accepts a live all-day addition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DayWindowSpike());
    await tester.pumpAndSettle();
    expect(find.textContaining('缓冲 9 天'), findsOneWidget);
    final calendar = tester.widget<SfCalendar>(find.byType(SfCalendar));
    final initialCount = calendar.dataSource!.appointments!.length;
    await tester.tap(find.text('添加全天事件'));
    await tester.pumpAndSettle();
    expect(calendar.dataSource!.appointments!.length, initialCount + 1);
    await tester.tap(find.text('七天'));
    await tester.pumpAndSettle();
    expect(find.textContaining('缓冲 21 天'), findsOneWidget);
    await tester.tap(find.byTooltip('下一窗口'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('三天'));
    await tester.pumpAndSettle();
    expect(find.textContaining('缓冲 9 天'), findsOneWidget);
    // A buffered day enters semantics as soon as a fraction of its column is
    // painted; the preceding entirely clipped date remains absent.
    final anchor = calendar.initialDisplayDate;
    String subject(int offset) {
      final date = DateTime(anchor.year, anchor.month, anchor.day + offset);
      return '${date.month}/${date.day} · 事件 1';
    }

    expect(_semanticLabels(tester), isNot(contains(subject(3))));
    final drag = await tester.startGesture(const Offset(300, 400));
    await drag.moveBy(const Offset(-20, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-57, 0));
    await tester.pump();
    expect(_semanticLabels(tester), contains(subject(3)));
    expect(_semanticLabels(tester), isNot(contains(subject(-1))));
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

String _semanticLabels(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    labels.add(node.label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return labels.join('\n');
}
