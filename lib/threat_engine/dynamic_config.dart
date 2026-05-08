// lib/threat_engine/dynamic_config.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DynamicConfig {
  static DynamicConfig? _instance;
  late Map<String, dynamic> _config;
  bool _loaded = false;

  // Full hardcoded defaults (your current engine values for all 10 categories)
  static const Map<String, dynamic> _defaults = {
    // 1. Threat categories (from TC_A_3.1)
    'threat_categories': [
      {'name': 'benign', 'enabled': true, 'min_score': 0, 'max_score': 24},
      {'name': 'phishing', 'enabled': true, 'min_score': 50, 'max_score': 100},
      {'name': 'malware', 'enabled': true, 'min_score': 75, 'max_score': 100},
      {'name': 'defacement', 'enabled': true, 'min_score': 50, 'max_score': 100},
    ],
    // 2. Security rules (TC_A_3.1)
    'security_rules': {
      'enable_homograph_check': true,
      'enable_typosquatting': true,
      'enable_unshorten': true,
      'max_redirect_hops': 5,
      'new_domain_days_threshold': 30,
      'path_depth_warning': 3,
      'entropy_threshold': 4.2,
    },
    // 3. Ad-intensity threshold (TC_A_6.1)
    'ad_intensity_threshold': 0.5,
    // 4. Tracker detection keywords (TC_A_6.1)
    'tracker_detection_keywords': [
      'googleadservices', 'doubleclick', 'googlesyndication', 'adservice',
      'adserver', 'adunit', 'advertisement', 'sponsored', 'popunder', 'popup', 'adsbygoogle'
    ],
    // 5. Global blacklist (TC_A_8.1)
    'global_blacklist': [],
    // 6. Global whitelist (TC_A_8.1)
    'global_whitelist': [
      'google.com', 'microsoft.com', 'apple.com', 'amazon.com', 'paypal.com',
      'facebook.com', 'twitter.com', 'linkedin.com', 'github.com', 'zoom.us',
    ],
    // 7. Suspicious TLDs (new)
    'suspicious_tlds': ['tk', 'xyz', 'top', 'club', 'work', 'date', 'stream', 'gq', 'ml', 'cf', 'ga', 'ru', 'cn', 'pw', 'cc', 'bid', 'trade', 'webcam', 'science'],
    // 8. Phishing keywords (new)
    'phishing_keywords': [
      r'verify', r'account', r'banking', r'secure', r'login', r'signin',
      r'update', r'confirm', r'password', r'credential', r'paypal', r'apple',
      r'microsoft', r'amazon', r'netflix', r'wallet', r'crypto', r'bitcoin',
      r'seed.?phrase', r'private.?key', r'mnemonic', r'airdrop', r'free.?crypto',
      r'double.?your.?money', r'urgent.?action', r'verify.?wallet', r'connect.?wallet'
    ],
    // 9. URL shorteners (new)
    'url_shorteners': ['bit.ly', 'tinyurl', 'goo.gl', 'ow.ly', 'is.gd', 'buff.ly', 'short.link'],
    // 10. External API toggles & fusion weights (optional extras)
    'enabled_external_sources': ['google_sb', 'virustotal', 'openphish', 'urlhaus', 'ipqs', 'whois'],
    'fusion_weights': {
      'static': 0.35,
      'ml': 0.30,
      'behavior': 0.20,
      'ai': 0.10,
      'external': 0.05,
    },
  };

  DynamicConfig._() {
    _config = Map.from(_defaults);
  }

  static Future<DynamicConfig> getInstance() async {
    if (_instance == null) {
      _instance = DynamicConfig._();
      await _instance!._load();
    }
    return _instance!;
  }

  Future<void> _load() async {
    // 1. Try Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('threat_engine')
          .get()
          .timeout(const Duration(seconds: 3));
      if (doc.exists) {
        final data = doc.data()!;
        _config = Map<String, dynamic>.from(_defaults);
        _config.addAll(data);
        await _saveToCache();
        _loaded = true;
        return;
      }
    } catch (e) {
      print('DynamicConfig: Firestore fetch failed: $e');
    }

    // 2. Try cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('threat_engine_config');
      if (cached != null) {
        final Map<String, dynamic> cachedMap = jsonDecode(cached);
        _config = Map<String, dynamic>.from(_defaults);
        _config.addAll(cachedMap);
        _loaded = true;
        return;
      }
    } catch (e) {
      print('DynamicConfig: Cache load failed: $e');
    }

    // 3. Fallback to defaults (already set)
    _loaded = true;
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('threat_engine_config', jsonEncode(_config));
    } catch (e) {
      print('DynamicConfig: Failed to save cache: $e');
    }
  }

  // Public getters for all 10 categories
  List<Map<String, dynamic>> get threatCategories =>
      List<Map<String, dynamic>>.from(_config['threat_categories'] ?? []);
  Map<String, dynamic> get securityRules =>
      Map<String, dynamic>.from(_config['security_rules'] ?? {});
  double get adIntensityThreshold =>
      (_config['ad_intensity_threshold'] ?? 0.5).toDouble();
  List<String> get trackerDetectionKeywords =>
      List<String>.from(_config['tracker_detection_keywords'] ?? []);
  List<String> get globalBlacklist =>
      List<String>.from(_config['global_blacklist'] ?? []);
  List<String> get globalWhitelist =>
      List<String>.from(_config['global_whitelist'] ?? []);
  List<String> get suspiciousTlds =>
      List<String>.from(_config['suspicious_tlds'] ?? []);
  List<String> get phishingKeywords =>
      List<String>.from(_config['phishing_keywords'] ?? []);
  List<String> get urlShorteners =>
      List<String>.from(_config['url_shorteners'] ?? []);
  List<String> get enabledExternalSources =>
      List<String>.from(_config['enabled_external_sources'] ?? []);
  Map<String, dynamic> get fusionWeights =>
      Map<String, dynamic>.from(_config['fusion_weights'] ?? {});

  // Convenience helpers
  bool get enableHomographCheck => securityRules['enable_homograph_check'] ?? true;
  bool get enableTyposquatting => securityRules['enable_typosquatting'] ?? true;
  bool get enableUnshorten => securityRules['enable_unshorten'] ?? true;
  int get maxRedirectHops => securityRules['max_redirect_hops'] ?? 5;
  int get newDomainDaysThreshold => securityRules['new_domain_days_threshold'] ?? 30;
  int get pathDepthWarning => securityRules['path_depth_warning'] ?? 3;
  double get entropyThreshold => (securityRules['entropy_threshold'] ?? 4.2).toDouble();

  Future<void> refresh() async {
    await _load();
  }
}