import 'package:flutter/material.dart';
import '../services/log_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable.dart';
import 'live_stream_screen.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleIdController = TextEditingController();
  final _userIdController = TextEditingController();
  final _userNameController = TextEditingController();
  final _webSocketUrlController = TextEditingController();

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
    if (!mounted) return;
    setState(() {
      _vehicleIdController.text = config['vehicleId'] ?? 'TRUCK_001';
      _userIdController.text = config['userId'] ?? '';
      _userNameController.text = config['userName'] ?? '';
      _webSocketUrlController.text =
          config['webSocketUrl'] ?? 'wss://your-server.ngrok-free.app/ws';
      _isLoading = false;
    });
    LogService.info(
      'Config',
      'Config loaded: camera_id="${_vehicleIdController.text}", user_id="${_userIdController.text}", user_name="${_userNameController.text}", WebSocket="${_webSocketUrlController.text}"',
    );
  }

  Future<void> _onStart() async {
    if (!_formKey.currentState!.validate()) {
      LogService.warn('Config', 'Validation failed on config screen.');
      return;
    }
    setState(() => _isSaving = true);

    final vehicleId = _vehicleIdController.text.trim();
    final userId = _userIdController.text.trim();
    final userName = _userNameController.text.trim();
    final webSocketUrl = _webSocketUrlController.text.trim();

    LogService.info('Config',
        'Saving config: camera_id="$vehicleId", user_id="$userId", user_name="$userName", URL="$webSocketUrl"');
    await PreferencesService.saveConfig(
      vehicleId: vehicleId,
      userId: userId,
      userName: userName,
      webSocketUrl: webSocketUrl,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    LogService.info('Navigation', 'Navigating to Screen 2 (LiveStreamScreen)...');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveStreamScreen(
          vehicleId: vehicleId,
          userId: userId,
          userName: userName,
          webSocketUrl: webSocketUrl,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _vehicleIdController.dispose();
    _userIdController.dispose();
    _userNameController.dispose();
    _webSocketUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _hero(),
                          const SizedBox(height: 32),
                          _card(),
                          const SizedBox(height: 24),
                          Pressable(
                            onPressed: _isSaving ? null : _onStart,
                            loading: _isSaving,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Start session'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Settings are saved on this device and restored next time.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.inkFaint),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _hero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.sensors_rounded, size: 26, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          'Fleet live console',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 6),
        const Text(
          'Stream the vehicle camera to your AI endpoint and get drowsiness alerts back in real time.',
          style: TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.45),
        ),
      ],
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(Icons.videocam_outlined, 'Camera / vehicle ID'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _vehicleIdController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.ink,
            ),
            decoration: const InputDecoration(hintText: 'e.g. TRUCK_001'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a camera ID' : null,
          ),
          const SizedBox(height: 20),
          _fieldLabel(Icons.person_outline_rounded, 'Driver name'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _userNameController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.ink,
            ),
            decoration: const InputDecoration(hintText: 'e.g. Priya Sharma'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter the driver name' : null,
          ),
          const SizedBox(height: 20),
          _fieldLabel(Icons.badge_outlined, 'User ID'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _userIdController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.ink,
            ),
            decoration: const InputDecoration(hintText: 'account or driver id the server expects'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter the user ID your endpoint requires' : null,
          ),
          const SizedBox(height: 20),
          _fieldLabel(Icons.link_rounded, 'WebSocket endpoint'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _webSocketUrlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
              fontFamily: kMonoFont,
              color: AppColors.ink,
            ),
            decoration: const InputDecoration(hintText: 'wss://host.ngrok-free.app/ws'),
            validator: (v) {
              final url = (v ?? '').trim();
              if (url.isEmpty) return 'Enter the endpoint URL';
              if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
                return 'Start with ws:// or wss://';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.brand),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
