import 'dart:convert';
import 'package:http/http.dart' as http;

class UrlScanService {
  static const _baseUrl = 'https://urlscan.io/api/v1';
  final String _apiKey;

  UrlScanService(this._apiKey);

  /// Submits [url] to URLScan.io sandbox and polls for the result.
  /// Returns null on network error. Returns `{'status': 'timeout'}` if the
  /// sandbox doesn't respond within ~30 seconds.
  Future<Map<String, dynamic>?> analyze(String url) async {
    try {
      // Step 1 — submit scan
      final submitRes = await http.post(
        Uri.parse('$_baseUrl/scan/'),
        headers: {
          'API-Key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'url': url, 'visibility': 'private'}),
      ).timeout(const Duration(seconds: 10));

      if (submitRes.statusCode != 200) return null;

      final submitData = jsonDecode(submitRes.body) as Map<String, dynamic>;
      final uuid = submitData['uuid'] as String?;
      if (uuid == null) return null;

      final reportUrl = 'https://urlscan.io/result/$uuid/';

      // Step 2 — poll for result (6 attempts × 5 s = 30 s max)
      for (int attempt = 0; attempt < 6; attempt++) {
        await Future.delayed(const Duration(seconds: 5));

        final resultRes = await http.get(
          Uri.parse('$_baseUrl/result/$uuid/'),
          headers: {'API-Key': _apiKey},
        ).timeout(const Duration(seconds: 10));

        if (resultRes.statusCode == 200) {
          final data = jsonDecode(resultRes.body) as Map<String, dynamic>;
          return _parseResult(data, reportUrl);
        }
        // 404 = not ready yet, keep polling
      }

      return {'status': 'timeout', 'report_url': reportUrl};
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _parseResult(Map<String, dynamic> data, String reportUrl) {
    final verdicts = data['verdicts']?['overall'] as Map<String, dynamic>? ?? {};
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    final lists = data['lists'] as Map<String, dynamic>? ?? {};

    final score = verdicts['score'] as int? ?? 0;
    final malicious = verdicts['malicious'] as bool? ?? false;
    final tags = List<String>.from(verdicts['tags'] as List? ?? []);
    final scriptsCount = (lists['scripts'] as List?)?.length ?? 0;
    final domainsCount = (lists['domains'] as List?)?.length ?? 0;
    final maliciousCount = stats['malicious'] as int? ?? 0;

    String verdict;
    if (malicious || score >= 70) {
      verdict = 'malicious';
    } else if (score >= 30 || maliciousCount > 0) {
      verdict = 'suspicious';
    } else {
      verdict = 'safe';
    }

    return {
      'status': 'ok',
      'verdict': verdict,
      'score': score,
      'malicious': malicious,
      'tags': tags,
      'scripts_count': scriptsCount,
      'domains_count': domainsCount,
      'malicious_resources': maliciousCount,
      'report_url': reportUrl,
    };
  }
}
