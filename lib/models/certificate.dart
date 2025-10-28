class Certificate {
  final String id;
  final String employeeName;
  final String employeeEmail;
  final String position;
  final DateTime? startDate;
  final DateTime? expirationDate;
  final String? type;
  final String certificateBase64;
  final String? photoBase64;

  Certificate({
    required this.id,
    required this.employeeName,
    required this.employeeEmail,
    required this.position,
    this.startDate,
    this.expirationDate,
    this.type,
    required this.certificateBase64,
    this.photoBase64,
  });

  factory Certificate.fromEmployee(Map<String, dynamic> employee) {
    return Certificate(
      id: employee['_id'] ?? '',
      employeeName: employee['name'] ?? '',
      employeeEmail: employee['email'] ?? '',
      position: employee['position'] ?? '',
      startDate: employee['startDate'] != null 
          ? DateTime.tryParse(employee['startDate']) 
          : null,
      expirationDate: employee['endDate'] != null 
          ? DateTime.tryParse(employee['endDate']) 
          : null,
      type: _getTypeFromPosition(employee['position'] ?? ''),
      certificateBase64: employee['certificate'] ?? '',
      photoBase64: employee['photo'] ?? '',
    );
  }

  static String _getTypeFromPosition(String position) {
    final pos = position.toLowerCase();
    if (pos.contains('manager') || pos.contains('chef') || pos.contains('directeur')) {
      return 'Management';
    } else if (pos.contains('développeur') || pos.contains('developer') || pos.contains('dev')) {
      return 'Développement';
    } else if (pos.contains('designer') || pos.contains('design')) {
      return 'Design';
    } else if (pos.contains('analyst') || pos.contains('analyste')) {
      return 'Analyse';
    } else if (pos.contains('commercial') || pos.contains('vente') || pos.contains('sales')) {
      return 'Commercial';
    } else if (pos.contains('rh') || pos.contains('ressources humaines') || pos.contains('hr')) {
      return 'Ressources Humaines';
    } else if (pos.contains('finance') || pos.contains('comptab')) {
      return 'Finance';
    } else {
      return 'Autres';
    }
  }

  bool get isExpired {
    if (expirationDate == null) return false;
    return expirationDate!.isBefore(DateTime.now());
  }

  bool get isExpiringSoon {
    if (expirationDate == null) return false;
    final daysUntilExpiry = expirationDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry > 0 && daysUntilExpiry <= 30;
  }

  bool get isActive {
    if (expirationDate == null) return true;
    return expirationDate!.isAfter(DateTime.now());
  }

  int get daysUntilExpiry {
    if (expirationDate == null) return -1;
    return expirationDate!.difference(DateTime.now()).inDays;
  }
}