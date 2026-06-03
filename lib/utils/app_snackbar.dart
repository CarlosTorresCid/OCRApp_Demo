import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

/// Llave global del navigator — debe asignarse al MaterialApp:
///   navigatorKey: AppNotify.navigatorKey
GlobalKey<NavigatorState> get appNavigatorKey => _navigatorKey;

class AppNotify {
  static void success(String title, String message) {
    _show(title: title, message: message, bg: Colors.green, text: Colors.white);
  }

  static void error(String title, String message) {
    _show(title: title, message: message, bg: Colors.red, text: Colors.white);
  }

  static void info(String title, String message) {
    _show(title: title, message: message, bg: Colors.blue, text: Colors.white);
  }

  static void warning(String title, String message) {
    _show(title: title, message: message, bg: Colors.orange, text: Colors.white);
  }

  static void connection(String title, String message) {
    _show(title: title, message: message, bg: Colors.grey.shade800, text: Colors.white);
  }

  static VoidCallback loading(String title, String message) {
    return _show(
      title: title,
      message: message,
      bg: Colors.blue,
      text: Colors.white,
      persistent: true,
    );
  }

  static VoidCallback _show({
    required String title,
    required String message,
    required Color bg,
    required Color text,
    bool persistent = false,
  }) {
    final overlay = _navigatorKey.currentState?.overlay;
    if (overlay == null) return () {};

    return OverlayNotification.show(
      overlay: overlay,
      title: title,
      message: message,
      backgroundColor: bg,
      textColor: text,
      persistent: persistent,
    );
  }
}

class OverlayNotification {
  static OverlayEntry? _lastEntry;

  /// Devuelve una función que cierra esta notificación concreta.
  static VoidCallback show({
    required OverlayState overlay,
    required String title,
    required String message,
    required Color backgroundColor,
    required Color textColor,
    bool persistent = false,
  }) {
    _lastEntry?.remove();
    _lastEntry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _NotifyOverlayWidget(
        title: title,
        message: message,
        backgroundColor: backgroundColor,
        textColor: textColor,
        persistent: persistent,
        onDismiss: () {
          if (_lastEntry == entry) {
            _lastEntry = null;
          }
          entry.remove();
        },
      ),
    );

    _lastEntry = entry;
    overlay.insert(entry);

    return () {
      if (_lastEntry == entry) {
        _lastEntry = null;
      }
      try { entry.remove(); } catch (_) {}
    };
  }
}

class _NotifyOverlayWidget extends StatefulWidget {
  final String title;
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final bool persistent;
  final VoidCallback onDismiss;

  const _NotifyOverlayWidget({
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.onDismiss,
    this.persistent = false,
  });

  @override
  State<_NotifyOverlayWidget> createState() => _NotifyOverlayWidgetState();
}

class _NotifyOverlayWidgetState extends State<_NotifyOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  bool _isRemoved = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();

    if (!widget.persistent) {
      Future.delayed(const Duration(milliseconds: 4000), () {
        if (mounted && !_isRemoved) {
          _controller.reverse().then((_) {
            if (mounted && !_isRemoved) {
              _isRemoved = true;
              widget.onDismiss();
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _manualDismiss() {
    if (!_isRemoved) {
      _isRemoved = true;
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double hPadding = (kIsWeb && width >= 600) ? width * 0.20 : 16.0;

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: hPadding,
            right: hPadding,
            child: SlideTransition(
              position: _offsetAnimation,
              child: Material(
                color: Colors.transparent,
                child: Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.up,
                  onDismissed: (_) => _manualDismiss(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: widget.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.message,
                          style: TextStyle(
                            color: widget.textColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
