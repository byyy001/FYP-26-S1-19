import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../threat_engine/scan_settings.dart';

class ScanSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _settingsDoc(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('scan_preferences');
  }

  String? get _currentUserId => _auth.currentUser?.uid;

  Map<String, dynamic> _settingsToMap(ScanSettings settings) {
    return {
      'userLevel': settings.userLevel,
      'phishingSensitivity': settings.phishingSensitivity,
      'deepScan': settings.deepScan,
      'scriptAnalysis': settings.scriptAnalysis,
      'useExternalApis': settings.useExternalApis,
      'isPremium': settings.isPremium,
      'enableMachineLearning': settings.enableMachineLearning,
      'useEnsemble': settings.useEnsemble,
      'useLogisticRegression': settings.useLogisticRegression,
      'useDecisionTree': settings.useDecisionTree,
      'useXGBoost': settings.useXGBoost,
      'useLightGBM': settings.useLightGBM,
      'httpSitesWarning': settings.httpSitesWarning,
      'adReductionAnalysis': settings.adReductionAnalysis,
      'adDensityLevel': settings.adDensityLevel,
      'autoRecheckScans': settings.autoRecheckScans,
      'sharingConfiguration': settings.sharingConfiguration,
      'adFilter': settings.adFilter,
    };
  }

  Map<String, dynamic> defaultSettingsData({
    String userLevel = 'beginner',
    bool isPremium = true,
  }) {
    final ScanSettings baseSettings = switch (userLevel) {
      'advanced' => ScanSettings.forAdvanced(),
      'free' => ScanSettings.defaultSettings(),
      _ => ScanSettings.forBeginner(),
    };

    return _settingsToMap(
      baseSettings.copyWith(
        userLevel: userLevel,
        isPremium: isPremium,
      ),
    );
  }

  Future<void> createDefaultSettingsForUser({
    String? userId,
    String userLevel = 'beginner',
    bool isPremium = true,
    bool overwrite = false,
  }) async {
    final targetUserId = userId ?? _currentUserId;
    if (targetUserId == null) {
      return;
    }

    final docRef = _settingsDoc(targetUserId);
    final doc = await docRef.get();
    final existingData = doc.data();

    if (doc.exists && !overwrite) {
      return;
    }

    final now = FieldValue.serverTimestamp();
    final createdAt = doc.exists
        ? existingData == null
              ? null
              : existingData['createdAt']
        : now;

    await docRef.set({
      ...defaultSettingsData(
        userLevel: userLevel,
        isPremium: isPremium,
      ),
      'sid': docRef.id,
      'createdAt': createdAt,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getSettings({String? userId}) async {
    final targetUserId = userId ?? _currentUserId;
    if (targetUserId == null) {
      return null;
    }

    final doc = await _settingsDoc(targetUserId).get();
    return doc.data();
  }

  ScanSettings mapToScanSettings(Map<String, dynamic> data) {
    final userLevel = data['userLevel'] ?? 'beginner';

    return ScanSettings(
      phishingSensitivity: data['phishingSensitivity'] ?? true,
      httpSitesWarning: data['httpSitesWarning'] ?? false,
      scriptAnalysis: data['scriptAnalysis'] ?? true,
      adReductionAnalysis: data['adReductionAnalysis'] ?? false,
      adDensityLevel: data['adDensityLevel'] ?? 1,
      autoRecheckScans: data['autoRecheckScans'] ?? false,
      sharingConfiguration: data['sharingConfiguration'] ?? false,
      useExternalApis: data['useExternalApis'] ?? true,
      isPremium: data['isPremium'] ?? true,
      userLevel: userLevel,
      enableMachineLearning: data['enableMachineLearning'] ?? true,
      useEnsemble: data['useEnsemble'] ?? (userLevel == 'beginner'),
      useLogisticRegression: data['useLogisticRegression'] ?? true,
      useDecisionTree: data['useDecisionTree'] ?? true,
      useXGBoost: data['useXGBoost'] ?? true,
      useLightGBM: data['useLightGBM'] ?? true,
      deepScan: data['deepScan'] ?? true,
      adFilter: data['adFilter'] ?? false,
    );
  }

  Future<ScanSettings> getScanSettings({String? userId}) async {
    final data = await getSettings(userId: userId);
    if (data == null) {
      return ScanSettings.forBeginner();
    }

    return mapToScanSettings(data);
  }

  Future<void> updateSettings({
    String? userId,
    required Map<String, dynamic> settings,
  }) async {
    final targetUserId = userId ?? _currentUserId;
    if (targetUserId == null) {
      return;
    }

    final docRef = _settingsDoc(targetUserId);
    final doc = await docRef.get();
    final existingData = doc.data();
    final createdAt = doc.exists
        ? existingData == null
              ? null
              : existingData['createdAt']
        : FieldValue.serverTimestamp();

    await docRef.set({
      if (!doc.exists) ...defaultSettingsData(),
      ...settings,
      'sid': docRef.id,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveSettings({
    String? userId,
    required ScanSettings settings,
  }) async {
    await updateSettings(
      userId: userId,
      settings: _settingsToMap(settings),
    );
  }
}
