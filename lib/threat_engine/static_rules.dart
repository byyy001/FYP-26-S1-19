// ============================================================================
// static_rules.dart – Layers 1 & 2: Static Rule Engine + Heuristic Scoring
// ============================================================================
// This file implements two core layers of the threat detection system:
//
//   Layer 1 – Static Rule Engine:
//     • Regex‑based pattern matching for phishing keywords.
//     • Blacklist checks for suspicious TLDs and URL shorteners.
//     • Whitelist checks for trusted domains (to reduce false positives).
//
//   Layer 2 – Heuristic Scoring:
//     • Typosquatting detection via Levenshtein distance.
//     • Structural anomaly detection (IP addresses, special characters, etc.).
//     • Entropy (already computed in feature_extractor) is used indirectly.
//
// The `analyze()` method returns a list of threats, each with a `type`,
// `severity` (high / medium / low), and a human‑readable `description`.
// These threats are later combined with the ML score in the hybrid engine.
// ============================================================================

import 'dart:math';
import 'feature_extractor.dart';

class StaticRuleEngine {
  // --------------------------------------------------------------------------
  // Layer 1: Blacklists / Whitelists (static data)
  // --------------------------------------------------------------------------

  /// Top‑level domains (TLDs) frequently abused in phishing campaigns.
  /// Source: industry reports and known malicious TLD lists.
  static const Set<String> suspiciousTlds = {
    'tk', 'xyz', 'top', 'club', 'work', 'date', 'stream', 'gq', 'ml', 'cf',
    'ga', 'ru', 'cn', 'pw', 'cc', 'bid', 'trade', 'webcam', 'science'
  };

  /// Regular expressions for keywords that often appear in phishing URLs.
  /// These patterns catch both whole words and obfuscated variants (e.g., "verify").
  static const List<String> phishingKeywords = [
    r'verify', r'account', r'banking', r'secure', r'login', r'signin',
    r'update', r'confirm', r'password', r'credential', r'paypal', r'apple',
    r'microsoft', r'amazon', r'netflix', r'wallet', r'crypto', r'bitcoin',
    r'seed.?phrase', r'private.?key', r'mnemonic', r'airdrop', r'free.?crypto',
    r'double.?your.?money', r'urgent.?action', r'verify.?wallet',
    r'connect.?wallet', r'claim.?reward', r'prize.?winner'
  ];

  /// Known URL shortening services – often used to hide the final destination.
  static const List<String> shorteners = [
    'bit.ly', 'tinyurl', 'goo.gl', 'ow.ly', 'is.gd', 'buff.ly', 'short.link'
  ];

  /// Domains that are considered completely safe (whitelist).
  /// Visiting these domains is extremely unlikely to be malicious.
  static const Set<String> trustedDomains = {
    'google.com', 'microsoft.com', 'apple.com', 'amazon.com', 'paypal.com',
    'facebook.com', 'twitter.com', 'linkedin.com', 'github.com', 'zoom.us',
    'dropbox.com', 'drive.google.com'
  };

  // --------------------------------------------------------------------------
  // Instance data
  // --------------------------------------------------------------------------

  final UrlFeatures features;

  StaticRuleEngine(this.features);

  // --------------------------------------------------------------------------
  // Layer 1: Core rule checks (return booleans / lists)
  // --------------------------------------------------------------------------

  /// Returns true if the URL's TLD is in the suspicious list.
  bool get isSuspiciousTld => suspiciousTlds.contains(features.tldSuffix);

  /// Returns true if the URL uses a known link shortener.
  bool get isShortener => shorteners.any((s) => features.url.contains(s));

  /// Returns true if the domain (including TLD) is in the trusted whitelist.
  bool get isTrustedDomain {
    final full = '${features.domain}.${features.tldSuffix}';
    return trustedDomains.contains(full) ||
        trustedDomains.any((d) => d.startsWith(features.domain));
  }

  /// Finds all phishing‑related keywords present in the URL (case‑insensitive).
  /// Returns a list of matched patterns (cleaned for readability).
  List<String> findPhishingKeywords() {
    final matches = <String>[];
    final lower = features.url.toLowerCase();
    for (final pattern in phishingKeywords) {
      if (RegExp(pattern).hasMatch(lower)) {
        // Remove regex control characters for cleaner output
        matches.add(pattern.replaceAll(RegExp(r'\\.?'), ''));
      }
    }
    return matches;
  }

