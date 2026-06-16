import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremat/features/settings/debug_screen.dart';
import 'package:incremat/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap() => const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DebugScreen(),
      ),
    );

void main() {
  testWidgets('DebugScreen builds without throwing (simulator off)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.text('Developer · Simulator'), findsOneWidget);
    expect(find.text('Simulator mode'), findsOneWidget);
  });

  testWidgets('DebugScreen simulator controls build (simulator on)',
      (tester) async {
    SharedPreferences.setMockInitialValues({'simulator_mode': true});
    await tester.pumpWidget(_wrap());
    // Let SharedPreferences load (flips simMode -> true) and the simulator's
    // delayed initial status fire.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Reps'), findsOneWidget);
    expect(find.text('Auto reps'), findsOneWidget);
    expect(find.text('Connection'), findsOneWidget);
  });

  testWidgets('rep buttons are tappable and drive the count', (tester) async {
    SharedPreferences.setMockInitialValues({'simulator_mode': true});
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Guards against the layout regression where the controls painted but had
    // zero hit-test size, so taps never reached the buttons.
    expect(find.text('0'), findsOneWidget);
    await tester.tap(find.text('+1'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('+5'));
    await tester.pump();
    expect(find.text('6'), findsOneWidget);
  });
}
