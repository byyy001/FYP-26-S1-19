// ============================================================================
// static_rules.dart – Layer 2: Static Rule Engine + Heuristic Scoring + External Blacklists
// FIXED: Always include Whois and IPQS details (even when score = 0)
// ============================================================================
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import '../layer1_feature_extraction/feature_extractor.dart';
import '../scan_settings.dart';
import '../services/google_safe_browsing.dart';
import '../services/virustotal.dart';
import '../dynamic_config.dart';

// --------------------------------------------------------------------------
// Helper class to hold API keys
// --------------------------------------------------------------------------
class ApiKeys {
  static const String openPhishApiKey = '';
  static const String urlhausApiKey = '';
  static const String ipQualityScoreApiKey = 'wSefzuwEeVLGmEJ2adJHGhHBdaacAhcw';
  static const String whoisApiKey = 'at_RL2ksZSnT1Lk6EdCG7tEZldd84gJi';
}

// --------------------------------------------------------------------------
// Dynamic Whitelist Manager (Cisco Umbrella Top 1 Million)
// --------------------------------------------------------------------------
class DynamicWhitelistManager {
  static DynamicWhitelistManager? _instance;
  static const String _cacheFileName = 'umbrella_top1m.cache';
  static const Duration _cacheMaxAge = Duration(days: 1);
  static const int _maxDomains = 100000;

  Set<String>? _whitelist;
  DateTime? _lastUpdated;

  DynamicWhitelistManager._();

  static Future<DynamicWhitelistManager> getInstance() async {
    if (_instance == null) {
      _instance = DynamicWhitelistManager._();
      await _instance!._loadCache();
      if (_instance!._isStale()) {
        _instance!._refreshInBackground();
      }
    }
    return _instance!;
  }

  Future<void> _loadCache() async {
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final lines = contents.split('\n');
        if (lines.isNotEmpty) {
          final timestampLine = lines.first;
          final timestamp = DateTime.tryParse(timestampLine);
          if (timestamp != null) {
            _lastUpdated = timestamp;
            _whitelist = {};
            for (int i = 1; i < lines.length; i++) {
              final domain = lines[i].trim();
              if (domain.isNotEmpty) {
                _whitelist!.add(domain);
              }
            }
          }
        }
      }
    } catch (e) {
      print('DynamicWhitelistManager: Failed to load cache: $e');
    }
    _whitelist ??= {};
    _lastUpdated ??= DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _saveCache() async {
    try {
      final file = await _getCacheFile();
      final buffer = StringBuffer();
      buffer.writeln(_lastUpdated!.toIso8601String());
      if (_whitelist != null) {
        for (final domain in _whitelist!) {
          buffer.writeln(domain);
        }
      }
      await file.writeAsString(buffer.toString());
    } catch (e) {
      print('DynamicWhitelistManager: Failed to save cache: $e');
    }
  }

  Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  bool _isStale() {
    if (_lastUpdated == null) return true;
    return DateTime.now().difference(_lastUpdated!) > _cacheMaxAge;
  }

  Future<void> _refreshInBackground() async {
    _refresh().catchError((e) => print('Background refresh failed: $e'));
  }

  Future<void> _refresh() async {
    try {
      print('DynamicWhitelistManager: Fetching latest Umbrella top 1M list...');
      final response = await http.get(Uri.parse('https://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip'));
      if (response.statusCode != 200) {
        print('Failed to download whitelist: HTTP ${response.statusCode}');
        return;
      }

      final archive = ZipDecoder().decodeBytes(response.bodyBytes);
      if (archive.isEmpty) {
        print('Zip file empty');
        return;
      }
      final zipEntry = archive.first;
      final csvContent = utf8.decode(zipEntry.content as List<int>);
      final lines = csvContent.split('\n');

      final newWhitelist = <String>{};
      int count = 0;
      for (final line in lines) {
        if (count >= _maxDomains) break;
        final parts = line.split(',');
        if (parts.length >= 2) {
          final domain = parts[1].trim().toLowerCase();
          if (domain.isNotEmpty) {
            newWhitelist.add(domain);
            count++;
          }
        }
      }
      _whitelist = newWhitelist;
      _lastUpdated = DateTime.now();
      await _saveCache();
      print('DynamicWhitelistManager: Updated whitelist with ${_whitelist!.length} domains');
    } catch (e) {
      print('DynamicWhitelistManager: Refresh error: $e');
    }
  }

  Future<bool> contains(String domain) async {
    if (_whitelist == null) await _loadCache();
    return _whitelist?.contains(domain) ?? false;
  }
}

