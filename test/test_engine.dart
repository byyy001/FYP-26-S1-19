// test/test_threat_engine.dart
import '../lib/threat_engine/layer5_facade/threat_engine.dart';
import '../lib/threat_engine/scan_settings.dart';

void main() async {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║           WebLink Scanner – Threat Engine Test                  ║');
  print('║      Free vs Beginner vs Advanced (model selection)             ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  print('[1] Loading threat engine...');
  final engine = await ThreatEngine.getInstance();
  print('[✓] Engine loaded.\n');

  final testUrls = [
    'https://www.google.com',                       // safe, trusted
    'http://paypal-verify-account.tk/login',        // malicious (blacklist hit)
    'https://bit.ly/3xyz123',                       // URL shortener
    'http://192.168.1.1/admin',                     // IP address
    'https://apple-id-verify.xyz/reset',            // typosquatting
    'https://www.robiox.com.py/users/377059899225/profile' //openphish url
  ];

  final freeSettings = ScanSettings.defaultSettings();
  final beginnerSettings = ScanSettings.forBeginner();
  final advancedSettings = ScanSettings.forAdvanced();

  for (final url in testUrls) {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📎 URL: $url');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Free user
    print('\n🔓 FREE USER (unregistered)');
    print('─────────────────────────────────────────────────────────────────');
    final freeResult = await engine.analyze(url, settings: freeSettings);
    _printResult(freeResult['scan_result'], label: 'Free');

    // Beginner user
    print('\n👶 BEGINNER PREMIUM USER (ensemble, deepScan)');
    print('─────────────────────────────────────────────────────────────────');
    final beginnerResult = await engine.analyze(url, settings: beginnerSettings);
    _printResult(beginnerResult['scan_result'], label: 'Beginner');

    // Advanced user
    print('\n🧪 ADVANCED PREMIUM USER (individual models, deepScan)');
    print('─────────────────────────────────────────────────────────────────');
    final advancedResult = await engine.analyze(url, settings: advancedSettings);
    _printResult(advancedResult['scan_result'], label: 'Advanced');
  }

  print('\n✅ All scans completed.\n');
}

void _printResult(Map<String, dynamic> result, {required String label}) {
  print('  Risk score      : ${result['risk_score']}%');
  print('  Severity        : ${result['severity']}');
  print('  Threat type     : ${result['threat_type']}');
  print('  Explanation     : ${result['explanation']}');

  if (result['early_exit'] == true) {
    print('  ⚡ EARLY EXIT     : Yes – external blacklist hit, ML skipped.');
  } else {
    print('  ML confidence   : ${result['ml_confidence']}');
    if (result.containsKey('ml_score')) {
      print('  ML score        : ${result['ml_score']}');
    }
    if (result.containsKey('ai_score')) {
      print('  AI score        : ${result['ai_score']}');
    }
    print('  Behavior score  : ${result['behavior_score']}');
  }

  final externalScore = result['external_score'];
  final externalSources = result['external_sources'] as List?;
  if (externalSources != null && externalSources.isNotEmpty) {
    print('  External score  : $externalScore');
    print('  External sources: ${externalSources.join(', ')}');
  }

  final threats = result['detected_threats'];
  if (threats is List && threats.isNotEmpty) {
    print('  Detected threats:');
    for (final t in threats) {
      print('    • $t');
    }
  } else {
    print('  Detected threats: none');
  }

  final actions = result['actions'];
  if (actions is List && actions.isNotEmpty) {
    print('  Actions         : ${actions.join(' | ')}');
  }

  final safetyTips = result['safety_tips'];
  if (safetyTips is List && safetyTips.isNotEmpty) {
    print('  Safety tips:');
    for (final tip in safetyTips) {
      print('    • $tip');
    }
  }

  // ---------- ADVANCED TECHNICAL DETAILS ----------
  if (label == 'Advanced' && result.containsKey('individual_model_probabilities')) {
    print('  ┌───────────── ADVANCED TECHNICAL DETAILS ─────────────┐');

    final detailedStatic = result['detailed_detected_threats'];
    if (detailedStatic is List && detailedStatic.isNotEmpty) {
      print('  │ STATIC RULES FIRED:');
      for (final rule in detailedStatic) {
        final severity = rule['severity']?.toString().toUpperCase() ?? 'UNKNOWN';
        print('  │   • [$severity] ${rule['description']}');
      }
    } else {
      print('  │ STATIC RULES FIRED: none');
    }

    final behaviorPatterns = result['behavior_matched_patterns'];
    if (behaviorPatterns is List && behaviorPatterns.isNotEmpty) {
      print('  │ BEHAVIOR PATTERNS FOUND:');
      for (final pattern in behaviorPatterns) {
        print('  │   • $pattern');
      }
    } else {
      print('  │ BEHAVIOR PATTERNS FOUND: none');
    }

    final behaviorCategories = result['behavior_categories'];
    if (behaviorCategories is Map && behaviorCategories.containsKey('categories')) {
      final cats = behaviorCategories['categories'] as Map;
      print('  │ BEHAVIOR CATEGORIES:');
      cats.forEach((category, patternList) {
        final list = patternList as List;
        print('  │   $category: ${list.join(', ')}');
      });
      final summary = behaviorCategories['summary'] as Map;
      print('  │   Summary: total=${summary['total_patterns']}, categories=${summary['categories_count']}, severity=${summary['severity']}');
    }

    final probs = result['individual_model_probabilities'];
    if (probs is Map) {
      print('  │ INDIVIDUAL MODEL PROBABILITIES:');
      for (final entry in probs.entries) {
        final modelName = entry.key;
        final values = entry.value as List;
        final formatted = values.map((v) => (v as double).toStringAsFixed(3)).join(', ');
        print('  │   $modelName: [$formatted]');
      }
    }

    final ensemble = result['ensemble_probabilities'] as List;
    final ensembleFormatted = ensemble.map((v) => (v as double).toStringAsFixed(3)).join(', ');
    print('  │ Ensemble probabilities: [$ensembleFormatted]');

    print('  │ Model count   : ${result['model_count']}');
    print('  │ Static score  : ${result['static_score']}');
    print('  │ ML raw score  : ${result['ml_score_raw']}');

    final fusionWeights = result['fusion_weights'];
    if (fusionWeights is Map) {
      print('  │ Fusion weights:');
      fusionWeights.forEach((key, value) {
        final weight = (value as double).toStringAsFixed(3);
        print('  │   $key: $weight');
      });
    }

    // ==================== NEW: EXTERNAL API DETAILS ====================
    if (result.containsKey('external_details')) {
      final extDetails = result['external_details'] as Map<String, dynamic>;
      print('  │ EXTERNAL API DETAILS:');
      extDetails.forEach((source, data) {
        print('  │   $source: $data');
      });
    }
    // ================================================================

    print('  └────────────────────────────────────────────────────────┘');
  }

  if (label == 'Free' && result['early_exit'] == true) {
    print('  → Free user received simplified result (no ML).');
  } else if (label == 'Beginner') {
    print('  → Beginner: ensemble of all models, deepScan on.');
  } else if (label == 'Advanced') {
    print('  → Advanced: user-selected models (LR, DT, XGB), deepScan on.');
  }
}