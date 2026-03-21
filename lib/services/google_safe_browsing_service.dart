import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSafeBrowsingService {
  final String apiKey =
      'AIzaSyBguQy3kVHT3ZTYQEJiT6PnMeJAMp8dGvs'; // Replace with your API key

  // Safe Browsing API endpoint
  final String endpoint =
      'https://safebrowsing.googleapis.com/v4/threatMatches:find';

  // Check if URL is safe
  // CHANGE: return type changed from bool → bool?
  // true  = safe
  // false = unsafe
  // null  = API / network error
  Future<bool?> isUrlSafe(String url) async {
    try {
      // Prepare the request body
      Map<String, dynamic> requestBody = {
        "client": {"clientId": "your-client-id", "clientVersion": "1.0.0"},
        "threatInfo": {
          "threatTypes": [
            "MALWARE",
            "SOCIAL_ENGINEERING", // Phishing changed to social engineering
          ], // You can add more threat types if needed
          "platformTypes": ["ANY_PLATFORM"],
          "threatEntryTypes": ["URL"],
          "threatEntries": [
            {"url": url},
          ],
        },
      };

      // Make the HTTP request to Google Safe Browsing API
      final response = await http
          .post(
            Uri.parse(
              '$endpoint?key=$apiKey',
            ), //FIX: attach API key to endpoint
            headers: {"Content-Type": "application/json"},
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 10)); // Added timeout of 10 seconds

      // Handle response
      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);

        // If the URL is found in the blacklist
        if (responseData.containsKey('matches') &&
            responseData['matches'].isNotEmpty) {
          return false; // Unsafe URL (blacklisted)
        }
        return true; // Safe URL
      } else {
        print('Error: ${response.statusCode}');
        return null; // API error
      }
    } catch (e) {
      print('Error: $e');
      return null; // network / timeout error
    }
  }
}
