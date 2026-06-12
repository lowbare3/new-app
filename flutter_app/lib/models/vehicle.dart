class Vehicle {
  final String id;
  final String name;
  final String icon;
  final int capacity;
  final String description;
  final double baseFare;
  final double perKmRate;
  final double perMinRate;
  final double multiplier;
  final String eta;
  final int fareEstimate;
  final double distanceKm;
  final int durationMin;

  Vehicle({
    required this.id,
    required this.name,
    required this.icon,
    required this.capacity,
    required this.description,
    required this.baseFare,
    required this.perKmRate,
    required this.perMinRate,
    required this.multiplier,
    required this.eta,
    required this.fareEstimate,
    required this.distanceKm,
    required this.durationMin,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '🚗',
      capacity: json['capacity'] ?? 4,
      description: json['description'] ?? '',
      baseFare: (json['baseFare'] ?? 0).toDouble(),
      perKmRate: (json['perKmRate'] ?? 0).toDouble(),
      perMinRate: (json['perMinRate'] ?? 0).toDouble(),
      multiplier: (json['multiplier'] ?? 1).toDouble(),
      eta: json['eta'] ?? '',
      fareEstimate: json['fareEstimate'] ?? 0,
      distanceKm: (json['distanceKm'] ?? 0).toDouble(),
      durationMin: json['durationMin'] ?? 0,
    );
  }
}
