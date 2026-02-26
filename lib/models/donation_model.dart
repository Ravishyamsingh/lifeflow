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
  });

  // Convert DonationModel to JSON for Firestore
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
    };
  }

  // Create DonationModel from Firestore document
  factory DonationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DonationModel(
      donationId: data['donationId'] ?? '',
      donorId: data['donorId'] ?? '',
      donorName: data['donorName'] ?? 'Unknown',
      donorBloodType: data['donorBloodType'] ?? 'O+',
      recipientId: data['recipientId'] ?? '',
      recipientName: data['recipientName'] ?? 'Unknown',
      status: data['status'] ?? 'pending',
      donationDate:
          (data['donationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: data['location'],
      notes: data['notes'],
      isAnonymous: data['isAnonymous'] ?? false,
    );
  }

  // Copy with method
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
    );
  }
}
