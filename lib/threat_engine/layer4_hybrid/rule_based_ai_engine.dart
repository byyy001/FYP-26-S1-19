// ============================================================================
// rule_based_ai_engine.dart – Layer 3.8: AI-Inspired Risk Reasoning Engine
// ============================================================================
import '../layer1_feature_extraction/feature_extractor.dart';
import '../dynamic_config.dart';

class RuleBasedAIEngine {
  List<String>? _shorteners;
  List<String>? _suspiciousTlds;

  static const List<String> _fallbackShorteners = [
    'bit.ly',
    'tinyurl',
    't.co',
    'goo.gl',
    'is.gd',
    'buff.ly',
    'ow.ly',
  ];

  static const List<String> _fallbackSuspiciousTlds = [
    'zip',
    'xyz',
    'top',
    'club',
    'site',
    'online',
    'work',
    'click',
  ];

  RuleBasedAIEngine() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await DynamicConfig.getInstance();
    _shorteners = config.urlShorteners;
    _suspiciousTlds = config.suspiciousTlds;
  }

  /// Returns a score between 0.0 and 1.0
  double analyze(UrlFeatures features) {
    // Use dynamic config if it has finished loading.
    // Otherwise safely fall back to hardcoded defaults.
    final List<String> shorteners =
        (_shorteners != null && _shorteners!.isNotEmpty)
        ? _shorteners!
        : _fallbackShorteners;

    final List<String> suspiciousTlds =
        (_suspiciousTlds != null && _suspiciousTlds!.isNotEmpty)
        ? _suspiciousTlds!
        : _fallbackSuspiciousTlds;

    double score = 0.0;
    final url = features.url.toLowerCase();

    // ================================
    // 1. Suspicious Query Parameters
    // ================================
    final suspiciousParams = [
      'redirect=',
      'url=',
      'next=',
      'session=',
      'token=',
      'auth=',
      'utm_',
      'track=',
      'ref=',
    ];

    final int paramHits = suspiciousParams.where((p) => url.contains(p)).length;

    if (paramHits > 0) {
      score += (0.1 + paramHits * 0.05).clamp(0.1, 0.25);
    }

    // ================================
    // 2. URL Shorteners
    // ================================
    if (shorteners.any((s) => url.contains(s))) {
      score += 0.25;
    }

    // ================================
    // 3. Suspicious TLDs
    // ================================
    if (suspiciousTlds.contains(features.tldSuffix.toLowerCase())) {
      score += 0.2;
    }

    // ================================
    // 4. Domain Risk Heuristics
    // ================================
    if (features.domainLength > 18) score += 0.1;
    if (features.numHyphen > 2) score += 0.1;
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
    if (features.hasPhishingKeywords && features.hasRedirectParam) {
      score += 0.15;
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
    // 8. Soft Normalization
    // ================================
    return _normalize(score);
  }

  double _normalize(double raw) {
    return (raw / (raw + 0.5)).clamp(0.0, 1.0);
  }
}
