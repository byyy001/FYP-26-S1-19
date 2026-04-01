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

  final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('scans')
        .doc();

    await docRef.set({
      'url': url,
      'result': result,
      'source': source,
      'sid': docRef.id,
      'threatType': threatType,
      'scannedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getHistoryStream() {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('scans')
        .orderBy('scannedAt', descending: true)
        .limit(3)
        .snapshots();
  }
}
