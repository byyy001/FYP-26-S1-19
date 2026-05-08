// ============================================================================
// rule_based_ai_engine.dart – Layer 3.8: AI-Inspired Risk Reasoning Engine
// ============================================================================
// This engine enhances detection by simulating intelligent reasoning:
// Improvements:
// 1. Context-aware scoring (not flat rules)
// 2. Phishing intent detection (keywords + structure)
// 3. Better shortener detection (real-world usage)
// 4. Risk amplification for combined signals
// 5. Smooth normalization (AI-like scoring)
// ============================================================================

import '../layer1_feature_extraction/feature_extractor.dart';

class RuleBasedAIEngine {
  RuleBasedAIEngine();

  /// Returns a score between 0.0 and 1.0
  double analyze(UrlFeatures features) {
    double score = 0.0;

    final url = features.url.toLowerCase();

    // ================================
    // 1. Suspicious Query Parameters
    // ================================
    final suspiciousParams = [
      'redirect=', 'url=', 'next=',
      'session=', 'token=', 'auth=',
      'utm_', 'track=', 'ref='
    ];

    int paramHits = suspiciousParams.where((p) => url.contains(p)).length;
    if (paramHits > 0) {
      score += (0.1 + paramHits * 0.05).clamp(0.1, 0.25);
    }

    // ================================
    // 2. URL Shorteners (Improved)
    // ================================
    final shorteners = [
      'bit.ly', 'tinyurl', 't.co', 'goo.gl',
      'is.gd', 'buff.ly', 'ow.ly'
    ];

    if (shorteners.any((s) => url.contains(s))) {
      score += 0.25;
    }

    // ================================
    // 3. Suspicious TLDs (weighted)
    // ================================
    final suspiciousTlds = [
      'zip', 'xyz', 'top', 'club', 'site',
      'online', 'work', 'click'
    ];

    if (suspiciousTlds.contains(features.tldSuffix.toLowerCase())) {
      score += 0.2;
    }

    // ================================
    // 4. Domain Risk Heuristics
    // ================================
    if (features.domainLength > 18) score += 0.1;
    if (features.numHyphen > 2) score += 0.1;   // FIXED: numHyphen (singular)
    if (RegExp(r'\d').hasMatch(features.domain)) score += 0.1;

    // ================================
    // 5. Phishing Intent Detection
    // ================================
    if (features.hasPhishingKeywords) {
      score += 0.25;
    }

    // ================================
    // 6. Combination Intelligence
    // ================================
    if (features.hasPhishingKeywords &&
        features.hasRedirectParam) {
      score += 0.15; // classic phishing flow
    }

    if (features.hasPhishingKeywords &&
        suspiciousTlds.contains(features.tldSuffix.toLowerCase())) {
      score += 0.15;
    }

    if (features.hasIp && features.hasPhishingKeywords) {
      score += 0.2;
    }

    // ================================
    // 7. Path Complexity
    // ================================
    if (features.pathDepth > 6) {
      score += ((features.pathDepth - 5) * 0.02).clamp(0.05, 0.15);
    }

    // ================================
    // 8. Soft Normalization (AI-like)
    // ================================
    return _normalize(score);
  }

  /// Smooth scaling instead of hard clamp
  double _normalize(double raw) {
    return (raw / (raw + 0.5)).clamp(0.0, 1.0);
  }
}