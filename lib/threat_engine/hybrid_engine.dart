// ============================================================================
// hybrid_engine.dart – Layer 4: Threat Scoring & Reporting
// ============================================================================
// This file orchestrates the full analysis pipeline for threat detection.
// Responsibilities:
// 1. Extract features from the URL.
// 2. Run static rules & heuristics to detect threats.
// 3. Run ML classifiers (Logistic Regression + optional Decision Tree).
// 4. Run optional Behavior Engine for simulated behavioral analysis.
// 5. Run optional AI/Rule-based model for extra detection layers.
// 6. Fuse all scores using weighted ensemble, influenced by user settings.
// 7. Classify severity (HIGH/MEDIUM/LOW/SAFE) and threat type.
// 8. Generate explanations and recommended actions for the UI.
// 9. Return structured output ready for reporting or UI.
// ============================================================================

import 'feature_extractor.dart';
import 'static_rules.dart';
import 'logistic_regression.dart';
import 'decision_tree.dart';           // new import
import 'threat_engine.dart';
import 'behavior_engine.dart';
import 'rule_based_ai_engine.dart';

class HybridEngine {
  final LogisticRegression logisticModel;
  final DecisionTree? decisionTree;     // optional second model
  final BehaviorEngine? behaviorEngine;
  final RuleBasedAIEngine? aiEngine;

  // Map class index to threat type string (from dataset)
  static const List<String> _classNames = ['benign', 'defacement', 'phishing', 'malware'];

  HybridEngine({
    required this.logisticModel,
    this.decisionTree,
    this.behaviorEngine,
    this.aiEngine,
  });

  /// Performs full threat analysis for a given URL.
  /// Requires ScanSettings from the UI to adjust scoring dynamically.
  Map<String, dynamic> analyze(String url, {required ScanSettings settings}) {
    // 1. Extract URL features
    final features = UrlFeatures(url);
    final featureVector = features.toFeatureVector();

    // 2. Static rules and heuristics
    final ruleEngine = StaticRuleEngine(features);
    final staticThreats = ruleEngine.analyze();
    final staticScore = _computeStaticScore(staticThreats);

    // 3. Logistic Regression
    final lrResult = logisticModel.classify(features);
    final lrProb = lrResult['threat_probability'] as double;
    final mlConfidence = lrResult['confidence'] ?? 'medium';

    // 4. Decision Tree (if available)
    int dtClass = 0; // default benign
    double dtProb = lrProb; // fallback
    if (decisionTree != null) {
      final dtMulti = decisionTree!.predictMultiClass(featureVector);
      dtClass = dtMulti['class'] as int;
      // For binary probability, consider any non‑benign as malicious
      dtProb = dtClass == 0 ? 0.0 : 1.0;
    }

    // Combined binary probability (average of both models)
    final mlProb = (lrProb + dtProb) / 2.0;

    // Determine final threat type from decision tree if available, else fallback
    String threatType;
    if (decisionTree != null) {
      threatType = _classNames[dtClass];
    } else {
      // Fallback based on static rules + logistic
      threatType = lrProb > 0.7 ? 'phishing' : (lrProb > 0.4 ? 'suspicious' : 'benign');
    }

    // 5. Behavior Engine scoring
    double behaviorScore = behaviorEngine?.analyze(features) ?? 0.0;

    // 6. AI/Additional model scoring
    double aiScore = aiEngine?.analyze(features) ?? 0.0;

    // 7. Weighted fusion of all scores
    final combinedScore = _fuseScores(
      staticScore: staticScore,
      mlScore: mlProb, // mlProb is 0-1, _fuseScores multiplies by 100 internally
      behaviorScore: behaviorScore,
      aiScore: aiScore,
      settings: settings,
    );

    // 8. Classify severity (based on combined score)
    final severity = _getSeverity(combinedScore);

    // 9. Generate explanation
    final explanation = _explain(
      severity,
      threatType,
      staticThreats,
      mlConfidence,
      behaviorScore,
      aiScore,
    );

    // 10. Recommended actions
    final actions = _actions(combinedScore);

    // Return structured result
    return {
      'url': url,
      'scan_date': _timestamp(),
      'risk_score': combinedScore.toStringAsFixed(1),
      'severity': severity,
      'threat_type': threatType,
      'explanation': explanation,
      'detected_threats': staticThreats,
      'actions': actions,
      'ml_confidence': mlConfidence,
      'behavior_score': behaviorScore.toStringAsFixed(2),
      'ai_score': aiScore.toStringAsFixed(2),
      // optionally include decision tree class for debugging
      if (decisionTree != null) 'dt_class': dtClass,
    };
  }

