import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveScan({
    required String url,
    required String result,
    required String source,
    String threatType = '',
  }) async{
    final user = _auth.currentUser;

    if (user == null){
      return;
    }

    await _firestore
      .collection('users')
      .doc(user.uid)
      .collection('scans')
      .add({
    'url':url,
    'result':result,
    'source':source,
    'threatType': threatType,
    'scannedAt': FieldValue.serverTimestamp(),
      });
  }
}
