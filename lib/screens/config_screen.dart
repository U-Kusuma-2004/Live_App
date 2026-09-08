import 'package:flutter/material.dart';
import '../services/log_service.dart';
import '../services/preferences_service.dart';
import 'live_stream_screen.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _vehicleIdController = TextEditingController();
  final TextEditingController _webSocketUrlController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    LogService.info('Config', 'App initialized. Loading stored configuration...');
    _loadSavedConfiguration();
  }

  Future<void> _loadSavedConfiguration() async {
    final config = await PreferencesService.loadConfig();
    setState(() {
      _vehicleIdController.text = config['vehicleId'] ?? 'TRUCK_001';
      _webSocketUrlController.text =
          config['webSocketUrl'] ?? 'wss://your-runpod-server.ngrok-free.app/ws';
      _isLoading = false;
    });
    LogService.info(
      'Config',
      'Config loaded: VehicleID="${_vehicleIdController.text}", WebSocket="${_webSocketUrlController.text}"',
    );
  }

  Future<void> _onNextPressed() async {
    if (!_formKey.currentState!.validate()) {
      LogService.warn('Config', 'Validation failed on config screen.');
      return;
    }

    setState(() => _isSaving = true);

    final vehicleId = _vehicleIdController.text.trim();
    final webSocketUrl = _webSocketUrlController.text.trim();

    LogService.info('Config', 'Saving config: VehicleID="$vehicleId", URL="$webSocketUrl"');
    await PreferencesService.saveConfig(
      vehicleId: vehicleId,
      webSocketUrl: webSocketUrl,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    LogService.info('Navigation', 'Navigating to Screen 2 (LiveStreamScreen)...');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(
          vehicleId: vehicleId,
          webSocketUrl: webSocketUrl,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _vehicleIdController.dispose();
    _webSocketUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryCyan = Color(0xFF00E5FF);
    const bgDark = Color(0xFF0A0E17);
    const surfaceDark = Color(0xFF131B2A);
    const borderDark = Color(0xFF22304A);

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryCyan),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // Header / Hero Section
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: primaryCyan.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryCyan.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.videocam_rounded,
                            size: 40,
                            color: primaryCyan,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'VEHICLE CAMERA POC',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Color(0xFFF1F5F9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Camera Stream + GPS Telemetry + RunPod AI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Configuration Card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: surfaceDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderDark, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Field 1: User / Vehicle Name
                            const Row(
                              children: [
                                Icon(Icons.local_shipping_outlined, size: 16, color: primaryCyan),
                                SizedBox(width: 8),
                                Text(
                                  'USER / VEHICLE NAME',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _vehicleIdController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. TRUCK_001',
                                hintStyle: const TextStyle(color: Color(0xFF475569)),
                                filled: true,
                                fillColor: const Color(0xFF0A0E17),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: borderDark),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: borderDark),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: primaryCyan, width: 1.5),
                                ),
                                suffixIcon: _vehicleIdController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                                        onPressed: () => _vehicleIdController.clear(),
                                      )
                                    : null,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vehicle Name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Field 2: WebSocket URL
                            const Row(
                              children: [
                                Icon(Icons.link_rounded, size: 16, color: primaryCyan),
                                SizedBox(width: 8),
                                Text(
                                  'WEBSOCKET URL',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _webSocketUrlController,
                              keyboardType: TextInputType.url,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                fontFamily: 'monospace',
                              ),
                              decoration: InputDecoration(
                                hintText: 'wss://xxxxxxxx.ngrok-free.app/ws',
                                hintStyle: const TextStyle(color: Color(0xFF475569)),
                                filled: true,
                                fillColor: const Color(0xFF0A0E17),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: borderDark),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: borderDark),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: primaryCyan, width: 1.5),
                                ),
                                suffixIcon: _webSocketUrlController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                                        onPressed: () => _webSocketUrlController.clear(),
                                      )
                                    : null,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'WebSocket URL is required';
                                }
                                final url = value.trim();
                                if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
                                  return 'Must start with ws:// or wss://';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // NEXT Action Button
                      ElevatedButton(
                        onPressed: _isSaving ? null : _onNextPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryCyan,
                          foregroundColor: const Color(0xFF0A0E17),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 4,
                          shadowColor: primaryCyan.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF0A0E17),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'NEXT',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                      ),
                      const SizedBox(height: 24),

                      // Info text
                      const Center(
                        child: Text(
                          'Settings are stored locally on device for automatic recall.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
