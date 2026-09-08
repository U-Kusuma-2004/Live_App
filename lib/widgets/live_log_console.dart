import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/log_service.dart';

class LiveLogConsole extends StatefulWidget {
  final double maxHeight;
  final bool isCollapsible;
  final VoidCallback? onClose;

  const LiveLogConsole({
    super.key,
    this.maxHeight = 260,
    this.isCollapsible = true,
    this.onClose,
  });

  @override
  State<LiveLogConsole> createState() => _LiveLogConsoleState();
}

class _LiveLogConsoleState extends State<LiveLogConsole> {
  final ScrollController _scrollController = ScrollController();
  LogLevel? _selectedFilter;
  bool _autoScroll = true;
  bool _isCollapsed = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return const Color(0xFF60A5FA); // Blue
      case LogLevel.wsOut:
        return const Color(0xFF34D399); // Emerald
      case LogLevel.wsIn:
        return const Color(0xFF00E5FF); // Cyan
      case LogLevel.gps:
        return const Color(0xFFA78BFA); // Purple
      case LogLevel.camera:
        return const Color(0xFFFBBF24); // Amber
      case LogLevel.warn:
        return const Color(0xFFFB923C); // Orange
      case LogLevel.error:
        return const Color(0xFFFF3366); // Red
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgConsole = Color(0xFF070B12);
    const borderDark = Color(0xFF1E293B);

    return Container(
      decoration: BoxDecoration(
        color: bgConsole,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderDark, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Console Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              border: Border(bottom: BorderSide(color: borderDark)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 16, color: Color(0xFF00E5FF)),
                const SizedBox(width: 8),
                const Text(
                  'LIVE MONITOR & LOGS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                const Spacer(),

                // Auto scroll toggle
                IconButton(
                  icon: Icon(
                    _autoScroll ? Icons.arrow_downward_rounded : Icons.pause_circle_outline_rounded,
                    size: 16,
                    color: _autoScroll ? const Color(0xFF00E5FF) : const Color(0xFF64748B),
                  ),
                  tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll PAUSED',
                  onPressed: () => setState(() => _autoScroll = !_autoScroll),
                  visualDensity: VisualDensity.compact,
                ),

                // Copy all logs
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF94A3B8)),
                  tooltip: 'Copy all logs',
                  onPressed: () {
                    final text = LogService.exportLogsAsString();
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All logs copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  visualDensity: VisualDensity.compact,
                ),

                // Clear logs
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Color(0xFF94A3B8)),
                  tooltip: 'Clear logs',
                  onPressed: () => LogService.clear(),
                  visualDensity: VisualDensity.compact,
                ),

                if (widget.isCollapsible)
                  IconButton(
                    icon: Icon(
                      _isCollapsed ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 18,
                      color: const Color(0xFF94A3B8),
                    ),
                    onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                    visualDensity: VisualDensity.compact,
                  ),

                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                    onPressed: widget.onClose,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          if (!_isCollapsed) ...[
            // Filter Chips Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: const Color(0xFF090D16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', null),
                    _buildFilterChip('OUT', LogLevel.wsOut),
                    _buildFilterChip('IN', LogLevel.wsIn),
                    _buildFilterChip('GPS', LogLevel.gps),
                    _buildFilterChip('CAM', LogLevel.camera),
                    _buildFilterChip('ERR', LogLevel.error),
                  ],
                ),
              ),
            ),

            // Log entries stream list
            SizedBox(
              height: widget.maxHeight,
              child: ValueListenableBuilder<List<LogEntry>>(
                valueListenable: LogService.logsNotifier,
                builder: (context, allLogs, _) {
                  final filtered = _selectedFilter == null
                      ? allLogs
                      : allLogs.where((l) => l.level == _selectedFilter).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No logs recorded yet. Start streaming to monitor telemetry.',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  }

                  _scrollToBottom();

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      return _buildLogItem(entry);
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, LogLevel? level) {
    final isSelected = _selectedFilter == level;
    final color = level == null ? const Color(0xFF00E5FF) : _getLevelColor(level);

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = level),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF131B2A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? color : const Color(0xFF22304A),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isSelected ? color : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogItem(LogEntry entry) {
    final color = _getLevelColor(entry.level);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.formattedTime,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  entry.tag.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.message,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: entry.level == LogLevel.error
                        ? const Color(0xFFFF6B8B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ],
          ),
          if (entry.payload != null && entry.payload!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Container(
              margin: const EdgeInsets.only(left: 65),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: SelectableText(
                entry.payload!,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
          if (entry.error != null) ...[
            const SizedBox(height: 2),
            Container(
              margin: const EdgeInsets.only(left: 65),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF3B1219),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '❌ ${entry.error}',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Color(0xFFFF8FA3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
