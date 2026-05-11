// ============================================================================
// hybrid_engine.dart – Layer 4: Threat Scoring & Intelligent Fusion (Final)
// WITH DIRECT DYNAMIC CONFIG FETCH (FIXED BLACKLIST)
// FREE USER EARLY EXIT REMOVED – ALL SCANS RUN FULL ANALYSIS
// ============================================================================
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import '../layer1_feature_extraction/feature_extractor.dart';
import '../layer2_static_heuristics/static_rules.dart';
import '../layer3_ml/logistic_regression.dart';
import '../layer3_ml/decision_tree.dart';
import '../layer3_ml/xgboost.dart';
import '../layer3_ml/lightgbm.dart';
import '../utils/scaler.dart';
import 'behavior_engine.dart';
import 'rule_based_ai_engine.dart';
import '../scan_settings.dart';
import '../dynamic_config.dart';

class HybridEngine {
  final LogisticRegression logisticModel;
  final DecisionTree decisionTree;
  final XGBoostModel xgboost;
  final LightGBMModel? lightGBM;
  final BehaviorEngine? behaviorEngine;
  final RuleBasedAIEngine? aiEngine;
  final StandardScaler _scaler;

  static const List<String> _classNames = ['benign', 'defacement', 'phishing', 'malware'];

  HybridEngine({
    required this.logisticModel,
    required this.decisionTree,
    required this.xgboost,
    required StandardScaler scaler,
    this.lightGBM,
    this.behaviorEngine,
    this.aiEngine,
  }) : _scaler = scaler;

