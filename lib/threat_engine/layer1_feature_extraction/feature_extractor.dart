// ============================================================================
// feature_extractor.dart – Base Layer: Feature Extraction (Full 59 Features)
// ============================================================================
import 'dart:math';
import 'package:tldts/tldts.dart' as tldts; // kept for compatibility

class UrlFeatures {
  final String url;
  late final Uri uri;
  bool _parseFailed = false;
  late final String _domain;
  late final String _tldSuffix;
  late final String _subdomain;

  UrlFeatures(this.url) {
    // ✅ Normalize URL: add https:// if no scheme
    String normalizedUrl = url.trim();
    if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }
    try {
      uri = Uri.parse(normalizedUrl);
    } catch (_) {
      uri = Uri();
      _markFailed();
      return;
    }

    final host = uri.host;
    if (host.isEmpty) {
      _markFailed();
      return;
    }

    // Manual parser – works for almost all cases
    final parts = host.split('.');
    if (parts.length < 2) {
      _markFailed();
      return;
    }

    // Multi-part TLDs (common ones – extend as needed)
    const multiTlds = {
      'co.uk', 'org.uk', 'ac.uk', 'gov.uk', 'ltd.uk', 'me.uk',
      'com.au', 'org.au', 'net.au', 'id.au', 'asn.au',
      'co.jp', 'or.jp', 'ne.jp', 'ac.jp', 'ad.jp',
      'com.br', 'org.br', 'net.br', 'gov.br',
      'co.za', 'org.za', 'net.za',
      'co.nz', 'org.nz', 'net.nz',
      'com.mx', 'org.mx', 'net.mx',
      'com.cn', 'org.cn', 'net.cn',
    };

    String publicSuffix;
    String domain;
    String subdomain;

    final lastTwo = '${parts[parts.length-2]}.${parts[parts.length-1]}';
    if (parts.length >= 3 && multiTlds.contains(lastTwo)) {
      publicSuffix = lastTwo;
      domain = '${parts[parts.length-3]}.$lastTwo';
      subdomain = parts.sublist(0, parts.length - 3).join('.');
    } else {
      publicSuffix = parts.last;
      domain = '${parts[parts.length-2]}.$publicSuffix';
      subdomain = parts.sublist(0, parts.length - 2).join('.');
    }

