import 'dart:convert';
import 'dart:io';

class StandardScaler {
  final List<double> mean;
  final List<double> scale;

  StandardScaler({required this.mean, required this.scale});

  factory StandardScaler.fromJson(Map<String, dynamic> json) {
    return StandardScaler(
      mean: List<double>.from(json['mean']),
      scale: List<double>.from(json['scale']),
    );
  }

  // New method: load from JSON string (for asset loading)
  static StandardScaler fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString);
    return StandardScaler.fromJson(json);
  }

  // Keep the original file-based load for desktop compatibility (optional)
  static Future<StandardScaler> load(String path) async {
    final content = await File(path).readAsString();
    return fromJsonString(content);
  }

  List<double> transform(List<double> features) {
    if (features.length != mean.length) {
      throw Exception('Feature length mismatch: expected ${mean.length}, got ${features.length}');
    }
    return List.generate(features.length, (i) {
      return (features[i] - mean[i]) / scale[i];
    });
  }
}