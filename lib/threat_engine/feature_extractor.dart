// ============================================================================
// feature_extractor.dart – Base Layer: Feature Extraction
// ============================================================================
// This file extracts 16 features from a URL:
//   - Lengths (URL, domain, subdomain, path)
//   - Character counts (., -, _, /, ?, =, &, @, %)
//   - Boolean flags (has IP, has port, uses HTTPS, has query)
//   - Shannon entropy (measure of randomness)
// These features are used by the static rules, heuristics, and ML classifier.
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

  // Domain parts (using tldts for correct Public Suffix handling)
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

  // Shannon entropy (high entropy may indicate obfuscation)
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

  // Feature vector for ML (16 features in fixed order)
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