  // --------------------------------------------------------------------------
  // Layer 2: Heuristic anomaly detection
  // --------------------------------------------------------------------------

  /// Detects structural anomalies in the URL (e.g., IP address, '@' symbol,
  /// double slashes, heavy percent‑encoding, punycode indicator).
  List<String> findSuspiciousPatterns() {
    final patterns = <String>[];
    if (features.hasIp) patterns.add('IP address used');
    if (features.url.contains('@')) patterns.add('Contains @ symbol');
    if (RegExp(r'//[^/]+//').hasMatch(features.url)) {
      patterns.add('Double slash anomaly');
    }
    if (RegExp(r'%[0-9a-f]{2}', caseSensitive: false).hasMatch(features.url)) {
      patterns.add('Heavy URL encoding');
    }
    if (RegExp(r'--').hasMatch(features.domain)) {
      patterns.add('Punycode indicator');
    }
    return patterns;
  }

  /// Typosquatting detection: checks if the domain name is a close misspelling
  /// of a well‑known brand using Levenshtein distance (distance ≤ 2).
  /// Returns the name of the impersonated brand, or null if none.
  String? detectTyposquatting() {
    const brands = ['paypal', 'google', 'apple', 'microsoft', 'amazon'];
    final domain = features.domain.toLowerCase();
    for (final brand in brands) {
      if (_levenshtein(domain, brand) <= 2) return brand;
    }
    return null;
  }

  /// Levenshtein distance algorithm (standard implementation).
  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final v0 = List<int>.generate(t.length + 1, (i) => i);
    var v1 = List<int>.filled(t.length + 1, 0);

    for (var i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,          // deletion
          v0[j + 1] + 1,      // insertion
          v0[j] + cost        // substitution
        ].reduce(min);
      }
      for (var j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  // --------------------------------------------------------------------------
  // Public API: Run all checks and return a list of detected threats
  // --------------------------------------------------------------------------

  /// Performs a complete analysis using all static rules and heuristics.
  /// Returns a list of maps, each containing:
  ///   - `type`: a unique identifier for the threat (e.g., 'suspicious_tld')
  ///   - `severity`: 'high', 'medium', or 'low'
  ///   - `description`: a user‑friendly explanation
  List<Map<String, dynamic>> analyze() {
    final threats = <Map<String, dynamic>>[];

    // Layer 1: Suspicious TLD
    if (isSuspiciousTld) {
      threats.add({
        'type': 'suspicious_tld',
        'severity': 'medium',
        'description': "TLD '.${features.tldSuffix}' is often used in phishing.",
      });
    }

    // Layer 1: Phishing keywords
    final keywords = findPhishingKeywords();
    if (keywords.isNotEmpty) {
      threats.add({
        'type': 'phishing_keywords',
        'severity': 'high',
        'description': "Contains phishing terms: ${keywords.take(3).join(', ')}.",
      });
    }

    // Layer 2: Suspicious patterns (IP, @, etc.)
    final patterns = findSuspiciousPatterns();
    if (patterns.isNotEmpty) {
      threats.add({
        'type': 'suspicious_pattern',
        'severity': 'medium',
        'description': patterns.join(', '),
      });
    }

    // Layer 2: IP address (already caught by patterns, but we keep separate for clarity)
    if (features.hasIp) {
      threats.add({
        'type': 'ip_address_url',
        'severity': 'high',
        'description': 'URL uses an IP address instead of a domain name.',
      });
    }

    // Layer 1: URL shortener
    if (isShortener) {
      threats.add({
        'type': 'url_shortener',
        'severity': 'low',
        'description': 'Link uses a URL shortening service.',
      });
    }

    // Layer 2: Typosquatting
    final brand = detectTyposquatting();
    if (brand != null) {
      threats.add({
        'type': 'typosquatting',
        'severity': 'high',
        'description': 'Domain may impersonate "$brand".',
      });
    }

    // Layer 1: Trusted domain (does not add a threat; it's a positive signal)
    // (We don't add a threat for trusted domains – they are used later to reduce score.)

    return threats;
  }
}