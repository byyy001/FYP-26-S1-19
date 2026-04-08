// ============================================================================
// scan_settings.dart – Scan Configuration Object
// ============================================================================
class ScanSettings {
  // Core scanning options
  final bool phishingSensitivity;
  final bool httpSitesWarning;
  final bool scriptAnalysis;
  final bool adReductionAnalysis;
  final int adDensityLevel;
  final bool autoRecheckScans;
  final bool sharingConfiguration;
  final bool useExternalApis;
  final bool isPremium;

  // API keys (used by StaticRuleEngine)
  final String? googleSafeBrowsingKey;
  final String? virusTotalKey;

  // ===== NEW: User level and model selection =====
  final String userLevel; // 'free', 'beginner', 'advanced'
  
  // Master ML switch
  final bool enableMachineLearning;
  
  // Model selection (only used if enableMachineLearning == true)
  final bool useEnsemble;          // if true, runs all available models and averages
  final bool useLogisticRegression;
  final bool useDecisionTree;
  final bool useXGBoost;
  final bool useLightGBM;          // for future use
  
  // Additional feature toggles
  final bool deepScan;             // script-level inspection (eval, redirects, etc.)
  final bool adFilter;             // ad-intensity reduction

  const ScanSettings({
    required this.phishingSensitivity,
    required this.httpSitesWarning,
    required this.scriptAnalysis,
    required this.adReductionAnalysis,
    required this.adDensityLevel,
    required this.autoRecheckScans,
    required this.sharingConfiguration,
    this.useExternalApis = false,
    this.isPremium = false,
    this.googleSafeBrowsingKey,
    this.virusTotalKey,
    // New fields with defaults
    this.userLevel = 'free',
    this.enableMachineLearning = true,
    this.useEnsemble = true,
    this.useLogisticRegression = false,
    this.useDecisionTree = false,
    this.useXGBoost = false,
    this.useLightGBM = false,
    this.deepScan = false,
    this.adFilter = false,
  });

  /// Default settings (free user)
  factory ScanSettings.defaultSettings() {
    return const ScanSettings(
      phishingSensitivity: true,
      httpSitesWarning: true,
      scriptAnalysis: true,
      adReductionAnalysis: true,
      adDensityLevel: 1,
      autoRecheckScans: true,
      sharingConfiguration: true,
      useExternalApis: true,
      isPremium: false,
      googleSafeBrowsingKey: null,
      virusTotalKey: null,
      userLevel: 'free',
      enableMachineLearning: true,
      useEnsemble: true,
      useLogisticRegression: false,
      useDecisionTree: false,
      useXGBoost: false,
      useLightGBM: false,
      deepScan: false,
      adFilter: false,
    );
  }

  /// Preset for beginner (non-technical) registered users
  factory ScanSettings.forBeginner() {
    return const ScanSettings(
      phishingSensitivity: true,
      httpSitesWarning: true,
      scriptAnalysis: true,
      adReductionAnalysis: true,
      adDensityLevel: 1,
      autoRecheckScans: true,
      sharingConfiguration: true,
      useExternalApis: true,
      isPremium: true,
      userLevel: 'beginner',
      enableMachineLearning: true,
      useEnsemble: true,              // use all models (ensemble)
      useLogisticRegression: false,
      useDecisionTree: false,
      useXGBoost: false,
      useLightGBM: false,
      deepScan: true,                 // script analysis on
      adFilter: false,
    );
  }

  /// Preset for advanced (technical) registered users – allows model selection
  factory ScanSettings.forAdvanced() {
    return const ScanSettings(
      phishingSensitivity: true,
      httpSitesWarning: true,
      scriptAnalysis: true,
      adReductionAnalysis: true,
      adDensityLevel: 1,
      autoRecheckScans: true,
      sharingConfiguration: true,
      useExternalApis: true,
      isPremium: true,
      userLevel: 'advanced',
      enableMachineLearning: true,
      useEnsemble: false,             // let user pick models individually
      useLogisticRegression: true,
      useDecisionTree: true,
      useXGBoost: true,
      useLightGBM: false,            // enable when LightGBM is added
      deepScan: true,
      adFilter: true,
    );
  }

  /// Clone with optional overrides
  ScanSettings copyWith({
    bool? phishingSensitivity,
    bool? httpSitesWarning,
    bool? scriptAnalysis,
    bool? adReductionAnalysis,
    int? adDensityLevel,
    bool? autoRecheckScans,
    bool? sharingConfiguration,
    bool? useExternalApis,
    bool? isPremium,
    String? googleSafeBrowsingKey,
    String? virusTotalKey,
    String? userLevel,
    bool? enableMachineLearning,
    bool? useEnsemble,
    bool? useLogisticRegression,
    bool? useDecisionTree,
    bool? useXGBoost,
    bool? useLightGBM,
    bool? deepScan,
    bool? adFilter,
  }) {
    return ScanSettings(
      phishingSensitivity: phishingSensitivity ?? this.phishingSensitivity,
      httpSitesWarning: httpSitesWarning ?? this.httpSitesWarning,
      scriptAnalysis: scriptAnalysis ?? this.scriptAnalysis,
      adReductionAnalysis: adReductionAnalysis ?? this.adReductionAnalysis,
      adDensityLevel: adDensityLevel ?? this.adDensityLevel,
      autoRecheckScans: autoRecheckScans ?? this.autoRecheckScans,
      sharingConfiguration: sharingConfiguration ?? this.sharingConfiguration,
      useExternalApis: useExternalApis ?? this.useExternalApis,
      isPremium: isPremium ?? this.isPremium,
      googleSafeBrowsingKey: googleSafeBrowsingKey ?? this.googleSafeBrowsingKey,
      virusTotalKey: virusTotalKey ?? this.virusTotalKey,
      userLevel: userLevel ?? this.userLevel,
      enableMachineLearning: enableMachineLearning ?? this.enableMachineLearning,
      useEnsemble: useEnsemble ?? this.useEnsemble,
      useLogisticRegression: useLogisticRegression ?? this.useLogisticRegression,
      useDecisionTree: useDecisionTree ?? this.useDecisionTree,
      useXGBoost: useXGBoost ?? this.useXGBoost,
      useLightGBM: useLightGBM ?? this.useLightGBM,
      deepScan: deepScan ?? this.deepScan,
      adFilter: adFilter ?? this.adFilter,
    );
  }
}