    _domain = domain;
    _tldSuffix = publicSuffix;
    _subdomain = subdomain;
    _parseFailed = false;
  }

  void _markFailed() {
    _parseFailed = true;
    _domain = '';
    _tldSuffix = '';
    _subdomain = '';
  }

  bool get isMalformed => _parseFailed;

  // ================================
  // Domain Info
  // ================================
  String get tldSuffix => _tldSuffix;
  String get domain => _domain;
  String get subdomain => _subdomain;

  // ================================
  // Length & Basic Counts (keep from your existing file)
  // ================================
  int get length => url.length;
  int get domainLength => domain.length;
  int get subdomainLength => subdomain.length;
  int get pathLength => uri.path.length;

  int countChar(String c) => c.allMatches(url).length;
  int get numAt => countChar('@');
  int get numQuestion => countChar('?');
  int get numHyphen => countChar('-');
  int get numEqual => countChar('=');
  int get numDot => countChar('.');
  int get numHash => countChar('#');
  int get numPercent => countChar('%');
  int get numPlus => countChar('+');
  int get numDollar => countChar('\$');
  int get numExclamation => countChar('!');
  int get numStar => countChar('*');
  int get numComma => countChar(',');
  int get numDoubleSlash => '//'.allMatches(url).length;
  int get numDigits => url.replaceAll(RegExp(r'[^0-9]'), '').length;
  int get numLetters => url.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;

  // ================================
  // Boolean Features
  // ================================
  bool get hasIp => RegExp(r'\d+\.\d+\.\d+\.\d+').hasMatch(url);
  bool get hasPort => uri.hasPort;
  bool get hasHttps => uri.scheme == 'https';
  bool get hasQuery => uri.query.isNotEmpty;
  bool get isShortenedUrl {
    final shorteners = ['bit.ly', 'tinyurl.com', 'goo.gl', 't.co', 'ow.ly'];
    return shorteners.contains(domain.toLowerCase());
  }
  bool get hasRedirectParam => url.contains('redirect=') || url.contains('url=');

  // ================================
  // Entropy
  // ================================
  double get entropy {
    if (url.isEmpty) return 0.0;
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
  bool get highEntropy => entropy > 4.2;

  // ================================
  // Phishing / Suspicious Flags
  // ================================
  bool get hasPhishingKeywords {
    final keywords = [
      'login', 'verify', 'secure', 'account', 'update', 'bank',
      'confirm', 'signin', 'paypal', 'apple', 'amazon', 'google',
      'microsoft', 'reset', 'unlock', 'billing', 'payment'
    ];
    final lower = url.toLowerCase();
    return keywords.any((k) => lower.contains(k));
  }
  bool get hasSuspiciousTld {
    final suspiciousTlds = ['tk', 'xyz', 'top', 'club', 'online', 'pw', 'site'];
    return suspiciousTlds.contains(tldSuffix.toLowerCase());
  }
  bool get isTyposquatting {
    final legitDomains = ['google', 'facebook', 'paypal', 'amazon', 'microsoft', 'apple'];
    final d = domain.toLowerCase();
    for (final legit in legitDomains) {
      if (_levenshtein(d, legit) <= 2 && d != legit) return true;
    }
    return false;
  }
  bool get hasSuspiciousEncoding => url.contains('%') || url.contains('@') || url.contains('//');
  bool get isGovEdu => tldSuffix == 'gov' || tldSuffix == 'edu';
  bool get hasSuspiciousExtension {
    final suspiciousExt = ['.exe', '.zip', '.rar', '.scr', '.bat', '.cmd', '.js', '.vbs'];
    return suspiciousExt.any((ext) => url.toLowerCase().contains(ext));
  }

  // ================================
  // Path / Subdomain / Parameter Counts
  // ================================
  int get subdomainParts => subdomain.split('.').where((s) => s.isNotEmpty).length;
  int get pathDepth => uri.pathSegments.length;
  int get numQueryParams => uri.queryParameters.length;
  int get underscoreCountInPath => '_'.allMatches(uri.path).length;

  // ================================
  // Advanced Phishing Features (placeholder)
  // ================================
  bool get phishUrgencyWords => hasPhishingKeywords;
  bool get phishSecurityWords => hasPhishingKeywords;
  bool get phishBrandMentions => isTyposquatting || hasPhishingKeywords;
  bool get phishBrandHijack => isTyposquatting;
  bool get phishMultipleSubdomains => subdomainParts > 2;
  bool get phishLongPath => pathLength > 30;
  bool get phishManyParams => numQueryParams > 3;
  bool get phishSuspiciousTld => hasSuspiciousTld;
  bool get phishAdvExactBrandMatch => false;
  bool get phishAdvBrandInSubdomain => subdomain.toLowerCase().contains(domain.split('.')[0]);
  bool get phishAdvBrandInPath => uri.path.toLowerCase().contains(domain.split('.')[0]);
  int get phishAdvHyphenCount => numHyphen;
  int get phishAdvNumberCount => numDigits;
  bool get phishAdvSuspiciousTld => hasSuspiciousTld;
  bool get phishAdvLongDomain => domainLength > 20;
  bool get phishAdvManySubdomains => subdomainParts > 3;
  bool get phishAdvEncodedChars => hasSuspiciousEncoding;
  bool get phishAdvPathKeywords => hasPhishingKeywords;
  bool get phishAdvHasRedirect => hasRedirectParam;
  bool get phishAdvManyParams => numQueryParams > 5;
  bool get pathHasHackedTerms => hasPhishingKeywords;
  int get pathUnderscoreCount => underscoreCountInPath;

  // ================================
  // Web Features (External - placeholders)
  // ================================
  int get webHttpStatus => 200;
  bool get webIsLive => true;
  double get webExtRatio => 0.0;
  int get webUniqueDomains => 0;
  bool get webFavicon => false;
  bool get webCsp => false;
  bool get webXframe => false;
  bool get webHsts => false;
  bool get webXcontent => false;
  int get webSecurityScore => 0;
  int get webFormsCount => 0;
  int get webPasswordFields => 0;
  int get webHiddenInputs => 0;
  bool get webHasLogin => false;
  bool get webSslValid => hasHttps;

  // ================================
  // Helper
  // ================================
  int _levenshtein(String s1, String s2) {
    final dp = List.generate(s1.length + 1, (_) => List<int>.filled(s2.length + 1, 0));
    for (int i = 0; i <= s1.length; i++) dp[i][0] = i;
    for (int j = 0; j <= s2.length; j++) dp[0][j] = j;
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        dp[i][j] = [dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost].reduce(min);
      }
    }
    return dp[s1.length][s2.length];
  }

  // ================================
  // Full Feature Vector (59 features)
  // ================================
  List<double> toFeatureVector() => [
        length.toDouble(),
        numAt.toDouble(),
        numQuestion.toDouble(),
        numHyphen.toDouble(),
        numEqual.toDouble(),
        numDot.toDouble(),
        numHash.toDouble(),
        numPercent.toDouble(),
        numPlus.toDouble(),
        numDollar.toDouble(),
        numExclamation.toDouble(),
        numStar.toDouble(),
        numComma.toDouble(),
        numDoubleSlash.toDouble(),
        numDigits.toDouble(),
        numLetters.toDouble(),
        hasRedirectParam ? 1.0 : 0.0,
        hasHttps ? 1.0 : 0.0,
        isShortenedUrl ? 1.0 : 0.0,
        hasIp ? 1.0 : 0.0,
        webHttpStatus.toDouble(),
        webIsLive ? 1.0 : 0.0,
        webExtRatio,
        webUniqueDomains.toDouble(),
        webFavicon ? 1.0 : 0.0,
        webCsp ? 1.0 : 0.0,
        webXframe ? 1.0 : 0.0,
        webHsts ? 1.0 : 0.0,
        webXcontent ? 1.0 : 0.0,
        webSecurityScore.toDouble(),
        webFormsCount.toDouble(),
        webPasswordFields.toDouble(),
        webHiddenInputs.toDouble(),
        webHasLogin ? 1.0 : 0.0,
        webSslValid ? 1.0 : 0.0,
        phishUrgencyWords ? 1.0 : 0.0,
        phishSecurityWords ? 1.0 : 0.0,
        phishBrandMentions ? 1.0 : 0.0,
        phishBrandHijack ? 1.0 : 0.0,
        phishMultipleSubdomains ? 1.0 : 0.0,
        phishLongPath ? 1.0 : 0.0,
        phishManyParams ? 1.0 : 0.0,
        phishSuspiciousTld ? 1.0 : 0.0,
        phishAdvExactBrandMatch ? 1.0 : 0.0,
        phishAdvBrandInSubdomain ? 1.0 : 0.0,
        phishAdvBrandInPath ? 1.0 : 0.0,
        phishAdvHyphenCount.toDouble(),
        phishAdvNumberCount.toDouble(),
        phishAdvSuspiciousTld ? 1.0 : 0.0,
        phishAdvLongDomain ? 1.0 : 0.0,
        phishAdvManySubdomains ? 1.0 : 0.0,
        phishAdvEncodedChars ? 1.0 : 0.0,
        phishAdvPathKeywords ? 1.0 : 0.0,
        phishAdvHasRedirect ? 1.0 : 0.0,
        phishAdvManyParams ? 1.0 : 0.0,
        pathHasHackedTerms ? 1.0 : 0.0,
        hasSuspiciousExtension ? 1.0 : 0.0,
        pathUnderscoreCount.toDouble(),
        isGovEdu ? 1.0 : 0.0,
      ];
}