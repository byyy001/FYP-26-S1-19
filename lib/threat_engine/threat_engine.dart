// ============================================================================
// threat_engine.dart – Main Entry Point (Facade)
// ============================================================================
// This file provides a singleton instance of the threat engine.
// It loads the logistic regression model from assets and exposes a single
// `analyze(String url)` method that returns the complete analysis result.
// Use it anywhere in your Flutter app:
//   final engine = await ThreatEngine.getInstance();
//   final result = await engine.analyze('https://example.com');
// ============================================================================

import 'hybrid_engine.dart';
import 'logistic_regression.dart';

class ThreatEngine {
  static ThreatEngine? _instance;  // Singleton instance
  late HybridEngine _engine;       // Underlying analysis engine

  ThreatEngine._();  // Private constructor

  /// Returns the singleton instance of ThreatEngine.
  static Future<ThreatEngine> getInstance() async {
    if (_instance != null) return _instance!;

    // Load the ML model from asset (JSON weights)
    final ml = await LogisticRegression.fromAsset(
        'assets/models/logistic_regression_weights.json');

    final engine = ThreatEngine._();
    engine._engine = HybridEngine(ml);
    _instance = engine;
    return engine;
  }

  /// Performs threat analysis for the given URL.
  /// Wraps the synchronous HybridEngine call into a Future for async usage.
  Future<Map<String, dynamic>> analyze(String url) async {
    return _engine.analyze(url);  // Now safe to use `await`
  }
}