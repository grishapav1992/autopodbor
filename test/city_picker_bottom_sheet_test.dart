// Widget-level test for `showCityPickerBottomSheet`. Drives the picker
// the same way a real user does: tap a launcher button to open the
// sheet, type a query, tap a tile, then assert the Future returned by
// the helper resolves to the chosen `City`.
//
// We bypass `rootBundle` by pre-populating the CityRepository
// singleton via `installSingletonForTest`. This isolates the test
// from any actual asset registration in pubspec.yaml.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/services/city_repository.dart';
import 'package:flutter_application_1/ui/common/widgets/city_picker_bottom_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixture = [
  {
    'r': 'Москва',
    'e': 'Moscow',
    'c': 'RU',
    'cn': 'Россия',
    'a': 'Москва',
    'p': 10381222,
  },
  {
    'r': 'Санкт-Петербург',
    'e': 'Saint Petersburg',
    'c': 'RU',
    'cn': 'Россия',
    'a': 'Санкт-Петербург',
    'p': 5351935,
  },
  {
    'r': 'Алматы',
    'e': 'Almaty',
    'c': 'KZ',
    'cn': 'Казахстан',
    'a': 'Алматы',
    'p': 1977011,
  },
];

void main() {
  setUp(() {
    CityRepository.resetSingletonForTest();
    CityRepository.installSingletonForTest(jsonEncode(_fixture));
  });
  tearDown(CityRepository.resetSingletonForTest);

  Widget host(Future<City?> Function(BuildContext) onPick,
      {ValueChanged<City?>? sink}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final picked = await onPick(context);
                sink?.call(picked);
              },
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('opens, types "мос", taps Moscow, returns the City',
      (tester) async {
    City? picked;
    await tester.pumpWidget(host(
      (ctx) => showCityPickerBottomSheet(ctx),
      sink: (c) => picked = c,
    ));

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    // Sheet is up.
    expect(find.text('Выберите город'), findsOneWidget);

    // The search field has autofocus; type into it.
    await tester.enterText(find.byType(TextField), 'мос');
    // Wait for the 80ms debounce + a frame.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Tile title is now the full "Россия, Москва" displayLabel.
    final moscowTile = find.descendant(
      of: find.byType(ListTile),
      matching: find.text('Россия, Москва'),
    );
    expect(moscowTile, findsOneWidget);
    await tester.tap(moscowTile);
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.nameRu, 'Москва');
    expect(picked!.displayLabel, 'Россия, Москва');
    expect(picked!.countryCode, 'RU');
  });

  testWidgets('country chip filters list — "KZ" hides Russian cities',
      (tester) async {
    await tester.pumpWidget(host((ctx) => showCityPickerBottomSheet(ctx)));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    // Tap the "Казахстан" chip.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Казахстан'));
    await tester.pumpAndSettle();

    // Tile titles are now "Казахстан, Алматы" / "Россия, Москва".
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Казахстан, Алматы'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Россия, Москва'),
      ),
      findsNothing,
    );
  });

  testWidgets('shows "out of list" banner when currentValue is unknown',
      (tester) async {
    await tester.pumpWidget(host(
      (ctx) => showCityPickerBottomSheet(ctx, currentValue: 'Мск'),
    ));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('«Мск» отсутствует в списке'),
      findsOneWidget,
    );
  });

  testWidgets('no banner when currentValue is a known city', (tester) async {
    await tester.pumpWidget(host(
      (ctx) => showCityPickerBottomSheet(ctx, currentValue: 'Москва'),
    ));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.textContaining('отсутствует в списке'), findsNothing);
  });

  testWidgets('empty state message when query has no matches',
      (tester) async {
    await tester.pumpWidget(host((ctx) => showCityPickerBottomSheet(ctx)));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'xyzqwerty');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.textContaining('Город не найден'), findsOneWidget);
  });

  testWidgets('returns null when dismissed without picking', (tester) async {
    // Non-null sentinel — if the picker dismisses without a result,
    // the sink callback should overwrite it with `null`.
    City? picked = City(
      nameRu: 'sentinel',
      nameEn: 'sentinel',
      countryCode: 'XX',
      countryNameRu: '',
      regionNameRu: '',
      population: 0,
    );
    await tester.pumpWidget(host(
      (ctx) => showCityPickerBottomSheet(ctx),
      sink: (c) => picked = c,
    ));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    // Tap outside / drag down — easiest is Navigator.pop without a
    // value via the back gesture replacement.
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });
}
