class VehicleModel {
  final String id;
  final String type;
  final String manufacturer;
  final String model;
  final String plateNumber;
  final String? year;
  final String? color;
  final bool isDefault;

  const VehicleModel({
    required this.id,
    required this.type,
    required this.manufacturer,
    required this.model,
    required this.plateNumber,
    this.year,
    this.color,
    this.isDefault = false,
  });

  String get displayName => '$manufacturer $model';

  String get typeIcon {
    switch (type) {
      case 'Bike':
        return '🏍️';
      case 'Car':
        return '🚗';
      case 'Van':
        return '🚐';
      case 'Auto':
        return '🛺';
      case 'Bus':
        return '🚌';
      case 'Light Commercial Vehicle':
        return '🚛';
      case 'Heavy Vehicle':
        return '🚚';
      default:
        return '🚗';
    }
  }

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      type: json['type'] as String,
      manufacturer: json['manufacturer'] as String,
      model: json['model'] as String,
      plateNumber: json['plateNumber'] as String,
      year: json['year'] as String?,
      color: json['color'] as String?,
      isDefault: (json['isDefault'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'manufacturer': manufacturer,
      'model': model,
      'plateNumber': plateNumber,
      if (year != null) 'year': year,
      if (color != null) 'color': color,
      'isDefault': isDefault,
    };
  }

  VehicleModel copyWith({
    String? id,
    String? type,
    String? manufacturer,
    String? model,
    String? plateNumber,
    String? year,
    String? color,
    bool? isDefault,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      type: type ?? this.type,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      plateNumber: plateNumber ?? this.plateNumber,
      year: year ?? this.year,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

const List<String> vehicleTypes = [
  'Bike',
  'Car',
  'Van',
  'Auto',
  'Bus',
  'Light Commercial Vehicle',
  'Heavy Vehicle',
];
