class Driver {
  final String id;
  final String name;
  final String phone;
  final String photo;
  final String carModel;
  final String carColor;
  final String plate;
  final double rating;
  final String status;
  double lat;
  double lng;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.photo,
    required this.carModel,
    required this.carColor,
    required this.plate,
    required this.rating,
    required this.status,
    required this.lat,
    required this.lng,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      photo: json['photo'] ?? '',
      carModel: json['carModel'] ?? '',
      carColor: json['carColor'] ?? '',
      plate: json['plate'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      status: json['status'] ?? 'available',
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
    );
  }
}
