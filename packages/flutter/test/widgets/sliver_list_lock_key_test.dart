// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildList(List<int> items, ScrollController controller, {double height = 100}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          height: 400,
          child: CustomScrollView(
            controller: controller,
            slivers: <Widget>[
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) => SizedBox(
                    key: ValueKey<int>(items[index]),
                    height: height,
                  ),
                  childCount: items.length,
                  findChildIndexCallback: (Key key) {
                    final int index = items.indexOf((key as ValueKey<int>).value);
                    return index < 0 ? null : index;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  for (final insert in <bool>[true, false]) {
    testWidgets('Key lock preserves a row when ${insert ? 'inserting' : 'removing'} above it', (
      WidgetTester tester,
    ) async {
      final items = List<int>.generate(20, (int index) => index);
      final controller = ScrollController(initialScrollOffset: 450);
      addTearDown(controller.dispose);
      await tester.pumpWidget(buildList(items, controller));
      final RenderSliverList sliver = tester.renderObject(find.byType(SliverList));
      const Key anchor = ValueKey<int>(5);
      final double oldY = tester.getTopLeft(find.byKey(anchor)).dy;
      sliver.lockKey = anchor;
      if (insert) {
        items.insertAll(3, <int>[100, 101, 102]);
      } else {
        items.removeAt(3);
      }
      await tester.pumpWidget(buildList(items, controller));
      expect(tester.getTopLeft(find.byKey(anchor)).dy, closeTo(oldY, 0.001));
      expect(controller.offset, closeTo(insert ? 750 : 350, 0.001));
      expect(tester.takeException(), isNull);
      sliver.lockKey = null;
    });
  }

  testWidgets('Key lock preserves a child moved to index zero', (WidgetTester tester) async {
    final items = List<int>.generate(20, (int index) => index);
    final controller = ScrollController(initialScrollOffset: 550);
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildList(items, controller));
    final RenderSliverList sliver = tester.renderObject(find.byType(SliverList));
    const Key anchor = ValueKey<int>(5);
    final double oldY = tester.getTopLeft(find.byKey(anchor)).dy;
    sliver.lockKey = anchor;
    items.removeRange(0, 5);
    await tester.pumpWidget(buildList(items, controller));
    expect(tester.getTopLeft(find.byKey(anchor)).dy, closeTo(oldY, 0.001));
    expect(controller.offset, closeTo(50, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Key lock preserves a child after removing uncached preceding rows', (
    WidgetTester tester,
  ) async {
    final items = List<int>.generate(30, (int index) => index);
    final controller = ScrollController(initialScrollOffset: 1450);
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildList(items, controller));
    final RenderSliverList sliver = tester.renderObject(find.byType(SliverList));
    const Key anchor = ValueKey<int>(15);
    final double oldY = tester.getTopLeft(find.byKey(anchor)).dy;
    sliver.lockKey = anchor;
    items.removeRange(0, 10);
    await tester.pumpWidget(buildList(items, controller));
    expect(tester.getTopLeft(find.byKey(anchor)).dy, closeTo(oldY, 0.001));
    // Dead reckoning need not normalize uncached extents until reaching the start.
    sliver.lockKey = null;
    controller.jumpTo(0);
    await tester.pump();
    expect(controller.offset, 0);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<int>(10))).dy,
      tester.getTopLeft(find.byType(CustomScrollView)).dy,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Key lock survives successive height changes', (WidgetTester tester) async {
    final items = List<int>.generate(20, (int index) => index);
    final controller = ScrollController(initialScrollOffset: 450);
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildList(items, controller));
    final RenderSliverList sliver = tester.renderObject(find.byType(SliverList));
    const Key anchor = ValueKey<int>(5);
    final double oldY = tester.getTopLeft(find.byKey(anchor)).dy;
    sliver.lockKey = anchor;
    await tester.pumpWidget(buildList(items, controller, height: 120));
    expect(tester.getTopLeft(find.byKey(anchor)).dy, closeTo(oldY, 0.001));
    await tester.pumpWidget(buildList(items, controller, height: 140));
    expect(tester.getTopLeft(find.byKey(anchor)).dy, closeTo(oldY, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Missing key does not lock an unrelated row', (WidgetTester tester) async {
    final items = List<int>.generate(20, (int index) => index);
    final controller = ScrollController(initialScrollOffset: 450);
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildList(items, controller));
    final RenderSliverList sliver = tester.renderObject(find.byType(SliverList));
    sliver.lockKey = const ValueKey<int>(5);
    items.remove(5);
    await tester.pumpWidget(buildList(items, controller));
    expect(tester.takeException(), isNull);
    expect(controller.offset, 450);
  });

  testWidgets('End sentinel preserves the bottom when appending', (WidgetTester tester) async {
    final items = List<int>.generate(10, (int index) => index);
    final controller = ScrollController(initialScrollOffset: 600);
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildList(items, controller));
    final RenderSliverList sliver = tester.renderObject(find.byType(SliverList));
    sliver.lockKey = RenderSliverList.kLockKeyLockToEnd;
    items.addAll(<int>[10, 11]);
    await tester.pumpWidget(buildList(items, controller));
    expect(controller.position.extentAfter, closeTo(0, 0.001));
    expect(controller.offset, closeTo(800, 0.001));
    expect(tester.takeException(), isNull);
  });
}
