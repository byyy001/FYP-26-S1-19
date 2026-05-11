// lib/threat_engine/layer5_facade/threat_engine.dart

import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';

import '../layer2_static_heuristics/static_rules.dart';
import '../layer4_hybrid/hybrid_engine.dart';
import '../layer3_ml/logistic_regression.dart';
import '../layer3_ml/decision_tree.dart';
import '../layer3_ml/xgboost.dart';
import '../layer3_ml/lightgbm.dart';
import '../layer4_hybrid/behavior_engine.dart';
import '../layer4_hybrid/rule_based_ai_engine.dart';
import '../utils/scaler.dart';
import '../scan_settings.dart';
import '../layer1_feature_extraction/feature_extractor.dart';

class ThreatEngine {
  static ThreatEngine? _instance;
  late HybridEngine _engine;

  ThreatEngine._();

  // --------------------------------------------------------------------------
  // Load deployed active model JSON files from Firebase Storage
  // --------------------------------------------------------------------------
  static Future<String> _loadCloudModelJson(String storagePath) async {
    try {
      final ref = FirebaseStorage.instance.ref(storagePath);
      final data = await ref.getData(50 * 1024 * 1024); // 50 MB max
      if (data == null) {
        throw Exception('No data returned from Firebase Storage: $storagePath');
      }
      print('Loaded cloud model: $storagePath');
      return utf8.decode(data);
    } catch (e) {
      print('Failed to load cloud model: $storagePath');
      print('Error: $e');
      rethrow;
    }
  }

  static Future<ThreatEngine> getInstance() async {
    if (_instance != null) return _instance!;

    // Load ACTIVE deployed model files from Firebase Storage
    final lrWeightsJson = await _loadCloudModelJson(
      'model_versions/active/logistic_regression/weights.json',
    );
    final lrScalerJson = await _loadCloudModelJson(
      'model_versions/active/logistic_regression/scaler_params.json',
    );
    final dtJson = await _loadCloudModelJson(
      'model_versions/active/decision_tree/model.json',
    );
    final xgbJson = await _loadCloudModelJson(
      'model_versions/active/xgboost/model.json',
    );
    final lgbJson = await _loadCloudModelJson(
      'model_versions/active/lightgbm/model.json',
    );

    final lr = await LogisticRegression.fromJson(lrWeightsJson, lrScalerJson);
    final scaler = StandardScaler.fromJsonString(lrScalerJson);
    final dt = DecisionTree.fromJson(dtJson);
    final xgb = XGBoostModel.fromJson(xgbJson);
    final lgb = await LightGBMModel.fromJson(lgbJson);

    final behavior = BehaviorEngine();
    final aiEngine = RuleBasedAIEngine();

    final engine = ThreatEngine._();
    engine._engine = HybridEngine(
      logisticModel: lr,
      decisionTree: dt,
      xgboost: xgb,
      scaler: scaler,
      lightGBM: lgb,
      behaviorEngine: behavior,
      aiEngine: aiEngine,
    );

    _instance = engine;
    return engine;
  }

  Future<Map<String, dynamic>> analyze(
    String url, {
    ScanSettings? settings,
  }) async {
    final config = settings ?? ScanSettings.defaultSettings();
    final features = UrlFeatures(url);
    final staticEngine = StaticRuleEngine(features, config);

    // ----- PRE-CHECK: WHITELIST ONLY – SKIP FULL ANALYSIS -----
    final isTrusted = await staticEngine.isTrustedDomain;
    if (isTrusted) {
      // Trusted domain → safe result, no ML / external analysis needed
      return {
        "url": url,
        "timestamp": DateTime.now().toIso8601String(),
        "scan_result": {
          'url': url,
          'scan_date': DateTime.now().toString(),
          'risk_score': '0.0',
          'severity': 'SAFE',
          'threat_type': 'benign',
          'explanation': 'This domain is trusted and considered safe.',
          'detected_threats': [],
          'ml_confidence': 'none',
          'ml_score': '0.0000',
          'ensemble_probs': [],
          'behavior_score': '0.00',
          'ai_score': '0.00',
          'external_score': '0.00',
          'external_sources': [],
          'actions': ['Safe to use'],
          'early_exit': false,
        },
      };
    }

    // ----- FOR ALL OTHER URLS (including free users + external malicious) -----
    // Run full hybrid engine analysis (ML, behavior, external data all included)
    final externalResult = await staticEngine.checkExternalBlacklists();

    final result = await _engine.analyze(
      url,
      settings: config,
      externalResult: externalResult,
    );

    return {
      "url": url,
      "timestamp": DateTime.now().toIso8601String(),
      "scan_result": result,
    };
  }

  String _getSeverity(double score) {
    if (score >= 75) return 'HIGH RISK';
    if (score >= 50) return 'MEDIUM RISK';
    if (score >= 25) return 'LOW RISK';
    return 'SAFE';
  }

  List<String> _actions(double score) {
    if (score >= 75) {
      return ['Do not proceed', 'Close immediately', 'Report URL'];
    }
    if (score >= 50) {
      return ['Avoid sensitive actions', 'Verify manually'];
    }
    if (score >= 25) {
      return ['Proceed with caution'];
    }
    return ['Safe to use'];
  }
}