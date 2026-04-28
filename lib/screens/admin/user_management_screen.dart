import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    // Wait for auth state to be confirmed before loading
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
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
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

  Future<void> _loadUsers() async {

    // Guard: ensure user is authenticated before querying
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not authenticated. Please log in.')),
    );
    return;
  }

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

    print('Fetched ${snapshot.docs.length} users');  // Debug log

    if (snapshot.docs.isEmpty) {
      setState(() => _hasMore = false);
      print('No users found!');
    } else {
      final newUsers = snapshot.docs.map((doc) {
        // Explicitly cast to Map<String, dynamic>
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
        print('Last Document ID: ${_lastDocument?.id}'); // Debugging line
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
      // Search filter
      final fullName = '${user['firstName']} ${user['lastName']}'.toLowerCase();
      final email = (user['email'] as String?)?.toLowerCase() ?? '';
      final matchesSearch = _searchQuery.isEmpty ||
          fullName.contains(_searchQuery) ||
          email.contains(_searchQuery);

      // Role filter
      final matchesRole = _selectedRoleFilter == 'All' ||
          user['role'] == _selectedRoleFilter;

      // Status filter
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Delete User', style: TextStyle(color: AppColors.primaryText)),
        content: Text('Are you sure you want to delete $userName? This action cannot be undone.',
            style: const TextStyle(color: AppColors.secondaryText)),
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
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      setState(() {
        _users.removeWhere((u) => u['id'] == userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User deleted successfully'), backgroundColor: AppColors.safe),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting user: $e'), backgroundColor: AppColors.highRisk),
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
        title: Text('Edit ${user['firstName']} ${user['lastName']}',
            style: const TextStyle(color: AppColors.primaryText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedRole,
              dropdownColor: AppColors.cardBackground,
              style: const TextStyle(color: AppColors.primaryText),
              decoration: const InputDecoration(
                labelText: 'Role',
                labelStyle: TextStyle(color: AppColors.secondaryText),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.divider),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'User', child: Text('User')),
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                DropdownMenuItem(value: 'Engineer', child: Text('Engineer')),
              ],
              onChanged: (value) => selectedRole = value!,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Active', style: TextStyle(color: AppColors.primaryText)),
              value: isActive,
              onChanged: (value) => isActive = value,
              activeColor: AppColors.safe,
            ),
          ],
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final filteredUsers = _filteredUsers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search and filters (without duplicate title)
        _buildSearchAndFiltersPanel(),
        const SizedBox(height: 24),

        // User list
        if (_isLoading && _users.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (filteredUsers.isEmpty)
          _buildEmptyState()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _UserCard(
                  user: user,
                  onEdit: () => _showEditDialog(user),
                  onDelete: () => _deleteUser(user['id'], '${user['firstName']} ${user['lastName']}'),
                ),
              );
            },
          ),

        // Load more button
        if (_hasMore && !_isLoading && _users.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: OutlinedButton(
                onPressed: _loadUsers,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primaryPurple.withOpacity(0.5)),
                ),
                child: const Text('Load More'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchAndFiltersPanel() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role filters
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _roleFilters.map((filter) {
              return _FilterChip(
                label: filter,
                selected: _selectedRoleFilter == filter,
                onSelected: () {
                  setState(() {
                    _selectedRoleFilter = filter;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Status filters
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _statusFilters.map((filter) {
              return _FilterChip(
                label: filter,
                selected: _selectedStatusFilter == filter,
                onSelected: () {
                  setState(() {
                    _selectedStatusFilter = filter;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Search field
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.primaryText),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              hintStyle: const TextStyle(color: AppColors.disabledText),
              prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
              filled: true,
              fillColor: AppColors.mainBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return _Panel(
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No users found.',
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryPurple.withOpacity(0.2)
              : AppColors.mainBackground,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? AppColors.primaryPurple.withOpacity(0.6)
                : AppColors.divider.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primaryText : AppColors.secondaryText,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = user['isActive'] == true;
    final String fullName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final String displayName = fullName.isNotEmpty ? fullName : 'No name';

    return _Panel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person_outline, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
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
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Text(
                  'Role:',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                const SizedBox(width: 12),
                const Text(
                  'Status:',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.safe.withOpacity(0.2)
                        : AppColors.highRisk.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? AppColors.safe.withOpacity(0.5)
                          : AppColors.highRisk.withOpacity(0.5),
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
          ),
          Row(
            children: [
              SizedBox(
                width: 70,
                height: 38,
                child: OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryText,
                    side: BorderSide(color: AppColors.primaryPurple.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                height: 38,
                child: OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.highRisk,
                    side: const BorderSide(color: AppColors.highRisk),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}