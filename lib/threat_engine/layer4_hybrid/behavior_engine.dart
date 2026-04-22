import 'package:http/http.dart' as http;
import '../layer1_feature_extraction/feature_extractor.dart';

class BehaviorEngine {
  BehaviorEngine();

  // --------------------------------------------------------------------------
  // Regex patterns – using triple‑quoted raw strings for safety
  // --------------------------------------------------------------------------
  static final RegExp _evalRegex = RegExp(r'''eval\s*\(''', caseSensitive: false);
  static final RegExp _docWriteRegex = RegExp(r'''document\.write(?:ln)?\s*\(''', caseSensitive: false);
  static final RegExp _newFuncRegex = RegExp(r'''new\s+Function\s*\(''', caseSensitive: false);
  static final RegExp _setTimeoutRegex = RegExp(r'''set(Timeout|Interval)\s*\(''', caseSensitive: false);

  static final RegExp _metaRefreshRegex = RegExp(
    r'''<meta[^>]*http-equiv\s*=\s*['"]?refresh['"]?''',
    caseSensitive: false,
  );
  static final RegExp _locationRedirect = RegExp(
    r'''(?:window|top|parent|self)\.location\s*=''',
    caseSensitive: false,
  );
  static final RegExp _jsRedirect = RegExp(
    r'''location\.(?:href|replace)\s*=''',
    caseSensitive: false,
  );
  static final RegExp _javascriptProto = RegExp(
    r'''javascript\s*:''',
    caseSensitive: false,
  );

  static final RegExp _atobRegex = RegExp(r'''atob\s*\(''', caseSensitive: false);
  static final RegExp _btoaRegex = RegExp(r'''btoa\s*\(''', caseSensitive: false);
  static final RegExp _fromCharCodeRegex = RegExp(
    r'''String\.fromCharCode\s*\(''',
    caseSensitive: false,
  );
  static final RegExp _hexEscapeRegex = RegExp(
    r'''\\x[0-9a-f]{2}''',
    caseSensitive: false,
  );
  static final RegExp _longHexRegex = RegExp(
    r'''0x[0-9a-f]{12,}''',
    caseSensitive: false,
  );
  static final RegExp _longUnicodeRegex = RegExp(
    r'''\\u[0-9a-f]{4}''',
    caseSensitive: false,
  );

  static final RegExp _inlineEventRegex = RegExp(
    r'''on(?:click|load|error|mouseover|submit)\s*=''',
    caseSensitive: false,
  );
  static final RegExp _dataUriIframe = RegExp(
    r'''<iframe[^>]+src\s*=\s*['"]data:text/html''',
    caseSensitive: false,
  );
  static final RegExp _scriptSrcRegex = RegExp(
    r'''<script[^>]+src\s*=\s*['"]([^'"]+)['"]''',
    caseSensitive: false,
  );

  static final List<RegExp> _adKeywordRegexes = [
    RegExp(r'''googleadservices''', caseSensitive: false),
    RegExp(r'''doubleclick''', caseSensitive: false),
    RegExp(r'''googlesyndication''', caseSensitive: false),
    RegExp(r'''adservice''', caseSensitive: false),
    RegExp(r'''adserver''', caseSensitive: false),
    RegExp(r'''adunit''', caseSensitive: false),
    RegExp(r'''advertisement''', caseSensitive: false),
    RegExp(r'''sponsored''', caseSensitive: false),
    RegExp(r'''popunder''', caseSensitive: false),
    RegExp(r'''popup''', caseSensitive: false),
    RegExp(r'''adsbygoogle''', caseSensitive: false),
    RegExp(r'''dfp''', caseSensitive: false),
  ];

