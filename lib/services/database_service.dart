import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/donation_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  // ==================== USER OPERATIONS ====================

  /// Create/Update user document in Firestore
  Future<void> createOrUpdateUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(
            user.toFirestore(),
            SetOptions(merge: true),
          );
      debugPrint('User ${user.uid} created/updated successfully');
    } catch (e) {
      debugPrint('Error creating/updating user: $e');
      rethrow;
    }
  }

  /// Get user by UID
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user: $e');
      rethrow;
    }
  }

  /// Get user stream for real-time updates
  Stream<UserModel?> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Update user profile fields
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? bio,
    String? bloodType,
    String? phoneNumber,
    String? location,
    String? photoUrl,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (bio != null) updates['bio'] = bio;
      if (bloodType != null) updates['bloodType'] = bloodType;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (location != null) updates['location'] = location;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      updates['lastLogin'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(uid).update(updates);
      debugPrint('User profile updated successfully');
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Update user role ('donor' or 'patient')
  Future<void> updateUserRole(String uid, String role) async {
    try {
      await _firestore.collection('users').doc(uid).update({'role': role});
    } catch (e) {
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }

  /// Get pending blood requests (for donors to browse)
  Stream<List<DonationModel>> getPendingBloodRequests() {
    return _firestore
        .collection('donations')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => DonationModel.fromFirestore(d)).toList());
  }

  /// Update donation availability status
  Future<void> setDonationAvailability(
    String uid,
    bool isAvailable,
  ) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isAvailableToDonate': isAvailable,
        'lastLogin': FieldValue.serverTimestamp(),
      });
      debugPrint('Donation availability updated');
    } catch (e) {
      debugPrint('Error updating donation availability: $e');
      rethrow;
    }
  }

  /// Get all available donors
  Stream<List<UserModel>> getAvailableDonors() {
    return _firestore
        .collection('users')
        .where('isAvailableToDonate', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }

  /// Search users by blood type
  Stream<List<UserModel>> getUsersByBloodType(String bloodType) {
    return _firestore
        .collection('users')
        .where('bloodType', isEqualTo: bloodType)
        .where('isAvailableToDonate', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }

  // ==================== DONATION OPERATIONS ====================

  /// Create a new donation request
  Future<String> createDonation(DonationModel donation) async {
    try {
      final docRef = _firestore.collection('donations').doc();
      final model = donation.copyWith(donationId: docRef.id);
      await docRef.set(model.toFirestore());
      debugPrint('Donation created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating donation: $e');
      rethrow;
    }
  }

  /// Get donation by ID
  Future<DonationModel?> getDonationById(String donationId) async {
    try {
      final doc =
          await _firestore.collection('donations').doc(donationId).get();
      if (doc.exists) {
        return DonationModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching donation: $e');
      rethrow;
    }
  }

  /// Get all donations for a user (as donor)
  Stream<List<DonationModel>> getUserDonations(String userId) {
    return _firestore
        .collection('donations')
        .where('donorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DonationModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get all donation requests for a user (as recipient)
  Stream<List<DonationModel>> getUserDonationRequests(String userId) {
    return _firestore
        .collection('donations')
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DonationModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Update donation status
  Future<void> updateDonationStatus(String donationId, String status) async {
    try {
      await _firestore.collection('donations').doc(donationId).update({
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      debugPrint('Donation status updated to: $status');
    } catch (e) {
      debugPrint('Error updating donation status: $e');
      rethrow;
    }
  }

  /// Get pending donations
  Stream<List<DonationModel>> getPendingDonations() {
    return _firestore
        .collection('donations')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DonationModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Accept a donation request (stores full donor info)
  Future<void> acceptDonation(
    String donationId,
    String donorUid, {
    String? donorName,
    String? donorBloodType,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': 'accepted',
        'acceptedBy': donorUid,
        'donorId': donorUid,
        'acceptedAt': FieldValue.serverTimestamp(),
      };
      if (donorName != null) updates['donorName'] = donorName;
      if (donorBloodType != null) updates['donorBloodType'] = donorBloodType;

      await _firestore.collection('donations').doc(donationId).update(updates);
      debugPrint('Donation accepted by $donorUid');
    } catch (e) {
      debugPrint('Error accepting donation: $e');
      rethrow;
    }
  }

  /// Update user's GPS location in Firestore
  Future<void> updateUserLocation(
    String uid, {
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      final updates = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'lastLogin': FieldValue.serverTimestamp(),
      };
      if (address != null) updates['location'] = address;
      await _firestore.collection('users').doc(uid).update(updates);
      debugPrint('User location updated');
    } catch (e) {
      debugPrint('Error updating user location: $e');
      rethrow;
    }
  }

  /// Get accepted donations for a donor (where they are the acceptor)
  Stream<List<DonationModel>> getAcceptedDonationsForDonor(String donorUid) {
    return _firestore
        .collection('donations')
        .where('acceptedBy', isEqualTo: donorUid)
        .orderBy('acceptedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => DonationModel.fromFirestore(d)).toList());
  }

  /// Complete a donation
  Future<void> completeDonation(String donationId) async {
    try {
      final donation = await getDonationById(donationId);
      if (donation != null) {
        // Update donation status
        await _firestore.collection('donations').doc(donationId).update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        // Increment donor's donation count
        await _firestore.collection('users').doc(donation.donorId).update({
          'totalDonations': FieldValue.increment(1),
        });

        // Increment recipient's lives saved count
        await _firestore.collection('users').doc(donation.recipientId).update({
          'livesSaved': FieldValue.increment(1),
        });

        debugPrint('Donation completed');
      }
    } catch (e) {
      debugPrint('Error completing donation: $e');
      rethrow;
    }
  }

  /// Cancel a donation
  Future<void> cancelDonation(String donationId) async {
    try {
      await _firestore.collection('donations').doc(donationId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Donation cancelled');
    } catch (e) {
      debugPrint('Error cancelling donation: $e');
      rethrow;
    }
  }

  // ==================== BATCH OPERATIONS ====================

  /// Get user statistics (donations made, lives saved)
  Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    try {
      final user = await getUserById(userId);
      if (user == null) {
        return {'totalDonations': 0, 'livesSaved': 0};
      }
      return {
        'totalDonations': user.totalDonations,
        'livesSaved': user.livesSaved,
      };
    } catch (e) {
      debugPrint('Error fetching user statistics: $e');
      rethrow;
    }
  }

  /// Get all users (for admin or discovery)
  Stream<List<UserModel>> getAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('lastLogin', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }

  /// Delete user account and related data
  Future<void> deleteUser(String userId) async {
    try {
      final batch = _firestore.batch();

      // Delete user document
      batch.delete(_firestore.collection('users').doc(userId));

      // Delete user's donations
      final userDonations = await _firestore
          .collection('donations')
          .where('donorId', isEqualTo: userId)
          .get();
      for (var doc in userDonations.docs) {
        batch.delete(doc.reference);
      }

      // Delete donation requests
      final donationRequests = await _firestore
          .collection('donations')
          .where('recipientId', isEqualTo: userId)
          .get();
      for (var doc in donationRequests.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('User account deleted');
    } catch (e) {
      debugPrint('Error deleting user account: $e');
      rethrow;
    }
  }

  /// Clear all Firestore data (use with caution!)
  Future<void> clearAllData() async {
    try {
      // Delete all users
      final users = await _firestore.collection('users').get();
      for (var doc in users.docs) {
        await doc.reference.delete();
      }

      // Delete all donations
      final donations = await _firestore.collection('donations').get();
      for (var doc in donations.docs) {
        await doc.reference.delete();
      }

      debugPrint('All data cleared successfully');
    } catch (e) {
      debugPrint('Error clearing data: $e');
      rethrow;
    }
  }
}
