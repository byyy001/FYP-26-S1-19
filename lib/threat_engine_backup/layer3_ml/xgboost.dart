// ============================================================================
// xgboost.dart – XGBoost Multi-class Classifier (FIXED VERSION)
// ============================================================================

import 'dart:convert';
import 'dart:math';

class XGBoostModel {
  final int numClass;
  final List<List<Map<String, dynamic>>> _classTrees;

  XGBoostModel._(this.numClass, this._classTrees);

  // ----------------------------------------------------------------------------
  // Load model from JSON
  // ----------------------------------------------------------------------------
  static XGBoostModel fromJson(String jsonString) {
    final Map<String, dynamic> root = jsonDecode(jsonString);

    final learner = root['learner'] as Map<String, dynamic>;
    final gradientBooster =
        learner['gradient_booster'] as Map<String, dynamic>;
    final model = gradientBooster['model'] as Map<String, dynamic>;

    final trees = model['trees'] as List<dynamic>;
    final treeInfo = model['tree_info'] as List<dynamic>;

    final learnerModelParam =
        learner['learner_model_param'] as Map<String, dynamic>;
    final numClass =
        int.parse(learnerModelParam['num_class'] ?? '4');

    // ✅ Correct way: group trees using tree_info
    final List<List<Map<String, dynamic>>> classTrees =
        List.generate(numClass, (_) => []);

    for (int i = 0; i < trees.length; i++) {
      final classId = treeInfo[i];
      classTrees[classId].add(
        (trees[i] as Map).cast<String, dynamic>(),
      );
    }

    return XGBoostModel._(numClass, classTrees);
  }

  // ----------------------------------------------------------------------------
  // Predict probabilities (softmax)
  // ----------------------------------------------------------------------------
  List<double> predictProbabilities(List<double> features) {
    final scores = List.filled(numClass, 0.0);

    for (int c = 0; c < numClass; c++) {
      double sum = 0.0;

      for (final tree in _classTrees[c]) {
        sum += _predictTree(tree, features);
      }

      scores[c] = sum;
    }

    // Softmax (numerically stable)
    final maxScore = scores.reduce(max);
    final expScores = scores.map((s) => exp(s - maxScore)).toList();
    final sumExp = expScores.reduce((a, b) => a + b);

    return expScores.map((e) => e / sumExp).toList();
  }

  // ----------------------------------------------------------------------------
  // Predict class
  // ----------------------------------------------------------------------------
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

  // ----------------------------------------------------------------------------
  // Predict single tree
  // ----------------------------------------------------------------------------
  double _predictTree(
      Map<String, dynamic> tree, List<double> features) {
    final splitIndices = tree['split_indices'];
    final splitConditions = tree['split_conditions'];
    final leftChildren = tree['left_children'];
    final rightChildren = tree['right_children'];
    final baseWeights = tree['base_weights'];

    // Validate structure
    if (splitIndices == null ||
        splitConditions == null ||
        leftChildren == null ||
        rightChildren == null ||
        baseWeights == null) {
      // Fallback
      return 0.0;
    }

    final splitIdxArr = (splitIndices as List).cast<num>();
    final splitCondArr = (splitConditions as List).cast<num>();
    final leftArr = (leftChildren as List).cast<num>();
    final rightArr = (rightChildren as List).cast<num>();
    final weightArr = (baseWeights as List).cast<num>();

    int nodeId = 0;

    while (true) {
      final left = leftArr[nodeId].toInt();
      final right = rightArr[nodeId].toInt();

      // ✅ Correct leaf detection
      if (left == -1 && right == -1) {
        return weightArr[nodeId].toDouble();
      }

      final splitIdx = splitIdxArr[nodeId].toInt();
      final splitVal = splitCondArr[nodeId].toDouble();

      // Safety check (prevents crashes)
      if (splitIdx >= features.length) {
        return 0.0;
      }

      if (features[splitIdx] <= splitVal) {
        nodeId = left;
      } else {
        nodeId = right;
      }
    }
  }
}