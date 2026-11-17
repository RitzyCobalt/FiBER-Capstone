import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/module_model.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'mock_exam.dart';
import 'module_viewer.dart';
import 'quiz.dart';

class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({super.key});

  @override
  State< JoinClassScreen > createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State< JoinClassScreen > {
  bool _isRefreshing = false;
  final TextEditingController _inlineCodeCtrl = TextEditingController();
  String? _inlineJoinError;

  List< String > get _joinedClasses => DataService.joinedClassCodes;

  @override
  void initState() {
    super.initState();
    DataService.moduleUpdateNotifier.addListener(_onDataUpdated);
  }

  @override
  void dispose() {
    _inlineCodeCtrl.dispose();
    DataService.moduleUpdateNotifier.removeListener(_onDataUpdated);
    super.dispose();
  }

  void _submitInlineJoin() {
    final code = _inlineCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _inlineJoinError = 'Please enter a class code.');
      return;
    }
    if (DataService.hasJoinedClass(code)) {
      setState(() => _inlineJoinError = 'You already joined $code.');
      return;
    }
    final ok = DataService.joinClass(code, uid: AuthService.currentUser?.id);
    if (ok) {
      _inlineCodeCtrl.clear();
      setState(() => _inlineJoinError = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Successfully enrolled in $code!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
      setState(
        () => _inlineJoinError = 'Class not found. Check the code.',
      );
    }
  }

  Future< void > _confirmUnenroll(ClassRoom classRoom) async {
    final confirmed = await showDialog< bool >(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Unenroll from Class?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to unenroll from "${classRoom.name}" (${classRoom.id})?',
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
            child: const Text('Unenroll'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DataService.unenrollFromClass(
        classRoom.id,
        uid: AuthService.currentUser?.id,
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unenrolled from ${classRoom.name}.'),
        ),
      );
    }
  }

  void _onDataUpdated() {
    if (mounted) setState(() {});
  }

  Future< void > _refreshClassesAndModules() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await DataService.loadModules();
    await DataService.loadClasses(uid: AuthService.currentUser?.id);
    if (!mounted) return;
    setState(() => _isRefreshing = false);
  }

  void _showJoinDialog() {
    final codeCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Join Class',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter class code (e.g., FIBER-2026)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  errorText: error,
                ),
                onChanged: (_) => setDialogState(() => error = null),
              ),
            ],
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
              onPressed: () {
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.isEmpty) {
                  setDialogState(() => error = 'Please enter a class code');
                  return;
                }

                if (DataService.hasJoinedClass(code)) {
                  setDialogState(() => error = 'You already joined this class');
                  return;
                }

                final success = DataService.joinClass(
                  code,
                  uid: AuthService.currentUser?.id,
                );
                if (success) {
                  setState(() {});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Joined class successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  setDialogState(
                    () => error = 'Class not found. Check the code.',
                  );
                }
              },
              child: const Text('Join Class'),
            ),
          ],
        ),
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 0,
        leading: BackButton(color: theme.colorScheme.onSurface),
        title: Text(
          'My Classes',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Classes',
            onPressed: _isRefreshing ? null : _refreshClassesAndModules,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Join Class'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0277BD),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _showJoinDialog,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _joinedClasses.isEmpty
            ? Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.lightBlue.shade50,
                        child: const Icon(
                          Icons.class_outlined,
                          size: 36,
                          color: Color(0xFF0277BD),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Joined Classes Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B3C5D),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the FIBER-XXXX class code from your teacher to access class Mini Quizzes, Mock Exams, and Module Folders.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Enter Class Code'),
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
                        onPressed: _showJoinDialog,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                itemCount: _joinedClasses.length,
                itemBuilder: (_, i) {
                  final code = _joinedClasses[i];
                  final classRoom = DataService.classes.firstWhere(
                    (c) => c.id.toUpperCase() == code.toUpperCase(),
                    orElse: () => ClassRoom(id: code, name: 'Class $code'),
                  );
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ClassPortalScreen(classRoom: classRoom),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 104,
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
                                    right: -8,
                                    bottom: -16,
                                    child: Icon(
                                      Icons.school_rounded,
                                      size: 88,
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
                                              classRoom.name,
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
                                        'Class Code: $code',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.folder_copy_outlined,
                                    size: 16,
                                    color: Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'Modules • Quizzes • Exams',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _confirmUnenroll(classRoom),
                                    icon: const Icon(
                                      Icons.exit_to_app_rounded,
                                      size: 15,
                                      color: Colors.redAccent,
                                    ),
                                    label: const Text(
                                      'Unenroll',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Open Class',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0277BD),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: Color(0xFF0277BD),
                                  ),
                                ],
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
//  Structured Class Portal (Google Classroom Stream Style:
//  Class Name, Active, Class Code, Mini Quizzes, Mock Exams, Module Folders)
// ══════════════════════════════════════════════════════════════════
class ClassPortalScreen extends StatefulWidget {
  final ClassRoom classRoom;

  const ClassPortalScreen({super.key, required this.classRoom});

  @override
  State< ClassPortalScreen > createState() => _ClassPortalScreenState();
}

class _ClassPortalScreenState extends State< ClassPortalScreen > {
  bool _isRefreshing = false;

  ClassRoom get classRoom => widget.classRoom;

  @override
  void initState() {
    super.initState();
    DataService.moduleUpdateNotifier.addListener(_onUpdated);
  }

  @override
  void dispose() {
    DataService.moduleUpdateNotifier.removeListener(_onUpdated);
    super.dispose();
  }

  void _onUpdated() {
    if (mounted) setState(() {});
  }

  Future< void > _refreshClassPortal() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await DataService.loadModules();
    await DataService.loadClasses(uid: AuthService.currentUser?.id);
    if (!mounted) return;
    setState(() => _isRefreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshed class modules, quizzes, and mock exams.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetClassCode = classRoom.id.trim().toUpperCase();
    final allModules = DataService.modules.where((m) {
      return m.isPublished &&
          (m.classCode ?? '').trim().toUpperCase() == targetClassCode;
    }).toList();

    final miniQuizzes =
        allModules.where((m) => m.category == 'quiz').toList();
    final mockExams =
        allModules.where((m) => m.category == 'mock_exam').toList();
    final moduleFolders =
        allModules.where((m) => m.category == 'module').toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          classRoom.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Class Materials',
            onPressed: _isRefreshing ? null : _refreshClassPortal,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Google Classroom-Style Hero Stream Banner ──
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B3C5D), Color(0xFF0288D1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -12,
                  bottom: -20,
                  child: Icon(
                    Icons.set_meal_rounded,
                    size: 110,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            classRoom.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.greenAccent),
                          ),
                          child: const Text(
                            '● Active',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: classRoom.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Class code copied!')),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.key_rounded,
                              size: 16,
                              color: Colors.cyanAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Class Code: ${classRoom.id}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.copy_rounded,
                              size: 15,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Section 1: Mini Quizzes ──
          _sectionCard(
            title: 'Mini Quizzes',
            subtitle: 'Short topic drills with instant answer feedback',
            icon: Icons.quiz_outlined,
            color: const Color(0xFF0277BD),
            emptyText: 'No mini quizzes available in this class yet.',
            items: miniQuizzes,
            onTapItem: (m) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MiniQuiz(initialModule: m)),
              );
            },
            actionLabel: 'Take Quiz',
          ),
          const SizedBox(height: 16),

          // ── Section 2: Mock Exams ──
          _sectionCard(
            title: 'Mock Exams',
            subtitle: 'Full timed Fisheries Board Exam simulations',
            icon: Icons.assignment_outlined,
            color: Colors.deepPurple,
            emptyText: 'No mock exams available in this class yet.',
            items: mockExams,
            onTapItem: (m) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MockExam(initialModule: m)),
              );
            },
            actionLabel: 'Start Exam',
          ),
          const SizedBox(height: 16),

          // ── Section 3: Module Folders ──
          _sectionCard(
            title: 'Module Folders',
            subtitle: 'Study handouts, reviewers, and lecture slides',
            icon: Icons.folder_open_rounded,
            color: Colors.teal.shade700,
            emptyText: 'No learning modules uploaded to this class yet.',
            items: moduleFolders,
            onTapItem: (m) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ModuleViewer(module: m)),
              );
            },
            actionLabel: 'Open Module',
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String emptyText,
    required List< Module > items,
    required void Function(Module) onTapItem,
    required String actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
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
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              emptyText,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            )
          else
            ...items.map((m) {
              final cleanFileName = DataService.cleanOriginalFileName(m);
              final fileTypeLabel = DataService.formatTypeLabel(m);
              final fileSizeLabel = DataService.formatBytesLabel(m.fileSize);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.18)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTapItem(m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(icon, color: color, size: 22),
                          ),
                          const SizedBox(width: 10),
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
                                    fontSize: 13.5,
                                    color: Color(0xFF0B3C5D),
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'File Type: $fileTypeLabel',
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'File Size: $fileSizeLabel',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Class: ${classRoom.name} (${classRoom.id}) • ${m.questions.length} Qs',
                                  softWrap: true,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () => onTapItem(m),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            actionLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}