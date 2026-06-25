/// A single pending operation in the offline outbox.
class OutboxOp {
  final String id;
  final String opType;
  final Map<String, dynamic> payload;
  final String? imageRef;
  final String? audioRef;
  final String? eventId;
  final String status;
  final int attempts;
  final String? lastError;
  final int createdAt;
  final String? serverId;

  /// Duplicate-match payload (JSON list of existing contacts) when [status] is
  /// 'needs_review'. Null otherwise.
  final String? reviewData;

  const OutboxOp({
    required this.id,
    required this.opType,
    required this.payload,
    this.imageRef,
    this.audioRef,
    this.eventId,
    required this.status,
    required this.attempts,
    this.lastError,
    required this.createdAt,
    this.serverId,
    this.reviewData,
  });

  bool get isPending => status == 'pending' || status == 'syncing';
  bool get isFailed => status == 'failed';
  bool get needsReview => status == 'needs_review';
}
