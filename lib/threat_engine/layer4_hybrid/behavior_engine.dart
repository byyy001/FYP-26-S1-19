import 'package:http/http.dart' as http;
import '../layer1_feature_extraction/feature_extractor.dart';

class BehaviorEngine {
  BehaviorEngine();

  // Core dangerous patterns (non-raw strings, double-escaped)
  static final RegExp _evalRegex = RegExp("eval\\s*\\(", caseSensitive: false);
  static final RegExp _docWriteRegex = RegExp("document\\.write(?:ln)?\\s*\\(", caseSensitive: false);
  static final RegExp _newFuncRegex = RegExp("new\\s+Function\\s*\\(", caseSensitive: false);
  static final RegExp _setTimeoutRegex = RegExp("set(Timeout|Interval)\\s*\\(", caseSensitive: false);

  // Redirects
  static final RegExp _metaRefreshRegex = RegExp("<meta[^>]*http-equiv\\s*=\\s*['\"]?refresh['\"]?", caseSensitive: false);
  static final RegExp _locationRedirect = RegExp("(?:window|top|parent|self)\\.location\\s*=", caseSensitive: false);
  static final RegExp _jsRedirect = RegExp("location\\.(?:href|replace)\\s*=", caseSensitive: false);
  static final RegExp _javascriptProto = RegExp("javascript\\s*:", caseSensitive: false);

  // Obfuscation
  static final RegExp _atobRegex = RegExp("atob\\s*\\(", caseSensitive: false);
  static final RegExp _btoaRegex = RegExp("btoa\\s*\\(", caseSensitive: false);
  static final RegExp _fromCharCodeRegex = RegExp("String\\.fromCharCode\\s*\\(", caseSensitive: false);
  static final RegExp _hexEscapeRegex = RegExp("\\\\x[0-9a-f]{2}", caseSensitive: false);
  static final RegExp _longHexRegex = RegExp("0x[0-9a-f]{12,}", caseSensitive: false);
  static final RegExp _longUnicodeRegex = RegExp("\\\\u[0-9a-f]{4}", caseSensitive: false);

  // Inline events & data URI
  static final RegExp _inlineEventRegex = RegExp("on(?:click|load|error|mouseover|submit)\\s*=", caseSensitive: false);
  static final RegExp _dataUriIframe = RegExp("<iframe[^>]+src\\s*=\\s*['\"]data:text/html", caseSensitive: false);

  // Ad & external script extraction
  static final RegExp _scriptSrcRegex = RegExp("<script[^>]+src\\s*=\\s*['\"]([^'\"]+)['\"]", caseSensitive: false);

  static final List<RegExp> _adKeywordRegexes = [
    "googleadservices", "doubleclick", "googlesyndication", "adservice",
    "adserver", "adunit", "advertisement", "sponsored", "popunder",
    "popup", "adsbygoogle", "dfp"
  ].map((kw) => RegExp(kw, caseSensitive: false)).toList();

