// ============================================================================
// behavior_engine.dart – Layer 3.5: Behavioral Analysis
// ============================================================================
// This file simulates URL behavior to detect suspicious patterns.
// Responsibilities:
// 1. Analyze URL structure, encoding, and redirection patterns.
// 2. Detect typosquatting and look-alike domains.
// 3. Identify abnormal path depth or query chains.
// 4. Assign a normalized behavior score (0.0 to 1.0).
// 5. Provide modular integration into the HybridEngine fusion scoring.
// ============================================================================

import 'feature_extractor.dart';

class BehaviorEngine {
  BehaviorEngine();

  /// Analyzes URL features and returns a behavior score [0.0 – 1.0].
  double analyze(UrlFeatures features) {
    double score = 0.0;

    // 1. Suspicious redirect parameter (e.g., ?redirect=, ?url=)
    if (features.hasRedirectParam) score += 0.25;

    // 2. Long URL path (obfuscation / multi-layer paths)
    if (features.pathDepth > 5) score += 0.15;

    // 3. High entropy (random-looking URL, common in phishing)
    if (features.highEntropy) score += 0.20;

    // 4. Suspicious characters (hex, %, @, encoded slashes)
    if (features.hasSuspiciousEncoding) score += 0.15;

    // 5. Typosquatting detection (look-alike domains)
    if (features.isTyposquatting) score += 0.25;

    // Clamp to 0.0 – 1.0
    return score.clamp(0.0, 1.0).toDouble();
  }
}