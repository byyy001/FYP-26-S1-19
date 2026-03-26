// ============================================================================
// ScanResult Model (included for self‑containment)
// ============================================================================

/// Represents a single URL scan result.
class ScanResult {
  final String url;
  final DateTime timestamp;          // when the scan was performed
  final String threatType;            // e.g., 'phishing', 'malware', 'ad_tracker', 'benign'
  final double riskScore;             // 0–100
  final String explanation;
  final List<String> detectedThreats;
  final String mlConfidence;          // 'high', 'medium', 'low'
  final double behaviorScore;         // 0–1
  final double aiScore;               // 0–1
  final String source;                // e.g., 'manual', 'camera', 'email'

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

  /// Creates a ScanResult from the map returned by the threat engine.
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

    // Parse timestamp – expecting ISO string or similar
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

// ============================================================================
// Data Classes for Insights
// ============================================================================

/// Represents a count of a specific threat type.
class ThreatCount {
  final String threatType;
  final int count;
  final double percentage; // of total scans

  ThreatCount({required this.threatType, required this.count, required this.percentage});
}

/// Represents a trend for a threat type over time.
class ThreatTrend {
  final String threatType;
  final double changePercent; // positive = increase, negative = decrease
  final String direction; // 'up' or 'down'

  ThreatTrend({required this.threatType, required this.changePercent, required this.direction});
}

/// A contextual tip for the user.
class SmartTip {
  final String message;
  final String? iconAsset; // optional: could be Icons.lightbulb etc.

  SmartTip({required this.message, this.iconAsset});
}

/// User's risk profile summary.
class RiskProfile {
  final String level; // 'low', 'moderate', 'high'
  final double score; // 0-100
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

