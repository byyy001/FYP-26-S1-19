// ============================================================================
// rule_based_ai_engine.dart – Layer 3.8: Additional AI / Rule-Based Analysis
// ============================================================================
// This engine complements the ML and static layers by:
// 1. Detecting suspicious query parameters (tracking, redirect, analytics)
// 2. Flagging free URL shorteners or temporary domains
// 3. Identifying unusual TLDs or uncommon domains
// 4. Returning a normalized threat score [0.0 – 1.0] for fusion in HybridEngine
// ============================================================================

import 'feature_extractor.dart';

class RuleBasedAIEngine {
  RuleBasedAIEngine();

  /// Returns a score between 0.0 and 1.0
  double analyze(UrlFeatures features) {
    double score = 0.0;

    // 1. Suspicious query parameters
    final suspiciousParams = ['utm_', 'ref=', 'track=', 'session=', 'cid=', 'redirect='];
    for (final p in suspiciousParams) {
      if (features.url.toLowerCase().contains(p)) {
        score += 0.15;
        break; // avoid stacking multiple times
      }
    }

    // 2. Free URL shorteners / temporary domains
    final shorteners = [
      'bit.ly', 'tinyurl.com', 'goo.gl', 't.co', 'is.gd', 'buff.ly', 'ow.ly'
    ];
    if (shorteners.any((s) => features.domain.toLowerCase() == s)) {
      score += 0.2;
    }

    // 3. Unusual / suspicious TLDs
    final suspiciousTlds = ['zip', 'kim', 'top', 'work', 'xyz', 'club', 'site'];
    if (suspiciousTlds.contains(features.tldSuffix.toLowerCase())) {
      score += 0.15;
    }

    // 4. Domain name heuristics
    // e.g., long domain with hyphens, numeric domain
    if (features.domainLength > 15 || features.numHyphens > 2 || RegExp(r'\d').hasMatch(features.domain)) {
      score += 0.2;
    }

    // 5. Abnormal path depth
    if (features.pathDepth > 5) score += 0.1;

    // Clamp score to 0.0 – 1.0
    return score.clamp(0.0, 1.0).toDouble();
  }
}