// --------------------------------------------------------------------------
// Static Rule Engine
// --------------------------------------------------------------------------
class StaticRuleEngine {
  List<String>? _suspiciousTlds;
  List<String>? _phishingKeywords;
  List<String>? _shorteners;
  Set<String>? _staticTrustedDomains;
  Set<String>? _globalBlacklist;
  bool? _enableHomographCheck;
  bool? _enableTyposquatting;
  bool? _enableUnshorten;
  int? _maxRedirectHops;
  int? _newDomainDaysThreshold;
  int? _pathDepthWarning;
  double? _entropyThreshold;
  List<String>? _enabledExternalSources;

  late final Future<void> _configLoaded;

  static Set<String>? _openPhishCache;
  static DateTime? _openPhishLastUpdate;
  static const Duration _openPhishCacheDuration = Duration(minutes: 30);

  final UrlFeatures features;
  final ScanSettings? settings;

  StaticRuleEngine(
    this.features,
    this.settings, {
    List<String>? enabledExternalSources,
  }) {
    _configLoaded = _loadDynamicConfig(enabledExternalSources);
  }

  Future<void> _ensureConfigLoaded() async {
    await _configLoaded;
  }

  Future<void> _loadDynamicConfig(List<String>? externalOverride) async {
    final config = await DynamicConfig.getInstance();
    _suspiciousTlds = config.suspiciousTlds;
    _phishingKeywords = config.phishingKeywords;
    _shorteners = config.urlShorteners;
    _staticTrustedDomains = config.globalWhitelist.toSet();
    _globalBlacklist = config.globalBlacklist.toSet();
    _enableHomographCheck = config.enableHomographCheck;
    _enableTyposquatting = config.enableTyposquatting;
    _enableUnshorten = config.enableUnshorten;
    _maxRedirectHops = config.maxRedirectHops;
    _newDomainDaysThreshold = config.newDomainDaysThreshold;
    _pathDepthWarning = config.pathDepthWarning;
    _entropyThreshold = config.entropyThreshold;

    final configuredSources = externalOverride ?? config.enabledExternalSources;
    if (configuredSources == null || configuredSources.isEmpty) {
      _enabledExternalSources = [
        'google_sb',
        'virustotal',
        'openphish',
        'urlhaus',
        'ipqs',
        'whois',
      ];
      print("⚠️ No external sources in config – using default: $_enabledExternalSources");
    } else {
      _enabledExternalSources = configuredSources;
      print("✅ External sources from config: $_enabledExternalSources");
    }
  }

  // Fallbacks
  List<String> get _fallbackSuspiciousTlds => const [
    'tk', 'xyz', 'top', 'club', 'work', 'date', 'stream', 'gq', 'ml', 'cf',
    'ga', 'ru', 'cn', 'pw', 'cc', 'bid', 'trade', 'webcam', 'science'
  ];
  List<String> get _fallbackPhishingKeywords => const [
    r'verify', r'account', r'banking', r'secure', r'login', r'signin',
    r'update', r'confirm', r'password', r'credential', r'paypal', r'apple',
    r'microsoft', r'amazon', r'netflix', r'wallet', r'crypto', r'bitcoin',
    r'seed.?phrase', r'private.?key', r'mnemonic', r'airdrop', r'free.?crypto',
    r'double.?your.?money', r'urgent.?action', r'verify.?wallet',
    r'connect.?wallet', r'claim.?reward', r'prize.?winner'
  ];
  List<String> get _fallbackShorteners => const [
    'bit.ly', 'tinyurl', 'goo.gl', 'ow.ly', 'is.gd', 'buff.ly', 'short.link'
  ];
  Set<String> get _fallbackStaticTrustedDomains => const {
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
    'youtube.com',
  };
  Set<String> get _fallbackBlacklist => const {};