  /// Converts static threat results to a numeric score (0-100)
  double _computeStaticScore(List<Map<String, dynamic>> threats) {
    double score = 0;
    for (final t in threats) {
      switch (t['severity']) {
        case 'high':
          score += 35;
          break;
        case 'medium':
          score += 20;
          break;
        case 'low':
          score += 10;
          break;
      }
    }
    return score.clamp(0, 100).toDouble();
  }

  /// Weighted fusion of all layer scores, adjusting with settings
  double _fuseScores({
    required double staticScore,
    required double mlScore,
    required double behaviorScore,
    required double aiScore,
    required ScanSettings settings,
  }) {
    // Base weights
    double phishingWeight = settings.phishingSensitivity ? 0.4 : 0.3;
    double mlWeight = 0.4;
    double behaviorWeight = 0.15;
    double aiWeight = 0.05;

    // Normalize total weight
    final total = phishingWeight + mlWeight + behaviorWeight + aiWeight;
    phishingWeight /= total;
    mlWeight /= total;
    behaviorWeight /= total;
    aiWeight /= total;

    return (staticScore * phishingWeight +
            mlScore * 100 * mlWeight +
            behaviorScore * 100 * behaviorWeight +
            aiScore * 100 * aiWeight)
        .clamp(0, 100)
        .toDouble();
  }

  /// Maps numeric score to severity label
  String _getSeverity(double score) {
    if (score >= 70) return 'HIGH RISK';
    if (score >= 40) return 'MEDIUM RISK';
    if (score >= 20) return 'LOW RISK';
    return 'SAFE';
  }

  /// Generates human-readable explanation combining all layers
  String _explain(
    String severity,
    String threatType,
    List<Map<String, dynamic>> staticThreats,
    String mlConfidence,
    double behaviorScore,
    double aiScore,
  ) {
    final buf = StringBuffer('$severity: ');
    if (threatType != 'benign') buf.write('This URL is classified as $threatType. ');
    if (staticThreats.isNotEmpty) {
      buf.write(staticThreats.take(2).map((t) => t['description']).join(' '));
    }
    if (mlConfidence == 'high') {
      buf.write(' Machine learning confirms similarity to known threats.');
    }
    if (behaviorScore > 0.5) {
      buf.write(' Behavioral analysis indicates suspicious patterns.');
    }
    if (aiScore > 0.5) {
      buf.write(' Additional AI model flags potential risk.');
    }
    return buf.toString();
  }

  /// Recommended actions based on final risk score
  List<String> _actions(double score) {
    if (score >= 70) {
      return [
        'Do not enter any personal information',
        'Close this tab immediately',
        'Report this site',
      ];
    } else if (score >= 40) {
      return ['Avoid sharing sensitive data', 'Verify the website manually'];
    } else if (score >= 20) {
      return ['Be cautious with links'];
    } else {
      return ['No action needed – link appears safe'];
    }
  }

  /// Returns timestamp for scan results
  String _timestamp() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minutePadded = now.minute.toString().padLeft(2, '0');
    final amPm = now.hour >= 12 ? 'pm' : 'am';
    return '${months[now.month - 1]} ${now.day}, ${now.year} $hour12:$minutePadded$amPm';
  }
}