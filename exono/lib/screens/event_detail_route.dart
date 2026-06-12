import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import 'event_follow_ups_screen.dart';
import 'pre_event_prep_screen.dart';
import '../utils/screen_logger.dart';

class EventDetailRoute extends StatefulWidget {
  final String eventId;

  const EventDetailRoute({super.key, required this.eventId});

  @override
  State<EventDetailRoute> createState() => _EventDetailRouteState();
}

class _EventDetailRouteState extends State<EventDetailRoute> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  Event? _event;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final event = await ApiService.getEvent(widget.eventId);
      if (mounted) setState(() { _event = event; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: _c.background);
    }
    if (_error != null || _event == null) {
      return Scaffold(
        backgroundColor: _c.background,
        body: Center(
          child: Text('Event not found', style: TextStyle(color: _c.textSecondary)),
        ),
      );
    }

    final event = _event!;
    switch (event.status) {
      case 'ongoing':
        WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/live-event'));
        return Scaffold(backgroundColor: _c.background);
      case 'upcoming':
        return PreEventPrepScreen(event: event);
      case 'completed':
        return EventFollowUpsScreen(event: event);
      default:
        return PreEventPrepScreen(event: event);
    }
  }
}
