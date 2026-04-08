// lib/threat_engine/layer5_facade/threat_engine.dart
import 'dart:io';
import 'package:path/path.dart' as p;

import '../layer2_static_heuristics/static_rules.dart';
import '../layer4_hybrid/hybrid_engine.dart';
import '../layer3_ml/logistic_regression.dart';
import '../layer3_ml/decision_tree.dart';
import '../layer3_ml/xgboost.dart';
import '../layer3_ml/lightgbm.dart';           // NEW
import '../layer4_hybrid/behavior_engine.dart';
import '../layer4_hybrid/rule_based_ai_engine.dart';
import '../utils/scaler.dart';
import '../scan_settings.dart';
import '../layer1_feature_extraction/feature_extractor.dart';

class ThreatEngine {
  static ThreatEngine? _instance;
  late HybridEngine _engine;

  ThreatEngine._();

  static Future<ThreatEngine> getInstance() async {
    if (_instance != null) return _instance!;

    final assetsDir = p.join(Directory.current.path, 'assets', 'models');
    final lrWeightsPath = p.join(assetsDir, 'logistic_regression_weights.json');
    final lrScalerPath = p.join(assetsDir, 'scaler_params.json');
    final dtPath = p.join(assetsDir, 'decision_tree.json');
    final xgbPath = p.join(assetsDir, 'xgboost_model.json');
    final lgbPath = p.join(assetsDir, 'lightgbm_model.json');   // NEW

    // Load Logistic Regression
    late LogisticRegression lr;
    try {
      final lrWeightsJson = await File(lrWeightsPath).readAsString();
      final lrScalerJson = await File(lrScalerPath).readAsString();
      lr = await LogisticRegression.fromJson(lrWeightsJson, lrScalerJson);
    } catch (e) {
      print('Error loading Logistic Regression: $e');
      rethrow;
    }

    // Load scaler
    final scaler = await StandardScaler.load(lrScalerPath);

    // Load Decision Tree
    late DecisionTree dt;
    try {
      final dtJson = await File(dtPath).readAsString();
      dt = DecisionTree.fromJson(dtJson);
    } catch (e) {
      print('Error loading Decision Tree: $e');
      rethrow;
    }

    // Load XGBoost
    late XGBoostModel xgb;
    try {
      final xgbJson = await File(xgbPath).readAsString();
      xgb = XGBoostModel.fromJson(xgbJson);
    } catch (e) {
      print('Error loading XGBoost: $e');
      rethrow;
    }

    // Load LightGBM (optional – continue if not found)
    LightGBMModel? lgb;
    try {
      final lgbJson = await File(lgbPath).readAsString();
      lgb = await LightGBMModel.fromJson(lgbJson);
      print('LightGBM model loaded successfully.');
    } catch (e) {
      print('Warning: LightGBM model not found or invalid. Continuing without it: $e');
      lgb = null;
    }

    final behavior = BehaviorEngine();
    final aiEngine = RuleBasedAIEngine();

    final engine = ThreatEngine._();
    engine._engine = HybridEngine(
      logisticModel: lr,
      decisionTree: dt,
      xgboost: xgb,
      scaler: scaler,
      lightGBM: lgb,                // NEW
      behaviorEngine: behavior,
      aiEngine: aiEngine,
    );

    _instance = engine;
    return engine;
  }

  Future<Map<String, dynamic>> analyze(String url, {ScanSettings? settings}) async {
    final config = settings ?? ScanSettings.defaultSettings();

    final features = UrlFeatures(url);
    final staticEngine = StaticRuleEngine(features, config);
    final externalResult = await staticEngine.checkExternalBlacklists();

    if (!config.isPremium && externalResult['is_malicious'] == true) {
      final score = (externalResult['score'] as double) * 100;
      final severity = _getSeverity(score);
      return {
        "url": url,
        "timestamp": DateTime.now().toIso8601String(),
        "scan_result": {
          'url': url,
          'scan_date': DateTime.now().toString(),
          'risk_score': score.toStringAsFixed(1),
          'severity': severity,
          'threat_type': 'malicious',
          'explanation': 'Flagged by external security sources: ${(externalResult['sources'] as List).join(', ')}. No further analysis performed.',
          'detected_threats': [],
          'ml_confidence': 'none',
          'ml_score': '0.0000',
          'ensemble_probs': [],
          'behavior_score': '0.00',
          'ai_score': '0.00',
          'external_score': externalResult['score'].toStringAsFixed(2),
          'external_sources': externalResult['sources'],
          'actions': _actions(score),
          'early_exit': true,
        },
      };
    }

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
    if (score >= 75) return ['Do not proceed', 'Close immediately', 'Report URL'];
    if (score >= 50) return ['Avoid sensitive actions', 'Verify manually'];
    if (score >= 25) return ['Proceed with caution'];
    return ['Safe to use'];
  }
}