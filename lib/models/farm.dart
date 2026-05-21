import 'model_utils.dart';

/// Immutable farm entity.
///
/// Mirrors the backend `/v1/farms` resource. The API wraps every payload in
/// the `{ success, data }` envelope; this model represents a single unwrapped
/// `data` (or `data[]` element) object only.
class Farm {
  const Farm({
    required this.id,
    required this.name,
    required this.cropType,
    required this.areaHectares,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.address,
  });

  final String id;
  final String name;
  final String cropType;
  final double areaHectares;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? address;

  factory Farm.fromJson(Map<String, dynamic> json) => Farm(
        id: json['id'] as String,
        name: json['name'] as String,
        cropType: (json['cropType'] ?? json['crop_type']) as String,
        areaHectares:
            toDoubleOrNull(json['areaHectares'] ?? json['area_hectares']) ?? 0,
        createdAt: DateTime.parse(
          (json['createdAt'] ?? json['created_at']).toString(),
        ),
        latitude: toDoubleOrNull(json['latitude']),
        longitude: toDoubleOrNull(json['longitude']),
        address: json['address'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cropType': cropType,
        'areaHectares': areaHectares,
        'createdAt': createdAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      };

  Farm copyWith({
    String? id,
    String? name,
    String? cropType,
    double? areaHectares,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
    String? address,
  }) =>
      Farm(
        id: id ?? this.id,
        name: name ?? this.name,
        cropType: cropType ?? this.cropType,
        areaHectares: areaHectares ?? this.areaHectares,
        createdAt: createdAt ?? this.createdAt,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        address: address ?? this.address,
      );
}