  /// Returns { 'behaviorScore': double, 'adDensity': double, 'matchedPatterns': List<String> }
  Future<Map<String, dynamic>> analyzeDetailed(String url, UrlFeatures features) async {
    final double urlScore = _urlHeuristicScore(features);
    final List<String> matchedPatterns = [];

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return {'behaviorScore': urlScore, 'adDensity': 0.0, 'matchedPatterns': matchedPatterns};
      }

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('html') && !contentType.contains('javascript') && !contentType.contains('text')) {
        return {'behaviorScore': urlScore, 'adDensity': 0.0, 'matchedPatterns': matchedPatterns};
      }

      final body = response.body;
      if (body.length > 500000) {
        return {'behaviorScore': urlScore, 'adDensity': 0.0, 'matchedPatterns': matchedPatterns};
      }

      double scriptRisk = 0.0;

      if (_evalRegex.hasMatch(body)) {
        scriptRisk += 0.30;
        matchedPatterns.add('eval() call');
      }
      if (_newFuncRegex.hasMatch(body)) {
        scriptRisk += 0.25;
        matchedPatterns.add('new Function()');
      }
      if (_setTimeoutRegex.hasMatch(body)) {
        scriptRisk += 0.05;
        matchedPatterns.add('setTimeout / setInterval');
      }
      if (_atobRegex.hasMatch(body) || _btoaRegex.hasMatch(body)) {
        scriptRisk += 0.20;
        matchedPatterns.add('atob / btoa encoding');
      }
      if (_fromCharCodeRegex.hasMatch(body)) {
        scriptRisk += 0.15;
        matchedPatterns.add('String.fromCharCode');
      }
      if (_hexEscapeRegex.allMatches(body).length > 5) {
        scriptRisk += 0.15;
        matchedPatterns.add('Multiple hex escapes');
      }
      if (_longHexRegex.allMatches(body).length > 2) {
        scriptRisk += 0.20;
        matchedPatterns.add('Long hex numbers');
      }
      if (_longUnicodeRegex.allMatches(body).length > 10) {
        scriptRisk += 0.15;
        matchedPatterns.add('Many unicode escapes');
      }
      if (_docWriteRegex.hasMatch(body)) {
        scriptRisk += 0.15;
        matchedPatterns.add('document.write()');
      }
      if (_metaRefreshRegex.hasMatch(body)) {
        scriptRisk += 0.25;
        matchedPatterns.add('Meta refresh redirect');
      }
      if (_locationRedirect.hasMatch(body)) {
        scriptRisk += 0.05;
        matchedPatterns.add('window.location redirect');
      }
      if (_jsRedirect.hasMatch(body)) {
        scriptRisk += 0.05;
        matchedPatterns.add('location.href/replace');
      }
      if (_javascriptProto.hasMatch(body)) {
        scriptRisk += 0.30;
        matchedPatterns.add('javascript: URI');
      }
      if (_dataUriIframe.hasMatch(body)) {
        scriptRisk += 0.25;
        matchedPatterns.add('data: URI iframe');
      }
      if (_inlineEventRegex.allMatches(body).length > 5) {
        scriptRisk += 0.10;
        matchedPatterns.add('Many inline event handlers');
      }

      scriptRisk = scriptRisk.clamp(0.0, 1.0);

      int adMatches = 0;
      for (final kwRegex in _adKeywordRegexes) {
        adMatches += kwRegex.allMatches(body).length;
      }
      final matches = _scriptSrcRegex.allMatches(body);
      for (final match in matches) {
        final src = match.group(1);
        if (src != null) {
          for (final kwRegex in _adKeywordRegexes) {
            if (kwRegex.hasMatch(src.toLowerCase())) {
              adMatches++;
              break;
            }
          }
        }
      }
      final contentFactor = (body.length / 10000).clamp(1.0, 10.0);
      final adDensity = (adMatches / (10 * contentFactor)).clamp(0.0, 1.0);

      final double combinedScore = (urlScore + scriptRisk) / 2;
      return {
        'behaviorScore': combinedScore,
        'adDensity': adDensity,
        'matchedPatterns': matchedPatterns,
      };
    } catch (e) {
      return {'behaviorScore': urlScore, 'adDensity': 0.0, 'matchedPatterns': matchedPatterns};
    }
  }

  double _urlHeuristicScore(UrlFeatures features) {
    double score = 0.0;

    final hasRedirect = features.hasRedirectParam;
    final depth = features.pathDepth;
    final highEntropy = features.highEntropy;
    final suspiciousEncoding = features.hasSuspiciousEncoding;
    final typosquatting = features.isTyposquatting;

    if (hasRedirect) score += 0.2;
    if (depth > 3) score += ((depth - 3) / 10).clamp(0.0, 0.2);
    if (highEntropy) score += 0.2;
    if (suspiciousEncoding) score += 0.15;
    if (typosquatting) score += 0.3;
    if (hasRedirect && suspiciousEncoding) score += 0.1;
    if (typosquatting && highEntropy) score += 0.1;

    return score / (1 + score);
  }
}