/// Delete-tombstone operations a repository exposes to [SyncOrchestrator].
///
/// v1.11.5 — a local delete marks a synced row `pendingDelete` (hidden from
/// every list) instead of removing it; the orchestrator sends the server
/// DELETE and only then [purge]s the row. A pulled row with `deleted_at`
/// is purged, and a locally tombstoned row is never resurrected by a pull.
abstract interface class SyncDeletable {
  /// Ids of rows deleted locally whose server DELETE is still pending.
  Future<List<String>> getPendingDeleteIds();

  /// Whether [id] is a local tombstone awaiting its server DELETE.
  Future<bool> isPendingDelete(String id);

  /// Hard-deletes [id] locally (server confirmed, or server-side deleted).
  Future<void> purge(String id);
}