  // --------------------------------------------------------------------------
  // MAIN ANALYSIS
  // --------------------------------------------------------------------------
  Future<Map<String, dynamic>> analyzeDetailed(
    String url,
    UrlFeatures features, {
    Map<String, dynamic>? externalThreatData,
  }) async {
    final double urlScore = _urlHeuristicScore(features);
    final List<String> matchedPatterns = [];
    double scriptRisk = 0.0;
    double adDensity = 0.0;

    // ----------------------------------------------------------------------
    // DOMAIN TRUST FILTER (reduce false positives)
    // ----------------------------------------------------------------------
    final bool isTrustedDomain =
        url.contains('google.com') ||
        url.contains('youtube.com') ||
        url.contains('facebook.com');

    // ----------------------------------------------------------------------
    // FETCH HTML
    // ----------------------------------------------------------------------
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response =
          await client.send(request).timeout(const Duration(seconds: 10));

      final streamedResponse = await http.Response.fromStream(response);
      final body = streamedResponse.body;
      final contentType = streamedResponse.headers['content-type'] ?? '';

      if (streamedResponse.statusCode == 200 &&
          (contentType.contains('html') ||
              contentType.contains('javascript') ||
              contentType.contains('text'))) {

        if (body.length <= 500000) {

          // ---------------- BASIC PATTERN DETECTION ----------------

          final evalMatches = _evalRegex.allMatches(body).length;
          if (evalMatches > 0) {
            scriptRisk += (evalMatches * 0.05).clamp(0.0, 0.25);
            matchedPatterns.add('eval() usage');
          }

          if (_newFuncRegex.hasMatch(body)) {
            scriptRisk += 0.15;
            matchedPatterns.add('new Function()');
          }

          if (_setTimeoutRegex.hasMatch(body)) {
            scriptRisk += 0.02; // reduced
          }

          if (_atobRegex.hasMatch(body) || _btoaRegex.hasMatch(body)) {
            scriptRisk += 0.10;
            matchedPatterns.add('Encoding functions (atob/btoa)');
          }

          if (_fromCharCodeRegex.hasMatch(body)) {
            scriptRisk += 0.10;
            matchedPatterns.add('String.fromCharCode');
          }

          if (_hexEscapeRegex.allMatches(body).length > 5) {
            scriptRisk += 0.10;
          }

          if (_longHexRegex.allMatches(body).length > 2) {
            scriptRisk += 0.15;
          }

          if (_longUnicodeRegex.allMatches(body).length > 10) {
            scriptRisk += 0.10;
          }

          if (_docWriteRegex.hasMatch(body)) {
            if (body.contains("<script")) {
              scriptRisk += 0.10;
            } else {
              scriptRisk += 0.03;
            }
          }

          if (_metaRefreshRegex.hasMatch(body)) {
            scriptRisk += 0.15;
            matchedPatterns.add('Meta refresh redirect');
          }

          if (_locationRedirect.hasMatch(body) ||
              _jsRedirect.hasMatch(body)) {
            scriptRisk += 0.05;
          }

          if (_javascriptProto.hasMatch(body)) {
            scriptRisk += 0.20;
            matchedPatterns.add('javascript: URI');
          }

          if (_dataUriIframe.hasMatch(body)) {
            scriptRisk += 0.20;
          }

          final inlineEvents = _inlineEventRegex.allMatches(body).length;
          if (inlineEvents > 10) {
            scriptRisk += 0.08;
          }

          // ---------------- CORRELATION DETECTION ----------------

          bool hasObfuscation =
              _atobRegex.hasMatch(body) ||
              _fromCharCodeRegex.hasMatch(body) ||
              _hexEscapeRegex.allMatches(body).length > 5;

          bool hasExecution =
              _evalRegex.hasMatch(body) ||
              _newFuncRegex.hasMatch(body);

          bool hasRedirect =
              _metaRefreshRegex.hasMatch(body) ||
              _locationRedirect.hasMatch(body) ||
              _jsRedirect.hasMatch(body);

          if (hasObfuscation && hasExecution) {
            matchedPatterns.add('Obfuscation + execution');
            scriptRisk += 0.25;
          }

          if (hasExecution && hasRedirect) {
            matchedPatterns.add('Execution + redirect');
            scriptRisk += 0.20;
          }

          if (hasObfuscation && hasRedirect) {
            matchedPatterns.add('Obfuscation + redirect');
            scriptRisk += 0.20;
          }

          // ---------------- AD DENSITY (REDUCED IMPACT) ----------------

          int adMatches = 0;
          for (final kw in _adKeywordRegexes) {
            adMatches += kw.allMatches(body).length;
          }

          final matches = _scriptSrcRegex.allMatches(body);
          for (final m in matches) {
            final src = m.group(1);
            if (src != null) {
              for (final kw in _adKeywordRegexes) {
                if (kw.hasMatch(src.toLowerCase())) {
                  adMatches++;
                  break;
                }
              }
            }
          }

          final contentFactor =
              (body.length / 10000).clamp(1.0, 10.0);
          adDensity =
              (adMatches / (10 * contentFactor)).clamp(0.0, 1.0);

          if (adDensity > 0.5) {
            matchedPatterns.add('Very high ad density');
            scriptRisk += 0.05; // reduced impact
          }
        }
      }

      client.close();
    } catch (e) {
      matchedPatterns.add('Network error: $e');
    }

    // ----------------------------------------------------------------------
    // URL FEATURES
    // ----------------------------------------------------------------------
    if (features.hasRedirectParam) scriptRisk += 0.10;
    if (features.highEntropy) scriptRisk += 0.10;
    if (features.hasSuspiciousEncoding) scriptRisk += 0.08;
    if (features.isTyposquatting) scriptRisk += 0.20;
    if (features.pathDepth > 3) scriptRisk += 0.05;

    // ----------------------------------------------------------------------
    // TRUST ADJUSTMENT
    // ----------------------------------------------------------------------
    if (isTrustedDomain) {
      scriptRisk *= 0.6;
    }

    scriptRisk = scriptRisk.clamp(0.0, 1.0);

    // ----------------------------------------------------------------------
    // FINAL SCORE (IMPROVED)
    // ----------------------------------------------------------------------
    final double combinedScore =
        (urlScore * 0.4) + (scriptRisk * 0.6);

    return {
      'behaviorScore': combinedScore,
      'adDensity': adDensity,
      'matchedPatterns': matchedPatterns.toSet().toList(),
    };
  }

  // --------------------------------------------------------------------------
  // URL HEURISTIC
  // --------------------------------------------------------------------------
  double _urlHeuristicScore(UrlFeatures features) {
    double score = 0.0;

    if (features.hasRedirectParam) score += 0.2;
    if (features.pathDepth > 3) {
      score += ((features.pathDepth - 3) / 10).clamp(0.0, 0.2);
    }
    if (features.highEntropy) score += 0.2;
    if (features.hasSuspiciousEncoding) score += 0.15;
    if (features.isTyposquatting) score += 0.3;

    return score / (1 + score);
  }
}