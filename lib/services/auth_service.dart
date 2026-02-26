import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'database_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final DatabaseService _databaseService = DatabaseService();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      // Create user document in Firestore using DatabaseService
      await _createUserDocument(userCredential.user!, name);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last login timestamp
      if (userCredential.user != null) {
        await _databaseService.updateUserProfile(
          uid: userCredential.user!.uid,
        );
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null; // User cancelled the sign-in
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // Create user document if new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(
          userCredential.user!,
          googleUser.displayName ?? 'User',
        );
      } else {
        // Update last login for existing user
        await _databaseService.updateUserProfile(
          uid: userCredential.user!.uid,
        );
      }

      return userCredential;
    } catch (e) {
      throw 'Failed to sign in with Google: ${e.toString()}';
    }
  }

  // ==================== PHONE AUTH ====================

  // Store verificationId and resendToken for OTP flow
  String? _verificationId;
  int? _resendToken;

  String? get verificationId => _verificationId;

  /// Step 1: Send OTP to phone number
  /// Returns a Future that completes when codeSent callback fires.
  /// Throws on failure. On success, verificationId is stored internally.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String errorMessage) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
    int? forceResendingToken,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken ?? _resendToken,

        // Android auto-verification: SMS is detected automatically
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-sign in (Android only) - happens when Google Play Services
          // detects the SMS automatically
          onAutoVerified(credential);
        },

        // Called when verification fails
        verificationFailed: (FirebaseAuthException e) {
          String message;
          switch (e.code) {
            case 'invalid-phone-number':
              message = 'The phone number is not valid.';
              break;
            case 'too-many-requests':
              message = 'Too many requests. Please try again later.';
              break;
            case 'quota-exceeded':
              message = 'SMS quota exceeded. Please try again later.';
              break;
            case 'app-not-authorized':
              message = 'This app is not authorized to use Firebase Authentication.';
              break;
            case 'captcha-check-failed':
              message = 'reCAPTCHA verification failed. Please try again.';
              break;
            default:
              message = e.message ?? 'Phone verification failed. Please try again.';
          }
          onError(message);
        },

        // Called when OTP is sent successfully
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },

        // Called when auto-retrieval timeout expires
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      throw 'Failed to verify phone number: ${e.toString()}';
    }
  }

  /// Step 2: Verify the OTP code entered by user
  Future<UserCredential?> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      // Create credential from the verification ID and OTP
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      return await signInWithPhoneCredential(credential);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-verification-code':
          throw 'Invalid OTP code. Please check and try again.';
        case 'invalid-verification-id':
          throw 'Verification session expired. Please request a new code.';
        case 'session-expired':
          throw 'The SMS code has expired. Please request a new code.';
        case 'credential-already-in-use':
          throw 'This phone number is already linked to another account.';
        default:
          throw _handleAuthException(e);
      }
    }
  }

  /// Sign in with phone credential (used by both auto-verify and manual OTP)
  Future<UserCredential?> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // Create user document in Firestore if new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(
          userCredential.user!,
          userCredential.user!.phoneNumber ?? 'Phone User',
        );
      } else {
        // Update last login for existing user
        await _databaseService.updateUserProfile(
          uid: userCredential.user!.uid,
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Resend OTP code
  Future<void> resendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String errorMessage) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    await verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
      onAutoVerified: onAutoVerified,
      forceResendingToken: _resendToken,
    );
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out: ${e.toString()}';
    }
  }

  // Create user document in Firestore using DatabaseService
  Future<void> _createUserDocument(User user, String name) async {
    try {
      final userModel = UserModel(
        uid: user.uid,
        name: name,
        email: user.email ?? '',
        photoUrl: user.photoURL,
        phoneNumber: user.phoneNumber,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        bloodType: null,
        isAvailableToDonate: false,
      );

      await _databaseService.createOrUpdateUser(userModel);
    } catch (e) {
      print('Error creating user document: $e');
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }
}
