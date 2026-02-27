import 'package:cloud_firestore/cloud_firestore.dart';

class DonationModel {
  final String donationId;
  final String donorId;
  final String donorName;
  final String donorBloodType;
  final String recipientId;
  final String recipientName;
  final String status; // pending, accepted, completed, cancelled
  final DateTime donationDate;
  final DateTime createdAt;
  final String? location;
  final String? notes;
  final bool isAnonymous;

  // ── Extended patient details ──
  final String? patientPhone;
  final String? patientAddress;
  final double? patientLat;
  final double? patientLng;
  final DateTime? patientDob;
  final String? patientDisease;      // diagnosis / reason
  final String? hospitalName;
  final String? hospitalAddress;     // full hospital address with pincode
  final String? doctorName;
  final int unitsNeeded;             // number of blood units
  final String urgency;              // 'critical' | 'urgent' | 'normal'
  final String? relationToPatient;   // self / relative / friend / other
  final double? hospitalLat;
  final double? hospitalLng;

  DonationModel({
    required this.donationId,
    required this.donorId,
    required this.donorName,
    required this.donorBloodType,
    required this.recipientId,
    required this.recipientName,
    this.status = 'pending',
    required this.donationDate,
    required this.createdAt,
    this.location,
    this.notes,
    this.isAnonymous = false,
    this.patientPhone,
    this.patientAddress,
    this.patientLat,
    this.patientLng,
    this.patientDob,
    this.patientDisease,
    this.hospitalName,
    this.hospitalAddress,
    this.doctorName,
    this.unitsNeeded = 1,
    this.urgency = 'urgent',
    this.relationToPatient,
    this.hospitalLat,
    this.hospitalLng,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'donationId': donationId,
      'donorId': donorId,
      'donorName': donorName,
      'donorBloodType': donorBloodType,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'status': status,
      'donationDate': Timestamp.fromDate(donationDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'location': location,
      'notes': notes,
      'isAnonymous': isAnonymous,
      'patientPhone': patientPhone,
      'patientAddress': patientAddress,
      'patientLat': patientLat,
      'patientLng': patientLng,
      'patientDob': patientDob != null ? Timestamp.fromDate(patientDob!) : null,
      'patientDisease': patientDisease,
      'hospitalName': hospitalName,
      'hospitalAddress': hospitalAddress,
      'doctorName': doctorName,
      'unitsNeeded': unitsNeeded,
      'urgency': urgency,
      'relationToPatient': relationToPatient,
      'hospitalLat': hospitalLat,
      'hospitalLng': hospitalLng,
    };
  }

  factory DonationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DonationModel(
      donationId: doc.id,
      donorId: data['donorId'] ?? '',
      donorName: data['donorName'] ?? 'Unknown',
      donorBloodType: data['donorBloodType'] ?? 'O+',
      recipientId: data['recipientId'] ?? '',
      recipientName: data['recipientName'] ?? 'Unknown',
      status: data['status'] ?? 'pending',
      donationDate:
          (data['donationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: data['location'],
      notes: data['notes'],
      isAnonymous: data['isAnonymous'] ?? false,
      patientPhone: data['patientPhone'],
      patientAddress: data['patientAddress'],
      patientLat: (data['patientLat'] as num?)?.toDouble(),
      patientLng: (data['patientLng'] as num?)?.toDouble(),
      patientDob: (data['patientDob'] as Timestamp?)?.toDate(),
      patientDisease: data['patientDisease'],
      hospitalName: data['hospitalName'],
      hospitalAddress: data['hospitalAddress'],
      doctorName: data['doctorName'],
      unitsNeeded: data['unitsNeeded'] ?? 1,
      urgency: data['urgency'] ?? 'urgent',
      relationToPatient: data['relationToPatient'],
      hospitalLat: (data['hospitalLat'] as num?)?.toDouble(),
      hospitalLng: (data['hospitalLng'] as num?)?.toDouble(),
    );
  }

  DonationModel copyWith({
    String? donationId,
    String? donorId,
    String? donorName,
    String? donorBloodType,
    String? recipientId,
    String? recipientName,
    String? status,
    DateTime? donationDate,
    DateTime? createdAt,
    String? location,
    String? notes,
    bool? isAnonymous,
    String? patientPhone,
    String? patientAddress,
    double? patientLat,
    double? patientLng,
    DateTime? patientDob,
    String? patientDisease,
    String? hospitalName,
    String? hospitalAddress,
    String? doctorName,
    int? unitsNeeded,
    String? urgency,
    String? relationToPatient,
    double? hospitalLat,
    double? hospitalLng,
  }) {
    return DonationModel(
      donationId: donationId ?? this.donationId,
      donorId: donorId ?? this.donorId,
      donorName: donorName ?? this.donorName,
      donorBloodType: donorBloodType ?? this.donorBloodType,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      status: status ?? this.status,
      donationDate: donationDate ?? this.donationDate,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      patientPhone: patientPhone ?? this.patientPhone,
      patientAddress: patientAddress ?? this.patientAddress,
      patientLat: patientLat ?? this.patientLat,
      patientLng: patientLng ?? this.patientLng,
      patientDob: patientDob ?? this.patientDob,
      patientDisease: patientDisease ?? this.patientDisease,
      hospitalName: hospitalName ?? this.hospitalName,
      hospitalAddress: hospitalAddress ?? this.hospitalAddress,
      doctorName: doctorName ?? this.doctorName,
      unitsNeeded: unitsNeeded ?? this.unitsNeeded,
      urgency: urgency ?? this.urgency,
      relationToPatient: relationToPatient ?? this.relationToPatient,
      hospitalLat: hospitalLat ?? this.hospitalLat,
      hospitalLng: hospitalLng ?? this.hospitalLng,
    );
  }
}
