import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../models/module_model.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/performance_service.dart';
import 'module_viewer.dart';

class ClassManagement extends StatefulWidget {
  const ClassManagement({super.key});

  @override
  State<ClassManagement> createState() => _ClassManagementState();
}

class _ClassManagementState extends State<ClassManagement> {
  final TextEditingController _nameCtrl = TextEditingController();
  bool _loadingClasses = true;

  @override
  void initState() {
    super.initState();
    _refreshClasses();
  }

  List< ClassRoom > get _teacherClasses =>
      DataService.getClassesForTeacher(AuthService.currentUser?.id);

  Future< void > _refreshClasses() async {
    await DataService.loadModules();
    await DataService.loadClasses(uid: AuthService.currentUser?.id);
    if (mounted) {
      setState(() => _loadingClasses = false);
    }
  }

  void _showEditClassDialog(ClassRoom classRoom) {
    final editCtrl = TextEditingController(text: classRoom.name);
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit Class (${classRoom.id})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: editCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Class Name',
              errorText: errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) {
              if (errorText != null) {
                setDialogState(() => errorText = null);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0277BD),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newName = editCtrl.text.trim();
                if (newName.isEmpty) {
                  setDialogState(
                    () => errorText = 'Class name cannot be empty.',
                  );
                  return;
                }
                final uid = AuthService.currentUser?.id ?? '';
                await DataService.updateClassDetails(
                  classCode: classRoom.id,
                  newName: newName,
                  teacherId: uid,
                  teacherEmail: AuthService.currentUser?.email,
                );
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Updated class name to "$newName".'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteClass(ClassRoom classRoom) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Delete Class?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${classRoom.name}" (${classRoom.id})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() => _loadingClasses = true);
              final uid = AuthService.currentUser?.id ?? '';
              await DataService.deleteClassByCode(
                classCode: classRoom.id,
                teacherId: uid,
                teacherEmail: AuthService.currentUser?.email,
              );
              if (!mounted) return;
              setState(() => _loadingClasses = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ Permanently deleted class "${classRoom.name}" (${classRoom.id}).',
                  ),
                  backgroundColor: Colors.green.shade700,
                ),
              );
            },
            child: const Text('Delete Class'),
          ),
        ],
      ),
    );
  }

  // ── Generate unique FIBER-XXXX class code ─────────────────────
  String _generateClassCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final existing = DataService.classes.map((c) => c.id.toUpperCase()).toSet();
    String code;
    do {
      final suffix = List.generate(
        4,
        (_) => chars[random.nextInt(chars.length)],
      ).join();
      code = 'FIBER-$suffix';
    } while (existing.contains(code));
    return code;
  }

  void _showCreateClassDialog() {
    _nameCtrl.clear();
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B3C5D), Color(0xFF0277BD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: const Row(
              children: [
                Icon(Icons.add_business_rounded, color: Colors.cyanAccent),
                SizedBox(width: 10),
                Text(
                  'Create a New Class',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter the class or section name below. A unique FIBER-XXXX class code will be generated automatically for your students.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Class Name (e.g., BSFi 4A - Aquaculture)',
                    filled: true,
                    fillColor: const Color(0xFFF8FBFF),
                    errorText: errorText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) {
                    if (errorText != null) {
                      setDialogState(() => errorText = null);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Create Class'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0277BD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final name = _nameCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(
                    () => errorText = 'Please enter a class name.',
                  );
                  return;
                }
                final code = _generateClassCode();
                DataService.createClassWithCode(
                  name,
                  code,
                  teacherId: AuthService.currentUser?.id,
                  teacherEmail: AuthService.currentUser?.email,
                );
                _nameCtrl.clear();
                Navigator.pop(dialogCtx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Created "$name" (Class Code: $code)'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openClassStudents(ClassRoom classRoom) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassStudentsScreen(classRoom: classRoom),
      ),
    );
  }

  static const List< List< Color > > _bannerGradients = [
    [Color(0xFF0B3C5D), Color(0xFF0288D1)],
    [Color(0xFF004D40), Color(0xFF00897B)],
    [Color(0xFF1A237E), Color(0xFF3949AB)],
    [Color(0xFF01579B), Color(0xFF00ACC1)],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Class Management',
          style: TextStyle(
            color: Color(0xFF0B3C5D),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: _showCreateClassDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Class'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0277BD),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0B3C5D)),
            tooltip: 'Refresh classes',
            onPressed: () {
              setState(() => _loadingClasses = true);
              _refreshClasses();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loadingClasses
            ? const Center(child: CircularProgressIndicator())
            : _teacherClasses.isEmpty
            ? Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.lightBlue.shade50,
                        child: const Icon(
                          Icons.school_outlined,
                          size: 38,
                          color: Color(0xFF0277BD),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Classes Created Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B3C5D),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a class to generate a unique FIBER-XXXX class code and track your students\' board exam readiness.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _showCreateClassDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Your First Class'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0277BD),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                itemCount: _teacherClasses.length,
                itemBuilder: (_, i) {
                  final c = _teacherClasses[i];
                  final colors = _bannerGradients[i % _bannerGradients.length];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _openClassStudents(c),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Google Classroom-style Top Banner
                            Container(
                              height: 108,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: colors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: -10,
                                    bottom: -18,
                                    child: Icon(
                                      Icons.set_meal_rounded,
                                      size: 92,
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              c.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.greenAccent
                                                  .withOpacity(0.22),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.greenAccent,
                                              ),
                                            ),
                                            child: const Text(
                                              '● Active',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Fisheries Board Exam Review Class',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Bottom Bar with Class Code Chip & Action
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: LayoutBuilder(
                                builder: (context, cardConstraints) {
                                  final isNarrow =
                                      cardConstraints.maxWidth < 360;
                                  return Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 10,
                                    children: [
                                      InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () {
                                          Clipboard.setData(
                                            ClipboardData(text: c.id),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Copied Class Code: ${c.id}',
                                              ),
                                              duration: const Duration(
                                                seconds: 1,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEAF7FF),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.lightBlue.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.key_rounded,
                                                size: 15,
                                                color: Color(0xFF0277BD),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                c.id,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Color(0xFF0B3C5D),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.copy_rounded,
                                                size: 14,
                                                color: Color(0xFF0277BD),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0F8FF),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color:
                                                    Colors.lightBlue.shade100,
                                              ),
                                            ),
                                            child: IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              constraints:
                                                  const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              padding: const EdgeInsets.all(6),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: Color(0xFF0277BD),
                                              ),
                                              tooltip: 'Edit Class Name',
                                              onPressed: () =>
                                                  _showEditClassDialog(c),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.red.shade100,
                                              ),
                                            ),
                                            child: IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              constraints:
                                                  const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              padding: const EdgeInsets.all(6),
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: Colors.redAccent,
                                              ),
                                              tooltip: 'Delete Class',
                                              onPressed: () =>
                                                  _confirmDeleteClass(c),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // ── Section 5.1: Dedicated Open Class Container ──
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            onTap: () => _openClassStudents(c),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isNarrow ? 11 : 14,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF0B3C5D),
                                                    Color(0xFF0288D1),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.meeting_room_rounded,
                                                    size: 15,
                                                    color: Colors.cyanAccent,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Open Class',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  SizedBox(width: 4),
                                                  Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 15,
                                                    color: Colors.white,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  4-Tab Teacher Class Portal (Module Library, Mini Quizzes,
//  Mock Exams, and Enrolled Students)
// ══════════════════════════════════════════════════════════════════
class ClassStudentsScreen extends StatefulWidget {
  final ClassRoom classRoom;

  const ClassStudentsScreen({super.key, required this.classRoom});

  @override
  State< ClassStudentsScreen > createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State< ClassStudentsScreen > {
  int _selectedSection = 0; // 0: Module Library, 1: Mini Quizzes, 2: Mock Exams, 3: Enrolled Students
  late Future< List< dynamic > > _studentsFuture;

  @override
  void initState() {
    super.initState();
    DataService.moduleUpdateNotifier.addListener(_onDataUpdated);
    _studentsFuture = DataService.getStudentsInClass(widget.classRoom.id);
  }

  @override
  void dispose() {
    DataService.moduleUpdateNotifier.removeListener(_onDataUpdated);
    super.dispose();
  }

  void _onDataUpdated() {
    if (mounted) setState(() {});
  }

  Future< void > _refresh() async {
    await DataService.loadModules();
    if (!mounted) return;
    setState(() {
      _studentsFuture = DataService.getStudentsInClass(widget.classRoom.id);
    });
  }

  List< Module > _materialsForCategory(String category) {
    final targetCode = widget.classRoom.id.trim().toUpperCase();
    return DataService.modules.where((m) {
      final code = (m.classCode ?? '').trim().toUpperCase();
      return code == targetCode && m.category == category;
    }).toList();
  }

  Future< void > _confirmDeleteMaterial(Module module) async {
    final confirmed = await showDialog< bool >(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Material?'),
        content: Text(
          'Remove "${module.title}" from ${widget.classRoom.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DataService.deleteModuleById(
        module.id,
        actorEmail: AuthService.currentUser?.email,
      );
      if (mounted) setState(() {});
    }
  }

  Future< void > _confirmRemoveStudent(Map< String, dynamic > student) async {
    final studentId = (student['id'] ?? '').toString();
    final email = (student['email'] ?? '').toString();
    final name = (student['name'] ?? email).toString();
    if (studentId.isEmpty) return;

    final confirmed = await showDialog< bool >(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remove Student from Class?'),
        content: Text(
          'Remove $name ($email) from "${widget.classRoom.name}" (${widget.classRoom.id})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove Student'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DataService.removeStudentFromClass(
        classCode: widget.classRoom.id,
        studentUid: studentId,
        studentEmail: email,
        teacherEmail: AuthService.currentUser?.email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed $name from ${widget.classRoom.name}.')),
      );
      _refresh();
    }
  }

  Widget _buildSectionTab(String label, IconData icon, int index) {
    final selected = _selectedSection == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSection = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF0B3C5D), Color(0xFF0288D1)],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? Colors.cyanAccent : const Color(0xFF0B3C5D),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : const Color(0xFF0B3C5D),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialList({
    required String category,
    required String title,
    required String emptyMessage,
    required IconData icon,
    required Color accentColor,
  }) {
    final items = _materialsForCategory(category);
    if (items.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: accentColor.withOpacity(0.12),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final m = items[index];
        final cleanFileName = DataService.cleanOriginalFileName(m);
        final fileTypeLabel = DataService.formatTypeLabel(m);
        final fileSizeLabel = DataService.formatBytesLabel(m.fileSize);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: accentColor.withOpacity(0.12),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'File Name: $cleanFileName',
                          softWrap: true,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: Color(0xFF0B3C5D),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'File Type: $fileTypeLabel',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'File Size: $fileSizeLabel',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Class: ${widget.classRoom.name} (${m.classCode ?? widget.classRoom.id})',
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${m.questions.length} Qs',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 17),
                      label: Text(
                        'Open & Preview $title',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ModuleViewer(module: m),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _confirmDeleteMaterial(m),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnrolledStudentsList() {
    return FutureBuilder< List< dynamic > >(
      future: _studentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = snapshot.data ?? [];
        if (students.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'No students have joined "${widget.classRoom.name}" yet.\nShare class code ${widget.classRoom.id} with your students.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final s = Map< String, dynamic >.from(students[index] as Map);
            final name = (s['name'] ?? '').toString().trim();
            final username = (s['username'] ?? '').toString().trim();
            final email = (s['email'] ?? '').toString().trim();
            final displayName = name.isNotEmpty
                ? name
                : (username.isNotEmpty ? username : email);
            final studySec = (s['studySeconds'] as int?) ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF0288D1),
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF0B3C5D),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.lightBlue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: Color(0xFF0277BD),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DataService.formatStudySeconds(studySec),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B3C5D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.analytics_outlined, size: 17),
                          label: const Text(
                            'View Student Dashboard',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0277BD),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeacherStudentDashboardView(
                                  studentId: s['id'].toString(),
                                  studentName: displayName,
                                  studentEmail: email,
                                  initialStudySeconds: studySec,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _confirmRemoveStudent(s),
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'Remove',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.classRoom.name} (${widget.classRoom.id})',
          style: const TextStyle(
            color: Color(0xFF0B3C5D),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0B3C5D)),
            tooltip: 'Refresh Class Data',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(5),
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
                  _buildSectionTab(
                    'Modules',
                    Icons.menu_book_rounded,
                    0,
                  ),
                  _buildSectionTab(
                    'Mini Quizzes',
                    Icons.quiz_outlined,
                    1,
                  ),
                  _buildSectionTab(
                    'Mock Exams',
                    Icons.assignment_outlined,
                    2,
                  ),
                  _buildSectionTab(
                    'Students',
                    Icons.groups_rounded,
                    3,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _selectedSection == 0
                ? _buildMaterialList(
                    category: 'module',
                    title: 'Module Library',
                    emptyMessage:
                        'No study modules, pictures, or videos uploaded to ${widget.classRoom.name} yet.',
                    icon: Icons.menu_book_rounded,
                    accentColor: Colors.teal.shade700,
                  )
                : _selectedSection == 1
                ? _buildMaterialList(
                    category: 'quiz',
                    title: 'Mini Quizzes',
                    emptyMessage:
                        'No Mini Quizzes uploaded to ${widget.classRoom.name} yet.',
                    icon: Icons.quiz_outlined,
                    accentColor: const Color(0xFF0277BD),
                  )
                : _selectedSection == 2
                ? _buildMaterialList(
                    category: 'mock_exam',
                    title: 'Mock Exams',
                    emptyMessage:
                        'No Mock Exams uploaded to ${widget.classRoom.name} yet.',
                    icon: Icons.assignment_outlined,
                    accentColor: Colors.deepPurple,
                  )
                : _buildEnrolledStudentsList(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Individual Student Dashboard View (For Teachers)
// ══════════════════════════════════════════════════════════════════
class TeacherStudentDashboardView extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String studentEmail;
  final int initialStudySeconds;

  const TeacherStudentDashboardView({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.initialStudySeconds,
  });

  @override
  State<TeacherStudentDashboardView> createState() =>
      _TeacherStudentDashboardViewState();
}

class _TeacherStudentDashboardViewState
    extends State< TeacherStudentDashboardView > {
  late Future< StudentPerformanceSummary? > _summaryFuture;
  late Future< StudentActivityCounts > _countsFuture;
  late Future< List< dynamic > > _recentAssessmentsFuture;
  late Future< int > _studySecondsFuture;

  StreamSubscription< DocumentSnapshot< Map< String, dynamic > > >?
      _studentDocSub;
  StreamSubscription< QuerySnapshot< Map< String, dynamic > > >?
      _assessmentsSub;
  bool _isRefreshing = false;
  String _historyFilter = 'all'; // 'all', 'mock_exam', 'quiz'

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtimeStudentExamUpdates();
  }

  @override
  void dispose() {
    _studentDocSub?.cancel();
    _assessmentsSub?.cancel();
    super.dispose();
  }

  void _subscribeRealtimeStudentExamUpdates() {
    try {
      _studentDocSub = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .snapshots()
          .listen((_) {
        if (mounted && !_isRefreshing) {
          setState(_loadData);
        }
      }, onError: (_) {});

      _assessmentsSub = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .collection('assessment_results')
          .snapshots()
          .listen((_) {
        if (mounted && !_isRefreshing) {
          setState(_loadData);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _loadData() {
    _summaryFuture = PerformanceService.loadLatestSummary(
      uid: widget.studentId,
    );
    _countsFuture = PerformanceService.loadStudentActivityCounts(
      uid: widget.studentId,
    );
    _recentAssessmentsFuture = _fetchRecentAssessments();
    _studySecondsFuture = _fetchLatestStudySeconds();
  }

  Future< void > _manualRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _loadData();
    });
    try {
      await Future.wait< dynamic >(< Future< dynamic > >[
        _summaryFuture,
        _countsFuture,
        _recentAssessmentsFuture,
        _studySecondsFuture,
      ]);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isRefreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Synced latest student mock exam & quiz records.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future< int > _fetchLatestStudySeconds() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .get();
      return (doc.data()?['studySeconds'] as num?)?.toInt() ??
          widget.initialStudySeconds;
    } catch (_) {
      return widget.initialStudySeconds;
    }
  }

  Future< List< dynamic > > _fetchRecentAssessments() async {
    try {
      // Uses PerformanceService.loadAssessmentHistory which merges both
      // users/{uid}.assessmentResultsList and users/{uid}/assessment_results
      // and sorts chronologically by completedAtIso descending.
      return await PerformanceService.loadAssessmentHistory(
        uid: widget.studentId,
      );
    } catch (_) {
      return < dynamic >[];
    }
  }

  String _formatExamDate(Map< String, dynamic > r) {
    final rawIso = (r['completedAtIso'] ?? r['completedAt'] ?? '').toString();
    final parsed = DateTime.tryParse(rawIso)?.toLocal();
    if (parsed == null) return 'Recently Completed';
    final y = parsed.year;
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return '$y-$m-$d • $hh:$mm';
  }

  void _showTeacherExamAnswerReview(Map< String, dynamic > record) {
    final details = (record['answerDetails'] as List< dynamic >? ?? const [])
        .whereType< Map >()
        .map((e) => Map< String, dynamic >.from(e))
        .toList();
    final title =
        (record['moduleTitle'] ?? record['subject'] ?? 'Examination')
            .toString();
    final score = record['score'] ?? 0;
    final total = record['total'] ?? 0;
    final pct = (record['percentage'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 440,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$title — Score: $score/$total (${pct.toStringAsFixed(1)}%)',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B3C5D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Completed: ${_formatExamDate(record)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: details.isEmpty
                      ? const Center(
                          child: Text(
                            'No per-question details recorded for this attempt.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: details.length,
                          itemBuilder: (_, i) {
                            final item = details[i];
                            final ok = item['isCorrect'] == true;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: ok
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      ok ? Colors.green : Colors.red,
                                  child: Text(
                                    ok ? '✓' : '✗',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  'Item ${i + 1}: ${item['question'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  'Student Answer: ${item['selectedChoice'] ?? ''}\nCorrect Answer: ${item['correctChoice'] ?? ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "${widget.studentName}'s Dashboard",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: OutlinedButton.icon(
              onPressed: _isRefreshing ? null : _manualRefresh,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: Text(_isRefreshing ? 'Syncing...' : 'Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0277BD),
                side: BorderSide(color: Colors.lightBlue.shade200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Student Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.lightBlue.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.lightBlueAccent,
                  child: Text(
                    widget.studentName.isNotEmpty
                        ? widget.studentName[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.studentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.studentEmail,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Top KPI Row: Study Time, Overall Accuracy, Assessments Completed
          FutureBuilder<List< dynamic >>(
            future: Future.wait([_studySecondsFuture, _summaryFuture]),
            builder: (context, snap) {
              final studySec = (snap.data != null && snap.data!.isNotEmpty)
                  ? (snap.data![0] as int)
                  : widget.initialStudySeconds;
              final summary = (snap.data != null && snap.data!.length > 1)
                  ? (snap.data![1] as StudentPerformanceSummary?)
                  : null;
              final accuracy = summary?.overallAverage ?? 0.0;
              final completed = summary?.completedAssessments ?? 0;

              return Row(
                children: [
                  Expanded(
                    child: _metricTile(
                      icon: Icons.timer_outlined,
                      label: 'Study Time',
                      value: DataService.formatStudySeconds(studySec),
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricTile(
                      icon: Icons.verified_outlined,
                      label: 'Accuracy',
                      value: '${accuracy.toStringAsFixed(1)}%',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricTile(
                      icon: Icons.assignment_turned_in_outlined,
                      label: 'Completed',
                      value: '$completed',
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Subject Performance & Accuracy Breakdown
          FutureBuilder<StudentPerformanceSummary?>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final summary = snapshot.data;
              final subjects =
                  summary?.subjects ?? const <SubjectPerformance>[];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subject Performance & Accuracy',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (subjects.isEmpty)
                      const Text(
                        'This student has not completed any quizzes or mock exams yet.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      )
                    else
                      ...subjects.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.subject} (${item.attempts} attempt${item.attempts == 1 ? '' : 's'})',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    '${item.totalScore}/${item.totalPossible} • ${item.averagePercent.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: (item.averagePercent / 100).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  minHeight: 10,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: const AlwaysStoppedAnimation(
                                    Colors.lightBlueAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Activity Overview (Quizzes, Mock Exams, Games)
          FutureBuilder<StudentActivityCounts>(
            future: _countsFuture,
            builder: (context, snapshot) {
              final counts = snapshot.data ?? StudentActivityCounts.empty;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activity Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Mini Quizzes Taken: ${counts.quizzes}'),
                    const SizedBox(height: 6),
                    Text('Mock Exams Taken: ${counts.mockExams}'),
                    const SizedBox(height: 6),
                    Text('Educational Mini Games Played: ${counts.games}'),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Detailed Mock Exam & Quiz History (Real-Time Synced + Filterable)
          FutureBuilder< List< dynamic > >(
            future: _recentAssessmentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text(
                          'Retrieving latest examination history...',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final allResults = snapshot.data ?? const < dynamic >[];
              final filteredResults = allResults.where((raw) {
                final r = Map< String, dynamic >.from(raw as Map);
                final rawType = (r['type'] ?? '').toString().toLowerCase();
                if (_historyFilter == 'mock_exam') {
                  return rawType == 'mock_exam';
                }
                if (_historyFilter == 'quiz') {
                  return rawType == 'quiz';
                }
                return true;
              }).toList();

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Mock Exam & Assessment History (Live)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_isRefreshing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text('All (${allResults.length})'),
                          selected: _historyFilter == 'all',
                          onSelected: (_) =>
                              setState(() => _historyFilter = 'all'),
                        ),
                        ChoiceChip(
                          label: const Text('Mock Exams'),
                          selected: _historyFilter == 'mock_exam',
                          onSelected: (_) =>
                              setState(() => _historyFilter = 'mock_exam'),
                        ),
                        ChoiceChip(
                          label: const Text('Mini Quizzes'),
                          selected: _historyFilter == 'quiz',
                          onSelected: (_) =>
                              setState(() => _historyFilter = 'quiz'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filteredResults.isEmpty)
                      const Text(
                        'No recorded examination attempts found for this filter yet.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      )
                    else
                      ...filteredResults.map((raw) {
                        final r = Map< String, dynamic >.from(raw as Map);
                        final type = (r['type'] ?? 'quiz')
                            .toString()
                            .toUpperCase()
                            .replaceAll('_', ' ');
                        final subject =
                            (r['moduleTitle'] ?? r['subject'] ?? 'General')
                                .toString();
                        final score = r['score'] ?? 0;
                        final total = r['total'] ?? 0;
                        final pct =
                            (r['percentage'] as num?)?.toDouble() ?? 0.0;
                        final durationSec =
                            (r['durationSeconds'] as num?)?.toInt() ?? 0;
                        final hasDetails =
                            (r['answerDetails'] as List< dynamic >? ?? const [])
                                .isNotEmpty;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FBFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: type.contains('EXAM')
                                  ? Colors.deepPurple.shade100
                                  : Colors.lightBlue.shade100,
                            ),
                          ),
                          child: ListTile(
                            onTap: hasDetails
                                ? () => _showTeacherExamAnswerReview(r)
                                : null,
                            leading: CircleAvatar(
                              backgroundColor: type.contains('EXAM')
                                  ? Colors.deepPurple.withOpacity(0.15)
                                  : Colors.blue.withOpacity(0.15),
                              child: Icon(
                                type.contains('EXAM')
                                    ? Icons.assignment
                                    : Icons.quiz,
                                color: type.contains('EXAM')
                                    ? Colors.deepPurple
                                    : Colors.blue,
                              ),
                            ),
                            title: Text(
                              '$type — $subject',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Score: $score / $total (${pct.toStringAsFixed(1)}%) • ${ durationSec > 0 ? "${DataService.formatStudySeconds(durationSec)} • " : ""}${_formatExamDate(r)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: hasDetails
                                ? const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF0277BD),
                                  )
                                : null,
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}