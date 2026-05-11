import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../constants/app_colors.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRoleFilter = 'All';
  String _selectedStatusFilter = 'All';
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final List<Map<String, dynamic>> _users = [];
  final int _pageSize = 10;

  final List<String> _roleFilters = ['All', 'User', 'Admin', 'Engineer'];
  final List<String> _statusFilters = ['All', 'Active', 'Suspended'];

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().first.then((user) {
      if (user != null && mounted) {
        _loadUsers();
        _searchController.addListener(_onSearchChanged);
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    _refreshUsers();
  }

  void _refreshUsers() {
    setState(() {
      _users.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    _loadUsers();
  }

  void _clearFilters() {
    setState(() {
      _selectedRoleFilter = 'All';
      _selectedStatusFilter = 'All';
      _searchController.clear();
      _searchQuery = '';
    });
    _refreshUsers();
  }

  Future<void> _loadUsers() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      if (_selectedRoleFilter != 'All') {
        query = query.where('role', isEqualTo: _selectedRoleFilter);
      }
      if (_selectedStatusFilter != 'All') {
        query = query.where('isActive', isEqualTo: _selectedStatusFilter == 'Active');
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        setState(() => _hasMore = false);
      } else {
        final newUsers = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'firstName': data['firstName']?.toString() ?? '',
            'lastName': data['lastName']?.toString() ?? '',
            'email': data['email']?.toString() ?? '',
            'role': data['role']?.toString() ?? 'User',
            'isActive': data['isActive'] ?? true,
            'isPremium': data['isPremium'] ?? false,
            'createdAt': data['createdAt'],
          };
        }).toList();

        setState(() {
          _users.addAll(newUsers);
          _lastDocument = snapshot.docs.last;
          _hasMore = snapshot.docs.length == _pageSize;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $e'), backgroundColor: AppColors.highRisk),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return _users.where((user) {
      final fullName = '${user['firstName']} ${user['lastName']}'.toLowerCase();
      final email = (user['email'] as String?)?.toLowerCase() ?? '';
      final matchesSearch = _searchQuery.isEmpty ||
          fullName.contains(_searchQuery) ||
          email.contains(_searchQuery);
      final matchesRole = _selectedRoleFilter == 'All' || user['role'] == _selectedRoleFilter;
      final isActive = user['isActive'] == true;
      final matchesStatus = _selectedStatusFilter == 'All' ||
          (_selectedStatusFilter == 'Active' && isActive) ||
          (_selectedStatusFilter == 'Suspended' && !isActive);
      return matchesSearch && matchesRole && matchesStatus;
    }).toList();
  }

  Future<void> _updateUserField(String userId, String field, dynamic value) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({field: value});
      setState(() {
        final index = _users.indexWhere((u) => u['id'] == userId);
        if (index != -1) _users[index][field] = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User updated successfully'), backgroundColor: AppColors.safe),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user: $e'), backgroundColor: AppColors.highRisk),
      );
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Delete User', style: TextStyle(color: AppColors.primaryText)),
        content: Text(
          'Are you sure you want to permanently delete $userName? This will remove their account and all data. This action cannot be undone.',
          style: const TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.highRisk)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      // Delete Firebase Auth account via Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('deleteAuthUser');
      await callable.call({'uid': userId});

      // Delete Firestore document
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      setState(() => _users.removeWhere((u) => u['id'] == userId));
      messenger.showSnackBar(
        const SnackBar(content: Text('User deleted successfully'), backgroundColor: AppColors.safe),
      );
    } on FirebaseFunctionsException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: ${e.message}'), backgroundColor: AppColors.highRisk),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.highRisk),
      );
    }
  }

  void _showEditDialog(Map<String, dynamic> user) {
    String selectedRole = user['role'] ?? 'User';
    bool isActive = user['isActive'] ?? true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit ${user['firstName']} ${user['lastName']}',
            style: const TextStyle(color: AppColors.primaryText)),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  dropdownColor: AppColors.cardBackground,
                  style: const TextStyle(color: AppColors.primaryText),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: const TextStyle(color: AppColors.secondaryText),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'User', child: Text('User')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'Engineer', child: Text('Engineer')),
                  ],
                  onChanged: (value) => setStateDialog(() => selectedRole = value!),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active', style: TextStyle(color: AppColors.primaryText)),
                  value: isActive,
                  onChanged: (value) => setStateDialog(() => isActive = value),
                  activeColor: AppColors.safe,
                  secondary: Icon(isActive ? Icons.check_circle : Icons.cancel, color: isActive ? AppColors.safe : AppColors.highRisk),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateUserField(user['id'], 'role', selectedRole);
              await _updateUserField(user['id'], 'isActive', isActive);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _filteredUsers;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchAndFiltersPanel(),
          const SizedBox(height: 24),

          if (_isLoading && _users.isEmpty)
            const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          else if (filteredUsers.isEmpty)
            _buildEmptyState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _UserCard(
                  user: filteredUsers[index],
                  onEdit: () => _showEditDialog(filteredUsers[index]),
                  onDelete: () => _deleteUser(filteredUsers[index]['id'], '${filteredUsers[index]['firstName']} ${filteredUsers[index]['lastName']}'),
                  isSmallScreen: isSmallScreen,
                ),
              ),
            ),

          if (_hasMore && !_isLoading && _users.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: TextButton(
                  onPressed: _loadUsers,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.primaryPurple.withOpacity(0.5)),
                    ),
                  ),
                  child: const Text('Load More'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFiltersPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role filters
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _roleFilters.map((filter) => ChoiceChip(
              label: Text(filter),
              selected: _selectedRoleFilter == filter,
              onSelected: (selected) {
                if (selected) setState(() => _selectedRoleFilter = filter);
              },
              selectedColor: AppColors.primaryPurple.withOpacity(0.2),
              backgroundColor: AppColors.mainBackground,
              labelStyle: TextStyle(
                color: _selectedRoleFilter == filter ? AppColors.primaryText : AppColors.secondaryText,
                fontWeight: _selectedRoleFilter == filter ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                color: _selectedRoleFilter == filter
                    ? AppColors.primaryPurple.withOpacity(0.6)
                    : AppColors.divider.withOpacity(0.3),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            )).toList(),
          ),
          const SizedBox(height: 12),
          // Status filters
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _statusFilters.map((filter) => ChoiceChip(
              label: Text(filter),
              selected: _selectedStatusFilter == filter,
              onSelected: (selected) {
                if (selected) setState(() => _selectedStatusFilter = filter);
              },
              selectedColor: AppColors.primaryPurple.withOpacity(0.2),
              backgroundColor: AppColors.mainBackground,
              labelStyle: TextStyle(
                color: _selectedStatusFilter == filter ? AppColors.primaryText : AppColors.secondaryText,
                fontWeight: _selectedStatusFilter == filter ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                color: _selectedStatusFilter == filter
                    ? AppColors.primaryPurple.withOpacity(0.6)
                    : AppColors.divider.withOpacity(0.3),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            )).toList(),
          ),
          const SizedBox(height: 16),
          // Search field with clear button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.primaryText),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle: const TextStyle(color: AppColors.disabledText),
                    prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.secondaryText),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _refreshUsers();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.mainBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedRoleFilter != 'All' || _selectedStatusFilter != 'All' || _searchQuery.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _clearFilters,
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryPurple),
                child: const Text('Clear Filters'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.history_toggle_off, color: AppColors.secondaryText, size: 48),
          SizedBox(height: 12),
          Text('No users found', style: TextStyle(color: AppColors.secondaryText, fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Try adjusting your filters', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isSmallScreen;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = user['isActive'] == true;
    final String fullName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final String displayName = fullName.isNotEmpty ? fullName : 'No name';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person_outline, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user['email'] ?? '',
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Role + Status chips (wrap to next line on small screens)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Role chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user['role'] ?? 'User',
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Status chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.safe.withOpacity(0.15) : AppColors.highRisk.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? AppColors.safe.withOpacity(0.5) : AppColors.highRisk.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Suspended',
                      style: TextStyle(
                        color: isActive ? AppColors.safe : AppColors.highRisk,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action buttons (solid, gradient for edit, red for delete)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Edit button (gradient)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.premiumGradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  onPressed: onEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Delete button (solid red)
              ElevatedButton(
                onPressed: onDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.highRisk,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}