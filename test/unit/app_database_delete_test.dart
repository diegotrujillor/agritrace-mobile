/// Local delete tombstones (v1.11.5). Before this, deleting a row only
/// removed it from Drift: no server DELETE was ever sent, so the next pull
/// (or re-login) brought it back (prod 2026-11-13, comercial@ demo).
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/database/app_database.dart';

ActivitiesTableCompanion _activity(String id, String syncStatus) =>
    ActivitiesTableCompanion(
      id: Value(id),
      plotId: const Value('p1'),
      type: const Value('fertilization'),
      occurredAt: Value(DateTime.utc(2026, 11, 13)),
      createdAt: Value(DateTime.utc(2026, 11, 13)),
      updatedAt: Value(DateTime.utc(2026, 11, 13)),
      syncStatus: Value(syncStatus),
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('deleting a never-synced row removes it outright (no server call)',
      () async {
    // Arrange
    await db.upsertActivity(_activity('a1', 'pendingCreate'));

    // Act
    await db.queueDelete('activity', 'a1');

    // Assert
    expect(await db.getActivity('a1'), isNull);
    expect(await db.getPendingDeleteIds('activity'), isEmpty);
  });

  test('deleting a synced row leaves a hidden pendingDelete tombstone',
      () async {
    // Arrange
    await db.upsertActivity(_activity('a1', 'synced'));
    await db.upsertActivity(_activity('a2', 'synced'));

    // Act
    await db.queueDelete('activity', 'a1');

    // Assert
    expect(await db.getPendingDeleteIds('activity'), ['a1']);
    expect(await db.isPendingDelete('activity', 'a1'), isTrue);
    final visible = await db.getActivitiesByPlot('p1');
    expect(visible.map((r) => r.id), ['a2']);
    final watched = await db.watchActivitiesByPlot('p1').first;
    expect(watched.map((r) => r.id), ['a2']);
    expect(await db.getPendingActivities(), isEmpty,
        reason: 'tombstones must not be pushed as create/update');
  });

  test('purgeRow hard-deletes the tombstone after the server confirmed',
      () async {
    // Arrange
    await db.upsertActivity(_activity('a1', 'synced'));
    await db.queueDelete('activity', 'a1');

    // Act
    await db.purgeRow('activity', 'a1');

    // Assert
    expect(await db.getActivity('a1'), isNull);
    expect(await db.isPendingDelete('activity', 'a1'), isFalse);
  });

  test('rejects an unknown entity name', () async {
    expect(() => db.queueDelete('users', 'x'), throwsArgumentError);
  });
}
