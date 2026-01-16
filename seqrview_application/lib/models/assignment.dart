class Assignment {
  final String uid;
  final String status;
  final String assignmentType;
  final ShiftCenter shiftCenter;
  final Role role;

  Assignment({
    required this.uid,
    required this.status,
    required this.assignmentType,
    required this.shiftCenter,
    required this.role,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      uid: json['uid'],
      status: json['status'],
      assignmentType: json['assignment_type'],
      shiftCenter: ShiftCenter.fromJson(json['shift_center']),
      role: Role.fromJson(json['role']),
    );
  }
  
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isCheckedIn => status == 'CHECK_IN';
  bool get isCompleted => status == 'COMPLETED';

  // Convenience Getters
  String get examName => shiftCenter.exam.name;
  String get centerName => shiftCenter.center.clientCenterName;
}

class ShiftCenter {
  final Exam exam;
  final Shift shift;
  final ExamCenter center;

  ShiftCenter({required this.exam, required this.shift, required this.center});

  factory ShiftCenter.fromJson(Map<String, dynamic> json) {
    return ShiftCenter(
      exam: Exam.fromJson(json['exam']),
      shift: Shift.fromJson(json['shift']),
      center: ExamCenter.fromJson(json['exam_center']),
    );
  }
}

class Exam {
  final String name;
  final String code;

  Exam({required this.name, required this.code});

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      name: json['name'],
      code: json['exam_code'],
    );
  }
}

class Shift {
  final String name;
  final String startTime;
  final String endTime;

  Shift({required this.name, required this.startTime, required this.endTime});

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      name: json['name'] ?? json['shift_code'],
      startTime: json['start_time'],
      endTime: json['end_time'],
    );
  }
}

class ExamCenter {
  final String clientCenterName;
  final String clientCenterCode;
  final double? latitude;
  final double? longitude;
  final int geofenceRadiusMeters;
  final MasterCenter? masterCenter;

  ExamCenter({
    required this.clientCenterName, 
    required this.clientCenterCode,
    this.latitude,
    this.longitude,
    this.geofenceRadiusMeters = 200,
    this.masterCenter
  });

  factory ExamCenter.fromJson(Map<String, dynamic> json) {
    return ExamCenter(
      clientCenterName: json['client_center_name'],
      clientCenterCode: json['client_center_code'],
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      geofenceRadiusMeters: json['geofence_radius_meters'] ?? 200,
      masterCenter: json['master_center'] != null 
          ? MasterCenter.fromJson(json['master_center']) 
          : null,
    );
  }
}

class MasterCenter {
  final String address;
  final String city;
  final double? latitude;
  final double? longitude;
  final int geofenceRadiusMeters;

  MasterCenter({
    required this.address, 
    required this.city,
    this.latitude,
    this.longitude,
    this.geofenceRadiusMeters = 200,
  });

  factory MasterCenter.fromJson(Map<String, dynamic> json) {
    return MasterCenter(
      address: json['address'] ?? "",
      city: json['city'] ?? "",
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      geofenceRadiusMeters: json['geofence_radius_meters'] ?? 200,
    );
  }
}

class Role {
  final String name;
  final String code;

  Role({required this.name, required this.code});

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      name: json['name'],
      code: json['code'],
    );
  }
}