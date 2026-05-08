// ============================================================================
// logistic_regression.dart – Multi‑class Logistic Regression
// ============================================================================
import 'dart:convert';
import 'dart:math' as math;

class LogisticRegression {
  final List<List<double>> _weights; // shape: [n_classes, n_features]
  final List<double> _bias;          // shape: [n_classes]
  final List<double> _mean;          // scaler mean
  final List<double> _scale;         // scaler scale

  LogisticRegression._({
    required List<List<double>> weights,
    required List<double> bias,
    required List<double> mean,
    required List<double> scale,
  })  : _weights = weights,
        _bias = bias,
        _mean = mean,
        _scale = scale;

  /// Load model from JSON files (supports both binary and multi‑class).
  static Future<LogisticRegression> fromJson(String weightsJson, String scalerJson) async {
    final weightsMap = jsonDecode(weightsJson);
    final scalerMap = jsonDecode(scalerJson);

    // weights can be 2D (n_classes x n_features) or 1D (binary)
    dynamic weights = weightsMap['weights'];
    List<List<double>> w;
    if (weights is List && weights.isNotEmpty && weights[0] is List) {
      // weights is a list of lists – multi‑class
      w = weights.map((e) => List<double>.from(e)).toList();
    } else if (weights is List && weights[0] is num) {
      // binary case – convert to single row
      w = [List<double>.from(weights)];
    } else {
      throw Exception('Invalid weights format');
    }

    // bias: could be list (multi-class) or single value
    dynamic bias = weightsMap['bias'];
    List<double> b;
    if (bias is List) {
      b = List<double>.from(bias);
    } else if (bias is num) {
      b = [bias.toDouble()];
    } else {
      throw Exception('Invalid bias format');
    }

    if (w.length != b.length) {
      throw Exception('Number of classes mismatch: weights rows = ${w.length}, bias length = ${b.length}');
    }

    final mean = List<double>.from(scalerMap['mean']);
    final scale = List<double>.from(scalerMap['scale']);

    return LogisticRegression._(
      weights: w,
      bias: b,
      mean: mean,
      scale: scale,
    );
  }

  /// Apply scaling (as in training)
  List<double> _scaleFeatures(List<double> features) {
    if (features.length != _mean.length) {
      throw Exception('Feature length mismatch: expected ${_mean.length}, got ${features.length}');
    }
    return List.generate(features.length, (i) {
      return (features[i] - _mean[i]) / _scale[i];
    });
  }

  /// Compute softmax probabilities for all classes
  List<double> predictProbabilities(List<double> rawFeatures) {
    final features = _scaleFeatures(rawFeatures);
    final scores = List<double>.filled(_weights.length, 0.0);
    for (int c = 0; c < _weights.length; c++) {
      double sum = _bias[c];
      for (int f = 0; f < features.length; f++) {
        sum += _weights[c][f] * features[f];
      }
      scores[c] = sum;
    }
    final maxScore = scores.reduce(math.max);
    final expScores = scores.map((s) => math.exp(s - maxScore)).toList();
    final sumExp = expScores.reduce((a, b) => a + b);
    return expScores.map((e) => e / sumExp).toList();
  }

  /// Return the predicted class index (0‑based)
  int predictClass(List<double> features) {
    final probs = predictProbabilities(features);
    int bestClass = 0;
    double bestProb = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > bestProb) {
        bestProb = probs[i];
        bestClass = i;
      }
    }
    return bestClass;
  }

  /// Legacy classify method – returns threat probability (sum of threat classes) and confidence.
  Map<String, dynamic> classify(List<double> features) {
    final probs = predictProbabilities(features);
    // For binary: probs[1] is malicious; for multi‑class, sum all threat classes (classes 1..n-1)
    final threatProb = _weights.length == 2
        ? probs[1]
        : probs.sublist(1).fold(0.0, (a, b) => a + b);
    final maxProb = probs.reduce(math.max);
    final isMalicious = maxProb > 0.5 && (probs.indexOf(maxProb) > 0);
    final confidence = maxProb >= 0.8 ? 'high' : (maxProb >= 0.6 ? 'medium' : 'low');
    return {
      'prediction': isMalicious ? 'malicious' : 'benign',
      'threat_probability': threatProb,
      'confidence': confidence,
      'score': maxProb,
      'class_probs': probs,
      'class': probs.indexOf(maxProb),
    };
  }
}