  Future<Map<String, dynamic>> analyze(
    String url, {
    required ScanSettings settings,
    required Map<String, dynamic> externalResult,
  }) async {
    // ----------------------------------------------------------------------
    // 1. LOAD DYNAMIC CONFIG (always fresh)
    // ----------------------------------------------------------------------
    final config = await DynamicConfig.getInstance();
    await config.refreshBlacklist();
    print("✅ Config loaded. Blacklist: ${config.globalBlacklist}");

    // ----------------------------------------------------------------------
    // 2. REDIRECT RESOLUTION — always runs, even on basic scans.
    // The resolved URL is what gets analysed so a shortener/redirect pointing
    // at a malicious page is not missed.
    // ----------------------------------------------------------------------
    final String effectiveUrl = await _quickResolveUrl(url, config);
    if (effectiveUrl != url) {
      print("↪️ Redirect resolved: $url → $effectiveUrl");
    }

    // ----------------------------------------------------------------------
    // 3. GLOBAL BLACKLIST / WHITELIST CHECKS (HIGHEST PRIORITY)
    // Checks both the original URL and the redirect destination.
    // ----------------------------------------------------------------------
    final features = UrlFeatures(effectiveUrl);
    final domain = features.domain;
    final blacklist = config.globalBlacklist;
    final whitelist = config.globalWhitelist;
    final originalDomain = effectiveUrl != url ? UrlFeatures(url).domain : domain;

    bool isBlacklisted = blacklist.contains(domain) ||
        blacklist.any((bl) => domain == bl || domain.endsWith('.$bl')) ||
        (originalDomain != domain &&
            (blacklist.contains(originalDomain) ||
                blacklist.any((bl) => originalDomain == bl || originalDomain.endsWith('.$bl'))));
    if (isBlacklisted) {
      print("🚫 BLACKLIST HIT: $domain is in global blacklist");
      return _buildBlacklistResult(url);
    }

    bool isWhitelisted = whitelist.contains(domain) ||
        whitelist.any((wl) => domain == wl || domain.endsWith('.$wl'));
    if (isWhitelisted) {
      print("✅ WHITELIST HIT: $domain is in global whitelist");
      return _buildWhitelistResult(url);
    }

    // ----------------------------------------------------------------------
    // 3. FREE USER EARLY EXIT – REMOVED
    // All URLs (including free users) now go through full analysis.
    // ----------------------------------------------------------------------

    // ----------------------------------------------------------------------
    // 4. STATIC RULE ENGINE
    // ----------------------------------------------------------------------
    final staticEngine = StaticRuleEngine(features, settings);
    if (await staticEngine.isTrustedDomain) {
      return _buildSafeResult(url);
    }

    // ----------------------------------------------------------------------
    // 5. REDIRECT CHAIN ANALYSIS (uses config.maxRedirectHops)
    // ----------------------------------------------------------------------
    Map<String, dynamic>? redirectResult;
    List<String> redirectChain = [];
    String finalUrl = url;
    bool redirectMalicious = false;
    String redirectThreatDesc = '';

    if (settings.deepScan) {
      redirectResult = await _analyzeRedirectChain(url, settings, config);
      redirectChain = List<String>.from(redirectResult['chain'] ?? []);
      finalUrl = redirectResult['final_url'] ?? url;
      redirectMalicious = redirectResult['is_malicious'] ?? false;
      redirectThreatDesc = redirectResult['threat_description'] ?? '';

      if (redirectMalicious) {
        if ((externalResult['score'] as double? ?? 0.0) < 0.8) {
          externalResult['score'] = 0.8;
          externalResult['is_malicious'] = true;
          if (!(externalResult['sources'] as List).contains('RedirectChain')) {
            (externalResult['sources'] as List).add('RedirectChain');
          }
        }
      }
    }

    final rawVector = features.toFeatureVector();
    final scaledVector = _scaler.transform(rawVector);

    List<Map<String, dynamic>> staticThreats = await staticEngine.analyzeSync();

    if (redirectMalicious && redirectThreatDesc.isNotEmpty) {
      staticThreats.add({
        'type': 'malicious_redirect',
        'severity': 'high',
        'description': redirectThreatDesc,
        'score': 0.9,
      });
    }

    // Use dynamic new domain threshold
    final newDomainThreshold = config.newDomainDaysThreshold;
    if (externalResult.containsKey('details')) {
      final details = externalResult['details'] as Map<String, dynamic>;
      if (details.containsKey('whois')) {
        final whois = details['whois'] as Map<String, dynamic>;
        final ageDays = whois['age_days'];
        if (ageDays != null && ageDays is int && ageDays < newDomainThreshold) {
          staticThreats.add({
            'type': 'new_domain',
            'severity': 'medium',
            'description': 'Domain registered less than $newDomainThreshold days ago ($ageDays days). New domains are often used for phishing or malware.',
            'score': 0.7,
          });
        }
      }
    }

    final externalScoreRaw = (externalResult['score'] as double?) ?? 0.0;
    final externalSourcesRaw = externalResult['sources'] as List? ?? [];
    final List<String> externalSourcesList = externalSourcesRaw.cast<String>();

    if (staticThreats.isEmpty && externalScoreRaw >= 0.5) {
      staticThreats.add({
        'type': 'external_flag',
        'severity': externalScoreRaw >= 0.8 ? 'high' : 'medium',
        'description': 'Flagged by external threat intelligence: ${externalSourcesList.join(', ')} (score: ${(externalScoreRaw * 100).toStringAsFixed(0)}%)',
        'score': externalScoreRaw,
      });
    }

    final staticScore = _computeStaticScore(staticThreats);

    // ---- ML predictions ----
    List<double> lrProbs = [0.25, 0.25, 0.25, 0.25];
    List<double> dtProbs = [0.25, 0.25, 0.25, 0.25];
    List<double> xgbProbs = [0.25, 0.25, 0.25, 0.25];
    List<double> lgbProbs = [0.25, 0.25, 0.25, 0.25];
    bool lgbUsed = false;
    List<double> ensembleProbs = List.filled(4, 0.0);
    int modelCount = 0;
    bool mlUsed = false;

    if (settings.enableMachineLearning) {
      mlUsed = true;
      lrProbs = _safePredict(() => logisticModel.predictProbabilities(rawVector));
      dtProbs = _safePredict(() {
        final res = decisionTree.predictMultiClass(rawVector);
        return (res['probabilities'] as List).cast<double>();
      });
      xgbProbs = _safePredict(() => xgboost.predictProbabilities(scaledVector));
      if (lightGBM != null && settings.useLightGBM) {
        lgbProbs = _safePredict(() => lightGBM!.predictProbabilities(rawVector));
        lgbUsed = true;
      }

      if (settings.useEnsemble) {
        for (int i = 0; i < 4; i++) {
          ensembleProbs[i] = lrProbs[i] + dtProbs[i] + xgbProbs[i];
        }
        modelCount = 3;
        if (lgbUsed) {
          for (int i = 0; i < 4; i++) {
            ensembleProbs[i] += lgbProbs[i];
          }
          modelCount++;
        }
        for (int i = 0; i < 4; i++) {
          ensembleProbs[i] /= modelCount;
        }
      } else {
        modelCount = 0;
        if (settings.useLogisticRegression) {
          for (int i = 0; i < 4; i++) {
            ensembleProbs[i] += lrProbs[i];
          }
          modelCount++;
        }
        if (settings.useDecisionTree) {
          for (int i = 0; i < 4; i++) {
            ensembleProbs[i] += dtProbs[i];
          }
          modelCount++;
        }
        if (settings.useXGBoost) {
          for (int i = 0; i < 4; i++) {
            ensembleProbs[i] += xgbProbs[i];
          }
          modelCount++;
        }
        if (lgbUsed && settings.useLightGBM) {
          for (int i = 0; i < 4; i++) {
            ensembleProbs[i] += lgbProbs[i];
          }
          modelCount++;
        }
        if (modelCount > 0) {
          for (int i = 0; i < 4; i++) {
            ensembleProbs[i] /= modelCount;
          }
        } else {
          ensembleProbs = xgbProbs;
          modelCount = 1;
        }
      }
    } else {
      ensembleProbs = [0.25, 0.25, 0.25, 0.25];
      modelCount = 0;
    }

    final maxProb = ensembleProbs.reduce(math.max);
    final fusedClass = ensembleProbs.indexOf(maxProb);
    const double confidenceThreshold = 0.85;
    final lowConfidence = maxProb < confidenceThreshold;
    final adjustedClass = fusedClass;
    double mlScore = maxProb;
    String threatType = _classNames[adjustedClass];
    String mlConfidence = (!mlUsed || lowConfidence)
        ? 'low'
        : (mlScore >= 0.9 ? 'high' : 'medium');

    // Ambiguity penalty
    final sortedProbs = List<double>.from(ensembleProbs)..sort((a,b) => b.compareTo(a));
    if (sortedProbs.length >= 2 && (sortedProbs[0] - sortedProbs[1]) < 0.2) {
      mlScore *= 0.7;
      mlConfidence = 'low';
    }

    // Behavior & AI
    double behaviorScore = 0.0;
    double aiScore = 0.0;
    double adDensity = 0.0;
    List<String> behaviorPatterns = [];

    if (settings.deepScan && settings.scriptAnalysis) {
      final detailed = await behaviorEngine?.analyzeDetailed(
        effectiveUrl,
        features,
        externalThreatData: externalResult,
      ) ?? {'behaviorScore': 0.0, 'adDensity': 0.0, 'matchedPatterns': []};
      behaviorScore = detailed['behaviorScore']!;
      adDensity = detailed['adDensity']!;
      behaviorPatterns = List<String>.from(detailed['matchedPatterns'] as List? ?? []);
      aiScore = aiEngine?.analyze(features) ?? 0.0;
    }

    final externalScore = externalScoreRaw;

    double hybridScore = _fuseScores(
      staticScore: staticScore,
      mlScore: mlScore,
      behaviorScore: behaviorScore,
      aiScore: aiScore,
      externalScore: externalScore,
      settings: settings,
      mlConfidence: mlConfidence,
    );

    // Domain age adjustment
    final whoisDetails = externalResult['details']?['whois'] as Map<String, dynamic>?;
    if (whoisDetails != null && whoisDetails['age_days'] != null) {
      final ageDays = whoisDetails['age_days'] as int;
      if (ageDays < 7) {
        hybridScore = (hybridScore + 10).clamp(0, 100);
      } else if (ageDays > 365) {
        hybridScore = (hybridScore - 5).clamp(0, 100);
      }
    }

    if (adjustedClass == 2 && mlConfidence == 'high') {
      hybridScore = math.max(hybridScore, 80.0);
      if (mlScore > 0.98) hybridScore = math.min(100, hybridScore + 15);
    }

    // External override (continuous boost)
    if (externalScore >= 0.8) {
      double boost = (externalScore - 0.8) * 100;
      hybridScore = hybridScore + boost;
      hybridScore = hybridScore.clamp(0, 100);
      if (externalSourcesList.contains('VirusTotal') ||
          externalSourcesList.contains('OpenPhish') ||
          externalSourcesList.contains('IPQualityScore')) {
        threatType = 'malicious';
      }
      mlConfidence = 'low';
    }

    // 50% cap when no external evidence
    if (externalScore == 0.0 && hybridScore > 50.0) {
      hybridScore = 50.0;
      if (threatType != 'benign') {
        threatType = 'suspicious';
      }
      mlConfidence = 'low';
    }

    // Safety override
    if (hybridScore < 25.0 && externalScore < 0.5) {
      threatType = 'benign';
    }

    final severity = _getSeverity(hybridScore);

    final explanation = _generateExplanation(
      threatType,
      staticThreats,
      mlConfidence,
      behaviorScore,
      aiScore,
      externalScore,
      mlUsed,
    );

    final actionsAndTips = _getDynamicActionsAndTips(
      threatType: threatType,
      mlConfidence: mlConfidence,
      externalScore: externalScore,
      staticThreats: staticThreats,
      behaviorPatterns: behaviorPatterns,
      riskScore: hybridScore,
      externalSources: externalSourcesList,
    );

    Map<String, dynamic> result = {
      'url': url,
      'scan_date': DateTime.now().toIso8601String(),
      'risk_score': hybridScore.toStringAsFixed(1),
      'severity': severity,
      'threat_type': threatType,
      'explanation': explanation,
      'detected_threats': staticThreats.map((t) => t['description']).toList(),
      'ml_confidence': mlConfidence,
      'ml_score': mlScore.toStringAsFixed(4),
      'ai_score': aiScore.toStringAsFixed(2),
      'behavior_score': behaviorScore.toStringAsFixed(2),
      'ad_density': adDensity.toStringAsFixed(2),
      'external_score': externalScore.toStringAsFixed(2),
      'external_sources': externalSourcesList,
      'actions': actionsAndTips['actions'],
      'safety_tips': actionsAndTips['safetyTips'],
    };

    if (settings.userLevel == 'beginner') {
      result['guidance'] = _getBeginnerGuidance(threatType, severity, mlConfidence);
      result['confidence_description'] = _confidenceDescription(mlConfidence);
    }

    if (settings.userLevel == 'advanced') {
      result['detailed_detected_threats'] = staticThreats;
      result['behavior_matched_patterns'] = behaviorPatterns;
      result['behavior_categories'] = _categorizeBehaviorPatterns(behaviorPatterns);
      result['individual_model_probabilities'] = {
        'logistic_regression': lrProbs,
        'decision_tree': dtProbs,
        'xgboost': xgbProbs,
        if (lgbUsed) 'lightgbm': lgbProbs,
      };
      result['ensemble_probabilities'] = ensembleProbs;
      result['model_count'] = modelCount;
      result['raw_feature_vector'] = rawVector;
      result['static_score'] = staticScore;
      result['ml_score_raw'] = mlScore;
      result['fusion_weights'] = _getFusionWeights(settings, mlConfidence, externalScore);
      result['external_details'] = externalResult['details'];
      if (redirectChain.isNotEmpty) {
        result['redirect_chain'] = redirectChain;
        result['final_url_after_redirect'] = finalUrl;
      }
    }

    return result;
  }

