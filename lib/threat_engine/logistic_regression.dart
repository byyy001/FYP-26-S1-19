// ============================================================================
// logistic_regression.dart – Layer 3: ML Classifier (Logistic Regression)
// ============================================================================
// This file provides a logistic regression classifier for URL threat detection.
// It loads weights and bias from a JSON asset and calculates the probability
// that a URL is malicious based on the 16 features from feature_extractor.
// Confidence levels (high/medium/low) are derived from the probability's
// distance from 0.5.
// ============================================================================

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'feature_extractor.dart';

class LogisticRegression {
  final List<double> weights;
  final double bias;

  LogisticRegression(this.weights, this.bias);

  // Load pre‑trained weights from JSON asset
  static Future<LogisticRegression> fromAsset(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final json = jsonDecode(jsonString);
    return LogisticRegression(
      List<double>.from(json['weights']),
      json['bias'].toDouble(),
    );
  }

  // Sigmoid function: 1 / (1 + exp(-z))
  double predictProbability(List<double> features) {
    double z = bias;
    for (int i = 0; i < weights.length; i++) {
      z += weights[i] * features[i];
    }
    return 1.0 / (1.0 + math.exp(-z));
  }

  // Return classification result with confidence
  Map<String, dynamic> classify(UrlFeatures features) {
    final prob = predictProbability(features.toFeatureVector());
    final isMalicious = prob > 0.5;
    final confidence = prob > 0.8 || prob < 0.2
        ? 'high'
        : prob > 0.6 || prob < 0.4
            ? 'medium'
            : 'low';
    return {
      'threat_probability': prob,
      'prediction': isMalicious ? 'malicious' : 'benign',
      'confidence': confidence,
    };
  }
}