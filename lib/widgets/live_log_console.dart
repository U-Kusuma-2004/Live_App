import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';

/// A deliberately dark terminal panel embedded in the light console — the one
/// place where a charcoal surface is right, because it *is* a log tail.
class LiveLogConsole extends StatefulWidget {
  final double maxHeight;
  final bool isCollapsible;
  final VoidCallback? onClose;

  const LiveLogConsole({
    super.key,
    this.maxHeight = 240,
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
    if (!_autoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return const Color(0xFF7CA9FF);
      case LogLevel.wsOut:
        return const Color(0xFF4ADE9B);
      case LogLevel.wsIn:
        return const Color(0xFF57C7FF);
      case LogLevel.gps:
        return const Color(0xFFB69CFF);
      case LogLevel.camera:
        return const Color(0xFFFFC65C);
      case LogLevel.warn:
        return const Color(0xFFFFA24D);
      case LogLevel.error:
        return const Color(0xFFFF7A85);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.console,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _isCollapsed ? const SizedBox(width: double.infinity) : _body(),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: const BoxDecoration(
        color: AppColors.consoleHeader,
        border: Border(bottom: BorderSide(color: AppColors.consoleLine)),
      ),
      child: Row(
        children: [
          const Icon(Icons.terminal_rounded, size: 15, color: Color(0xFF57C7FF)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Live monitor',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE6EBF2),
              ),
            ),
          ),
          _iconBtn(
            _autoScroll ? Icons.vertical_align_bottom_rounded : Icons.pause_rounded,
            _autoScroll ? 'Auto-scroll on' : 'Auto-scroll paused',
            () => setState(() => _autoScroll = !_autoScroll),
            active: _autoScroll,
          ),
          _iconBtn(Icons.copy_rounded, 'Copy logs', () {
            Clipboard.setData(ClipboardData(text: LogService.exportLogsAsString()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logs copied to clipboard')),
            );
          }),
          _iconBtn(Icons.delete_outline_rounded, 'Clear', LogService.clear),
          if (widget.isCollapsible)
            _iconBtn(
              _isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
              _isCollapsed ? 'Expand' : 'Collapse',
              () => setState(() => _isCollapsed = !_isCollapsed),
            ),
          if (widget.onClose != null)
            _iconBtn(Icons.close_rounded, 'Hide', widget.onClose!),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tip, VoidCallback onTap, {bool active = false}) {
    return IconButton(
      icon: Icon(icon, size: 16),
      color: active ? const Color(0xFF57C7FF) : const Color(0xFF93A0B2),
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onTap,
    );
  }

  Widget _body() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: const Color(0xFF161D26),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All', null),
                _chip('Out', LogLevel.wsOut),
                _chip('In', LogLevel.wsIn),
                _chip('GPS', LogLevel.gps),
                _chip('Cam', LogLevel.camera),
                _chip('Errors', LogLevel.error),
              ],
            ),
          ),
        ),
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
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nothing logged yet. Start the stream to watch telemetry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF6B7787),
                        fontSize: 12,
                        fontFamily: kMonoFont,
                      ),
                    ),
                  ),
                );
              }

              _scrollToBottom();

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                itemCount: filtered.length,
                itemBuilder: (context, i) => _logItem(filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, LogLevel? level) {
    final selected = _selectedFilter == level;
    final color = level == null ? const Color(0xFF57C7FF) : _levelColor(level);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = level),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : const Color(0xFF222B36),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? color : const Color(0xFF9AA6B6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logItem(LogEntry entry) {
    final color = _levelColor(entry.level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
                  fontFamily: kMonoFont,
                  color: Color(0xFF67748A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.tag,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    fontFamily: kMonoFont,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.message,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: kMonoFont,
                    height: 1.35,
                    color: entry.level == LogLevel.error
                        ? const Color(0xFFFF9AA3)
                        : const Color(0xFFD9E0EA),
                  ),
                ),
              ),
            ],
          ),
          if (entry.payload != null && entry.payload!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Container(
              margin: const EdgeInsets.only(left: 62),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF12181F),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.consoleLine),
              ),
              child: SelectableText(
                entry.payload!,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: kMonoFont,
                  height: 1.4,
                  color: Color(0xFF8D9AAC),
                ),
              ),
            ),
          ],
          if (entry.error != null) ...[
            const SizedBox(height: 3),
            Container(
              margin: const EdgeInsets.only(left: 62),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF3A1B20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                entry.error.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: kMonoFont,
                  height: 1.4,
                  color: Color(0xFFFFA3AC),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
