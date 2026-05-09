// lib/screens/admin/security_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';

class SecurityManagementScreen extends StatefulWidget {
  const SecurityManagementScreen({super.key});

  @override
  State<SecurityManagementScreen> createState() => _SecurityManagementScreenState();
}

class _SecurityManagementScreenState extends State<SecurityManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _config = {};

  // All editable fields
  List<Map<String, dynamic>> _threatCategories = [];
  Map<String, dynamic> _securityRules = {};
  double _adIntensityThreshold = 0.5;
  List<String> _trackerKeywords = [];
  List<String> _globalBlacklist = [];
  List<String> _globalWhitelist = [];
  List<String> _suspiciousTlds = [];
  List<String> _phishingKeywords = [];
  List<String> _urlShorteners = [];
  List<String> _enabledExternalSources = [];
  Map<String, dynamic> _fusionWeights = {};

  // Controllers for dynamic lists
  final List<TextEditingController> _trackerKeywordControllers = [];
  final List<TextEditingController> _blacklistControllers = [];
  final List<TextEditingController> _whitelistControllers = [];
  final List<TextEditingController> _suspiciousTldControllers = [];
  final List<TextEditingController> _phishingKeywordControllers = [];
  final List<TextEditingController> _shortenerControllers = [];
  final List<TextEditingController> _externalSourceControllers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (var c in _trackerKeywordControllers) c.dispose();
    for (var c in _blacklistControllers) c.dispose();
    for (var c in _whitelistControllers) c.dispose();
    for (var c in _suspiciousTldControllers) c.dispose();
    for (var c in _phishingKeywordControllers) c.dispose();
    for (var c in _shortenerControllers) c.dispose();
    for (var c in _externalSourceControllers) c.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final user = await FirebaseAuth.instance.authStateChanges().first;
      if (user == null || !mounted) return;

      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('threat_engine')
          .get();
      _config = doc.exists ? doc.data()! : {};

      _threatCategories = List<Map<String, dynamic>>.from(
        _config['threat_categories'] ?? [
          {'name': 'benign', 'enabled': true, 'min_score': 0, 'max_score': 24},
          {'name': 'phishing', 'enabled': true, 'min_score': 50, 'max_score': 100},
          {'name': 'malware', 'enabled': true, 'min_score': 75, 'max_score': 100},
          {'name': 'defacement', 'enabled': true, 'min_score': 50, 'max_score': 100},
        ],
      );

      _securityRules = Map<String, dynamic>.from(
        _config['security_rules'] ?? {
          'enable_homograph_check': true,
          'enable_typosquatting': true,
          'enable_unshorten': true,
          'max_redirect_hops': 5,
          'new_domain_days_threshold': 30,
          'path_depth_warning': 3,
          'entropy_threshold': 4.2,
        },
      );

      _adIntensityThreshold = (_config['ad_intensity_threshold'] ?? 0.5).toDouble();
      _trackerKeywords = List<String>.from(_config['tracker_detection_keywords'] ?? []);
      _globalBlacklist = List<String>.from(_config['global_blacklist'] ?? []);
      _globalWhitelist = List<String>.from(_config['global_whitelist'] ?? []);
      _suspiciousTlds = List<String>.from(_config['suspicious_tlds'] ?? []);
      _phishingKeywords = List<String>.from(_config['phishing_keywords'] ?? []);
      _urlShorteners = List<String>.from(_config['url_shorteners'] ?? []);
      _enabledExternalSources = List<String>.from(_config['enabled_external_sources'] ?? []);
      _fusionWeights = Map<String, dynamic>.from(_config['fusion_weights'] ?? {});

      _refreshControllers();
    } catch (e) {
      _showSnackBar('Error loading config: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _refreshControllers() {
    _clearControllers();
    for (var item in _trackerKeywords) {
      _trackerKeywordControllers.add(TextEditingController(text: item));
    }
    for (var item in _globalBlacklist) {
      _blacklistControllers.add(TextEditingController(text: item));
    }
    for (var item in _globalWhitelist) {
      _whitelistControllers.add(TextEditingController(text: item));
    }
    for (var item in _suspiciousTlds) {
      _suspiciousTldControllers.add(TextEditingController(text: item));
    }
    for (var item in _phishingKeywords) {
      _phishingKeywordControllers.add(TextEditingController(text: item));
    }
    for (var item in _urlShorteners) {
      _shortenerControllers.add(TextEditingController(text: item));
    }
    for (var item in _enabledExternalSources) {
      _externalSourceControllers.add(TextEditingController(text: item));
    }
  }

  void _clearControllers() {
    _trackerKeywordControllers.clear();
    _blacklistControllers.clear();
    _whitelistControllers.clear();
    _suspiciousTldControllers.clear();
    _phishingKeywordControllers.clear();
    _shortenerControllers.clear();
    _externalSourceControllers.clear();
  }

  List<String> _getTrimmedList(List<TextEditingController> controllers) {
    return controllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    final updatedConfig = {
      'threat_categories': _threatCategories,
      'security_rules': _securityRules,
      'ad_intensity_threshold': _adIntensityThreshold,
      'tracker_detection_keywords': _getTrimmedList(_trackerKeywordControllers),
      'global_blacklist': _getTrimmedList(_blacklistControllers),
      'global_whitelist': _getTrimmedList(_whitelistControllers),
      'suspicious_tlds': _getTrimmedList(_suspiciousTldControllers),
      'phishing_keywords': _getTrimmedList(_phishingKeywordControllers),
      'url_shorteners': _getTrimmedList(_shortenerControllers),
      'enabled_external_sources': _getTrimmedList(_externalSourceControllers),
      'fusion_weights': _fusionWeights,
      'version': FieldValue.increment(1),
      'last_updated': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('threat_engine')
          .set(updatedConfig, SetOptions(merge: true));

      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('threat_engine_config', updatedConfig.toString());

      _showSnackBar('Configuration saved successfully');
    } catch (e) {
      _showSnackBar('Error saving config: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.highRisk : AppColors.safe,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.mainBackground,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: AppColors.primaryPurple,
                    unselectedLabelColor: AppColors.secondaryText,
                    indicatorColor: AppColors.primaryPurple,
                    tabs: const [
                      Tab(text: 'Categories & Rules'),
                      Tab(text: 'Thresholds'),
                      Tab(text: 'Black/White Lists'),
                      Tab(text: 'Keywords & Shorteners'),
                      Tab(text: 'External & Fusion'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCategoriesAndRulesTab(),
                  _buildThresholdsTab(),
                  _buildBlackWhiteListsTab(),
                  _buildKeywordsShortenersTab(),
                  _buildExternalFusionTab(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Configuration', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- TABS --------------------
  Widget _buildCategoriesAndRulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildThreatCategoriesCard(),
          const SizedBox(height: 20),
          _buildSecurityRulesCard(),
        ],
      ),
    );
  }

  Widget _buildThresholdsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildAdIntensityCard(),
          const SizedBox(height: 20),
          _buildFusionWeightsCard(),
        ],
      ),
    );
  }

  Widget _buildBlackWhiteListsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildListCard(
            'Global Blacklist',
            'Domains blocked immediately.',
            _blacklistControllers,
            (idx) => _removeController(_blacklistControllers, idx),
            () => _addController(_blacklistControllers),
          ),
          const SizedBox(height: 20),
          _buildListCard(
            'Global Whitelist',
            'Domains considered safe.',
            _whitelistControllers,
            (idx) => _removeController(_whitelistControllers, idx),
            () => _addController(_whitelistControllers),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordsShortenersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildListCard(
            'Suspicious TLDs',
            'Top-level domains often abused.',
            _suspiciousTldControllers,
            (idx) => _removeController(_suspiciousTldControllers, idx),
            () => _addController(_suspiciousTldControllers),
          ),
          const SizedBox(height: 20),
          _buildListCard(
            'Phishing Keywords',
            'Regex patterns for phishing detection.',
            _phishingKeywordControllers,
            (idx) => _removeController(_phishingKeywordControllers, idx),
            () => _addController(_phishingKeywordControllers),
          ),
          const SizedBox(height: 20),
          _buildListCard(
            'URL Shorteners',
            'Shortening services to expand.',
            _shortenerControllers,
            (idx) => _removeController(_shortenerControllers, idx),
            () => _addController(_shortenerControllers),
          ),
          const SizedBox(height: 20),
          _buildListCard(
            'Tracker Detection Keywords',
            'Keywords for ad/tracker scripts.',
            _trackerKeywordControllers,
            (idx) => _removeController(_trackerKeywordControllers, idx),
            () => _addController(_trackerKeywordControllers),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalFusionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildListCard(
            'Enabled External Sources',
            'API sources to query (google_sb, virustotal, openphish, urlhaus, ipqs, whois).',
            _externalSourceControllers,
            (idx) => _removeController(_externalSourceControllers, idx),
            () => _addController(_externalSourceControllers),
          ),
        ],
      ),
    );
  }

  // -------------------- Reusable Cards --------------------
  Widget _buildThreatCategoriesCard() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Threat Categories',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _threatCategories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final cat = _threatCategories[idx];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat['name'].toString().toUpperCase(),
                            style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Switch(
                          value: cat['enabled'] ?? true,
                          onChanged: (val) => setState(() => cat['enabled'] = val),
                          activeColor: Colors.greenAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberField(
                            'Min Score',
                            (cat['min_score'] ?? 0).toInt(),
                            (val) => cat['min_score'] = val.clamp(0, 100),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildNumberField(
                            'Max Score',
                            (cat['max_score'] ?? 100).toInt(),
                            (val) => cat['max_score'] = val.clamp(0, 100),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _threatCategories.add({
                  'name': 'new_category',
                  'enabled': true,
                  'min_score': 0,
                  'max_score': 100,
                });
              }),
              icon: const Icon(Icons.add, color: AppColors.primaryPurple),
              label: const Text('Add Category', style: TextStyle(color: AppColors.primaryPurple)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityRulesCard() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Security Rules',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
          const SizedBox(height: 16),
          _buildRuleToggle('Homograph Attack Check', 'enable_homograph_check'),
          _buildRuleToggle('Typosquatting Detection', 'enable_typosquatting'),
          _buildRuleToggle('Expand Shortened URLs', 'enable_unshorten'),
          _buildRuleNumber('Max Redirect Hops', 'max_redirect_hops', 1, 10),
          _buildRuleNumber('New Domain Warning (days)', 'new_domain_days_threshold', 1, 365),
          _buildRuleNumber('Path Depth Warning', 'path_depth_warning', 1, 20),
          _buildRuleNumber('Entropy Threshold', 'entropy_threshold', 0.0, 10.0, isDouble: true),
        ],
      ),
    );
  }

  Widget _buildAdIntensityCard() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ad-Intensity Threshold',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Threshold (0.0 = low, 1.0 = high)',
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    ),
                    Text(
                      '${(_adIntensityThreshold * 100).toInt()}%',
                      style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Slider(
                  value: _adIntensityThreshold,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  activeColor: AppColors.primaryPurple,
                  onChanged: (val) => setState(() => _adIntensityThreshold = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFusionWeightsCard() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fusion Weights',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
          const SizedBox(height: 16),
          ...['static', 'ml', 'behavior', 'ai', 'external'].map((key) {
            final val = (_fusionWeights[key] ?? 0.25).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            key.toUpperCase(),
                            style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${(val * 100).toInt()}%',
                          style: const TextStyle(color: AppColors.primaryText),
                        ),
                      ],
                    ),
                    Slider(
                      value: val,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      activeColor: AppColors.primaryPurple,
                      onChanged: (newVal) => setState(() => _fusionWeights[key] = newVal),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          const Text(
            'Weights are normalized automatically.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(
    String title,
    String description,
    List<TextEditingController> controllers,
    void Function(int) onRemove,
    VoidCallback onAdd,
  ) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controllers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              return Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controllers[idx],
                      style: const TextStyle(color: AppColors.primaryText),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.mainBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        hintText: 'Enter value',
                        hintStyle: const TextStyle(color: AppColors.disabledText),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.highRisk),
                    onPressed: () => onRemove(idx),
                  ),
                ],
              );
            },
          ),
          if (controllers.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(14)),
              child: Text(
                'No entries. Click "Add" to insert.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, color: AppColors.primaryPurple),
              label: const Text('Add', style: TextStyle(color: AppColors.primaryPurple)),
            ),
          ),
        ],
      ),
    );
  }

  // Helpers
  void _addController(List<TextEditingController> list) {
    setState(() => list.add(TextEditingController()));
  }

  void _removeController(List<TextEditingController> list, int idx) {
    list[idx].dispose();
    setState(() => list.removeAt(idx));
  }

  Widget _buildRuleToggle(String label, String key) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: _securityRules[key] ?? true,
            onChanged: (val) => setState(() => _securityRules[key] = val),
            activeColor: Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildRuleNumber(String label, String key, num minVal, num maxVal, {bool isDouble = false}) {
    final value = _securityRules[key] ?? (isDouble ? 0.0 : 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.mainBackground, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: value.toString(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.primaryText),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (val) {
                final parsed = isDouble ? double.tryParse(val) : int.tryParse(val);
                if (parsed != null) {
                  setState(() {
                    if (isDouble) {
                      _securityRules[key] = (parsed as double).clamp(minVal.toDouble(), maxVal.toDouble());
                    } else {
                      _securityRules[key] = (parsed as int).clamp(minVal.toInt(), maxVal.toInt());
                    }
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(String label, int initialValue, void Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue.toString(),
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.primaryText),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (val) {
            final intVal = int.tryParse(val) ?? 0;
            onChanged(intVal);
          },
        ),
      ],
    );
  }
}

// ==================== PANEL WIDGET ====================
class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _Panel({
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryPurple.withAlpha(35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withAlpha(14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}