  Future<bool> get isBlacklisted async {
    await _ensureConfigLoaded();
    final domain = features.domain.toLowerCase();
    final blacklist = _globalBlacklist ?? _fallbackBlacklist;
    if (blacklist.contains(domain)) return true;
    for (final bl in blacklist) {
      if (domain == bl || domain.endsWith('.$bl')) return true;
    }
    return false;
  }

  Future<bool> get isSuspiciousTld async {
    await _ensureConfigLoaded();
    final tld = features.tldSuffix;
    final list = _suspiciousTlds ?? _fallbackSuspiciousTlds;
    return list.contains(tld);
  }
  
  Future<bool> get isShortener async {
    await _ensureConfigLoaded();
    final url = features.url;
    final list = _shorteners ?? _fallbackShorteners;
    return list.any((s) => url.contains(s));
  }
  
  Future<bool> get isShortenerDomain async {
    await _ensureConfigLoaded();
    final domain = features.domain;
    final list = _shorteners ?? _fallbackShorteners;
    return list.any((s) => domain.contains(s));
  }

  Future<bool> get isTrustedDomain async {
    await _ensureConfigLoaded();
    final full = features.domain;
    if (full.isEmpty) return false;
    if (await isBlacklisted) return false;
    if (await isShortenerDomain) return false;
    final dynamicManager = await DynamicWhitelistManager.getInstance();
    if (await dynamicManager.contains(full)) return true;
    final trustedSet = _staticTrustedDomains ?? _fallbackStaticTrustedDomains;
    if (trustedSet.contains(full)) return true;
    for (final trusted in trustedSet) {
      if (full.endsWith('.$trusted') || full == trusted) return true;
    }
    return false;
  }

  Future<List<String>> findPhishingKeywords() async {
    await _ensureConfigLoaded();
    final matches = <String>[];
    final lower = features.url.toLowerCase();
    final keywords = _phishingKeywords ?? _fallbackPhishingKeywords;
    for (final pattern in keywords) {
      if (RegExp(pattern).hasMatch(lower)) {
        matches.add(pattern.replaceAll(RegExp(r'\\.?'), ''));
      }
    }
    return matches;
  }

  List<String> findSuspiciousPatterns() {
    final patterns = <String>[];
    if (features.hasIp) patterns.add('IP address used');
    if (features.url.contains('@')) patterns.add('Contains @ symbol');
    if (RegExp(r'//[^/]+//').hasMatch(features.url)) patterns.add('Double slash anomaly');
    if (RegExp(r'%[0-9a-f]{2}', caseSensitive: false).hasMatch(features.url)) patterns.add('Heavy URL encoding');
    if (RegExp(r'--').hasMatch(features.domain)) patterns.add('Punycode indicator');
    final threshold = (_entropyThreshold != null) ? _entropyThreshold! : 4.2;
    if (features.entropy > threshold) patterns.add('High URL entropy detected');
    return patterns;
  }

