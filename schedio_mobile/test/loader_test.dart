import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/widgets.dart';

Widget host(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: MaterialApp(home: Scaffold(body: Center(child: child))),
);

Finder get logo => find.byWidgetPredicate(
  (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == brandMarkAsset,
);

void main() {
  tearDown(() => AppMotion.ambient = false);

  testWidgets('shows the Schedio mark while loading and nothing when done', (tester) async {
    AppMotion.ambient = false;
    await tester.pumpWidget(host(const SchedioLoadingIndicator(size: 70)));
    expect(logo, findsOneWidget);
    expect(tester.getSize(find.byType(SchedioLoadingIndicator)), const Size(70, 70));
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);

    await tester.pumpWidget(host(const SchedioLoadingIndicator(size: 70, isLoading: false)));
    expect(logo, findsNothing);
    expect(tester.getSize(find.byType(SchedioLoadingIndicator)), Size.zero);
  });

  testWidgets('loops the break animation continuously while loading', (tester) async {
    AppMotion.ambient = true;
    await tester.pumpWidget(host(const SchedioLoadingIndicator(size: 70)));
    expect(logo, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(logo, findsNWidgets(3), reason: 'two broken halves and the logo behind them');
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 200));
    expect(logo, findsOneWidget, reason: 'the next cycle starts from one whole logo');
    expect(tester.binding.hasScheduledFrame, isTrue, reason: 'still animating');

    await tester.pumpWidget(host(const SchedioLoadingIndicator(size: 70, isLoading: false)));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'stopped when loading finished');
    expect(tester.takeException(), isNull);
  });

  testWidgets('respects reduced motion with a still logo', (tester) async {
    AppMotion.ambient = true;
    await tester.pumpWidget(host(const SchedioLoadingIndicator(), reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(logo, findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('disposes cleanly while animating', (tester) async {
    AppMotion.ambient = true;
    await tester.pumpWidget(host(const SchedioLoadingIndicator()));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(host(const SizedBox()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
