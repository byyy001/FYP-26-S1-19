// ============================================================================
// decision_tree.dart – Layer 3: ML Classifier (Decision Tree)
// ============================================================================
// This file provides a decision tree classifier for URL threat detection.
// It loads a JSON representation of a pre‑trained decision tree from an asset
// and supports:
//   - Binary malicious probability (for compatibility with hybrid scoring)
//   - Multi‑class prediction (benign, defacement, phishing, malware)
//
// The JSON format follows a recursive structure. Leaf nodes can contain:
//   - "value" (double) – the binary probability (legacy)
//   - "distribution" (List<double>) – class probabilities for 4 classes
//   - "class" (int) – predicted class index (0‑3) for fast inference
//
// The tree is built using the dataset with 65 features, but only the first 16
// features are used (matching feature_extractor); the rest are ignored.
// ============================================================================

import 'dart:convert';
import 'package:flutter/services.dart';
import 'feature_extractor.dart';

class DecisionTree {
  final Map<String, dynamic> _root;

  DecisionTree(this._root);

  /// Loads a decision tree from a JSON asset.
  static Future<DecisionTree> fromAsset(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final json = jsonDecode(jsonString);
    return DecisionTree(json);
  }

  // --------------------------------------------------------------------------
  // Binary probability (0 = benign, 1 = malicious)
  // --------------------------------------------------------------------------

  /// Predicts the probability of a URL being malicious (any threat type).
  /// Used by the hybrid engine for score fusion.
  double predictProbability(List<double> features) {
    final node = _traverseToLeaf(_root, features);
    if (node.containsKey('value')) {
      // Leaf stores binary probability directly
      return node['value'].toDouble();
    } else if (node.containsKey('distribution')) {
      // Leaf stores class distribution – sum probabilities of malicious classes
      final dist = List<double>.from(node['distribution']);
      // Assume classes: 0=benign, 1=defacement, 2=phishing, 3=malware
      return dist[1] + dist[2] + dist[3]; // any non‑benign
    } else if (node.containsKey('class')) {
      // Leaf stores majority class
      final cls = node['class'] as int;
      return cls == 0 ? 0.0 : 1.0;
    }
    return 0.5; // fallback
  }

  // --------------------------------------------------------------------------
  // Multi‑class prediction (detailed threat type)
  // --------------------------------------------------------------------------

  /// Returns a map with:
  ///   - 'class': predicted class index (0=benign,1=defacement,2=phishing,3=malware)
  ///   - 'confidence': confidence level (high/medium/low)
  ///   - 'probabilities': List<double> of class probabilities (if available)
  Map<String, dynamic> predictMultiClass(List<double> features) {
    final node = _traverseToLeaf(_root, features);

    // Default values
    int cls = 0;
    double confidenceVal = 0.0;
    List<double>? probs;

    if (node.containsKey('class')) {
      cls = node['class'] as int;
      confidenceVal = 1.0; // leaf with majority class – we can't know true confidence
    } else if (node.containsKey('distribution')) {
      probs = List<double>.from(node['distribution']);
      // Find class with highest probability
      cls = 0;
      double maxProb = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > maxProb) {
          maxProb = probs[i];
          cls = i;
        }
      }
      confidenceVal = maxProb;
    } else if (node.containsKey('value')) {
      // Legacy binary leaf – convert to multi‑class
      final prob = node['value'].toDouble();
      cls = prob > 0.5 ? 2 : 0; // map >0.5 to phishing as placeholder
      confidenceVal = prob > 0.5 ? prob : 1 - prob;
    }

    // Determine confidence string
    String confidence;
    if (confidenceVal > 0.8) {
      confidence = 'high';
    } else if (confidenceVal > 0.6) {
      confidence = 'medium';
    } else {
      confidence = 'low';
    }

    return {
      'class': cls,
      'confidence': confidence,
      'probabilities': probs ?? [0.0, 0.0, 0.0, 0.0], // fallback
    };
  }

  /// Convenience method that takes a UrlFeatures object (binary probability).
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

  // --------------------------------------------------------------------------
  // Tree traversal
  // --------------------------------------------------------------------------

  Map<String, dynamic> _traverseToLeaf(Map<String, dynamic> node, List<double> features) {
    // If it's a leaf (has 'value', 'distribution', or 'class'), return it
    if (node.containsKey('value') || node.containsKey('distribution') || node.containsKey('class')) {
      return node;
    }

    // Internal node: must have 'feature', 'threshold', 'left', 'right'
    final featureIndex = node['feature'] as int;
    final threshold = node['threshold'].toDouble();
    final left = node['left'] as Map<String, dynamic>;
    final right = node['right'] as Map<String, dynamic>;

    if (features[featureIndex] <= threshold) {
      return _traverseToLeaf(left, features);
    } else {
      return _traverseToLeaf(right, features);
    }
  }
}