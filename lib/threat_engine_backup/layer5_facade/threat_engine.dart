// lib/threat_engine/layer5_facade/threat_engine.dart
import 'package:flutter/services.dart' show rootBundle;
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

  static Future<ThreatEngine> getInstance() async {
    if (_instance != null) return _instance!;

    // Load model JSON files from assets using rootBundle
    final lrWeightsJson = await rootBundle.loadString('assets/models/logistic_regression_weights.json');
    final lrScalerJson = await rootBundle.loadString('assets/models/scaler_params.json');
    final dtJson = await rootBundle.loadString('assets/models/decision_tree.json');
    final xgbJson = await rootBundle.loadString('assets/models/xgboost_model.json');
    String? lgbJson;
    try {
      lgbJson = await rootBundle.loadString('assets/models/lightgbm_model.json');
    } catch (e) {
      print('LightGBM model not found – continuing without it');
    }

    // Load Logistic Regression
    final lr = await LogisticRegression.fromJson(lrWeightsJson, lrScalerJson);
    // Load scaler from JSON string
    final scaler = StandardScaler.fromJsonString(lrScalerJson);
    // Load Decision Tree
    final dt = DecisionTree.fromJson(dtJson);
    // Load XGBoost
    final xgb = XGBoostModel.fromJson(xgbJson);
    // Load LightGBM (optional)
    LightGBMModel? lgb;
    if (lgbJson != null) {
      lgb = await LightGBMModel.fromJson(lgbJson);
    }

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