/// Kind of alert. Matches the backend `type` enum. Wire values are already
/// lowercase single words so [name] doubles as the wire value, but parsing
/// goes through [fromWire] for tolerance.
enum AlertType {
  weather,
  reminder;

  String get wire => name;

  String get label => switch (this) {
        AlertType.weather => 'Clima',
        AlertType.reminder => 'Recordatorio',
      };

  static AlertType fromWire(Object? value) => AlertType.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => AlertType.reminder,
      );
}

/// Severity drives the accent colour in the UI. Matches backend enum.
enum AlertSeverity {
  info,
  warning,
  severe;

  String get wire => name;

  String get label => switch (this) {
        AlertSeverity.info => 'Info',
        AlertSeverity.warning => 'Atención',
        AlertSeverity.severe => 'Urgente',
      };

  static AlertSeverity fromWire(Object? value) =>
      AlertSeverity.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => AlertSeverity.info,
      );
}

/// Lifecycle status. Matches backend enum.
enum AlertStatus {
  pending,
  sent,
  dismissed;

  String get wire => name;

  String get label => switch (this) {
        AlertStatus.pending => 'Pendiente',
        AlertStatus.sent => 'Enviada',
        AlertStatus.dismissed => 'Descartada',
      };

  static AlertStatus fromWire(Object? value) =>
      AlertStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => AlertStatus.pending,
      );
}

/// Immutable alert entity. Mirrors the backend `/v1/alerts` resource: a
/// weather notice or a scheduled reminder, owned by a producer and
/// optionally tied to a plot. Represents a single unwrapped `data`
/// envelope element only.
class Alert {
  const Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.status,
    required this.createdAt,
    this.plotId,
    this.body,
    this.scheduledFor,
  });

  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final AlertStatus status;
  final DateTime createdAt;
  final String? plotId;
  final String? body;
  final DateTime? scheduledFor;

  static DateTime? _parseNullableDate(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] as String,
        type: AlertType.fromWire(json['type']),
        severity: AlertSeverity.fromWire(json['severity']),
        title: json['title'] as String,
        status: AlertStatus.fromWire(json['status']),
        createdAt: DateTime.parse(json['createdAt'] as String),
        plotId: json['plotId'] as String?,
        body: json['body'] as String?,
        scheduledFor: _parseNullableDate(json['scheduledFor']),
      );

  Alert copyWith({AlertStatus? status}) => Alert(
        id: id,
        type: type,
        severity: severity,
        title: title,
        status: status ?? this.status,
        createdAt: createdAt,
        plotId: plotId,
        body: body,
        scheduledFor: scheduledFor,
      );
}