  Future<String?> detectTyposquatting() async {
    await _ensureConfigLoaded();
    if (_enableTyposquatting != true) return null;
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
  // External Blacklist Checks (always collect details)
  // --------------------------------------------------------------------------
  Future<bool> _isInCsaOrSpfList() async {
    try {
      final csaFile = File('assets/blacklists/csa_malicious.txt');
      final spfFile = File('assets/blacklists/spf_malicious.txt');
      if (!await csaFile.exists() || !await spfFile.exists()) return false;
      final csaContent = await csaFile.readAsString();
      final spfContent = await spfFile.readAsString();
      final domains = csaContent.split('\n') + spfContent.split('\n');
      final host = features.domain;
      return domains.any((line) => line.trim().toLowerCase() == host.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  Future<double> _checkGoogleSafeBrowsing() async {
    await _ensureConfigLoaded();
    if (settings != null && !settings!.useExternalApis) return 0.0;
    if (!(_enabledExternalSources?.contains('google_sb') ?? false)) return 0.0;
    final score = await GoogleSafeBrowsing.checkUrl(features.url);
    return score ?? 0.0;
  }

  Future<Map<String, dynamic>> _checkVirusTotal() async {
    await _ensureConfigLoaded();
    if (settings != null && !settings!.useExternalApis) {
      return {'score': 0.0, 'details': null};
    }
    if (!(_enabledExternalSources?.contains('virustotal') ?? false)) {
      return {'score': 0.0, 'details': null};
    }
    final result = await VirusTotal.checkUrl(features.url);
    if (result == null) return {'score': 0.0, 'details': null};
    return {
      'score': result['score'] as double,
      'details': {
        'malicious': result['malicious'],
        'suspicious': result['suspicious'],
        'total': result['total'],
      },
    };
  }

  static Future<void> _refreshOpenPhishFeed() async {
    try {
      final response = await http.get(Uri.parse('https://openphish.com/feed.txt'));
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        final urls = <String>{};
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) urls.add(trimmed);
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

  Future<Map<String, dynamic>> _checkOpenPhish() async {
    await _ensureConfigLoaded();
    if (settings != null && !settings!.useExternalApis) {
      return {'score': 0.0, 'found': false, 'details': null};
    }
    if (!(_enabledExternalSources?.contains('openphish') ?? false)) {
      return {'score': 0.0, 'found': false, 'details': null};
    }
    try {
      final found = await _isInOpenPhish(features.url);
      if (found) {
        return {
          'score': 1.0,
          'found': true,
          'details': {'source': 'OpenPhish', 'note': 'URL found in public feed'}
        };
      }
      return {'score': 0.0, 'found': false, 'details': null};
    } catch (e) {
      print('OpenPhish error: $e');
      return {'score': 0.0, 'found': false, 'details': null};
    }
  }

  Future<Map<String, dynamic>> _checkURLhaus() async {
    await _ensureConfigLoaded();
    if (settings != null && !settings!.useExternalApis) {
      return {'score': 0.0, 'found': false, 'details': null};
    }
    if (!(_enabledExternalSources?.contains('urlhaus') ?? false)) {
      return {'score': 0.0, 'found': false, 'details': null};
    }
    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => host == 'urlhaus-api.abuse.ch';
      final client = IOClient(httpClient);
      final url = Uri.parse('https://urlhaus-api.abuse.ch/v1/url/');
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'url=${Uri.encodeComponent(features.url)}',
      ).timeout(const Duration(seconds: 5));
      client.close();
      if (response.statusCode != 200) return {'score': 0.0, 'found': false, 'details': null};
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

  Future<Map<String, dynamic>> _checkIpQualityScore() async {
    await _ensureConfigLoaded();
    if (settings != null && !settings!.useExternalApis) return {'score': 0.0, 'details': null};
    if (!(_enabledExternalSources?.contains('ipqs') ?? false)) return {'score': 0.0, 'details': null};
    if (ApiKeys.ipQualityScoreApiKey.isEmpty) return {'score': 0.0, 'details': null};
    try {
      final url = Uri.parse('https://ipqualityscore.com/api/json/url/${ApiKeys.ipQualityScoreApiKey}/${Uri.encodeComponent(features.url)}');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return {'score': 0.0, 'details': null};
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        final riskScore = (json['risk_score'] as num?)?.toDouble() ?? 0.0;
        final normalizedScore = riskScore / 100.0;
        // Always return details, even if score is 0
        return {
          'score': normalizedScore,
          'details': {
            'risk_score': riskScore,
            'domain_age_human': json['domain_age']?['human'] ?? 'unknown',
            'suspicious_tld': json['suspicious_tld'] ?? false,
            'redirect_risk': json['redirect_risk'] ?? false,
            'unsafe': json['unsafe'] ?? false,
          }
        };
      } else {
        print('IPQualityScore API error: ${json['message']}');
        return {'score': 0.0, 'details': null};
      }
    } catch (e) {
      print('IPQualityScore error: $e');
      return {'score': 0.0, 'details': null};
    }
  }

  Future<Map<String, dynamic>> _checkWhoisAPI() async {
    await _ensureConfigLoaded();
    if (settings != null && !settings!.useExternalApis) return {'score': 0.0, 'details': null};
    if (!(_enabledExternalSources?.contains('whois') ?? false)) return {'score': 0.0, 'details': null};
    if (ApiKeys.whoisApiKey.isEmpty) return {'score': 0.0, 'details': null};
    final domain = features.domain;
    if (domain.isEmpty) return {'score': 0.0, 'details': null};
    try {
      final url = Uri.parse('https://www.whoisxmlapi.com/whoisserver/WhoisService')
          .replace(queryParameters: {
            'apiKey': ApiKeys.whoisApiKey,
            'domainName': domain,
            'outputFormat': 'JSON'
          });
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return {'score': 0.0, 'details': null};
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json.containsKey('ErrorMessage')) {
        print('WhoisAPI error: ${json['ErrorMessage']}');
        return {'score': 0.0, 'details': null};
      }
      final whoisRecord = json['WhoisRecord'] as Map<String, dynamic>?;
      if (whoisRecord == null) return {'score': 0.0, 'details': null};
      final createdDateStr = whoisRecord['createdDate'] as String?;
      if (createdDateStr == null) {
        // No creation date – return basic details anyway
        return {
          'score': 0.0,
          'details': {'error': 'No creation date found', 'registrar': whoisRecord['registrarName']}
        };
      }
      final created = DateTime.parse(createdDateStr);
      final ageDays = DateTime.now().difference(created).inDays;
      final threshold = _newDomainDaysThreshold ?? 30;
      print('WhoisAPI: Domain age $ageDays days (${ageDays < threshold ? "new" : "established"})');
      // Always return details, score is 0.8 if new, else 0.0
      final score = (ageDays < threshold) ? 0.8 : 0.0;
      return {
        'score': score,
        'details': {
          'age_days': ageDays,
          'warning': ageDays < threshold ? 'Domain registered less than $threshold days ago ($ageDays days)' : null,
          'created_date': createdDateStr,
          'registrar': whoisRecord['registrarName'],
        }
      };
    } catch (e) {
      print('WhoisAPI error: $e');
      return {'score': 0.0, 'details': null};
    }
  }

  Future<String?> _expandShortener(String url) async {
    await _ensureConfigLoaded();
    if (_enableUnshorten != true) return null;
    try {
      final client = HttpClient()
        ..autoUncompress = true
        ..connectionTimeout = const Duration(seconds: 3);
      final request = await client.headUrl(Uri.parse(url));
      final response = await request.close();
      final finalUrl = response.headers.value('location');
      client.close();
      if (finalUrl != null && finalUrl != url) return finalUrl;
    } catch (e) {
      // ignore
    }
    return null;
  }

  // --------------------------------------------------------------------------
  // Main external check – ALWAYS include Whois and IPQS details if available
  // --------------------------------------------------------------------------
  Future<Map<String, dynamic>> checkExternalBlacklists() async {
    await _ensureConfigLoaded();
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

    final vtResult = await _checkVirusTotal();
    if (vtResult['score'] > 0) {
      maxScore = max(maxScore, vtResult['score'] as double);
      sources.add('VirusTotal');
      details['virustotal'] = vtResult['details'];
    } else if (vtResult['details'] != null) {
      // Still store details even if score 0
      details['virustotal'] = vtResult['details'];
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
    }
    // Always include IPQS details (if any) regardless of score
    if (ipqsResult['details'] != null) {
      details['ipqualityscore'] = ipqsResult['details'];
    }

    final whoisResult = await _checkWhoisAPI();
    // Add to sources only if score > 0 (new domain)
    if (whoisResult['score'] != null && (whoisResult['score'] as double) > 0) {
      maxScore = max(maxScore, whoisResult['score'] as double);
      sources.add('WhoisAPI');
    }
    // Always include Whois details (age, registrar, etc.) even if score 0
    if (whoisResult['details'] != null) {
      details['whois'] = whoisResult['details'];
    }

    print("🔍 External check result: score=$maxScore, sources=$sources");

    return {
      'is_malicious': maxScore >= 0.8,
      'score': maxScore,
      'sources': sources,
      'details': details,
    };
  }

  // --------------------------------------------------------------------------
  // Public API: Run full static + heuristic analysis
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> analyzeSync() async {
    await _ensureConfigLoaded();
    final threats = <Map<String, dynamic>>[];

    if (await isBlacklisted) {
      threats.add({
        'type': 'global_blacklist',
        'severity': 'high',
        'description': 'Domain is globally blacklisted by administrator.',
        'score': 1.0,
      });
      return threats;
    }

    if (await isTrustedDomain) return threats;

    if (features.isMalformed) {
      threats.add({
        'type': 'malformed_url',
        'severity': 'high',
        'description': 'URL could not be parsed – may be malformed or suspicious.',
        'score': 0.9,
      });
    }

    if (await isSuspiciousTld) {
      threats.add({
        'type': 'suspicious_tld',
        'severity': 'medium',
        'description': "TLD '.${features.tldSuffix}' is often used in phishing.",
        'score': 0.5,
      });
    }

    final keywords = await findPhishingKeywords();
    if (keywords.isNotEmpty) {
      final severity = keywords.length >= 3 ? 'high' : 'medium';
      threats.add({
        'type': 'phishing_keywords',
        'severity': severity,
        'description': "Contains phishing terms: ${keywords.take(3).join(', ')}.",
        'score': severity == 'high' ? 0.7 : 0.5,
      });
    }

    final patterns = findSuspiciousPatterns();
    for (final pattern in patterns) {
      threats.add({
        'type': 'suspicious_pattern',
        'severity': 'medium',
        'description': pattern,
        'score': 0.6,
      });
    }

    if (await isShortener) {
      threats.add({
        'type': 'url_shortener',
        'severity': 'medium',
        'description': 'Link uses a URL shortening service.',
        'score': 0.5,
      });
      final expanded = await _expandShortener(features.url);
      if (expanded != null && expanded != features.url) {
        threats.add({
          'type': 'shortener_expanded',
          'severity': 'low',
          'description': 'Expands to: $expanded',
          'score': 0.1,
        });
      }
    }

    if (features.url.startsWith('http://') && !await isTrustedDomain) {
      threats.add({
        'type': 'unencrypted_http',
        'severity': 'low',
        'description': 'Unencrypted HTTP connection – information could be intercepted.',
        'score': 0.2,
      });
    }

    final path = features.uri.path.toLowerCase();
    final suspiciousPaths = [
      '/cgi-bin/', '/wp-admin/', '/phpmyadmin/', '/backup/', '/shell/', '/config/',
      '/admin/', '/login/', '/wp-login.php', '/xmlrpc.php'
    ];
    if (suspiciousPaths.any((p) => path.contains(p))) {
      threats.add({
        'type': 'suspicious_path',
        'severity': 'medium',
        'description': 'Suspicious path pattern detected (e.g., admin, backup, shell).',
        'score': 0.5,
      });
    }

    final domain = features.domain;
    if (_enableHomographCheck == true && domain.contains(RegExp(r'[^\x00-\x7F]'))) {
      threats.add({
        'type': 'homograph_attack',
        'severity': 'high',
        'description': 'Homograph attack possible – domain uses non‑standard characters that may impersonate legitimate sites.',
        'score': 0.8,
      });
    }

    final brand = await detectTyposquatting();
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

  Future<Map<String, dynamic>> analyzeAsync() async {
    final syncThreats = await analyzeSync();
    final external = await checkExternalBlacklists();
    return {
      'threats': syncThreats,
      'external': external,
    };
  }
}