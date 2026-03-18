// ============================================================================
// feature_extractor.dart – Base Layer: Feature Extraction
// ============================================================================
// This file extracts 16 features from a URL for ML and heuristic analysis.
// Additionally, it provides extra getters for behavior simulation and AI scoring:
//   - Suspicious redirect parameters
//   - Path depth
//   - High entropy
//   - Suspicious encoding
//   - Typosquatting detection
// ============================================================================

import 'dart:math';
import 'package:tldts/tldts.dart' as tldts;

class UrlFeatures {
  final String url;
  late final Uri uri;
  late final dynamic tld;

  UrlFeatures(this.url) {
    uri = Uri.parse(url);
    tld = tldts.parse(url);
  }

  // Domain parts
  String get tldSuffix => tld.publicSuffix ?? '';
  String get domain => tld.domain ?? '';
  String get subdomain => tld.subdomain ?? '';

  // Lengths
  int get length => url.length;
  int get domainLength => domain.length;
  int get subdomainLength => subdomain.length;
  int get pathLength => uri.path.length;

  // Character counts
  int get numDots => '.'.allMatches(url).length;
  int get numHyphens => '-'.allMatches(url).length;
  int get numUnderscores => '_'.allMatches(url).length;
  int get numSlashes => '/'.allMatches(url).length;
  int get numQuestionMarks => '?'.allMatches(url).length;
  int get numEquals => '='.allMatches(url).length;
  int get numAmpersands => '&'.allMatches(url).length;
  int get numAt => '@'.allMatches(url).length;
  int get numPercent => '%'.allMatches(url).length;

  // Boolean flags
  bool get hasIp => RegExp(r'\d+\.\d+\.\d+\.\d+').hasMatch(url);
  bool get hasPort => uri.hasPort;
  bool get hasHttps => uri.scheme == 'https';
  bool get hasQuery => uri.query.isNotEmpty;

  // Shannon entropy
  double get entropy {
    final freq = <int, int>{};
    for (final c in url.codeUnits) {
      freq[c] = (freq[c] ?? 0) + 1;
    }
    double e = 0.0;
    for (final count in freq.values) {
      final p = count / url.length;
      e -= p * log(p) / ln2;
    }
    return e;
  }

  // --------------------------------------------------------------------------
  // Additional getters for BehaviorEngine and RuleBasedAIEngine
  // --------------------------------------------------------------------------

  // Checks if URL has suspicious redirect parameters
  bool get hasRedirectParam => url.contains('?redirect=') || url.contains('?url=');

  // Path depth = number of segments in the path
  int get pathDepth => uri.pathSegments.length;

  // High entropy flag (threshold 4.0)
  bool get highEntropy => entropy > 4.0;

  // Suspicious encoding characters
  bool get hasSuspiciousEncoding => url.contains('%') || url.contains('@');

  // Basic typosquatting detection (common substitutions)
  bool get isTyposquatting {
    final domainLower = domain.toLowerCase();
    final patterns = ['goog1e', 'faceb00k', 'paypa1', 'amzon', 'micr0soft'];
    return patterns.any((p) => domainLower.contains(p));
  }

  // Feature vector for ML (16 features)
  List<double> toFeatureVector() => [
        length.toDouble(),
        domainLength.toDouble(),
        subdomainLength.toDouble(),
        numDots.toDouble(),
        numHyphens.toDouble(),
        numUnderscores.toDouble(),
        numSlashes.toDouble(),
        numQuestionMarks.toDouble(),
        numEquals.toDouble(),
        numAmpersands.toDouble(),
        numAt.toDouble(),
        numPercent.toDouble(),
        hasIp ? 1.0 : 0.0,
        hasPort ? 1.0 : 0.0,
        hasHttps ? 1.0 : 0.0,
        entropy,
      ];
}