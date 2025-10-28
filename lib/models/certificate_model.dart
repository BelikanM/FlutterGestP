class CertificateModel {
  final String id;
  final String name;
  final String position;
  final String email;
  final String photo;
  final String certificate;
  final DateTime startDate;
  final DateTime endDate;
  final String userId;
  final DateTime createdAt;

  CertificateModel({
    required this.id,
    required this.name,
    required this.position,
    required this.email,
    required this.photo,
    required this.certificate,
    required this.startDate,
    required this.endDate,
    required this.userId,
    required this.createdAt,
  });

  factory CertificateModel.fromJson(Map<String, dynamic> json) {
    return CertificateModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      position: json['position'] ?? '',
      email: json['email'] ?? '',
      photo: json['photo'] ?? '',
      certificate: json['certificate'] ?? '',
      startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['endDate'] ?? DateTime.now().toIso8601String()),
      userId: json['userId'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'position': position,
      'email': email,
      'photo': photo,
      'certificate': certificate,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  bool get isValid {
    final now = DateTime.now();
    return endDate.isAfter(now);
  }

  bool get isExpiringSoon {
    final now = DateTime.now();
    final threeMonthsFromNow = now.add(const Duration(days: 90));
    return endDate.isAfter(now) && endDate.isBefore(threeMonthsFromNow);
  }

  int get daysUntilExpiry {
    return endDate.difference(DateTime.now()).inDays;
  }
}
