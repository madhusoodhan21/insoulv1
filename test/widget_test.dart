// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import 'package:insoulv1/ble_service.dart';
import 'package:insoulv1/exercise_screen.dart';
import 'package:insoulv1/main.dart';
import 'package:insoulv1/profile_screen.dart';

void main() {
  test('filters only InSoul-related BLE device names', () {
    expect(BleService.isInSoulRelatedDeviceName('InSoul'), isTrue);
    expect(BleService.isInSoulRelatedDeviceName('SmartGait_L'), isTrue);
    expect(BleService.isInSoulRelatedDeviceName('GaitSymmetryAnalyzer'), isTrue);
    expect(BleService.isInSoulRelatedDeviceName('RandomPhone'), isFalse);
    expect(BleService.isInSoulRelatedDeviceName(''), isFalse);
  });

  test('keyboard debug emits the firmware sample packet shape', () {
    final ble = BleService(initialize: false);

    ble.debugSimulateSensorInput('L', 'heel', true);

    final packet = jsonDecode(ble.debugSerialLines.single) as Map<String, dynamic>;
    expect(packet['type'], 'sample');
    expect(packet['seq'], 0);
    expect(packet['t'], isA<int>());
    expect(packet['imu'], isNull);
    expect(packet['fsr'], {
      'l': {'heel': 3500, 'toe': 500},
      'r': {'heel': 500, 'toe': 500},
    });
  });

  testWidgets('profile screen includes a font size adjuster', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BleService(initialize: false)),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    expect(find.text('Font Size'), findsOneWidget);
    final sliderFinder = find.byType(Slider);
    expect(sliderFinder, findsOneWidget);

    final slider = tester.widget<Slider>(sliderFinder);
    expect(slider.value, 1.0);

    slider.onChanged?.call(1.25);
    await tester.pump();

    expect(find.text('Larger'), findsOneWidget);
  });

  testWidgets('toe standing waits for FSR input before starting the timer', (WidgetTester tester) async {
    final ble = BleService(initialize: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: ble),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: ExerciseScreen()),
      ),
    );

    await tester.tap(find.text('START').first);
    await tester.pumpAndSettle();

    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Stand on sensor to start'), findsOneWidget);
    expect(find.text('Timing active'), findsNothing);

    ble.setPressureDetected(true);
    await tester.pump();
    expect(find.text('Timing active'), findsOneWidget);
  });

  testWidgets('keyboard debug simulates left and right FSR input while disconnected', (WidgetTester tester) async {
    final ble = BleService(initialize: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: ble),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );

    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(logicalKey: LogicalKeyboardKey.keyY, physicalKey: PhysicalKeyboardKey.keyY),
    );
    await tester.pump();
    expect(ble.pressureDetected, isTrue);
    expect(ble.singleLegLoad, 'L');

    HardwareKeyboard.instance.handleKeyEvent(
      const KeyUpEvent(logicalKey: LogicalKeyboardKey.keyY, physicalKey: PhysicalKeyboardKey.keyY),
    );
    await tester.pump();
    expect(ble.pressureDetected, isFalse);
    expect(ble.singleLegLoad, isNull);

    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(logicalKey: LogicalKeyboardKey.keyU, physicalKey: PhysicalKeyboardKey.keyU),
    );
    await tester.pump();
    expect(ble.pressureDetected, isTrue);
    expect(ble.singleLegLoad, 'R');
  });
}
