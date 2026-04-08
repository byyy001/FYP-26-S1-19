// ============================================================================
// static_rules.dart – Layer 2: Static Rule Engine + Heuristic Scoring + External Blacklists
// ============================================================================
import 'dart:math';
import 'dart:io'; // For file reading (CSA/SPF) and HttpClient
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../layer1_feature_extraction/feature_extractor.dart';
import '../scan_settings.dart';
import '../services/google_safe_browsing.dart';
import '../services/virustotal.dart';

// --------------------------------------------------------------------------
// Helper class to hold API keys (you should move these to a secure config)
// --------------------------------------------------------------------------
class ApiKeys {
  // ⚠️ SECURITY WARNING: These keys are exposed in source code.
  // Revoke them immediately and replace with environment variables.
  // Example: static const String ipQualityScoreApiKey = String.fromEnvironment('IPQS_KEY');
  static const String openPhishApiKey = '';           // OpenPhish public feed needs no key
  static const String urlhausApiKey = '';             // URLhaus is public, no key needed
  static const String ipQualityScoreApiKey = '41x7jw1Zwbqgd4UAbeuwpJaHyC4JOyy3'; // REPLACE THIS (revoked)
  static const String whoisApiKey = 'at_RL2ksZSnT1Lk6EdCG7tEZldd84gJi';           // REPLACE THIS
}

class StaticRuleEngine {
  // --------------------------------------------------------------------------
  // Blacklists / Whitelists (static data)
  // --------------------------------------------------------------------------

  static const Set<String> suspiciousTlds = {
    'tk', 'xyz', 'top', 'club', 'work', 'date', 'stream', 'gq', 'ml', 'cf',
    'ga', 'ru', 'cn', 'pw', 'cc', 'bid', 'trade', 'webcam', 'science'
  };

  static const List<String> phishingKeywords = [
    r'verify', r'account', r'banking', r'secure', r'login', r'signin',
    r'update', r'confirm', r'password', r'credential', r'paypal', r'apple',
    r'microsoft', r'amazon', r'netflix', r'wallet', r'crypto', r'bitcoin',
    r'seed.?phrase', r'private.?key', r'mnemonic', r'airdrop', r'free.?crypto',
    r'double.?your.?money', r'urgent.?action', r'verify.?wallet',
    r'connect.?wallet', r'claim.?reward', r'prize.?winner'
  ];

  static const List<String> shorteners = [
    'bit.ly', 'tinyurl', 'goo.gl', 'ow.ly', 'is.gd', 'buff.ly', 'short.link'
  ];

  static const Set<String> trustedDomains = {
    'google.com', 'microsoft.com', 'apple.com', 'amazon.com', 'paypal.com',
    'facebook.com', 'twitter.com', 'linkedin.com', 'github.com', 'zoom.us',
    'dropbox.com', 'drive.google.com', 'yahoo.com', 'bing.com', 'duckduckgo.com',
    'reddit.com', 'stackoverflow.com', 'wikipedia.org', 'cloudflare.com',
    'adobe.com', 'salesforce.com', 'slack.com', 'spotify.com', 'netflix.com',
    'twitch.tv', 'whatsapp.com', 'instagram.com', 'tiktok.com', 'snapchat.com',
    'chase.com', 'bankofamerica.com', 'wellsfargo.com', 'capitalone.com',
    'citi.com', 'usbank.com', 'stripe.com', 'square.com',
    'gov', 'edu', 'mil', 'usps.com', 'irs.gov', 'whitehouse.gov',
    'harvard.edu', 'stanford.edu', 'mit.edu', 'ox.ac.uk', 'cam.ac.uk',
    'bbc.com', 'cnn.com', 'nytimes.com', 'wsj.com', 'reuters.com',
    'aljazeera.com', 'theguardian.com', 'economist.com',
  };

  // --------------------------------------------------------------------------
  // OpenPhish static cache (shared across all engine instances)
  // --------------------------------------------------------------------------
  static Set<String>? _openPhishCache;
  static DateTime? _openPhishLastUpdate;
  static const Duration _openPhishCacheDuration = Duration(minutes: 30);

