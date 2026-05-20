import 'api_service.dart';

/// A single local change to push to the backend. Sprint 3 has no local DB
/// (that is Sprint 4), so the change set is supplied by the caller — there is
/// no local change journal to drain yet. The shape mirrors the documented
/// sync protocol: `{ entity, id, action, data }`.
class SyncChange {
  const SyncChange({
    required this.entity,
    required this.id,
    required this.action,
    required this.data,
  });

  /// `'farm' | 'plot' | 'activity'`.
  final String entity;
  final String id;

  /// `'create' | 'update'`.
  final String action;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
        'entity': entity,
        'id': id,
        'action': action,
        'data': data,
      };
}

/// Outcome of a [SyncService.syncNow] round trip. Immutable.
class SyncResult {
  const SyncResult({
    required this.synced,
    required this.conflicts,
    required this.pulledChanges,
    required this.timestamp,
  });

  /// Number of pushed changes accepted by the server.
  final int synced;

  /// Number of server-detected conflicts (Last-Write-Wins resolved server
  /// side per the documented protocol).
  final int conflicts;

  /// Raw change records returned by the pull leg. Applying these to a local
  /// store is Sprint 4; for now they are surfaced for visibility/tests.
  final List<Map<String, dynamic>> pulledChanges;

  /// Server clock at completion — the cursor for the next incremental pull.
  final DateTime timestamp;
}

/// Thin wrapper over [ApiService] for the `/sync` endpoints.
///
/// Mirrors the other services: no Flutter deps, constructor injection. The
/// push leg posts a change set; the pull leg fetches changes since a cursor.
/// The pull response is read through the standard `{ success, data }`
/// envelope; the push response carries `synced`/`conflicts` counters.
class SyncService {
  const SyncService(this._api);

  final ApiService _api;

  /// Pushes [changes] then pulls everything changed since [since].
  ///
  /// [since] is the previous successful sync timestamp (null on first run →
  /// full pull). With no local DB this sprint, [changes] defaults to empty.
  Future<SyncResult> syncNow({
    List<SyncChange> changes = const [],
    DateTime? since,
  }) async {
    final pushResponse = await _api.client.post('/sync', data: {
      'changes': [for (final c in changes) c.toJson()],
    });
    final push = _pushEnvelope(pushResponse.data);

    final pullResponse = await _api.client.get(
      '/sync/changes',
      queryParameters: {
        // .toUtc() so the ISO string carries the 'Z' suffix the backend
        // expects for the `since` filter.
        if (since != null) 'since': since.toUtc().toIso8601String(),
      },
    );
    final pull = _pullEnvelope(pullResponse.data);

    final rawChanges = (pull['changes'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);

    return SyncResult(
      synced: _toInt(push['synced']),
      conflicts: _toInt(push['conflicts']),
      pulledChanges: rawChanges,
      timestamp: _parseTimestamp(pull['timestamp'] ?? push['timestamp']),
    );
  }

  /// Push response is `{ success, synced, conflicts, timestamp }` (counters
  /// at top level, not under a `data` key).
  Map<String, dynamic> _pushEnvelope(Object? body) {
    if (body is! Map<String, dynamic> || body['success'] != true) {
      throw const FormatException('Invalid sync push response');
    }
    return body;
  }

  /// Pull response uses the standard `{ success, data: { changes, timestamp } }`
  /// envelope.
  Map<String, dynamic> _pullEnvelope(Object? body) {
    if (body is! Map<String, dynamic> ||
        body['success'] != true ||
        body['data'] == null) {
      throw const FormatException('Invalid sync pull response');
    }
    return body['data'] as Map<String, dynamic>;
  }

  int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  DateTime _parseTimestamp(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }
}
