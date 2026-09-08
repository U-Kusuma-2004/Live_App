import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liveapp/main.dart';
import 'package:liveapp/widgets/ai_event_banner.dart';
import 'package:liveapp/models/ai_event.dart';
import 'package:liveapp/widgets/status_badge.dart';
import 'package:liveapp/widgets/telemetry_tile.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'vehicle_id': 'TRUCK_001',
      'websocket_url': 'wss://test.runpod.io/ws',
    });
  });

  testWidgets('ConfigScreen renders with title and form fields', (WidgetTester tester) async {
    await tester.pumpWidget(const LiveCameraPocApp());
    // Pump to process async SharedPreferences load
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('VEHICLE CAMERA POC'), findsOneWidget);
    expect(find.text('USER / VEHICLE NAME'), findsOneWidget);
    expect(find.text('WEBSOCKET URL'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.text('TRUCK_001'), findsOneWidget);
    expect(find.text('wss://test.runpod.io/ws'), findsOneWidget);
  });

  testWidgets('AiEventBanner renders active alert when event provided', (WidgetTester tester) async {
    const event = AiEvent(
      vehicleId: 'TRUCK_001',
      event: 'DROWSINESS',
      confidence: 0.94,
      timestamp: 1725770000,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiEventBanner(event: event),
        ),
      ),
    );

    expect(find.text('DROWSINESS DETECTED'), findsOneWidget);
    expect(find.textContaining('Confidence: 94%'), findsOneWidget);
  });

  testWidgets('TelemetryTile renders metric and unit correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TelemetryTile(
            title: 'Speed',
            value: '42.5',
            unit: 'km/h',
            icon: Icons.speed,
          ),
        ),
      ),
    );

    expect(find.text('SPEED'), findsOneWidget);
    expect(find.text('42.5'), findsOneWidget);
    expect(find.text('km/h'), findsOneWidget);
  });

  testWidgets('StatusBadge renders label and status value', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(
            label: 'WS',
            value: 'connected',
            statusType: BadgeStatusType.active,
          ),
        ),
      ),
    );

    expect(find.text('WS: '), findsOneWidget);
    expect(find.text('CONNECTED'), findsOneWidget);
  });
}