  UserInsights({
    required this.userName,
    required this.periodDays,
    required this.totalScans,
    required this.topThreats,
    required this.trends,
    required this.smartTips,
    required this.riskProfile,
  });
}

// ============================================================================
// Main AI Threat Analyzer Service
// ============================================================================

class AIThreatAnalyzer {
  /// Analyzes a list of scan results and returns personalized insights.
  static UserInsights analyze(
    String userName,
    List<ScanResult> scans, {
    int periodDays = 30,
  }) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: periodDays));

    // Filter scans within the period
    final recentScans = scans.where((s) => s.timestamp.isAfter(cutoff)).toList();

    // If no scans in period, return empty insights
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
      );
    }

    // 1. Aggregate threat types
    final threatCounts = <String, int>{};
    for (final scan in recentScans) {
      final type = scan.threatType.toLowerCase();
      threatCounts[type] = (threatCounts[type] ?? 0) + 1;
    }

    // Sort and take top 3
    final sortedEntries = threatCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(3).toList();

    final topThreats = topEntries.map((e) => ThreatCount(
      threatType: e.key,
      count: e.value,
      percentage: (e.value / recentScans.length) * 100,
    )).toList();

    // 2. Trend analysis (compare with previous period)
    final previousCutoff = cutoff.subtract(Duration(days: periodDays));
    final previousScans = scans.where((s) =>
        s.timestamp.isAfter(previousCutoff) && s.timestamp.isBefore(cutoff)).toList();

    final trends = <ThreatTrend>[];
    for (final entry in topEntries) {
      final type = entry.key;
      final currentCount = entry.value;
      final previousCount = previousScans.where((s) => s.threatType.toLowerCase() == type).length;

      if (previousCount > 0) {
        final change = ((currentCount - previousCount) / previousCount) * 100;
        trends.add(ThreatTrend(
          threatType: type,
          changePercent: change,
          direction: change >= 0 ? 'up' : 'down',
        ));
      } else if (currentCount > 0) {
        // New threat type appeared
        trends.add(ThreatTrend(
          threatType: type,
          changePercent: 100, // infinite increase, but we cap
          direction: 'up',
        ));
      }
    }

    // 3. Enhanced pattern mining (rule‑based tips)
    final tips = <SmartTip>[];

    // Helper to add tip if not already present
    void addTip(String message) {
      if (!tips.any((tip) => tip.message == message)) {
        tips.add(SmartTip(message: message));
      }
    }

    // Tip based on most common threat
    if (topThreats.isNotEmpty) {
      final top = topThreats.first;
      if (top.threatType == 'phishing') {
        if (top.percentage > 50) {
          addTip('Phishing makes up over 50% of your threats. Be extra cautious with links asking for personal info.');
        } else {
          addTip('Phishing is your most common threat. Always verify the sender before clicking links.');
        }
      } else if (top.threatType == 'malware') {
        addTip('Malware is your top threat. Avoid downloading files from untrusted sources.');
      } else if (top.threatType == 'ad_tracker') {
        addTip('Ad trackers are common in your scans. Consider using an ad blocker for more privacy.');
      }
    }

    // Tip based on trends
    for (final trend in trends) {
      if (trend.changePercent.abs() > 50) {
        if (trend.direction == 'up') {
          addTip('${trend.threatType} has increased significantly (${trend.changePercent.toStringAsFixed(0)}%). Stay alert!');
        } else {
          addTip('Great! ${trend.threatType} is down ${trend.changePercent.abs().toStringAsFixed(0)}% compared to last period.');
        }
      }
    }

    // Tip based on email source
    final emailScans = recentScans.where((s) => s.source == 'email').length;
    if (emailScans > 0) {
      final emailPercent = (emailScans / recentScans.length) * 100;
      if (emailPercent > 50) {
        addTip('Most of your scans come from emails. Be extra careful with unexpected messages.');
      } else if (emailPercent > 20) {
        addTip('You scan many links from emails. Verify sender addresses before clicking.');
      }
    }

    // Tip based on streaming sites
    final streamingScans = recentScans.where((s) =>
        s.url.contains('stream') || s.url.contains('movie') || s.url.contains('watch')).length;
    if (streamingScans > 3) {
      addTip('You frequently visit streaming sites. Stick to official platforms to avoid malware.');
    }

    // Tip based on risk profile (will be computed later, but we can use avgRisk)
    final double avgRisk = recentScans.map((s) => s.riskScore).reduce((a, b) => a + b) / recentScans.length;
    if (avgRisk >= 70) {
      addTip('Your risk profile is high. Consider enabling auto‑recheck scans for continuous protection.');
    } else if (avgRisk <= 20 && recentScans.length > 10) {
      addTip('Your risk profile is low – you’re doing great! Keep up safe browsing habits.');
    }

    // Tip based on total scans
    if (recentScans.length > 50) {
      addTip('You’re an active user! Review your top threats in the chart above to stay informed.');
    } else if (recentScans.length < 5) {
      addTip('Scan more URLs to get personalized security insights.');
    }

    // Fallback tip if none added
    if (tips.isEmpty) {
      addTip('Stay safe online: never share personal info on suspicious sites.');
    }

    // 4. Risk profile calculation
    double totalRisk = 0;
    for (final scan in recentScans) {
      totalRisk += scan.riskScore;
    }
    final avgRiskProfile = totalRisk / recentScans.length;

    String riskLevel;
    String riskDesc;
    if (avgRiskProfile >= 70) {
      riskLevel = 'high';
      riskDesc = 'Your scan history shows a high proportion of malicious URLs. Stay vigilant!';
    } else if (avgRiskProfile >= 40) {
      riskLevel = 'moderate';
      riskDesc = 'You encounter some risky links. Review the tips above to stay safe.';
    } else {
      riskLevel = 'low';
      riskDesc = 'You have a low risk profile. Keep up the good habits!';
    }

    final riskProfile = RiskProfile(
      level: riskLevel,
      score: avgRiskProfile,
      description: riskDesc,
    );

    return UserInsights(
      userName: userName,
      periodDays: periodDays,
      totalScans: recentScans.length,
      topThreats: topThreats,
      trends: trends,
      smartTips: tips,
      riskProfile: riskProfile,
    );
  }
}