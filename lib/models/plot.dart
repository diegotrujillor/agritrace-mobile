import 'model_utils.dart';

/// Lifecycle status of a plot. Matches the backend `status` enum exactly:
/// `planning` | `growing` | `ready` | `harvested`.
enum PlotStatus {
  planning,
  growing,
  ready,
  harvested;

  /// Human-readable Spanish label for UI display.
  String get label => switch (this) {
        PlotStatus.planning => 'Planificación',
        PlotStatus.growing => 'En crecimiento',
        PlotStatus.ready => 'Listo para cosecha',
        PlotStatus.harvested => 'Cosechado',
      };

  static PlotStatus fromName(Object? value) => PlotStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => PlotStatus.planning,
      );
}

/// Immutable plot entity.
///
/// Mirrors the backend `/v1/plots` resource (a plot belongs to a farm via
/// [farmId]). Represents a single unwrapped `data` envelope element only.
class Plot {
  const Plot({
    required this.id,
    required this.farmId,
    required this.name,
    required this.cropType,
    required this.status,
    required this.createdAt,
    this.variety,
    this.areaHectares,
  });

  final String id;
  final String farmId;
  final String name;
  final String cropType;
  final PlotStatus status;
  final DateTime createdAt;
  final String? variety;
  final double? areaHectares;

  factory Plot.fromJson(Map<String, dynamic> json) => Plot(
        id: json['id'] as String,
        farmId: (json['farmId'] ?? json['farm_id']) as String,
        name: json['name'] as String,
        cropType: (json['cropType'] ?? json['crop_type']) as String,
        status: PlotStatus.fromName(json['status']),
        createdAt: DateTime.parse(
          (json['createdAt'] ?? json['created_at']).toString(),
        ),
        variety: json['variety'] as String?,
        areaHectares:
            toDoubleOrNull(json['areaHectares'] ?? json['area_hectares']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'farmId': farmId,
        'name': name,
        'cropType': cropType,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'variety': variety,
        'areaHectares': areaHectares,
      };

  Plot copyWith({
    String? id,
    String? farmId,
    String? name,
    String? cropType,
    PlotStatus? status,
    DateTime? createdAt,
    String? variety,
    double? areaHectares,
  }) =>
      Plot(
        id: id ?? this.id,
        farmId: farmId ?? this.farmId,
        name: name ?? this.name,
        cropType: cropType ?? this.cropType,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        variety: variety ?? this.variety,
        areaHectares: areaHectares ?? this.areaHectares,
      );
}
