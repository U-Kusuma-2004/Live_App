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

    expect(find.text('Fleet live console'), findsOneWidget);
    expect(find.text('Vehicle name'), findsOneWidget);
    expect(find.text('WebSocket endpoint'), findsOneWidget);
    expect(find.text('Start session'), findsOneWidget);
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

    expect(find.text('Drowsiness'), findsOneWidget);
    expect(find.textContaining('Confidence 94%'), findsOneWidget);
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

    expect(find.text('Speed'), findsOneWidget);
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

    expect(find.text('WS'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('StatusBadge stays visible inside a Row of Expanded (connection strip)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: StatusBadge(
                  label: 'Camera',
                  value: 'streaming',
                  statusType: BadgeStatusType.active,
                  compact: true,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: StatusBadge(
                  label: 'Link',
                  value: 'reconnecting',
                  statusType: BadgeStatusType.pending,
                  compact: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // The min-row + Flexible bug collapsed these to a ~9px invisible dot.
    expect(tester.getSize(find.text('Camera')).width, greaterThan(20));
    expect(tester.getSize(find.byType(StatusBadge).first).height, greaterThan(28));
    expect(find.text('Streaming'), findsOneWidget);
    expect(find.text('Reconnecting'), findsOneWidget);
  });
}
