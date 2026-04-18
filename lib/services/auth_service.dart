import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'scan_settings_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ScanSettingsService _scanSettingsService = ScanSettingsService();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUpWithEmail({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;

    if (user != null) {
      await user.updateDisplayName('$firstName $lastName');

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'authProvider': 'email',
        'role': 'User',
        'isActive': true,
        'isPremium': false, 
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _scanSettingsService.createDefaultSettingsForUser(
        userId: user.uid,
      );
    }

    return userCredential;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
  final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

  if (googleUser == null) {
    return null;
  }

  final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken, // ✅ IMPORTANT
    idToken: googleAuth.idToken,
  );

  final userCredential =
      await _auth.signInWithCredential(credential);

  final user = userCredential.user;

  if (user != null) {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      final nameParts = (user.displayName ?? '').trim().split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      await docRef.set({
        'uid': user.uid,
        'firstName': firstName,
        'lastName': lastName,
        'email': user.email ?? '',
        'authProvider': 'google',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _scanSettingsService.createDefaultSettingsForUser(
        userId: user.uid,
      );
      }
    }

    return userCredential;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
