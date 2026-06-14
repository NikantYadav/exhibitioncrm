import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/event.dart';
import '../providers/live_event_provider.dart';
import '../services/api_service.dart';
import 'event_follow_ups_screen.dart';
import 'pre_event_prep_screen.dart';

class EventRouterScreen extends StatefulWidget {
  final String eventId;
  final Event? event;

  const EventRouterScreen({super.key, required this.eventId, this.event});

  @override
  State<EventRouterScreen> createState() => _EventRouterScreenState();
}

class _EventRouterScreenState extends State<EventRouterScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      // Event already available — navigate before first frame renders.
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigate(widget.event!));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final event = await _fetch();
        if (event != null) _navigate(event);
      });
    }
  }

  Future<Event?> _fetch() async {
    try {
      return await ApiService.getEvent(widget.eventId);
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) context.go('/events');
      return null;
    }
  }

  void _navigate(Event event) {
    if (!mounted) return;
    if (event.status == 'ongoing') {
      context.read<LiveEventProvider>().refresh();
      context.go('/live-event');
    } else if (event.status == 'completed') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => EventFollowUpsScreen(event: event)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PreEventPrepScreen(event: event)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
