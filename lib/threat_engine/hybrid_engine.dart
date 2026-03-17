// ============================================================================
// hybrid_engine.dart – Layer 4: Threat Scoring & Reporting
// ============================================================================
// This file orchestrates the full analysis:
//   1. Extract features from the URL.
//   2. Run static rules & heuristics to obtain a list of threats.
//   3. Run the ML classifier to get a probability and confidence.
//   4. Combine static and ML scores with dynamic weighting (higher ML weight
//      when confidence is high).
//   5. Classify severity (HIGH/MEDIUM/LOW/SAFE) and threat type.
//   6. Generate a human‑readable explanation and recommended actions.
//   7. Format output for the UI.
// ============================================================================

import 'feature_extractor.dart';
import 'static_rules.dart';
import 'logistic_regression.dart';

class HybridEngine {
  final LogisticRegression mlModel;

  HybridEngine(this.mlModel);

  /// Performs complete threat analysis for a given URL.
  /// Returns a map ready for UI display.
  Map<String, dynamic> analyze(String url) {
    // 1. Extract features
    final features = UrlFeatures(url);

    // 2. Run static rules & heuristics
    final ruleEngine = StaticRuleEngine(features);
    final threats = ruleEngine.analyze();

    // 3. ML classification
    final mlResult = mlModel.classify(features);
    final mlProb = mlResult['threat_probability'] as double;

    // 4. Compute static risk score from threats (simple severity weighting)
    double staticScore = 0;
    for (final t in threats) {
      if (t['severity'] == 'high') staticScore += 35;
      else if (t['severity'] == 'medium') staticScore += 20;
      else if (t['severity'] == 'low') staticScore += 10;
    }
    staticScore = staticScore.clamp(0, 100) as double;

    // Adaptive weighting: trust ML more when its confidence is high
    final mlWeight = mlResult['confidence'] == 'high' ? 0.7 : 0.5;
    final staticWeight = 1 - mlWeight;

    // Combine static + ML scores and cast to double to avoid 'num' type issues
    final combinedScore =
        (staticScore * staticWeight + mlProb * 100 * mlWeight).clamp(0, 100) as double;

    // 5. Determine severity and threat type
    final classification = _classify(combinedScore);
    final severity = classification['severity']!;
    final threatType = classification['type']!;

    // 6. Build explanation and actions
    final explanation = _explain(severity, threatType, threats, mlProb);
    final actions = _actions(combinedScore);

    // 7. Return formatted result
    return {
      'url': url,
      'scan_date': _timestamp(),
      'risk_score': combinedScore.toStringAsFixed(1),
      'severity': severity,
      'threat_type': threatType,
      'explanation': explanation,
      'detected_threats': threats,
      'actions': actions,
      'ml_confidence': mlResult['confidence'],
    };
  }

  /// Maps a numeric risk score (0‑100) to a severity label and threat type.
  /// Returns a Map to avoid Dart 3 record issues.
  Map<String, String> _classify(double score) {
    if (score >= 70) return {'severity': 'HIGH RISK', 'type': 'phishing'};
    if (score >= 40) return {'severity': 'MEDIUM RISK', 'type': 'suspicious'};
    if (score >= 20) return {'severity': 'LOW RISK', 'type': 'ad_tracker'};
    return {'severity': 'SAFE', 'type': 'benign'};
  }

  /// Generates a plain‑English explanation by combining severity,
  /// threat type, and the first two detected threats.
  String _explain(String severity, String type,
      List<Map<String, dynamic>> threats, double mlProb) {
    final buf = StringBuffer('$severity: ');
    if (type != 'benign') buf.write('This URL is classified as $type. ');
    if (threats.isNotEmpty) {
      buf.write(threats.take(2).map((t) => t['description']).join(' '));
    }
    if (mlProb > 0.7) {
      buf.write(' Machine learning confirms high similarity to known threats.');
    }
    return buf.toString();
  }

  /// Provides recommended actions based on the final risk score.
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

  /// Returns the current date and time formatted as e.g. "Feb 18, 2026 6:08pm".
  String _timestamp() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    // Convert 24‑hour to 12‑hour format
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minutePadded = now.minute.toString().padLeft(2, '0');
    final amPm = now.hour >= 12 ? 'pm' : 'am';

    return '${months[now.month - 1]} ${now.day}, ${now.year} '
        '$hour12:$minutePadded$amPm';
  }
}