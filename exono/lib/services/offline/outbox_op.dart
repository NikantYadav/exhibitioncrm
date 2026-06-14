/// A single pending operation in the offline outbox.
class OutboxOp {
  final String id;
  final String opType;
  final Map<String, dynamic> payload;
  final String? imageRef;
  final String? eventId;
  final String status;
  final int attempts;
  final String? lastError;
  final int createdAt;
  final String? serverId;

  const OutboxOp({
    required this.id,
    required this.opType,
    required this.payload,
    this.imageRef,
    this.eventId,
    required this.status,
    required this.attempts,
    this.lastError,
    required this.createdAt,
    this.serverId,
  });

  bool get isPending => status == 'pending' || status == 'syncing';
  bool get isFailed => status == 'failed';
}
