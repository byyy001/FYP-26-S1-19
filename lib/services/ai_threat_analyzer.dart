
// ============================================================================
// Data Classes for Scan Result and Insights
// ============================================================================

/// Represents a single URL scan result.
class ScanResult {
  final String url;
  final DateTime timestamp;
  final String threatType;
  final double riskScore;
  final String explanation;
  final List<String> detectedThreats;
  final String mlConfidence;
  final double behaviorScore;
  final double aiScore;
  final String source;

  ScanResult({
    required this.url,
    required this.timestamp,
    required this.threatType,
    required this.riskScore,
    required this.explanation,
    required this.detectedThreats,
    required this.mlConfidence,
    required this.behaviorScore,
    required this.aiScore,
    this.source = 'manual',
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    double parseRiskScore(dynamic value) {
      if (value == null) return 0;
      final str = value.toString().replaceAll('%', '');
      return double.tryParse(str) ?? 0;
    }

    List<String> parseDetectedThreats(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {}
      }
      return DateTime.now();
    }

    return ScanResult(
      url: json['url']?.toString() ?? '',
      timestamp: parseTimestamp(json['timestamp']),
      threatType: json['threat_type']?.toString() ?? 'unknown',
      riskScore: parseRiskScore(json['risk_score']),
      explanation: json['explanation']?.toString() ?? '',
      detectedThreats: parseDetectedThreats(json['detected_threats']),
      mlConfidence: json['ml_confidence']?.toString() ?? 'low',
      behaviorScore: (json['behavior_score'] as num?)?.toDouble() ?? 0.0,
      aiScore: (json['ai_score'] as num?)?.toDouble() ?? 0.0,
      source: json['source']?.toString() ?? 'manual',
    );
  }
}

/// Represents a count of a specific threat type (e.g., 'malware', 'phishing').
class ThreatCount {
  final String threatType;
  final int count;
  final double percentage;

  ThreatCount({required this.threatType, required this.count, required this.percentage});
}

/// Represents a trend for a threat type over time.
class ThreatTrend {
  final String threatType;
  final double changePercent;
  final String direction; // 'up' or 'down'
  final int previousCount;
  final int currentCount;

  ThreatTrend({
    required this.threatType,
    required this.changePercent,
    required this.direction,
    required this.previousCount,
    required this.currentCount,
  });
}

/// A contextual tip for the user.
class SmartTip {
  final String message;
  final String? iconAsset; // not used, kept for compatibility

  SmartTip({required this.message, this.iconAsset});
}

/// User's risk profile summary.
class RiskProfile {
  final String level;
  final double score;
  final String description;

  RiskProfile({required this.level, required this.score, required this.description});
}

/// The complete insights object returned by the analyzer.
class UserInsights {
  final String userName;
  final int periodDays;
  final int totalScans;
  final List<ThreatCount> topThreats;
  final List<ThreatTrend> trends;
  final List<SmartTip> smartTips;
  final RiskProfile riskProfile;
  final String? mostDangerousUrl;
  final String? oldestSafeUrl;
  final double riskScoreMax;

  UserInsights({
    required this.userName,
    required this.periodDays,
    required this.totalScans,
    required this.topThreats,
    required this.trends,
    required this.smartTips,
    required this.riskProfile,
    this.mostDangerousUrl,
    this.oldestSafeUrl,
    required this.riskScoreMax,
  });
}

// ============================================================================
// AI Threat Analyzer Service (Improved, professional, no emojis)
// ============================================================================

