import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liveapp/services/log_service.dart';
import 'package:liveapp/widgets/live_log_console.dart';

void main() {
  setUp(() {
    LogService.clear();
  });

  test('LogService captures info, wsOut, wsIn, gps, camera, and error entries', () {
    LogService.info('TestTag', 'Test info message');
    LogService.wsOut('WebSocket', 'Frame sent', payload: '{"frame_id": 1}');
    LogService.wsIn('WebSocket', 'AI Event received', payload: '{"event": "DROWSINESS"}');
    LogService.gps('GPS', 'Position fix acquired', payload: '{"lat": 17.3850}');
    LogService.camera('Camera', 'Stream started');
    LogService.error('ErrorTag', 'An exception occurred', error: Exception('Test exception'));

    final logs = LogService.logsNotifier.value;
    expect(logs.length, 6);
    expect(logs[0].level, LogLevel.info);
    expect(logs[1].level, LogLevel.wsOut);
    expect(logs[2].level, LogLevel.wsIn);
    expect(logs[3].level, LogLevel.gps);
    expect(logs[4].level, LogLevel.camera);
    expect(logs[5].level, LogLevel.error);

    final exported = LogService.exportLogsAsString();
    expect(exported.contains('Test info message'), isTrue);
    expect(exported.contains('Frame sent'), isTrue);
    expect(exported.contains('AI Event received'), isTrue);
  });

  testWidgets('LiveLogConsole renders logs and filter buttons', (WidgetTester tester) async {
    LogService.info('App', 'Booting application');
    LogService.wsOut('WebSocket', 'Sending frame #1', payload: '{"test": 1}');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiveLogConsole(maxHeight: 300),
        ),
      ),
    );

    expect(find.text('Live monitor'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Out'), findsOneWidget);
    expect(find.text('In'), findsOneWidget);
    expect(find.text('GPS'), findsOneWidget);
    expect(find.text('Cam'), findsOneWidget);
    expect(find.text('Errors'), findsOneWidget);
    expect(find.textContaining('Booting application'), findsOneWidget);
  });
}
