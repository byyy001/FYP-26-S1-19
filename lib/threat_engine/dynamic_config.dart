import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DynamicConfig {
  static DynamicConfig? _instance;
  late Map<String, dynamic> _config;
  bool _loaded = false;
  late Future<void> _initialization;

  static const Map<String, dynamic> _defaults = {
    'threat_categories': [
      {'name': 'benign', 'enabled': true, 'min_score': 0, 'max_score': 24},
      {'name': 'phishing', 'enabled': true, 'min_score': 50, 'max_score': 100},
      {'name': 'malware', 'enabled': true, 'min_score': 75, 'max_score': 100},
      {'name': 'defacement', 'enabled': true, 'min_score': 50, 'max_score': 100},
    ],
    'security_rules': {
      'enable_homograph_check': true,
      'enable_typosquatting': true,
      'enable_unshorten': true,
      'max_redirect_hops': 5,
      'new_domain_days_threshold': 30,
      'path_depth_warning': 3,
      'entropy_threshold': 4.2,
    },
    'ad_intensity_threshold': 0.5,
    'tracker_detection_keywords': [
      'googleadservices', 'doubleclick', 'googlesyndication', 'adservice',
      'adserver', 'adunit', 'advertisement', 'sponsored', 'popunder', 'popup', 'adsbygoogle'
    ],
    'global_blacklist': [],
    'global_whitelist': [
      'google.com', 'microsoft.com', 'apple.com', 'amazon.com', 'paypal.com',
      'facebook.com', 'twitter.com', 'linkedin.com', 'github.com', 'zoom.us',
    ],
    'suspicious_tlds': ['tk', 'xyz', 'top', 'club', 'work', 'date', 'stream', 'gq', 'ml', 'cf', 'ga', 'ru', 'cn', 'pw', 'cc', 'bid', 'trade', 'webcam', 'science'],
    'phishing_keywords': [
      r'verify', r'account', r'banking', r'secure', r'login', r'signin',
      r'update', r'confirm', r'password', r'credential', r'paypal', r'apple',
      r'microsoft', r'amazon', r'netflix', r'wallet', r'crypto', r'bitcoin',
      r'seed.?phrase', r'private.?key', r'mnemonic', r'airdrop', r'free.?crypto',
      r'double.?your.?money', r'urgent.?action', r'verify.?wallet', r'connect.?wallet'
    ],
    'url_shorteners': ['bit.ly', 'tinyurl', 'goo.gl', 'ow.ly', 'is.gd', 'buff.ly', 'short.link'],
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
    _initialization = _load();
  }

  static Future<DynamicConfig> getInstance() async {
    if (_instance == null) {
      _instance = DynamicConfig._();
      await _instance!._initialization;
    }
    return _instance!;
  }

  Future<void> _load() async {
    // Wait for auth — Firestore rules require an authenticated user
    final user = await FirebaseAuth.instance.authStateChanges().first;

    // 1. Try Firestore (direct, always fresh)
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('app_config')
            .doc('threat_engine')
            .get()
            .timeout(const Duration(seconds: 3));
        if (doc.exists) {
          final data = doc.data()!;
          print("✅ DynamicConfig: Loaded from Firestore");
          print("   global_blacklist: ${data['global_blacklist']}");
          _config = Map<String, dynamic>.from(_defaults);
          _config.addAll(data);
          _loaded = true;
          await _saveToCache();
          return;
        } else {
          print("⚠️ Firestore document does not exist, using defaults");
        }
      } catch (e) {
        print("❌ DynamicConfig: Firestore fetch failed: $e");
      }
    } else {
      print("⚠️ DynamicConfig: No authenticated user, skipping Firestore");
    }

    // 2. Fallback to cache (only if Firestore fails or no user)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('threat_engine_config');
      if (cached != null) {
        final Map<String, dynamic> cachedMap = jsonDecode(cached);
        print("✅ DynamicConfig: Loaded from cache");
        print("   global_blacklist: ${cachedMap['global_blacklist']}");
        _config = Map<String, dynamic>.from(_defaults);
        _config.addAll(cachedMap);
        _loaded = true;
        return;
      }
    } catch (e) {
      print("❌ DynamicConfig: Cache load failed: $e");
    }

    // 3. Defaults
    print("⚠️ DynamicConfig: Using hardcoded defaults");
    _config = Map.from(_defaults);
    _loaded = true;
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('threat_engine_config', jsonEncode(_config));
    } catch (e) {
      print("❌ DynamicConfig: Failed to save cache: $e");
    }
  }

  // Getters (no extra checks needed because _initialization ensures load)
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

  /// Re-fetches only the blacklist and whitelist from Firestore.
  /// Lightweight — called before every scan so changes take effect immediately.
  Future<void> refreshBlacklist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('threat_engine')
          .get()
          .timeout(const Duration(seconds: 3));
      if (doc.exists) {
        final data = doc.data()!;
        if (data.containsKey('global_blacklist')) {
          _config['global_blacklist'] = data['global_blacklist'];
        }
        if (data.containsKey('global_whitelist')) {
          _config['global_whitelist'] = data['global_whitelist'];
        }
      }
    } catch (_) {}
  }
}