class AIThreatAnalyzer {
  static UserInsights analyze(
    String userName,
    List<ScanResult> scans, {
    int periodDays = 30,
    bool deduplicateUrls = true,
  }) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: periodDays));

    final recentScansRaw = scans.where((s) => s.timestamp.isAfter(cutoff)).toList();

    List<ScanResult> recentScans;
    if (deduplicateUrls) {
      final urlMap = <String, ScanResult>{};
      for (final scan in recentScansRaw) {
        final existing = urlMap[scan.url];
        if (existing == null || scan.timestamp.isAfter(existing.timestamp)) {
          urlMap[scan.url] = scan;
        }
      }
      recentScans = urlMap.values.toList();
    } else {
      recentScans = recentScansRaw;
    }

    if (recentScans.isEmpty) {
      return UserInsights(
        userName: userName,
        periodDays: periodDays,
        totalScans: 0,
        topThreats: [],
        trends: [],
        smartTips: [
          SmartTip(message: 'No scans in the last $periodDays days. Start scanning to see insights!')
        ],
        riskProfile: RiskProfile(
          level: 'unknown',
          score: 0,
          description: 'Insufficient data to determine risk profile.',
        ),
        mostDangerousUrl: null,
        oldestSafeUrl: null,
        riskScoreMax: 0,
      );
    }

    // ---- 1. Threat counts with exponential decay ----
    const double decayDays = 7.0;
    final threatWeights = <String, double>{};
    final threatRawCounts = <String, int>{};

    for (final scan in recentScans) {
      final type = _normalizeThreatTypeForAnalysis(scan.threatType.toLowerCase());
      final int ageDays = now.difference(scan.timestamp).inDays;
      double weight = 1.0;
      if (ageDays > decayDays) {
        weight = (decayDays / ageDays).clamp(0.2, 1.0);
      }
      threatWeights[type] = (threatWeights[type] ?? 0) + weight;
      threatRawCounts[type] = (threatRawCounts[type] ?? 0) + 1;
    }

    final threatCounts = <String, int>{};
    for (final entry in threatWeights.entries) {
      threatCounts[entry.key] = entry.value.round();
    }

    final sortedEntries = threatCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(3).toList();

    final double totalWeightedScans = threatWeights.values.fold(0.0, (a, b) => a + b);
    final topThreats = topEntries.map((e) => ThreatCount(
      threatType: e.key,
      count: e.value,
      percentage: totalWeightedScans == 0 ? 0 : (e.value / totalWeightedScans) * 100,
    )).toList();

    // ---- 2. Trend analysis (exclude 'benign' from trends) ----
    final previousCutoff = cutoff.subtract(Duration(days: periodDays));
    final previousScansRaw = scans.where((s) =>
        s.timestamp.isAfter(previousCutoff) && s.timestamp.isBefore(cutoff)).toList();

    List<ScanResult> previousScans;
    if (deduplicateUrls) {
      final prevUrlMap = <String, ScanResult>{};
      for (final scan in previousScansRaw) {
        final existing = prevUrlMap[scan.url];
        if (existing == null || scan.timestamp.isAfter(existing.timestamp)) {
          prevUrlMap[scan.url] = scan;
        }
      }
      previousScans = prevUrlMap.values.toList();
    } else {
      previousScans = previousScansRaw;
    }

    final prevThreatCounts = <String, int>{};
    for (final scan in previousScans) {
      final type = _normalizeThreatTypeForAnalysis(scan.threatType.toLowerCase());
      prevThreatCounts[type] = (prevThreatCounts[type] ?? 0) + 1;
    }

    final trends = <ThreatTrend>[];
    final allThreatTypes = {...threatCounts.keys, ...prevThreatCounts.keys};
    for (final type in allThreatTypes) {
      // Skip 'benign' entirely – it's not a threat and shouldn't appear in trends
      if (type == 'benign') continue;
      final int current = threatCounts[type] ?? 0;
      final int previous = prevThreatCounts[type] ?? 0;
      if (current == 0 && previous == 0) continue;
      double changePercent;
      if (previous == 0) {
        changePercent = 100.0;
      } else {
        changePercent = ((current - previous) / previous) * 100;
      }
      final direction = changePercent >= 0 ? 'up' : 'down';
      trends.add(ThreatTrend(
        threatType: type,
        changePercent: changePercent,
        direction: direction,
        previousCount: previous,
        currentCount: current,
      ));
    }
    trends.sort((a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()));

    // ---- 3. Smart tips (professional, no emojis, prioritised) ----
    final tips = <SmartTip>[];
    final dangerScans = recentScans.where((s) => s.riskScore >= 50).toList();
    final safeScans = recentScans.where((s) => s.threatType.toLowerCase() == 'benign').toList();
    final maliciousScans = recentScans.where((s) => _isMaliciousThreat(s.threatType)).toList();
    final suspiciousScans = recentScans.where((s) => _isSuspiciousThreat(s.threatType)).toList();
    final double safePercent = recentScans.isEmpty ? 0 : (safeScans.length / recentScans.length) * 100;
    final double maliciousPercent = recentScans.isEmpty ? 0 : (maliciousScans.length / recentScans.length) * 100;
    final double suspiciousPercent = recentScans.isEmpty ? 0 : (suspiciousScans.length / recentScans.length) * 100;

    void addTip(String message, {int priority = 0}) {
      if (!tips.any((tip) => tip.message == message)) {
        if (priority > 0) {
          tips.insert(0, SmartTip(message: message));
        } else {
          tips.add(SmartTip(message: message));
        }
      }
    }

    // Most dangerous URL (high priority)
    if (dangerScans.isNotEmpty) {
      final mostDangerous = dangerScans.reduce((a, b) => a.riskScore > b.riskScore ? a : b);
      addTip('Most dangerous URL: ${_shortUrl(mostDangerous.url)} (risk ${mostDangerous.riskScore.toStringAsFixed(0)}%). Avoid this site completely.', priority: 3);
    }

    // Oldest safe URL not rescanned (priority 2)
    final safeUrls = <String, ScanResult>{};
    for (final scan in safeScans) {
      final existing = safeUrls[scan.url];
      if (existing == null || scan.timestamp.isAfter(existing.timestamp)) {
        safeUrls[scan.url] = scan;
      }
    }
    final oldestSafe = safeUrls.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (oldestSafe.isNotEmpty) {
      final oldest = oldestSafe.first;
      final int daysSince = now.difference(oldest.timestamp).inDays;
      if (daysSince > 14) {
        addTip('You haven’t rechecked ${_shortUrl(oldest.url)} in $daysSince days. Even safe sites can become compromised – rescan periodically.', priority: 2);
      }
    }

    // High-risk behaviour tips
    if (maliciousPercent > 50 && recentScans.length > 5) {
      addTip('Over 50% of your scans detected malware or phishing. This is critical – run a full antivirus scan and change your browsing habits.', priority: 3);
    } else if (suspiciousPercent > 40 && recentScans.length > 5) {
      addTip('Many of your scans are suspicious (${suspiciousPercent.toStringAsFixed(0)}%). Double‑check URLs before clicking, especially in emails.', priority: 2);
    }

    // Top threat specific tips
    if (topThreats.isNotEmpty) {
      final top = topThreats.first;
      final total = recentScans.length;
      final count = top.count;
      final percent = (count / total * 100).toStringAsFixed(1);
      if (top.threatType == 'malware') {
        addTip('Malware is your top threat (${count}/${total} scans, ${percent}%). Never download files from untrusted sources and keep your antivirus updated.', priority: 2);
      } else if (top.threatType == 'phishing') {
        addTip('Phishing is your most common risk (${count}/${total} scans, ${percent}%). Always verify the sender before clicking links, even if they look legitimate.', priority: 2);
      } else if (top.threatType == 'ad_tracker') {
        addTip('Ad trackers appear frequently. Use an ad blocker and consider privacy‑focused browsers like Brave or Firefox.', priority: 1);
      } else if (top.threatType == 'benign') {
        addTip('Most of your scans are safe. Keep up the good habits, but stay vigilant – threats evolve quickly.', priority: 0);
      }
    }

    // Trend‑based tips (only significant changes, exclude benign)
    for (final trend in trends.take(2)) {
      if (trend.changePercent.abs() >= 50) {
        if (trend.direction == 'up') {
          if (trend.threatType == 'malware') {
            addTip('Malware detections increased by ${trend.changePercent.toStringAsFixed(0)}%. Run a full system scan immediately.', priority: 2);
          } else if (trend.threatType == 'phishing') {
            addTip('Phishing attempts increased by ${trend.changePercent.toStringAsFixed(0)}%. Be extra cautious with email and SMS links.', priority: 2);
          } else {
            addTip('${_formatThreatType(trend.threatType)} increased by ${trend.changePercent.toStringAsFixed(0)}% – stay alert.', priority: 1);
          }
        } else {
          addTip('Great! ${_formatThreatType(trend.threatType)} decreased by ${trend.changePercent.abs().toStringAsFixed(0)}% compared to last period.', priority: 0);
        }
      }
    }

    // General safety tips based on scan volume
    if (recentScans.length > 20) {
      addTip('You’re a power user! Consider our auto‑scan feature to protect every link automatically.', priority: 0);
    } else if (recentScans.length < 5) {
      addTip('Scan more URLs to get deeper insights. The more you scan, the better we can protect you.', priority: 0);
    }

    // Email source tip
    final emailScans = recentScans.where((s) => s.source == 'email').length;
    if (emailScans > recentScans.length * 0.5) {
      addTip('Most of your scans come from emails. Phishing often arrives via email – always check the sender address before clicking.', priority: 1);
    }

    // Fallback
    if (tips.isEmpty) {
      addTip('Stay safe: always scan unfamiliar links before opening them. You’re doing great.', priority: 0);
    }

    // ---- 4. Risk profile with improved thresholds ----
    double totalWeight = 0;
    double weightedRisk = 0;
    double maxRisk = 0;
    for (final scan in recentScans) {
      final int ageDays = now.difference(scan.timestamp).inDays;
      double weight = 1.0;
      if (ageDays > decayDays) {
        weight = (decayDays / ageDays).clamp(0.2, 1.0);
      }
      totalWeight += weight;
      weightedRisk += scan.riskScore * weight;
      if (scan.riskScore > maxRisk) maxRisk = scan.riskScore;
    }
    final double avgRisk = totalWeight > 0 ? weightedRisk / totalWeight : 0;

    String riskLevel;
    String riskDesc;
    if (maxRisk > 75 || avgRisk > 75) {
      riskLevel = 'critical';
      riskDesc = 'Critical: Immediate action required. Run a full antivirus scan and review all your recent clicks.';
    } else if (maxRisk > 50 || avgRisk > 50) {
      riskLevel = 'high';
      riskDesc = 'High risk: You have encountered many malicious links. Change your browsing habits and enable auto‑scan.';
    } else if (maxRisk > 25 || avgRisk > 25) {
      riskLevel = 'moderate';
      riskDesc = 'Moderate risk: Some suspicious links detected. Stay vigilant and double‑check URLs before clicking.';
    } else {
      riskLevel = 'low';
      riskDesc = safePercent > 70
          ? 'Low risk: Most of your scans are safe. Keep up the good habits!'
          : 'Low risk: Your exposure is minimal. Continue scanning unfamiliar links.';
    }

    final riskProfile = RiskProfile(
      level: riskLevel,
      score: avgRisk,
      description: riskDesc,
    );

    String? mostDangerousUrl;
    if (dangerScans.isNotEmpty) {
      final mostDangerous = dangerScans.reduce((a, b) => a.riskScore > b.riskScore ? a : b);
      mostDangerousUrl = mostDangerous.url;
    }
    String? oldestSafeUrl;
    if (oldestSafe.isNotEmpty) {
      oldestSafeUrl = oldestSafe.first.url;
    }

    return UserInsights(
      userName: userName,
      periodDays: periodDays,
      totalScans: recentScans.length,
      topThreats: topThreats,
      trends: trends,
      smartTips: tips,
      riskProfile: riskProfile,
      mostDangerousUrl: mostDangerousUrl,
      oldestSafeUrl: oldestSafeUrl,
      riskScoreMax: maxRisk,
    );
  }

  // --------------------------------------------------------------------------
  // Helper methods
  // --------------------------------------------------------------------------

  static String _normalizeThreatTypeForAnalysis(String type) {
    switch (type) {
      case 'benign':
      case 'safe':
        return 'benign';
      case 'malware':
      case 'malicious':
      case 'unsafe':
        return 'malware';
      case 'phishing':
      case 'suspicious':
      case 'ad_tracker':
      case 'defacement':
        return 'phishing'; // group all suspicious under 'phishing' for trends/top threats
      default:
        return type;
    }
  }

  static bool _isMaliciousThreat(String type) {
    final t = type.toLowerCase();
    return t == 'malware' || t == 'malicious' || t == 'unsafe';
  }

  static bool _isSuspiciousThreat(String type) {
    final t = type.toLowerCase();
    return t == 'phishing' || t == 'suspicious' || t == 'ad_tracker' || t == 'defacement';
  }

  static String _shortUrl(String url) {
    final uri = Uri.tryParse(url);
    String host = uri?.host ?? url;
    host = host.replaceAll(RegExp(r'^www\.'), '');
    return host;
  }

  static String _formatThreatType(String type) {
    switch (type) {
      case 'phishing': return 'Phishing';
      case 'malware': return 'Malware';
      case 'ad_tracker': return 'Ad trackers';
      case 'benign': return 'Safe sites';
      default: return type[0].toUpperCase() + type.substring(1);
    }
  }
}