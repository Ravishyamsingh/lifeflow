import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? phoneNumber;
  final String? bloodType;
  final bool isAvailableToDonate;
  final DateTime createdAt;
  final DateTime lastLogin;
  final String? bio;
  final int totalDonations;
  final int livesSaved;
  final String? location;
  final String? role; // 'donor' or 'patient'

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.phoneNumber,
    this.bloodType,
    this.isAvailableToDonate = false,
    required this.createdAt,
    required this.lastLogin,
    this.bio,
    this.totalDonations = 0,
    this.livesSaved = 0,
    this.location,
    this.role,
  });

  // Convert UserModel to JSON for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'bloodType': bloodType,
      'isAvailableToDonate': isAvailableToDonate,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': Timestamp.fromDate(lastLogin),
      'bio': bio,
      'totalDonations': totalDonations,
      'livesSaved': livesSaved,
      'location': location,
      'role': role,
    };
  }

  // Create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? '',
      name: data['name'] ?? 'User',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      phoneNumber: data['phoneNumber'],
      bloodType: data['bloodType'],
      isAvailableToDonate: data['isAvailableToDonate'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bio: data['bio'],
      totalDonations: data['totalDonations'] ?? 0,
      livesSaved: data['livesSaved'] ?? 0,
      location: data['location'],
      role: data['role'],
    );
  }

  // Copy with method for updating properties
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? phoneNumber,
    String? bloodType,
    bool? isAvailableToDonate,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? bio,
    int? totalDonations,
    int? livesSaved,
    String? location,
    String? role,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bloodType: bloodType ?? this.bloodType,
      isAvailableToDonate: isAvailableToDonate ?? this.isAvailableToDonate,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      bio: bio ?? this.bio,
      totalDonations: totalDonations ?? this.totalDonations,
      livesSaved: livesSaved ?? this.livesSaved,
      location: location ?? this.location,
      role: role ?? this.role,
    );
  }
}
