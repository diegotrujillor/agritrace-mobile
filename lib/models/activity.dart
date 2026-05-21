/// Type of agricultural activity recorded against a plot. Matches the
/// backend `type` enum. The serialised wire value is snake_case
/// (`pest_control`); [ActivityType.name] is camelCase in Dart, so
/// serialisation goes through [wire] / [fromWire] explicitly.
enum ActivityType {
  sowing,
  fertilization,
  irrigation,
  pestControl,
  harvest,
  other;

  /// Backend wire value (snake_case).
  String get wire => switch (this) {
        ActivityType.sowing => 'sowing',
        ActivityType.fertilization => 'fertilization',
        ActivityType.irrigation => 'irrigation',
        ActivityType.pestControl => 'pest_control',
        ActivityType.harvest => 'harvest',
        ActivityType.other => 'other',
      };

  /// Human-readable Spanish label for UI display.
  String get label => switch (this) {
        ActivityType.sowing => 'Siembra',
        ActivityType.fertilization => 'Fertilización',
        ActivityType.irrigation => 'Riego',
        ActivityType.pestControl => 'Control de plagas',
        ActivityType.harvest => 'Cosecha',
        ActivityType.other => 'Otra',
      };

  /// Tolerant parse: accepts the snake_case wire value, falling back to
  /// [ActivityType.other] for unknown/missing input rather than throwing.
  static ActivityType fromWire(Object? value) => ActivityType.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => ActivityType.other,
      );
}

/// Immutable activity entity.
///
/// Mirrors the backend `/v1/activities` resource (an activity belongs to a
/// plot via [plotId]). Represents a single unwrapped `data` envelope element
/// only.
class Activity {
  const Activity({
    required this.id,
    required this.plotId,
    required this.type,
    required this.occurredAt,
    required this.createdAt,
    this.description,
    this.photoUrl,
  });

  final String id;
  final String plotId;
  final ActivityType type;
  final DateTime occurredAt;
  final DateTime createdAt;
  final String? description;
  final String? photoUrl;

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as String,
        plotId: (json['plotId'] ?? json['plot_id']) as String,
        type: ActivityType.fromWire(json['type']),
        occurredAt: DateTime.parse(
          (json['occurredAt'] ?? json['occurred_at']).toString(),
        ),
        createdAt: DateTime.parse(
          (json['createdAt'] ?? json['created_at']).toString(),
        ),
        description: json['description'] as String?,
        photoUrl: (json['photoUrl'] ?? json['photo_url']) as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'plotId': plotId,
        'type': type.wire,
        'occurredAt': occurredAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'description': description,
        'photoUrl': photoUrl,
      };

  Activity copyWith({
    String? id,
    String? plotId,
    ActivityType? type,
    DateTime? occurredAt,
    DateTime? createdAt,
    String? description,
    String? photoUrl,
  }) =>
      Activity(
        id: id ?? this.id,
        plotId: plotId ?? this.plotId,
        type: type ?? this.type,
        occurredAt: occurredAt ?? this.occurredAt,
        createdAt: createdAt ?? this.createdAt,
        description: description ?? this.description,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}
