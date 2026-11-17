import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/alumni_model.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../widgets/alumni_avatar.dart';
import 'account_settings.dart';
import 'system_settings.dart';
import 'about_us.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State< AdminPanel > {
  final GlobalKey< ScaffoldState > _scaffoldKey = GlobalKey< ScaffoldState >();
  int _selectedTab = 0;
  List< Map< String, dynamic > > _users = [];
  List< Map< String, dynamic > > _teacherRequests = [];
  bool _isLoadingUsers = false;
  bool _isLoadingLogs = false;
  String? _processingRequestId;
  int _userListRefreshKey = 0;

  String _selectedRoleFilter = 'all';
  final TextEditingController _userSearchCtrl = TextEditingController();

  final _editFormKey = GlobalKey< FormState >();
  late TextEditingController _emailCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    DataService.moduleUpdateNotifier.addListener(_onRealtimeDataUpdated);
    AuthService.userProfileNotifier.addListener(_onRealtimeDataUpdated);
    _refreshLogs();
    _loadUsers();
    DataService.loadAlumniProfiles().then((_) {
      if (mounted) setState(() {});
    });
    DataService.loadModules().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onRealtimeDataUpdated() {
    if (mounted) setState(() {});
  }

  Future< void > _openFromSidebar(Widget page) async {
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (!mounted) return;
    setState(() {});
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  void dispose() {
    DataService.moduleUpdateNotifier.removeListener(_onRealtimeDataUpdated);
    AuthService.userProfileNotifier.removeListener(_onRealtimeDataUpdated);
    _userSearchCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future< void > _refreshLogs() async {
    if (!mounted) return;
    setState(() => _isLoadingLogs = true);
    await DataService.loadSystemLogs();
    if (!mounted) return;
    setState(() => _isLoadingLogs = false);
  }

  Future< void > _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoadingUsers = true);
    final results = await Future.wait([
      AuthService.getAllUsersAsync(),
      DataService.loadTeacherAccountRequests(),
    ]);
    if (!mounted) return;
    setState(() {
      _users = results[0];
      _teacherRequests = results[1];
      _isLoadingUsers = false;
    });
  }

  Future< void > _handleApproveTeacherRequest(
    Map< String, dynamic > req,
  ) async {
    final reqId = (req['id'] ?? '').toString();
    final name = (req['name'] ?? '').toString().trim();
    final username = (req['username'] ?? '').toString().trim();
    final email = (req['email'] ?? '').toString().trim();
    final department = (req['department'] ?? '').toString().trim();
    if (reqId.isEmpty || email.isEmpty) return;

    setState(() => _processingRequestId = reqId);
    final success = await AuthService.createTeacherAccount(
      email: email,
      name: name,
      username: username.isNotEmpty ? username : email.split('@').first,
      department: department,
      sendPasswordSetupLink: true,
    );

    if (!mounted) return;

    if (success) {
      await DataService.resolveTeacherAccountRequest(
        id: reqId,
        status: 'approved',
        email: email,
        adminEmail: AuthService.currentUser?.email,
      );
      if (!mounted) return;
      setState(() => _processingRequestId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Approved $name ($email). A password setup link was sent to their email.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _loadUsers();
    } else {
      setState(() => _processingRequestId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthService.lastErrorMessage ??
                'Failed to approve request. Account may already exist.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future< void > _handleRejectTeacherRequest(
    Map< String, dynamic > req,
  ) async {
    final reqId = (req['id'] ?? '').toString();
    final name = (req['name'] ?? '').toString().trim();
    final email = (req['email'] ?? '').toString().trim();
    if (reqId.isEmpty) return;

    final confirmed = await showDialog< bool >(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Teacher Request'),
        content: Text(
          'Reject the teacher account request from $name ($email)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingRequestId = reqId);
    await DataService.resolveTeacherAccountRequest(
      id: reqId,
      status: 'rejected',
      email: email,
      adminEmail: AuthService.currentUser?.email,
    );
    if (!mounted) return;
    setState(() => _processingRequestId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rejected teacher request for $email.')),
    );
    await _loadUsers();
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final id = user['id'];
    if (id == null || id.toString().isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete ${user['email'] ?? 'this user'} from Firebase?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AuthService.deleteUser(id.toString());
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User deleted.')));
    setState(() => _userListRefreshKey++);
    await _loadUsers();
  }

  Future<void> _showCreateTeacherDialog() async {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Create Teacher Account',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Username is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Email is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: '8–20 chars, uppercase, lowercase, number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 8 || v.length > 20) {
                        return '8 to 20 characters required';
                      }
                      if (!RegExp(r'[A-Z]').hasMatch(v) ||
                          !RegExp(r'[a-z]').hasMatch(v) ||
                          !RegExp(r'[0-9]').hasMatch(v)) {
                        return 'Include uppercase, lowercase, and number';
                      }
                      return null;
                    },
                  ),
                  if (passwordCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F8FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.lightBlue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPwdReqItem(
                            '8–20 characters',
                            passwordCtrl.text.length >= 8 &&
                                passwordCtrl.text.length <= 20,
                          ),
                          _buildPwdReqItem(
                            'Uppercase letter (A–Z)',
                            RegExp(r'[A-Z]').hasMatch(passwordCtrl.text),
                          ),
                          _buildPwdReqItem(
                            'Lowercase letter (a–z)',
                            RegExp(r'[a-z]').hasMatch(passwordCtrl.text),
                          ),
                          _buildPwdReqItem(
                            'Number (0–9)',
                            RegExp(r'[0-9]').hasMatch(passwordCtrl.text),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      final success = await AuthService.createTeacherAccount(
                        email: emailCtrl.text.trim(),
                        password: passwordCtrl.text,
                        name: nameCtrl.text.trim(),
                        username: usernameCtrl.text.trim(),
                      );
                      setDialogState(() => isLoading = false);
                      Navigator.pop(context);
                      if (success) {
                        setState(() => _userListRefreshKey++);
                        await _loadUsers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Teacher account created successfully!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed. Email may already be in use.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUserEditDialog(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    final initialRole = (user['role'] ?? 'student').toString().toLowerCase();

    _emailCtrl.text = (user['email'] ?? '').toString();
    _nameCtrl.text = (user['name'] ?? '').toString();
    _usernameCtrl.text = (user['username'] ?? '').toString();
    _passwordCtrl.clear();

    String selectedRole = ['student', 'teacher', 'admin'].contains(initialRole)
        ? initialRole
        : 'student';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit User'),
          content: Form(
            key: _editFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'New Password (optional)',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(
                        value: 'student',
                        child: Text('Student'),
                      ),
                      DropdownMenuItem(
                        value: 'teacher',
                        child: Text('Teacher'),
                      ),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final success = await AuthService.editUser(
      id: userId,
      newEmail: _emailCtrl.text.trim().isNotEmpty
          ? _emailCtrl.text.trim()
          : null,
      newName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
      newUsername: _usernameCtrl.text.trim().isNotEmpty
          ? _usernameCtrl.text.trim()
          : null,
      newRole: selectedRole,
      newPassword:
          _passwordCtrl.text.trim().isNotEmpty &&
              userId == AuthService.currentUser?.id
          ? _passwordCtrl.text.trim()
          : null,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User updated.')));
      setState(() => _userListRefreshKey++);
      await _loadUsers();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update user.')));
    }
  }

  Widget _buildPwdReqItem(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 14,
            color: met ? Colors.green.shade700 : Colors.blueGrey,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: met ? FontWeight.bold : FontWeight.normal,
                color: met ? Colors.green.shade800 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future< void > _showAlumniDialog({AlumniProfile? profile}) async {
    final isEditing = profile != null;
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    final positionCtrl = TextEditingController(
      text: (profile?.position.trim().isNotEmpty == true)
          ? profile!.position
          : (profile?.title ?? ''),
    );
    final companyCtrl = TextEditingController(text: profile?.company ?? '');
    final batchCtrl = TextEditingController(text: profile?.batchYear ?? '');
    final highlightCtrl = TextEditingController(text: profile?.highlight ?? '');
    final orderCtrl = TextEditingController(
      text: (profile?.displayOrder ?? DataService.alumniProfiles.length + 1)
          .toString(),
    );

    String imageUrl = profile?.imageUrl ?? ''; // existing saved image
    Uint8List? pickedBytes; // new image, not uploaded yet
    String? pickedName;
    bool isVisible = profile?.isVisible ?? true;
    bool isSaving = false;
    final formKey = GlobalKey<FormState>();

    const maxBytes = 5 * 1024 * 1024;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> pickImage() async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.image,
              allowMultiple: false,
              withData: true, // required on Android/iOS to get bytes
            );
            if (result == null || result.files.isEmpty)
              return; // canceled: keep current image

            final file = result.files.first;
            if (file.bytes == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not read the selected image.'),
                ),
              );
              return;
            }
            if (file.bytes!.lengthInBytes > maxBytes) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image must be 5 MB or smaller.')),
              );
              return;
            }
            setDialogState(() {
              pickedBytes = file.bytes;
              pickedName = file.name;
            });
          }

          Future<void> save() async {
            if (!formKey.currentState!.validate()) return;
            setDialogState(() => isSaving = true);

            try {
              var finalImageUrl = imageUrl;
              if (pickedBytes != null) {
                finalImageUrl = DataService.encodeAlumniImage(pickedBytes!);
              }

              final cleanPosition = positionCtrl.text.trim();
              final finalProfile = AlumniProfile(
                id:
                    profile?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameCtrl.text.trim(),
                title: cleanPosition,
                position: cleanPosition,
                company: companyCtrl.text.trim(),
                batchYear: batchCtrl.text.trim(),
                salary: profile?.salary ?? '',
                imageUrl: finalImageUrl,
                highlight: highlightCtrl.text.trim(),
                isVisible: isVisible,
                displayOrder: int.tryParse(orderCtrl.text.trim()) ?? 0,
                createdAt: profile?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );

              await DataService.saveAlumniProfile(finalProfile);

              if (!mounted) return;
              setState(() {});
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isEditing
                        ? 'Alumni profile updated.'
                        : 'Alumni profile added.',
                  ),
                ),
              );
            } catch (e) {
              debugPrint('Alumni save failed: $e');
              setDialogState(() => isSaving = false);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Save failed. Please try again. ($e)')),
              );
            }
          }

          Widget imagePreview() {
            const size = 96.0;
            if (pickedBytes != null) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  pickedBytes!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              );
            }
            if (imageUrl.isNotEmpty) {
              return alumniAvatar(imageUrl, size: size);
            }
            return _placeholder(size);
          }

          return AlertDialog(
            title: Text(
              isEditing ? 'Edit Alumni Profile' : 'Add Alumni Profile',
            ),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(child: imagePreview()),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: isSaving ? null : pickImage,
                        icon: const Icon(Icons.add_a_photo),
                        label: Text(
                          (pickedBytes != null || imageUrl.isNotEmpty)
                              ? 'Replace Image'
                              : 'Upload Image',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: positionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Position in the Company',
                          hintText: 'e.g., Fisheries Officer / Aquaculture Specialist',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: companyCtrl,
                        decoration: const InputDecoration(labelText: 'Company'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: batchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Batch Year',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: highlightCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Highlight',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: orderCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Display Order',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: isVisible,
                        onChanged: (value) =>
                            setDialogState(() => isVisible = value),
                        title: const Text('Visible on front page'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _placeholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // light blue, adjust to your theme
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.person, size: 48, color: Color(0xFF1976D2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adminName = AuthService.currentUser?.name.trim().isNotEmpty == true
        ? AuthService.currentUser!.name.trim()
        : 'FiBER Administrator';

   return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 0,
        title: const Text(
          'FiBER System Administration',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B3C5D),
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF0B3C5D)),
            tooltip: 'Log out',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await AuthService.logout();
                        if (!mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor:
            theme.drawerTheme.backgroundColor ?? theme.colorScheme.surface,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openFromSidebar(const AccountSettingsScreen()),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B3C5D), Color(0xFF0288D1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthService.buildProfileAvatar(
                        radius: 28,
                        fallbackIcon: Icons.admin_panel_settings_rounded,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        adminName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        AuthService.currentUser?.email ??
                            'Administrator Portal',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.manage_accounts_outlined,
                              size: 14,
                              color: Colors.cyanAccent,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Profile & Account Settings',
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 15,
                              color: Colors.cyanAccent,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _DrawerTile(
                icon: Icons.settings_outlined,
                title: 'System Settings',
                onTap: () => _openFromSidebar(const SystemSettingsScreen()),
              ),
              const SizedBox(height: 8),
              _DrawerTile(
                icon: Icons.info_outline,
                title: 'About Us',
                onTap: () => _openFromSidebar(const AboutUsScreen()),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      _buildAdminHeroBanner(adminName),
                      const SizedBox(height: 14),
                      _buildModernTabBar(),
                    ],
                  ),
                ),
                Expanded(
                  child: _selectedTab == 0
                      ? _buildSystemLogs(theme)
                      : _selectedTab == 1
                      ? _buildAppContent(theme)
                      : _buildUserAccounts(theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminHeroBanner(String adminName) {
    final totalUsers = _users.length;
    final totalAlumni = DataService.alumniProfiles.length;
    final totalLogs = DataService.systemLogs.length;
    final pendingReqs = _teacherRequests.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3C5D), Color(0xFF0288D1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0288D1).withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -12,
            child: Icon(
              Icons.shield_moon_rounded,
              size: 100,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $adminName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'CvSU-Naic Fisheries Board Exam Reviewer • Admin Control Center',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (pendingReqs > 0)
                    InkWell(
                      onTap: () => setState(() => _selectedTab = 2),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.notifications_active_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$pendingReqs Pending',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _heroStatItem(
                      Icons.people_alt_rounded,
                      '$totalUsers',
                      'Accounts',
                      Colors.cyanAccent,
                    ),
                    Container(width: 1, height: 32, color: Colors.white24),
                    _heroStatItem(
                      Icons.workspace_premium_rounded,
                      '$totalAlumni',
                      'BFAS Alumni',
                      Colors.amberAccent,
                    ),
                    Container(width: 1, height: 32, color: Colors.white24),
                    _heroStatItem(
                      Icons.receipt_long_rounded,
                      '$totalLogs',
                      'Activity Logs',
                      Colors.greenAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStatItem(
    IconData icon,
    String value,
    String label,
    Color iconColor,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _tabButton('Activity Logs', Icons.history_toggle_off_rounded, 0),
          _tabButton('App Content', Icons.view_carousel_rounded, 1),
          _tabButton('User Accounts', Icons.manage_accounts_rounded, 2),
        ],
      ),
    );
  }

  Widget _tabButton(String label, IconData icon, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
            if (index == 2) _userListRefreshKey++;
          });
          if (index == 0) {
            _refreshLogs();
          } else if (index == 2) {
            _loadUsers();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF0B3C5D), Color(0xFF0288D1)],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.cyanAccent : const Color(0xFF0B3C5D),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : const Color(0xFF0B3C5D),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemLogs(ThemeData theme) {
    final logs = DataService.systemLogs;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Activity Logs (${logs.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0B3C5D),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Sync Logs'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0277BD),
                  side: BorderSide(color: Colors.lightBlue.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _isLoadingLogs ? null : _refreshLogs,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoadingLogs && logs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : logs.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'No system activity logs recorded yet.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (_, i) {
                      final raw = logs[logs.length - 1 - i];
                      final isError = raw.contains('FAILED') ||
                          raw.contains('REJECTED') ||
                          raw.contains('DELETED');
                      final isSuccess = raw.contains('CREATED') ||
                          raw.contains('APPROVED') ||
                          raw.contains('ACTIVATED') ||
                          raw.contains('ADDED');
                      final badgeColor = isError
                          ? Colors.red.shade700
                          : isSuccess
                              ? Colors.green.shade700
                              : const Color(0xFF0277BD);
                      final badgeIcon = isError
                          ? Icons.warning_amber_rounded
                          : isSuccess
                              ? Icons.check_circle_outline_rounded
                              : Icons.info_outline_rounded;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: badgeColor.withOpacity(0.22),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: badgeColor.withOpacity(0.12),
                              child: Icon(
                                badgeIcon,
                                color: badgeColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                raw,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0B3C5D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppContent(ThemeData theme) {
    final modules = DataService.modules;
    final sortedAlumniProfiles = [...DataService.alumniProfiles]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Featured BFAS Alumni',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0B3C5D),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Add Alumni'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0277BD),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () => _showAlumniDialog(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sortedAlumniProfiles.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'No alumni profiles yet. Tap "Add Alumni" to feature BFAS graduates on the landing page.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            ...sortedAlumniProfiles.map(
              (alumni) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    alumniAvatar(alumni.imageUrl, size: 54),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  alumni.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF0B3C5D),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: alumni.isVisible
                                      ? Colors.green.shade50
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  alumni.isVisible ? 'Visible' : 'Hidden',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: alumni.isVisible
                                        ? Colors.green.shade800
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Position: ${alumni.position.trim().isNotEmpty ? alumni.position.trim() : alumni.title}${alumni.company.isNotEmpty ? ' • ${alumni.company}' : ''}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF0277BD),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Batch ${alumni.batchYear.isEmpty ? "N/A" : alumni.batchYear} • Display Order #${alumni.displayOrder}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        alumni.isVisible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: alumni.isVisible
                            ? Colors.green.shade700
                            : Colors.grey,
                      ),
                      tooltip: alumni.isVisible
                          ? 'Hide from landing page'
                          : 'Show on landing page',
                      onPressed: () async {
                        await DataService.saveAlumniProfile(
                          alumni.copyWith(
                            isVisible: !alumni.isVisible,
                            updatedAt: DateTime.now(),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF0277BD),
                      ),
                      onPressed: () => _showAlumniDialog(profile: alumni),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog< bool >(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            title: const Text('Delete Alumni Profile'),
                            content: Text(
                              'Remove ${alumni.name} from the landing page?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await DataService.deleteAlumniProfile(alumni.id);
                          if (mounted) setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          const Text(
            'Published Learning Materials',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF0B3C5D),
            ),
          ),
          const SizedBox(height: 10),
          if (modules.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'No learning materials uploaded yet.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            ...modules.map((module) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE1F5FE),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFF0277BD),
                    ),
                  ),
                  title: Text(
                    module.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B3C5D),
                    ),
                  ),
                  subtitle: Text(
                    'Category: ${module.category.toUpperCase()} • ${module.questions.length} Questions${module.classCode != null ? " • Class: ${module.classCode}" : ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildUserAccounts(ThemeData theme) {
    final query = _userSearchCtrl.text.trim().toLowerCase();
    final filteredUsers = _users.where((user) {
      final role = (user['role'] ?? 'student').toString().trim().toLowerCase();
      final matchesRole =
          _selectedRoleFilter == 'all' || role == _selectedRoleFilter;
      if (!matchesRole) return false;
      if (query.isEmpty) return true;
      final name = (user['name'] ?? '').toString().toLowerCase();
      final username = (user['username'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      return name.contains(query) ||
          username.contains(query) ||
          email.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registered Accounts (${filteredUsers.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0B3C5D),
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Create Teacher'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0277BD),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: _showCreateTeacherDialog,
                  ),
                  IconButton(
                    onPressed: _loadUsers,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF0B3C5D),
                    ),
                    tooltip: 'Refresh Accounts',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _userSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search accounts by name, username, or email...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: Color(0xFF0277BD),
              ),
              suffixIcon: _userSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _userSearchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.lightBlue.shade100),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.lightBlue.shade100),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRoleFilterChip('All Roles', 'all'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('Admins', 'admin'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('Teachers', 'teacher'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('Students', 'student'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoadingUsers
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    key: ValueKey(_userListRefreshKey),
                    children: [
                      if (_teacherRequests.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFE1F5FE),
                                Colors.lightBlue.shade50,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF0288D1).withOpacity(0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Color(0xFF0277BD),
                                    child: Icon(
                                      Icons.how_to_reg_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Pending Faculty Requests (${_teacherRequests.length})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF0B3C5D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ..._teacherRequests.map((req) {
                                final reqId = (req['id'] ?? '').toString();
                                final name = (req['name'] ?? '').toString();
                                final username =
                                    (req['username'] ?? '').toString();
                                final email = (req['email'] ?? '').toString();
                                final dept =
                                    (req['department'] ?? '').toString();
                                final isBusy = _processingRequestId == reqId;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name.isNotEmpty ? name : username,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Color(0xFF0B3C5D),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              'PENDING APPROVAL',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        email,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF0277BD),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (dept.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          dept,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: isBusy
                                                ? null
                                                : () =>
                                                    _handleRejectTeacherRequest(
                                                      req,
                                                    ),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                              color: Colors.redAccent,
                                            ),
                                            label: const Text(
                                              'Reject',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: Colors.redAccent,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: isBusy
                                                ? null
                                                : () =>
                                                    _handleApproveTeacherRequest(
                                                      req,
                                                    ),
                                            icon: isBusy
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.check_circle_outline,
                                                    size: 16,
                                                  ),
                                            label: const Text('Approve Faculty'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green.shade700,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                      if (filteredUsers.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: Text(
                              'No matching user accounts found.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        )
                      else
                        ...filteredUsers.map((user) {
                          final email = (user['email'] ?? '').toString();
                          final name = (user['name'] ?? '').toString();
                          final username = (user['username'] ?? '').toString();
                          final role = (user['role'] ?? 'student')
                              .toString()
                              .toLowerCase();
                          final dept = (user['department'] ?? '').toString();
                          final roleColor = role == 'admin'
                              ? Colors.deepPurple
                              : role == 'teacher'
                                  ? const Color(0xFF00897B)
                                  : const Color(0xFF0277BD);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: roleColor.withOpacity(0.14),
                                  child: Text(
                                    (name.isNotEmpty
                                            ? name[0]
                                            : email.isNotEmpty
                                                ? email[0]
                                                : 'U')
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: roleColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name.isNotEmpty
                                                  ? name
                                                  : username.isNotEmpty
                                                      ? username
                                                      : email,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.5,
                                                color: Color(0xFF0B3C5D),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: roleColor.withOpacity(
                                                0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              role.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: roleColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        email,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      if (dept.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          dept,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: roleColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xFF0277BD),
                                  ),
                                  tooltip: 'Edit Account',
                                  onPressed: () => _showUserEditDialog(user),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Delete Account',
                                  onPressed: () => _deleteUser(user),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip(String label, String value) {
    final selected = _selectedRoleFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF0288D1),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF0B3C5D),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedRoleFilter = value),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.08),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
