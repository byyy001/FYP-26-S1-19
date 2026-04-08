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

  static Future<StandardScaler> load(String path) async {
    final content = await File(path).readAsString();
    final json = jsonDecode(content);
    return StandardScaler.fromJson(json);
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