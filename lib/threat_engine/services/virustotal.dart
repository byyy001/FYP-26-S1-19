import 'dart:convert';
import 'package:http/http.dart' as http;

class VirusTotal {
  static const String _apiUrl = 'https://www.virustotal.com/api/v3/urls';
  static const String _apiKey = '5a221bf9933abf9baba14462dfafb08a1df966d3234795944d195f24b3d043ef';

  static Future<double?> checkUrl(String url) async {
    if (_apiKey == 'YOUR_VIRUSTOTAL_API_KEY') {
      print('VirusTotal: API key not configured');
      return null;
    }

    print('VirusTotal: Checking URL: $url');

    try {
      // Submit URL for analysis
      final submitResponse = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'x-apikey': _apiKey,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'url': url},
      );

      if (submitResponse.statusCode != 200) {
        print('VirusTotal: Error submitting URL (${submitResponse.statusCode})');
        return null;
      }

      final submitData = jsonDecode(submitResponse.body);
      final analysisId = submitData['data']['id'];

      // Poll for results
      Map<String, dynamic>? analysisData;
      int retries = 5; // increased retries for reliability
      int delay = 3;   // seconds between polls

      while (retries-- > 0) {
        await Future.delayed(Duration(seconds: delay));

        final response = await http.get(
          Uri.parse('https://www.virustotal.com/api/v3/analyses/$analysisId'),
          headers: {'x-apikey': _apiKey},
        );

        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body);
        final status = data['data']['attributes']['status'];

        if (status == 'completed') {
          analysisData = data;
          break;
        }
      }

      if (analysisData == null) {
        print('VirusTotal: Analysis timeout or failed');
        return null;
      }

      final stats = analysisData['data']['attributes']['stats'];
      final malicious = stats['malicious'] as int;
      final suspicious = stats['suspicious'] as int;
      final harmless = stats['harmless'] as int;
      final undetected = stats['undetected'] as int;
      final timeout = stats['timeout'] as int;

      final total = harmless + malicious + suspicious + undetected + timeout;

      if (malicious > 0 || suspicious > 0) {
        print('VirusTotal: Threat found! $malicious engines detected malicious, $suspicious suspicious (out of $total)');
      } else {
        print('VirusTotal: No threats found. ($malicious malicious, $suspicious suspicious out of $total)');
      }

      // New aggressive scoring: map detection counts to meaningful risk
      double score = 0.0;
      if (malicious > 0) {
        if (malicious >= 10) score = 1.0;
        else if (malicious >= 5) score = 0.9;
        else if (malicious >= 3) score = 0.8;
        else if (malicious >= 1) score = 0.6;  // 1 detection is still a strong signal
      } else if (suspicious > 0) {
        score = 0.2; // Suspicious only is moderate
      }

      return score.clamp(0.0, 1.0);
    } catch (e) {
      print('VirusTotal: Exception: $e');
      return null;
    }
  }
}