  // --------------------------------------------------------------------------
  // Quick redirect resolution — follows up to 3 hops, always runs.
  // Uses followRedirects=false so we control each hop manually.
  // --------------------------------------------------------------------------
  Future<String> _quickResolveUrl(String url, DynamicConfig config) async {
    String current = url;
    final maxHops = math.min(config.maxRedirectHops, 3);
    try {
      final client = http.Client();
      for (int i = 0; i < maxHops; i++) {
        final req = http.Request('GET', Uri.parse(current));
        req.followRedirects = false;
        final response = await client.send(req).timeout(const Duration(seconds: 3));
        await response.stream.drain();
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers['location'];
          if (location == null) break;
          final next = Uri.parse(current).resolve(location).toString();
          if (next == current) break;
          current = next;
        } else {
          break;
        }
      }
      client.close();
    } catch (_) {}
    return current;
  }

  // --------------------------------------------------------------------------
  // Redirect chain analysis (uses config)
  // --------------------------------------------------------------------------
  Future<Map<String, dynamic>> _analyzeRedirectChain(
    String startUrl,
    ScanSettings settings,
    DynamicConfig config,
  ) async {
    final maxHops = config.maxRedirectHops;
    List<String> chain = [startUrl];
    String currentUrl = startUrl;
    bool isMalicious = false;
    String threatDescription = '';

    try {
      final client = http.Client();
      for (int i = 0; i < maxHops; i++) {
        final req = http.Request('GET', Uri.parse(currentUrl));
        req.followRedirects = false;
        final response = await client.send(req).timeout(const Duration(seconds: 5));
        await response.stream.drain();
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers['location'];
          if (location == null) break;
          final nextUrl = Uri.parse(currentUrl).resolve(location).toString();
          if (chain.contains(nextUrl)) break;
          chain.add(nextUrl);
          currentUrl = nextUrl;
        } else {
          break;
        }
      }
      client.close();

      final finalUrl = currentUrl;
      final finalFeatures = UrlFeatures(finalUrl);
      final staticEngine = StaticRuleEngine(finalFeatures, settings);

      if (await staticEngine.isTrustedDomain) {
        isMalicious = false;
        threatDescription = '';
      } else {
        final finalThreats = await staticEngine.analyzeSync();
        if (finalThreats.isNotEmpty) {
          isMalicious = true;
          threatDescription = 'Redirects to suspicious URL: $finalUrl. Issues: ${finalThreats.map((t) => t['description']).join('; ')}';
        } else {
          isMalicious = false;
        }
      }

      return {
        'chain': chain,
        'final_url': finalUrl,
        'is_malicious': isMalicious,
        'threat_description': threatDescription,
      };
    } catch (e) {
      return {
        'chain': [startUrl],
        'final_url': startUrl,
        'is_malicious': false,
        'threat_description': '',
      };
    }
  }

  // --------------------------------------------------------------------------
  // GLOBAL BLACKLIST RESULT
  // --------------------------------------------------------------------------
  Map<String, dynamic> _buildBlacklistResult(String url) {
    return {
      'url': url,
      'scan_date': DateTime.now().toIso8601String(),
      'risk_score': '100.0',
      'severity': 'HIGH RISK',
      'threat_type': 'malicious',
      'explanation': 'This domain is globally blacklisted by administrator.',
      'detected_threats': ['Domain is in global blacklist'],
      'ml_confidence': 'none',
      'ml_score': '0.0000',
      'ai_score': '0.00',
      'behavior_score': '0.00',
      'ad_density': '0.00',
      'external_score': '0.00',
      'external_sources': [],
      'actions': ['Do not proceed', 'Close immediately', 'Report URL'],
      'safety_tips': ['This domain has been manually blacklisted by the system administrator.'],
    };
  }

  // --------------------------------------------------------------------------
  // GLOBAL WHITELIST RESULT
  // --------------------------------------------------------------------------
  Map<String, dynamic> _buildWhitelistResult(String url) {
    return {
      'url': url,
      'scan_date': DateTime.now().toIso8601String(),
      'risk_score': '0.0',
      'severity': 'SAFE',
      'threat_type': 'benign',
      'explanation': 'This domain is globally whitelisted and considered safe.',
      'detected_threats': [],
      'ml_confidence': 'none',
      'ml_score': '0.0000',
      'ai_score': '0.00',
      'behavior_score': '0.00',
      'ad_density': '0.00',
      'external_score': '0.00',
      'external_sources': [],
      'actions': ['Safe to use'],
      'safety_tips': ['Always keep your browser and antivirus updated.'],
    };
  }

  // --------------------------------------------------------------------------
  // Safe result for whitelisted domains (fallback)
  // --------------------------------------------------------------------------
  Map<String, dynamic> _buildSafeResult(String url) {
    return {
      'url': url,
      'scan_date': DateTime.now().toIso8601String(),
      'risk_score': '0.0',
      'severity': 'SAFE',
      'threat_type': 'benign',
      'explanation': 'This domain is trusted and considered safe.',
      'detected_threats': [],
      'ml_confidence': 'none',
      'ml_score': '0.0000',
      'ai_score': '0.00',
      'behavior_score': '0.00',
      'ad_density': '0.00',
      'external_score': '0.00',
      'external_sources': [],
      'actions': ['Safe to use'],
      'safety_tips': ['Always keep your browser and antivirus updated.'],
    };
  }

  // --------------------------------------------------------------------------
  // Free user early exit – no longer used, kept only as a helper
  // --------------------------------------------------------------------------
  Map<String, dynamic> _buildFreeEarlyExit(String url, Map<String, dynamic> external) {
    final score = (external['score'] as double? ?? 0.0) * 100;
    final severity = _getSeverity(score);
    return {
      'url': url,
      'scan_date': DateTime.now().toIso8601String(),
      'risk_score': score.toStringAsFixed(1),
      'severity': severity,
      'threat_type': 'malicious',
      'explanation': 'Flagged by external security sources: ${(external['sources'] as List).join(', ')}. No further analysis performed.',
      'detected_threats': [],
      'actions': _actions(score),
      'early_exit': true,
    };
  }

  // --------------------------------------------------------------------------
  // Beginner guidance helpers
  // --------------------------------------------------------------------------
  String _getBeginnerGuidance(String threatType, String severity, String mlConfidence) {
    if (threatType == 'benign') return 'This link appears safe to open.';
    if (severity == 'HIGH RISK') return 'Do not proceed! This link is very likely dangerous.';
    if (severity == 'MEDIUM RISK') return 'Be cautious. Only visit if you are absolutely sure.';
    return 'Exercise care. Avoid entering personal information.';
  }

  String _confidenceDescription(String conf) {
    if (conf == 'high') return 'We are very confident in this result.';
    if (conf == 'medium') return 'We are moderately confident. Some uncertainty remains.';
    return 'Low confidence – consider manual verification.';
  }

  Map<String, double> _getFusionWeights(ScanSettings s, String mlConf, double extScore) {
    double staticW = s.phishingSensitivity ? 0.35 : 0.25;
    double mlW = mlConf == 'high' ? 0.3 : (mlConf == 'medium' ? 0.2 : 0.1);
    double behaviorW = s.deepScan ? 0.2 : 0.0;
    double aiW = s.deepScan ? 0.1 : 0.0;
    double extW = 0.0;
    if (extScore > 0.8) extW = 0.5;
    else if (extScore > 0) extW = 0.3;
    final total = staticW + mlW + behaviorW + aiW + extW;
    return {
      'static': staticW / total,
      'ml': mlW / total,
      'behavior': behaviorW / total,
      'ai': aiW / total,
      'external': extW / total,
    };
  }

  List<double> _safePredict(List<double> Function() fn) {
    try {
      final res = fn();
      if (res.length != 4) throw Exception("Invalid output");
      return res;
    } catch (_) {
      return [0.25, 0.25, 0.25, 0.25];
    }
  }

  double _computeStaticScore(List<Map<String, dynamic>> threats) {
    double score = 0;
    for (final t in threats) {
      switch (t['severity']) {
        case 'high':
          score += 30;
          break;
        case 'medium':
          score += 15;
          break;
        case 'low':
          score += 8;
          break;
      }
    }
    return score.clamp(0, 100).toDouble();
  }

  double _fuseScores({
    required double staticScore,
    required double mlScore,
    required double behaviorScore,
    required double aiScore,
    required double externalScore,
    required ScanSettings settings,
    required String mlConfidence,
  }) {
    double staticWeight = settings.phishingSensitivity ? 0.35 : 0.25;
    double mlWeight = mlConfidence == 'high' ? 0.3 : (mlConfidence == 'medium' ? 0.2 : 0.0);
    double behaviorWeight = settings.deepScan ? 0.2 : 0.0;
    double aiWeight = settings.deepScan ? 0.1 : 0.0;
    double externalWeight = 0.0;
    if (externalScore > 0.8) externalWeight = 0.5;
    else if (externalScore > 0) externalWeight = 0.3;
    final total = staticWeight + mlWeight + behaviorWeight + aiWeight + externalWeight;
    double adjStatic = staticWeight / total;
    double adjMl = mlWeight / total;
    double adjBehavior = behaviorWeight / total;
    double adjAi = aiWeight / total;
    double adjExternal = externalWeight / total;
    double adjustedMlScore = mlScore;
    if (mlConfidence == 'low') adjustedMlScore *= 0.5;
    if (mlConfidence == 'none') adjustedMlScore = 0.0;
    return (staticScore * adjStatic +
            adjustedMlScore * 100 * adjMl +
            behaviorScore * 100 * adjBehavior +
            aiScore * 100 * adjAi +
            externalScore * 100 * adjExternal)
        .clamp(0, 100)
        .toDouble();
  }

  String _generateExplanation(
    String threatType,
    List<Map<String, dynamic>> threats,
    String mlConfidence,
    double behaviorScore,
    double aiScore,
    double externalScore,
    bool mlUsed,
  ) {
    final buffer = StringBuffer();
    if (threatType == 'benign') {
      buffer.write('This URL appears safe. ');
    } else {
      buffer.write('This URL is classified as $threatType. ');
    }
    if (threats.isNotEmpty) {
      buffer.write('Detected issues: ${threats.map((t) => t['description']).join('; ')}. ');
    }
    if (mlUsed && mlConfidence == 'high') {
      buffer.write('Machine learning analysis strongly indicates $threatType patterns. ');
    } else if (mlUsed && mlConfidence == 'medium') {
      buffer.write('Machine learning analysis suggests $threatType patterns with moderate confidence. ');
    } else if (!mlUsed) {
      buffer.write('Machine learning was disabled for this scan. ');
    }
    if (behaviorScore > 0.5) buffer.write('Suspicious script behaviors observed. ');
    if (aiScore > 0.5) buffer.write('Advanced AI analysis confirms suspicious patterns. ');
    if (externalScore > 0.5) buffer.write('Verified by external threat intelligence sources. ');
    if (threatType == 'benign' && threats.isEmpty && mlConfidence == 'none' && externalScore == 0) {
      buffer.write('No threats detected.');
    }
    return buffer.toString().trim();
  }

  String _getSeverity(double score) {
    if (score >= 75) return 'HIGH RISK';
    if (score >= 50) return 'MEDIUM RISK';
    if (score >= 25) return 'LOW RISK';
    return 'SAFE';
  }

  List<String> _actions(double score) {
    if (score >= 75) return ['Do not proceed', 'Close immediately', 'Report URL'];
    if (score >= 50) return ['Avoid sensitive actions', 'Verify manually'];
    if (score >= 25) return ['Proceed with caution'];
    return ['Safe to use'];
  }

  // --------------------------------------------------------------------------
  // Dynamic actions and safety tips
  // --------------------------------------------------------------------------
  Map<String, dynamic> _getDynamicActionsAndTips({
    required String threatType,
    required String mlConfidence,
    required double externalScore,
    required List<Map<String, dynamic>> staticThreats,
    required List<String> behaviorPatterns,
    required double riskScore,
    required List<String> externalSources,
  }) {
    List<String> actions = [];
    List<String> safetyTips = [];

    switch (threatType) {
      case 'benign':
        actions.add('Safe to use – no immediate threats detected');
        safetyTips.add('• Keep your browser and antivirus updated.');
        safetyTips.add('• Always double-check URLs before entering personal information.');
        break;
      case 'phishing':
        actions.addAll([
          'Do NOT enter any password, credit card, or personal information',
          'Close this page immediately',
          'Report this URL to Google Safe Browsing or OpenPhish',
        ]);
        safetyTips.addAll([
          '• Phishing sites impersonate legitimate companies to steal your login credentials and financial data.',
          '• Legitimate companies never ask for sensitive information via random links – always go directly to their official website.',
          '• Enable two-factor authentication (2FA) on important accounts for extra security.',
        ]);
        break;
      case 'malware':
      case 'malicious':
        actions.addAll([
          'Do NOT download any files from this site',
          'Do NOT run any scripts or allow browser notifications',
          'Close this page and run a full antivirus / anti-malware scan on your device',
        ]);
        safetyTips.addAll([
          '• Malware can steal your files, encrypt data (ransomware), or use your device for attacks.',
          '• Keep your operating system and all software up to date to patch security vulnerabilities.',
          '• Use an ad blocker and avoid clicking on pop-ups or "allow notifications" prompts.',
        ]);
        break;
      case 'defacement':
        actions.addAll([
          'The website may have been hacked – avoid interacting with the page',
          'Do not click any links or buttons on this site',
        ]);
        safetyTips.addAll([
          '• Defaced websites often contain hidden malicious redirects or drive-by downloads.',
          '• Wait for the site owner to restore the original content before visiting again.',
        ]);
        break;
      default:
        if (riskScore < 50) {
          actions.add('Proceed with caution – low risk, but stay alert');
        } else {
          actions.add('Exercise caution – the link shows suspicious signs');
        }
        safetyTips.add('• If unsure, manually verify the URL by typing it into a search engine to find the official site.');
    }

    if (mlConfidence == 'high' && threatType != 'benign') {
      actions.add('High confidence threat – take immediate action');
    } else if (mlConfidence == 'medium' && threatType != 'benign') {
      actions.add('Moderate confidence – consider manual verification');
    }

    if (externalScore >= 0.8) {
      actions.add('Verified by multiple threat intelligence sources');
      safetyTips.add('External security vendors have flagged this URL as dangerous.');
      if (externalSources.contains('VirusTotal')) {
        safetyTips.add('• VirusTotal: multiple antivirus engines detected malware or phishing.');
      }
      if (externalSources.contains('OpenPhish')) {
        safetyTips.add('• OpenPhish: this URL appears in a live phishing feed.');
      }
      if (externalSources.contains('IPQualityScore')) {
        safetyTips.add('• IPQualityScore: the domain has a very high risk score.');
      }
    }

    for (final threat in staticThreats) {
      final desc = threat['description'] as String;
      if (desc.contains('shortening service')) {
        actions.add('Expand the URL before visiting (use a link expander like CheckShortURL)');
        safetyTips.add('• Shortened URLs hide the real destination – always check where they lead before clicking.');
      }
      if (desc.contains('phishing terms')) {
        safetyTips.add('• The URL contains words like "verify", "secure", or "account" – commonly used in phishing attacks.');
      }
      if (desc.contains('typosquatting')) {
        actions.add('Double-check the domain name for misspellings (e.g., "paypal" vs "paypa1")');
        safetyTips.add('• Attackers register domains that look similar to popular brands to trick you.');
      }
      if (desc.contains('suspicious TLD')) {
        safetyTips.add('• Unusual top-level domains (e.g., .tk, .xyz, .top) are often abused for scams because they are cheap and anonymous.');
      }
      if (desc.contains('new domain') || desc.contains('registered less than')) {
        safetyTips.add('• Very new domains (less than 30 days old) are frequently used for fraudulent activity – be extra cautious.');
      }
      if (desc.contains('external threat intelligence')) {
        safetyTips.add('• External security services have flagged this URL as dangerous – do not proceed.');
      }
    }

    if (behaviorPatterns.isNotEmpty) {
      if (behaviorPatterns.contains('eval() call') ||
          behaviorPatterns.contains('atob / btoa encoding') ||
          behaviorPatterns.contains('String.fromCharCode')) {
        safetyTips.add('• Obfuscated JavaScript detected – the page may be hiding malicious code.');
      }
      if (behaviorPatterns.contains('window.location redirect') ||
          behaviorPatterns.contains('location.href/replace')) {
        actions.add('Check where the page redirects before proceeding');
        safetyTips.add('• Automatic redirects can lead to phishing or malware sites – be cautious.');
      }
      if (behaviorPatterns.contains('javascript: URI')) {
        actions.add('Do not click any "javascript:" links');
        safetyTips.add('• These can execute arbitrary code in your browser.');
      }
    }

    if (riskScore >= 75) {
      actions.add('🔴 High risk – do not proceed under any circumstances');
    } else if (riskScore >= 50) {
      actions.add('🟠 Medium risk – avoid entering personal information');
    } else if (riskScore >= 25) {
      actions.add('🟡 Low risk – proceed with caution, but avoid sensitive actions');
    } else {
      actions.add('🟢 Safe – no significant threats detected');
    }

    actions = actions.toSet().toList();
    safetyTips = safetyTips.toSet().toList();

    return {
      'actions': actions,
      'safetyTips': safetyTips,
    };
  }

  // --------------------------------------------------------------------------
  // Behavior pattern categorization
  // --------------------------------------------------------------------------
  Map<String, dynamic> _categorizeBehaviorPatterns(List<String> patterns) {
    final Map<String, List<String>> categories = {
      'Obfuscation': [],
      'Redirects': [],
      'Suspicious API Usage': [],
      'Encoding/Evasion': [],
      'Inline Events': [],
    };

    for (final pattern in patterns) {
      if (pattern.contains('eval') || pattern.contains('new Function') ||
          pattern.contains('fromCharCode')) {
        categories['Obfuscation']!.add(pattern);
      } else if (pattern.contains('redirect') || pattern.contains('location.href') ||
                 pattern.contains('javascript: URI') || pattern.contains('Meta refresh')) {
        categories['Redirects']!.add(pattern);
      } else if (pattern.contains('document.write') || pattern.contains('setTimeout') ||
                 pattern.contains('setInterval')) {
        categories['Suspicious API Usage']!.add(pattern);
      } else if (pattern.contains('hex') || pattern.contains('unicode') ||
                 pattern.contains('atob') || pattern.contains('btoa')) {
        categories['Encoding/Evasion']!.add(pattern);
      } else if (pattern.contains('inline event')) {
        categories['Inline Events']!.add(pattern);
      } else {
        if (!categories.containsKey('Other')) categories['Other'] = [];
        categories['Other']!.add(pattern);
      }
    }

    categories.removeWhere((key, value) => value.isEmpty);

    String overallSeverity = 'LOW';
    if (categories.containsKey('Obfuscation') || categories.containsKey('Redirects')) {
      overallSeverity = 'MEDIUM';
    }
    if (categories.containsKey('Encoding/Evasion') && categories['Encoding/Evasion']!.length > 2) {
      overallSeverity = 'HIGH';
    }

    return {
      'categories': categories,
      'summary': {
        'total_patterns': patterns.length,
        'categories_count': categories.length,
        'severity': overallSeverity,
      },
    };
  }
}