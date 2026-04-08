import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSafeBrowsing {
  static const String _apiKey = 'AIzaSyAFO_YPqEtZv3w80rXk1gYASaSSAt4EDq8';
  static const String _apiUrl =
      'https://safebrowsing.googleapis.com/v4/threatMatches:find';

  static Future<double?> checkUrl(String url) async {
    print('GoogleSafeBrowsing: Checking URL: $url');

    if (_apiKey == 'YOUR_GOOGLE_API_KEY') {
      print('GoogleSafeBrowsing: No API key provided, skipping.');
      return null;
    }

    try {
      final canonicalUrl = _canonicalize(url);

      final requestBody = {
        "client": {
          "clientId": "linksentry",
          "clientVersion": "1.0"
        },
        "threatInfo": {
          "threatTypes": [
            "MALWARE",
            "SOCIAL_ENGINEERING",
            "UNWANTED_SOFTWARE",
            "POTENTIALLY_HARMFUL_APPLICATION"
          ],
          "platformTypes": ["ANY_PLATFORM"],
          "threatEntryTypes": ["URL"],
          "threatEntries": [
            {"url": canonicalUrl}
          ]
        }
      };

      final uri = Uri.parse('$_apiUrl?key=$_apiKey');

      //print('GoogleSafeBrowsing: Request URI: $uri');
      //print('GoogleSafeBrowsing: Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      //print('GoogleSafeBrowsing: Response status: ${response.statusCode}');
      //print('GoogleSafeBrowsing: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // If matches exist → threat detected
        if (data.containsKey('matches')) {
          final matches = data['matches'] as List?;
          if (matches != null && matches.isNotEmpty) {
            print('GoogleSafeBrowsing: Threat detected!');
            return 0.9; // High risk
          }
        }

        print('GoogleSafeBrowsing: No threat found.');
        return 0.0; // Safe
      } else {
        print('GoogleSafeBrowsing: Error response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('GoogleSafeBrowsing: Exception: $e');
      return null;
    }
  }

  static String _canonicalize(String url) {
    var cleaned = url.trim().toLowerCase();

    if (!cleaned.startsWith('http://') &&
        !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }

    return cleaned;
  }
}