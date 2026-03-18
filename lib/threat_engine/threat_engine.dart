// ============================================================================
// threat_engine.dart – Main Entry Point (Facade) [Layer 5]
// ============================================================================
// This file acts as the main controller for the Threat Detection Engine.
//
// Responsibilities:
// - Initializes and holds all detection layers
// - Loads ML models (Logistic Regression for now)
// - Optionally loads Behavior Engine & Rule-Based AI Engine
// - Accepts user-defined scan settings
// - Orchestrates the full analysis pipeline
// - Returns final structured threat analysis results
//
// Usage:
//   final engine = await ThreatEngine.getInstance();
//   final result = await engine.analyze(
//     'https://example.com',
//     settings: ScanSettings.defaultSettings(),
//   );
//
// Design Notes:
// - Singleton pattern ensures only one engine instance exists
// - Designed to support multiple models and behavior analysis
// - Acts as a bridge between UI (Flutter) and detection layers
// ============================================================================

import 'hybrid_engine.dart';
import 'logistic_regression.dart';
import 'behavior_engine.dart';
import 'rule_based_ai_engine.dart';

/// Configuration model for scan settings (from UI)
class ScanSettings {
  final bool phishingSensitivity;
  final bool httpSitesWarning;
  final bool scriptAnalysis;
  final bool adReductionAnalysis;
  final int adDensityLevel;
  final bool autoRecheckScans;
  final bool sharingConfiguration;

  const ScanSettings({
    required this.phishingSensitivity,
    required this.httpSitesWarning,
    required this.scriptAnalysis,
    required this.adReductionAnalysis,
    required this.adDensityLevel,
    required this.autoRecheckScans,
    required this.sharingConfiguration,
  });

  /// Default settings (used if none provided)
  factory ScanSettings.defaultSettings() {
    return const ScanSettings(
      phishingSensitivity: true,
      httpSitesWarning: true,
      scriptAnalysis: true,
      adReductionAnalysis: true,
      adDensityLevel: 1,
      autoRecheckScans: true,
      sharingConfiguration: true,
    );
  }
}

class ThreatEngine {
  static ThreatEngine? _instance;   // Singleton instance
  late HybridEngine _engine;        // Core fusion engine

  ThreatEngine._(); // Private constructor

  /// Initializes and returns the singleton instance
  static Future<ThreatEngine> getInstance() async {
    if (_instance != null) return _instance!;

    // Load Logistic Regression model (Layer 3)
    final ml = await LogisticRegression.fromAsset(
      'assets/models/logistic_regression_weights.json',
    );

    // Optional: Initialize Behavior Engine
    final behavior = BehaviorEngine();

    // Optional: Initialize Rule-Based AI Engine
    final aiEngine = RuleBasedAIEngine();

    // Initialize Hybrid Engine (Fusion Layer)
    final engine = ThreatEngine._();
    engine._engine = HybridEngine(
      logisticModel: ml,
      behaviorEngine: behavior,
      aiEngine: aiEngine,
    );

    _instance = engine;
    return engine;
  }

  /// Main analysis function
  /// Accepts URL + optional user settings
  Future<Map<String, dynamic>> analyze(
    String url, {
    ScanSettings? settings,
  }) async {
    final config = settings ?? ScanSettings.defaultSettings();

    // Run analysis through hybrid engine
    final result = _engine.analyze(
      url,
      settings: config,
    );

    // Wrap with metadata (future-proofing)
    return {
      "url": url,
      "timestamp": DateTime.now().toIso8601String(),
      "scan_result": result,
    };
  }
}