  /// Fetches the OpenPhish feed (public, no API key) and caches it.
  static Future<void> _refreshOpenPhishFeed() async {
    try {
      final response = await http.get(Uri.parse('https://openphish.com/feed.txt'));
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        final urls = <String>{};
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            urls.add(trimmed);
          }
        }
        _openPhishCache = urls;
        _openPhishLastUpdate = DateTime.now();
        print('OpenPhish feed refreshed: ${urls.length} URLs loaded.');
      } else {
        print('OpenPhish feed error: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('OpenPhish feed error: $e');
    }
  }

  /// Checks if a URL is in the OpenPhish database.
  /// Uses the cached feed, refreshing it if older than 30 minutes.
  static Future<bool> _isInOpenPhish(String url) async {
    if (_openPhishCache == null ||
        _openPhishLastUpdate == null ||
        DateTime.now().difference(_openPhishLastUpdate!) > _openPhishCacheDuration) {
      await _refreshOpenPhishFeed();
    }
    if (_openPhishCache == null) return false;
    final normalized = url.toLowerCase().replaceAll(RegExp(r'/$'), '');
    return _openPhishCache!.contains(normalized);
  }

  // --------------------------------------------------------------------------
  // Instance data
  // --------------------------------------------------------------------------

  final UrlFeatures features;
  final ScanSettings? settings;

  StaticRuleEngine(this.features, [this.settings]);

  // --------------------------------------------------------------------------
  // Core rule checks (synchronous)
  // --------------------------------------------------------------------------

  bool get isSuspiciousTld => suspiciousTlds.contains(features.tldSuffix);
  bool get isShortener => shorteners.any((s) => features.url.contains(s));

  // FIXED: features.domain already includes TLD, so no need to append .tldSuffix
  bool get isTrustedDomain {
    final full = features.domain;
    if (full.isEmpty) return false;
    if (trustedDomains.contains(full)) return true;
    for (final trusted in trustedDomains) {
      if (full.endsWith('.$trusted') || full == trusted) return true;
    }
    return false;
  }

  List<String> findPhishingKeywords() {
    final matches = <String>[];
    final lower = features.url.toLowerCase();
    for (final pattern in phishingKeywords) {
      if (RegExp(pattern).hasMatch(lower)) {
        matches.add(pattern.replaceAll(RegExp(r'\\.?'), ''));
      }
    }
    return matches;
  }

  // --------------------------------------------------------------------------
  // Heuristic anomaly detection (synchronous)
  // --------------------------------------------------------------------------

  List<String> findSuspiciousPatterns() {
    final patterns = <String>[];
    if (features.hasIp) patterns.add('IP address used');
    if (features.url.contains('@')) patterns.add('Contains @ symbol');
    if (RegExp(r'//[^/]+//').hasMatch(features.url)) patterns.add('Double slash anomaly');
    if (RegExp(r'%[0-9a-f]{2}', caseSensitive: false).hasMatch(features.url)) patterns.add('Heavy URL encoding');
    if (RegExp(r'--').hasMatch(features.domain)) patterns.add('Punycode indicator');
    if (features.highEntropy) patterns.add('High URL entropy detected');
    return patterns;
  }

  String? detectTyposquatting() {
    const brands = ['paypal', 'google', 'apple', 'microsoft', 'amazon'];
    final domain = features.domain.toLowerCase();
    for (final brand in brands) {
      if (_levenshtein(domain, brand) <= 2) return brand;
    }
    return null;
  }

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
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce(min);
      }
      for (var j = 0; j <= t.length; j++) v0[j] = v1[j];
    }
    return v1[t.length];
  }

  // --------------------------------------------------------------------------
  // External Blacklist Checks (Async)
  // --------------------------------------------------------------------------

  Future<bool> _isInCsaOrSpfList() async {
    try {
      final csaFile = File('assets/blacklists/csa_malicious.txt');
      final spfFile = File('assets/blacklists/spf_malicious.txt');
      if (!await csaFile.exists() || !await spfFile.exists()) return false;
      final csaContent = await csaFile.readAsString();
      final spfContent = await spfFile.readAsString();
      final domains = csaContent.split('\n') + spfContent.split('\n');
      final host = features.domain; // already includes TLD
      return domains.any((line) => line.trim().toLowerCase() == host.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  Future<double> _checkGoogleSafeBrowsing() async {
    if (settings != null && !settings!.useExternalApis) return 0.0;
    final score = await GoogleSafeBrowsing.checkUrl(features.url);
    return score ?? 0.0;
  }

  Future<double> _checkVirusTotal() async {
    if (settings != null && !settings!.useExternalApis) return 0.0;
    final score = await VirusTotal.checkUrl(features.url);
    return score ?? 0.0;
  }

  // ==========================================================================
  // OpenPhish – public feed (replaces dead PhishTank)
  // ==========================================================================
  Future<Map<String, dynamic>> _checkOpenPhish() async {
    if (settings != null && !settings!.useExternalApis) {
      return {'score': 0.0, 'found': false, 'details': null};
    }
    try {
      final found = await _isInOpenPhish(features.url);
      // Always print the result so the user knows OpenPhish was checked
      print('OpenPhish: ${found ? "URL found in feed" : "URL not found"}');
      if (found) {
        return {
          'score': 1.0,
          'found': true,
          'details': {
            'source': 'OpenPhish',
            'note': 'URL found in public feed (updated every 30 minutes)',
          }
        };
      }
      return {'score': 0.0, 'found': false, 'details': null};
    } catch (e) {
      print('OpenPhish error: $e');
      return {'score': 0.0, 'found': false, 'details': null};
    }
  }

  // ==========================================================================
  // URLhaus – public API, fixed SSL certificate issue with IOClient
  // ==========================================================================
  Future<Map<String, dynamic>> _checkURLhaus() async {
    if (settings != null && !settings!.useExternalApis) {
      return {'score': 0.0, 'found': false, 'details': null};
    }
    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) {
          return host == 'urlhaus-api.abuse.ch';
        };
      final client = IOClient(httpClient);
      final url = Uri.parse('https://urlhaus-api.abuse.ch/v1/url/');
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'url=${Uri.encodeComponent(features.url)}',
      ).timeout(const Duration(seconds: 5));
      client.close();
      if (response.statusCode != 200) {
        return {'score': 0.0, 'found': false, 'details': null};
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['query_status'] == 'ok') {
        final urlInfo = json['url'] as Map<String, dynamic>?;
        if (urlInfo != null && urlInfo['threat'] != null) {
          return {
            'score': 1.0,
            'found': true,
            'details': {
              'threat': urlInfo['threat'],
              'date_added': urlInfo['date_added'],
              'reporter': urlInfo['reporter'],
            }
          };
        }
      }
      return {'score': 0.0, 'found': false, 'details': null};
    } catch (e) {
      print('URLhaus error: $e');
      return {'score': 0.0, 'found': false, 'details': null};
    }
  }

  // ==========================================================================
  // IPQualityScore – requires API key
  // ==========================================================================
  Future<Map<String, dynamic>> _checkIpQualityScore() async {
    if (settings != null && !settings!.useExternalApis) {
      return {'score': 0.0, 'details': null};
    }
    if (ApiKeys.ipQualityScoreApiKey.isEmpty) {
      print('IPQualityScore API key missing. Skipping.');
      return {'score': 0.0, 'details': null};
    }
    try {
      final url = Uri.parse('https://ipqualityscore.com/api/json/url/${ApiKeys.ipQualityScoreApiKey}/${Uri.encodeComponent(features.url)}');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return {'score': 0.0, 'details': null};
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        final riskScore = (json['risk_score'] as num?)?.toDouble() ?? 0.0;
        final normalizedScore = riskScore / 100.0;
        return {
          'score': normalizedScore,
          'details': {
            'risk_score': riskScore,
            'domain_age_human': json['domain_age']?['human'] ?? 'unknown',
            'suspicious_tld': json['suspicious_tld'] ?? false,
            'redirect_risk': json['redirect_risk'] ?? false,
          }
        };
      }
      return {'score': 0.0, 'details': null};
    } catch (e) {
      print('IPQualityScore error: $e');
      return {'score': 0.0, 'details': null};
    }
  }

  // ==========================================================================
  // WhoisAPI – gets domain registration age, with full null safety
  // FIXED: Use features.domain directly (already contains TLD)
  // ==========================================================================
  Future<Map<String, dynamic>> _checkWhoisAPI() async {
    if (settings != null && !settings!.useExternalApis) {
      return {'score': 0.0, 'details': null};
    }
    if (ApiKeys.whoisApiKey.isEmpty) {
      print('WhoisAPI key missing. Skipping.');
      return {'score': 0.0, 'details': null};
    }
    final domain = features.domain;
    if (domain.isEmpty) {
      print('WhoisAPI: Empty domain – skipping.');
      return {'score': 0.0, 'details': null};
    }
    try {
      final url = Uri.parse('https://www.whoisxmlapi.com/whoisserver/WhoisService')
          .replace(queryParameters: {
            'apiKey': ApiKeys.whoisApiKey,
            'domainName': domain,
            'outputFormat': 'JSON'
          });
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        print('WhoisAPI HTTP error: ${response.statusCode}');
        return {'score': 0.0, 'details': null};
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json.containsKey('ErrorMessage')) {
        print('WhoisAPI error: ${json['ErrorMessage']}');
        return {'score': 0.0, 'details': null};
      }
      final whoisRecord = json['WhoisRecord'] as Map<String, dynamic>?;
      if (whoisRecord == null) {
        print('WhoisAPI: No WhoisRecord for domain $domain');
        return {'score': 0.0, 'details': null};
      }
      final createdDateStr = whoisRecord['createdDate'] as String?;
      if (createdDateStr == null) {
        print('WhoisAPI: No createdDate for domain $domain');
        return {'score': 0.0, 'details': null};
      }
      final created = DateTime.parse(createdDateStr);
      final ageDays = DateTime.now().difference(created).inDays;
      // Always print the age result so the user sees WhoisAPI was checked
      print('WhoisAPI: Domain age $ageDays days (${ageDays < 30 ? "new" : "established"})');
      if (ageDays < 30) {
        return {
          'score': 0.8,
          'details': {
            'age_days': ageDays,
            'warning': 'Domain registered less than 30 days ago ($ageDays days)',
          }
        };
      }
      return {
        'score': 0.0,
        'details': {'age_days': ageDays, 'warning': null}
      };
    } catch (e) {
      print('WhoisAPI error: $e');
      return {'score': 0.0, 'details': null};
    }
  }

  // --------------------------------------------------------------------------
  // Main external check – returns score and whether it's malicious
  // --------------------------------------------------------------------------
  Future<Map<String, dynamic>> checkExternalBlacklists() async {
    double maxScore = 0.0;
    final sources = <String>[];
    final details = <String, dynamic>{};

    if (await _isInCsaOrSpfList()) {
      maxScore = max(maxScore, 1.0);
      sources.add('CSA/SPF');
      details['csa_spf'] = true;
    }

    final googleScore = await _checkGoogleSafeBrowsing();
    if (googleScore > 0) {
      maxScore = max(maxScore, googleScore);
      sources.add('Google Safe Browsing');
      details['google_sb'] = googleScore;
    }

    final vtScore = await _checkVirusTotal();
    if (vtScore > 0) {
      maxScore = max(maxScore, vtScore);
      sources.add('VirusTotal');
      details['virustotal'] = vtScore;
    }

    final opResult = await _checkOpenPhish();
    if (opResult['found'] == true) {
      maxScore = max(maxScore, opResult['score'] as double);
      sources.add('OpenPhish');
      details['openphish'] = opResult['details'];
    }

    final uhResult = await _checkURLhaus();
    if (uhResult['found'] == true) {
      maxScore = max(maxScore, uhResult['score'] as double);
      sources.add('URLhaus');
      details['urlhaus'] = uhResult['details'];
    }

    final ipqsResult = await _checkIpQualityScore();
    if (ipqsResult['score'] != null && (ipqsResult['score'] as double) > 0) {
      maxScore = max(maxScore, ipqsResult['score'] as double);
      sources.add('IPQualityScore');
      details['ipqualityscore'] = ipqsResult['details'];
    }

    final whoisResult = await _checkWhoisAPI();
    if (whoisResult['score'] != null && (whoisResult['score'] as double) > 0) {
      maxScore = max(maxScore, whoisResult['score'] as double);
      sources.add('WhoisAPI');
      details['whois'] = whoisResult['details'];
    }

    return {
      'is_malicious': maxScore >= 0.8,
      'score': maxScore,
      'sources': sources,
      'details': details,
    };
  }

  // --------------------------------------------------------------------------
  // Public API: Run full static + heuristic analysis (synchronous part)
  // --------------------------------------------------------------------------
  List<Map<String, dynamic>> analyzeSync() {
    final threats = <Map<String, dynamic>>[];
    if (isTrustedDomain) return threats;

    if (features.isMalformed) {
      threats.add({
        'type': 'malformed_url',
        'severity': 'high',
        'description': 'URL could not be parsed – may be malformed or suspicious.',
        'score': 0.9,
      });
    }

    if (isSuspiciousTld) {
      threats.add({
        'type': 'suspicious_tld',
        'severity': 'medium',
        'description': "TLD '.${features.tldSuffix}' is often used in phishing.",
        'score': 0.5,
      });
    }

    final keywords = findPhishingKeywords();
    if (keywords.isNotEmpty) {
      threats.add({
        'type': 'phishing_keywords',
        'severity': 'high',
        'description': "Contains phishing terms: ${keywords.take(3).join(', ')}.",
        'score': 0.7,
      });
    }

    final patterns = findSuspiciousPatterns();
    if (patterns.isNotEmpty) {
      threats.add({
        'type': 'suspicious_pattern',
        'severity': 'medium',
        'description': patterns.join(', '),
        'score': 0.6,
      });
    }

    if (isShortener) {
      threats.add({
        'type': 'url_shortener',
        'severity': 'low',
        'description': 'Link uses a URL shortening service.',
        'score': 0.3,
      });
    }

    final brand = detectTyposquatting();
    if (brand != null) {
      threats.add({
        'type': 'typosquatting',
        'severity': 'high',
        'description': 'Domain may impersonate "$brand".',
        'score': 0.8,
      });
    }

    return threats;
  }

  /// Async full analysis including external blacklists
  Future<Map<String, dynamic>> analyzeAsync() async {
    final syncThreats = analyzeSync();
    final external = await checkExternalBlacklists();
    return {
      'threats': syncThreats,
      'external': external,
    };
  }
}