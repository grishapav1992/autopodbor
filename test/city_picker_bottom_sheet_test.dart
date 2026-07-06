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
  {
    'r': 'Краснодар',
    'e': 'Krasnodar',
    'c': 'RU',
    'cn': 'Россия',
    'a': 'Краснодарский край',
    'p': 899541,
  },
];

void main() {
  setUp(() {
    CityRepository.resetSingletonForTest();
    CityRepository.installSingletonForTest(jsonEncode(_fixture));
  });
  tearDown(CityRepository.resetSingletonForTest);

  Widget host(
    Future<City?> Function(BuildContext) onPick, {
    ValueChanged<City?>? sink,
  }) {
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

  testWidgets('opens, types "мос", taps Moscow, returns the City', (
    tester,
  ) async {
    City? picked;
    await tester.pumpWidget(
      host((ctx) => showCityPickerBottomSheet(ctx), sink: (c) => picked = c),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    // Sheet is up.
    expect(find.text('Выберите город'), findsOneWidget);

    // Type into the search field (it does not autofocus — see the
    // dedicated test below).
    await tester.enterText(find.byType(TextField), 'мос');
    // Wait for the 80ms debounce + a frame.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Tile title is the bare city name — the RU-only picker dropped
    // the «Россия, …» prefix from every row.
    final moscowTile = find.descendant(
      of: find.byType(ListTile),
      matching: find.text('Москва'),
    );
    expect(moscowTile, findsOneWidget);
    await tester.tap(moscowTile);
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.nameRu, 'Москва');
    // What the callers write into their controllers/payloads.
    expect(picked!.shortLabel, 'Москва');
    expect(picked!.countryCode, 'RU');
  });

  testWidgets('region renders as a grey subtitle, not inline in the title', (
    tester,
  ) async {
    await tester.pumpWidget(host((ctx) => showCityPickerBottomSheet(ctx)));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'красн');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(ListTile, 'Краснодар');
    expect(tile, findsOneWidget);
    // Region moved out of the title line into the subtitle.
    expect(
      find.descendant(of: tile, matching: find.text('Краснодарский край')),
      findsOneWidget,
    );
    expect(find.textContaining('Россия,'), findsNothing);

    // Federal cities (admin1 == city) must not get a subtitle: search
    // Москва and make sure its tile has no second line.
    await tester.enterText(find.byType(TextField), 'моск');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    final moscowTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Москва'),
    );
    expect(moscowTile.subtitle, isNull);
  });

  testWidgets('search field does not autofocus — no keyboard on open (B5)', (
    tester,
  ) async {
    await tester.pumpWidget(host((ctx) => showCityPickerBottomSheet(ctx)));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    // autofocus=true used to pop the keyboard together with the sheet, so
    // the user saw «два окна» (picker + keyboard). The field must stay
    // unfocused until tapped.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isFalse);
  });

  testWidgets('fixed RU scope hides non-Russian cities', (tester) async {
    await tester.pumpWidget(host((ctx) => showCityPickerBottomSheet(ctx)));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'Казахстан'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Москва'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Алматы'),
      ),
      findsNothing,
    );
  });

  testWidgets('shows "out of list" banner when currentValue is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      host((ctx) => showCityPickerBottomSheet(ctx, currentValue: 'Мск')),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.textContaining('«Мск» отсутствует в списке'), findsOneWidget);
  });

  testWidgets('no banner when currentValue is a known city', (tester) async {
    await tester.pumpWidget(
      host((ctx) => showCityPickerBottomSheet(ctx, currentValue: 'Москва')),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.textContaining('отсутствует в списке'), findsNothing);
  });

  testWidgets('empty state message when query has no matches', (tester) async {
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
    await tester.pumpWidget(
      host((ctx) => showCityPickerBottomSheet(ctx), sink: (c) => picked = c),
    );
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
