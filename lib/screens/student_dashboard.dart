import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/module_model.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/performance_service.dart';
import 'about_us.dart';
import 'account_settings.dart';
import 'flashcards.dart';
import 'help_page.dart';
import 'join_class_screen.dart';
import 'mock_exam.dart';
import 'module_library.dart';
import 'quiz.dart';
import 'statistics_history_page.dart';
import 'system_settings.dart';
import 'word_hunt_game.dart';
import 'word_shark_game.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State< StudentHome >
    with WidgetsBindingObserver {
  final GlobalKey< ScaffoldState > _scaffoldKey = GlobalKey< ScaffoldState >();
  final TextEditingController _inlineClassCodeCtrl = TextEditingController();
  final PageController _subjectCarouselController = PageController(
    viewportFraction: 0.92,
  );
  int _currentSubjectSlide = 0;
  String? _joinClassError;
  bool _isRefreshing = false;
  Timer? _uiRefreshTimer;
  late Stream< StudentPerformanceSummary > _summaryStream =
      PerformanceService.watchSummary(uid: AuthService.currentUser?.id);
  late Stream< StudentActivityCounts > _activityCountsStream =
      PerformanceService.watchActivityCounts(uid: AuthService.currentUser?.id);

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              DataService.stopStudyTimer(uid: AuthService.currentUser?.id);
              DataService.resetStudyTimer();
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
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final uid = AuthService.currentUser?.id;
    _summaryStream = PerformanceService.watchSummary(uid: uid);
    _activityCountsStream = PerformanceService.watchActivityCounts(uid: uid);
    DataService.moduleUpdateNotifier.addListener(_onModuleUpdated);
    _initRealtimeStudentData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isInactiveOrBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
    DataService.setAppLifecyclePaused(isInactiveOrBackground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subjectCarouselController.dispose();
    _inlineClassCodeCtrl.dispose();
    _uiRefreshTimer?.cancel();
    DataService.moduleUpdateNotifier.removeListener(_onModuleUpdated);
    super.dispose();
  }

  void _onModuleUpdated() {
    if (mounted) setState(() {});
  }

  Future< void > _initRealtimeStudentData() async {
    if (AuthService.currentUser == null) {
      await AuthService.restoreSession();
    }
    final uid = AuthService.currentUser?.id;
    DataService.startRealtimeSync(uid: uid);
    await DataService.loadModules();
    await DataService.loadClasses(uid: uid);
    if (uid != null && uid.isNotEmpty) {
      _summaryStream = PerformanceService.watchSummary(uid: uid);
      _activityCountsStream = PerformanceService.watchActivityCounts(uid: uid);
    }
    if (mounted) setState(() {});
  }

  void _handleInlineJoinClass() {
    final code = _inlineClassCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _joinClassError = 'Please enter a FIBER-XXXX class code.');
      return;
    }
    if (DataService.hasJoinedClass(code)) {
      setState(() => _joinClassError = 'You are already enrolled in $code.');
      return;
    }
    final ok = DataService.joinClass(code, uid: AuthService.currentUser?.id);
    if (ok) {
      _inlineClassCodeCtrl.clear();
      setState(() {
        _joinClassError = null;
        _summaryStream =
            PerformanceService.watchSummary(uid: AuthService.currentUser?.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Successfully enrolled in class $code!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
      setState(
        () => _joinClassError = 'Class "$code" not found. Check with your teacher.',
      );
    }
  }

  Future< void > _confirmUnenrollClass(ClassRoom classRoom) async {
    final confirmed = await showDialog< bool >(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Unenroll from Class?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to unenroll from "${classRoom.name}" (${classRoom.id})?\n\nThis class will be removed from My Classes and your active Subject Performance dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.exit_to_app_rounded, size: 17),
            label: const Text('Unenroll'),
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
      setState(() {
        _summaryStream =
            PerformanceService.watchSummary(uid: AuthService.currentUser?.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unenrolled from "${classRoom.name}" (${classRoom.id}).'),
        ),
      );
    }
  }

  Future< void > _refreshDashboardData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    final uid = AuthService.currentUser?.id;
    await DataService.loadModules();
    await DataService.loadClasses(uid: uid);
    await PerformanceService.loadLatestSummary(uid: uid);
    if (!mounted) return;
    setState(() {
      _summaryStream = PerformanceService.watchSummary(uid: uid);
      _activityCountsStream = PerformanceService.watchActivityCounts(uid: uid);
      _isRefreshing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Synced latest student performance, assessments, and classes from Firebase.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
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

  void _openMiniGamesMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mini Games',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose an interactive activity to reinforce your learning',
                style: TextStyle(color: Colors.black54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              _FeatureCard(
                title: 'Flashcards',
                subtitle:
                    'Organize by subject, flip 3D cards, and track your accuracy',
                color: const Color.fromARGB(255, 8, 140, 201),
                icon: Icons.style,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FlashcardsScreen()),
                  );
                },
              ),
              _FeatureCard(
                title: 'Word Hunt',
                subtitle:
                    'Find fisheries terms with sound effects & real-time scoring',
                color: const Color(0xFF002855),
                icon: Icons.grid_on_rounded,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WordHuntGame()),
                  );
                },
              ),
              _FeatureCard(
                title: 'Word Shark',
                subtitle:
                    'Drag-and-drop FBLE vocabulary game with class leaderboard',
                color: const Color(0xFF00695C),
                icon: Icons.water_rounded,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WordSharkGame()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modules = DataService.modules;
    final joinedClasses = DataService.joinedClassCodes;
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'FiBER',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
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
            tooltip: 'Refresh Modules, Quizzes & Classes',
            onPressed: _isRefreshing ? null : _refreshDashboardData,
          ),
        ],
      ),
      drawer: _buildDrawer(theme),
      body: Container(
        decoration: BoxDecoration(color: Colors.lightBlue.shade50),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.7,
                child: Image.asset(
                  'lib/assets/images/Minimalist Blue Fish Pattern.png',
                  fit: BoxFit.cover,
                  color: Colors.lightBlue.shade200,
                  colorBlendMode: BlendMode.modulate,
                ),
              ),
            ),
            SafeArea(
              child: ListView(
                key: const PageStorageKey< String >('student_home_scroll'),
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Welcome Back & Live Study Time Hero Banner ──
                  _buildRealtimeStatsRow(theme),
                  const SizedBox(height: 16),

                  // ── Sections 2.1–2.4 & 3.1–3.2: Restored Circular & Horizontal Sliding Student Performance Dashboard ──
                  _buildComprehensiveStudentDashboard(theme),
                  const SizedBox(height: 18),

                  // ── 1. My Classes Container (With Dedicated Join Class Container, Google Classroom Cards & Unenroll) ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.lightBlue.shade100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.school_rounded,
                              color: Color(0xFF0B3C5D),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'My Classes',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF0B3C5D),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const JoinClassScreen(),
                                ),
                              ).then((_) {
                                if (mounted) setState(() {});
                              }),
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 16,
                              ),
                              label: const Text('All Classes'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Open your enrolled classes to access Module Folders, Mini-Quizzes, and Mock Exams',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 14),

                        // ── Section 4.1: Dedicated Join Class Container inside My Classes ──
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF082D49), Color(0xFF0B3C5D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.vpn_key_rounded,
                                    color: Colors.cyanAccent,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Join a Class',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Enter the FIBER-XXXX class code provided by your instructor:',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _inlineClassCodeCtrl,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'e.g., FIBER-2026',
                                        hintStyle: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12.5,
                                        ),
                                        isDense: true,
                                        filled: true,
                                        fillColor: const Color(0xFF031C32)
                                            .withOpacity(0.75),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: Colors.white24,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: Colors.white24,
                                          ),
                                        ),
                                      ),
                                      onChanged: (_) {
                                        if (_joinClassError != null) {
                                          setState(
                                            () => _joinClassError = null,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _handleInlineJoinClass,
                                    icon: const Icon(
                                      Icons.add_task_rounded,
                                      size: 17,
                                    ),
                                    label: const Text(
                                      'Join Class',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00BCD4),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_joinClassError != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _joinClassError!,
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (joinedClasses.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F8FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.lightBlue.shade100,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.class_outlined,
                                  size: 36,
                                  color: Color(0xFF0277BD),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'You haven\'t joined any classes yet.\nEnter your teacher\'s FIBER-XXXX code above to unlock class modules, quizzes, and mock exams.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...joinedClasses.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final code = entry.value;
                            final classRoom = DataService.classes.firstWhere(
                              (c) => c.id.toUpperCase() == code.toUpperCase(),
                              orElse: () =>
                                  ClassRoom(id: code, name: 'Class $code'),
                            );
                            final classMaterials = DataService.modules
                                .where(
                                  (m) =>
                                      m.isPublished &&
                                      (m.classCode ?? '')
                                              .trim()
                                              .toUpperCase() ==
                                          code.toUpperCase(),
                                )
                                .toList();
                            final modCount = classMaterials
                                .where((m) => m.category == 'module')
                                .length;
                            final quizCount = classMaterials
                                .where((m) => m.category == 'quiz')
                                .length;
                            final examCount = classMaterials
                                .where((m) => m.category == 'mock_exam')
                                .length;
                            final accentColors = < Color >[
                              const Color(0xFF0277BD),
                              const Color(0xFF00897B),
                              const Color(0xFF3949AB),
                              const Color(0xFF00ACC1),
                            ];
                            final accent =
                                accentColors[idx % accentColors.length];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: accent.withOpacity(0.28),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Top Student Classroom Strip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.1),
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        top: Radius.circular(17),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: accent,
                                          child: const Icon(
                                            Icons.menu_book_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                classRoom.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Color(0xFF0B3C5D),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Class Code: $code',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: accent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.green.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            'Enrolled',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            _classCountPill(
                                              Icons.folder_outlined,
                                              '$modCount Modules',
                                              Colors.teal.shade700,
                                            ),
                                            _classCountPill(
                                              Icons.quiz_outlined,
                                              '$quizCount Mini-Quizzes',
                                              const Color(0xFF0277BD),
                                            ),
                                            _classCountPill(
                                              Icons.assignment_outlined,
                                              '$examCount Mock Exams',
                                              Colors.deepPurple,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          ClassPortalScreen(
                                                        classRoom: classRoom,
                                                      ),
                                                    ),
                                                  ).then((_) {
                                                    if (mounted) setState(() {});
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.login_rounded,
                                                  size: 17,
                                                ),
                                                label: const Text(
                                                  'Open Class',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: accent,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _confirmUnenrollClass(
                                                classRoom,
                                              ),
                                              icon: const Icon(
                                                Icons.exit_to_app_rounded,
                                                size: 16,
                                                color: Colors.redAccent,
                                              ),
                                              label: const Text(
                                                'Unenroll',
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: Colors.red.shade200,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 2. Separate Mini Games Container (Flashcards, Word Hunt, Word Shark) ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.lightBlue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.sports_esports_rounded,
                              color: Color(0xFF0B3C5D),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Mini Games',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF0B3C5D),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: Color(0xFF0277BD),
                                size: 20,
                              ),
                              tooltip: 'Refresh Mini Games Data',
                              onPressed: _isRefreshing
                                  ? null
                                  : _refreshDashboardData,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Reinforce Fisheries Board Exam terminology through interactive games',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 14),
                        _FeatureCard(
                          title: 'Flashcards',
                          subtitle:
                              'Organize by subject, flip 3D cards, and track your accuracy',
                          color: const Color.fromARGB(255, 8, 140, 201),
                          icon: Icons.style_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FlashcardsScreen(),
                            ),
                          ),
                        ),
                        _FeatureCard(
                          title: 'Word Hunt',
                          subtitle:
                              'Find horizontal, vertical & diagonal fisheries terms',
                          color: const Color(0xFF002855),
                          icon: Icons.grid_on_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WordHuntGame(),
                            ),
                          ),
                        ),
                        _FeatureCard(
                          title: 'Word Shark',
                          subtitle:
                              'Drag-and-drop FBLE spelling challenge with class leaderboard',
                          color: const Color(0xFF00695C),
                          icon: Icons.water_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WordSharkGame(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Deep-Ocean Gradient Hero Banner (Matches Statistics History) ──
  Widget _buildRealtimeStatsRow(ThemeData theme) {
    final userName = AuthService.currentUser?.name.trim() ?? '';
    final greetingName = userName.isNotEmpty ? userName : 'Fisheries Scholar';

    return StreamBuilder< StudentPerformanceSummary >(
      stream: _summaryStream,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final accuracy = summary?.overallAverage ?? 0.0;
        final completed = summary?.completedAssessments ?? 0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B3C5D), Color(0xFF0288D1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0288D1).withOpacity(0.24),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -14,
                top: -14,
                child: Icon(
                  Icons.set_meal_rounded,
                  size: 110,
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
                              'Welcome back, $greetingName',
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
                              'Fisheries Technologist Board Exam Reviewer',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox.shrink(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                color: Colors.cyanAccent,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              ValueListenableBuilder< int >(
                                valueListenable:
                                    DataService.studySecondsNotifier,
                                builder: (_, __, ___) => Text(
                                  DataService.studyTimeFormatted,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Live Study Time',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 38, color: Colors.white24),
                        Expanded(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.verified_outlined,
                                color: Colors.greenAccent,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${accuracy.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Overall Accuracy',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 38, color: Colors.white24),
                        Expanded(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.assignment_turned_in_outlined,
                                color: Colors.amberAccent,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$completed',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Assessments',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  // ── Sections 2.1–2.4 & 3.1–3.2: Comprehensive Circular & Horizontal Sliding Student Dashboard ──
  Widget _buildComprehensiveStudentDashboard(ThemeData theme) {
    return StreamBuilder< StudentPerformanceSummary >(
      stream: _summaryStream,
      builder: (context, snapshot) {
        final summary = snapshot.data ?? StudentPerformanceSummary.empty();
        final subjects = summary.categorizedSubjects.isNotEmpty
            ? summary.categorizedSubjects
            : StudentPerformanceSummary.empty().categorizedSubjects;
        final safeSlide = _currentSubjectSlide.clamp(0, subjects.length - 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Part A (Sections 2.2 & 3.1): Circular Student Performance Dashboard ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.lightBlue.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1F5FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.donut_large_rounded,
                          color: Color(0xFF0277BD),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student Performance Dashboard',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Color(0xFF0B3C5D),
                              ),
                            ),
                            Text(
                              'Real-time circular analytics across assessments & mini-games',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.refresh_rounded,
                                color: Color(0xFF0277BD),
                                size: 20,
                              ),
                        tooltip: 'Refresh Dashboard',
                        onPressed: _isRefreshing ? null : _refreshDashboardData,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, gridConstraints) {
                      final cols = gridConstraints.maxWidth >= 520 ? 3 : 2;
                      final spacing = 10.0;
                      final itemWidth =
                          (gridConstraints.maxWidth - (spacing * (cols - 1))) /
                              cols;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _buildCircularMetricCard(
                              label: 'Overall Performance',
                              percent: summary.overallAverage,
                              centerText:
                                  '${summary.overallAverage.toStringAsFixed(1)}%',
                              detailText:
                                  '${summary.completedAssessments} Assessments',
                              color: const Color(0xFF00BCD4),
                              icon: Icons.speed_rounded,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildCircularMetricCard(
                              label: 'Passing Rate',
                              percent: summary.passingRate,
                              centerText:
                                  '${summary.passingRate.toStringAsFixed(1)}%',
                              detailText:
                                  '${summary.passedAssessments}/${summary.completedAssessments} Passed',
                              color: const Color(0xFF00C853),
                              icon: Icons.verified_rounded,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildCircularMetricCard(
                              label: 'Mini-Quizzes',
                              percent: summary.quizAveragePercent,
                              centerText:
                                  '${summary.quizAveragePercent.toStringAsFixed(1)}%',
                              detailText:
                                  'Score: ${summary.quizTotalScore}/${summary.quizTotalPossible} • ${summary.quizAttempts} Attempts',
                              color: const Color(0xFF0288D1),
                              icon: Icons.quiz_rounded,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildCircularMetricCard(
                              label: 'Mock Exams',
                              percent: summary.mockExamAveragePercent,
                              centerText:
                                  '${summary.mockExamAveragePercent.toStringAsFixed(1)}%',
                              detailText:
                                  'Score: ${summary.mockExamTotalScore}/${summary.mockExamTotalPossible} • ${summary.mockExamAttempts} Attempts',
                              color: const Color(0xFF7E57C2),
                              icon: Icons.assignment_rounded,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildCircularMetricCard(
                              label: 'Mini-Games',
                              percent: summary.miniGameProgressPercent,
                              centerText:
                                  '${summary.miniGameCompletedLevels} Lvls',
                              detailText:
                                  '${summary.miniGameTotalScore} pts • ${summary.miniGameAttempts} Attempts',
                              color: const Color(0xFF00897B),
                              icon: Icons.sports_esports_rounded,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildCircularMetricCard(
                              label: 'Overall Progress',
                              percent: summary.overallProgressPercent,
                              centerText:
                                  '${summary.totalLearningActivities} Done',
                              detailText:
                                  '${summary.overallProgressPercent.toStringAsFixed(0)}% Activity Goal',
                              color: const Color(0xFFFFB300),
                              icon: Icons.trending_up_rounded,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Part B (Sections 2.3 & 3.2): Horizontal Sliding Subject Performance Carousel (Alumni Style) ──
            Container(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF062942), Color(0xFF0B3C5D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.28)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B3C5D).withOpacity(0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.view_carousel_rounded,
                        color: Colors.cyanAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Subject Performance Carousel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Swipe left or right to compare Mini-Quiz & Mock Exam performance by FBLE subject',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 315,
                    child: PageView.builder(
                      key: const PageStorageKey< String >(
                        'student_subject_carousel',
                      ),
                      controller: _subjectCarouselController,
                      itemCount: subjects.length,
                      onPageChanged: (idx) {
                        if (mounted) {
                          setState(() => _currentSubjectSlide = idx);
                        }
                      },
                      itemBuilder: (context, idx) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: _buildSubjectCarouselSlide(
                            subjects[idx],
                            idx,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Alumni-Style Slide Navigation Arrows + Animated Pill Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.cyanAccent,
                          size: 18,
                        ),
                        tooltip: 'Previous Subject',
                        onPressed: safeSlide > 0
                            ? () => _subjectCarouselController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                )
                            : null,
                      ),
                      ...List< Widget >.generate(subjects.length, (i) {
                        final active = i == safeSlide;
                        return GestureDetector(
                          onTap: () => _subjectCarouselController.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.cyanAccent
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.cyanAccent,
                          size: 18,
                        ),
                        tooltip: 'Next Subject',
                        onPressed: safeSlide < subjects.length - 1
                            ? () => _subjectCarouselController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                )
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Performance Chart (Real-Time Stream) ───────────────────────
  Widget _buildPerformanceChart(ThemeData theme) {
    return StreamBuilder< StudentActivityCounts >(
      stream: _activityCountsStream,
      builder: (context, snapshot) {
        final counts = snapshot.data ?? StudentActivityCounts.empty;
        final total = counts.total;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.08),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activity Overview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              total == 0
                  ? Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No activity data yet',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Complete quizzes, exams, and games to see stats',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _ActivityBar(
                          label: 'Quizzes',
                          value: counts.quizzes,
                          total: total,
                          color: Colors.blue,
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        _ActivityBar(
                          label: 'Mock Exams',
                          value: counts.mockExams,
                          total: total,
                          color: Colors.purple,
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        _ActivityBar(
                          label: 'Games',
                          value: counts.games,
                          total: total,
                          color: Colors.green,
                          theme: theme,
                        ),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircularMetricCard({
    required String label,
    required double percent,
    required String centerText,
    required String detailText,
    required Color color,
    required IconData icon,
  }) {
    final clampedRatio = (percent / 100.0).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.28), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 68,
                  height: 68,
                  child: CircularProgressIndicator(
                    value: clampedRatio,
                    strokeWidth: 7.5,
                    strokeCap: StrokeCap.round,
                    backgroundColor: color.withOpacity(0.14),
                    valueColor: AlwaysStoppedAnimation< Color >(color),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      centerText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF0B3C5D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            detailText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCarouselSlide(SubjectPerformance subj, int index) {
    const List< Color > subjectAccents = < Color >[
      Color(0xFF0288D1), // Aquaculture
      Color(0xFF00897B), // Post-Harvest Fisheries
      Color(0xFF3949AB), // Fisheries Ecology and Capture Fisheries
      Color(0xFF6A1B9A), // Fisheries Resource Management
    ];
    const List< IconData > subjectIcons = < IconData >[
      Icons.water_rounded,
      Icons.inventory_2_rounded,
      Icons.sailing_rounded,
      Icons.eco_rounded,
    ];
    final accent = subjectAccents[index % subjectAccents.length];
    final icon = subjectIcons[index % subjectIcons.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.lightBlue.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Subject Title Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: accent.withOpacity(0.14),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subj.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0B3C5D),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total Attempts: ${subj.attempts} • Passed: ${subj.passedAttempts}/${subj.attempts}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Slide ${index + 1}/4',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 14),

          // 4 Circular Subject Indicators Row (Overall, Passing Rate, Mini-Quiz, Mock Exam)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniSubjectCircle(
                label: 'Overall',
                percent: subj.averagePercent,
                color: accent,
              ),
              _buildMiniSubjectCircle(
                label: 'Pass Rate',
                percent: subj.passingRate,
                color: const Color(0xFF00C853),
              ),
              _buildMiniSubjectCircle(
                label: 'Mini-Quiz',
                percent: subj.quizAveragePercent,
                color: const Color(0xFF0288D1),
              ),
              _buildMiniSubjectCircle(
                label: 'Mock Exam',
                percent: subj.mockExamAveragePercent,
                color: const Color(0xFF7E57C2),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Mini-Quiz vs Mock Exam Detailed Breakdown Boxes
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F8FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.lightBlue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            size: 14,
                            color: Color(0xFF0277BD),
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Mini-Quizzes',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                                color: Color(0xFF0B3C5D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Score: ${subj.quizScore}/${subj.quizPossible} (${subj.quizAveragePercent.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0277BD),
                        ),
                      ),
                      Text(
                        'Attempts: ${subj.quizAttempts}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepPurple.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 14,
                            color: Colors.deepPurple,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Mock Exams',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                                color: Color(0xFF0B3C5D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Score: ${subj.mockExamScore}/${subj.mockExamPossible} (${subj.mockExamAveragePercent.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.deepPurple,
                        ),
                      ),
                      Text(
                        'Attempts: ${subj.mockExamAttempts}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSubjectCircle({
    required String label,
    required double percent,
    required Color color,
  }) {
    final ratio = (percent / 100.0).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: color.withOpacity(0.14),
                  valueColor: AlwaysStoppedAnimation< Color >(color),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B3C5D),
          ),
        ),
      ],
    );
  }

  // ── Drawer (With Clickable Profile Header & Back-to-Sidebar Return) ──
  Widget _buildDrawer(ThemeData theme) {
    return Drawer(
      backgroundColor:
          theme.drawerTheme.backgroundColor ?? theme.colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ValueListenableBuilder< int >(
              valueListenable: AuthService.userProfileNotifier,
              builder: (context, _, __) {
                final user = AuthService.currentUser;
                final displayName = (user?.name.trim().isNotEmpty == true)
                    ? user!.name
                    : (user?.username.trim().isNotEmpty == true
                          ? user!.username
                          : 'FiBER Student');
                return InkWell(
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
                        AuthService.buildProfileAvatar(radius: 30),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                       Text(
                        user?.email ?? 'Student Portal',
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
              );
              },
            ),
            const SizedBox(height: 24),

            _DrawerTile(
              icon: Icons.analytics_outlined,
              title: 'Statistics History',
              onTap: () => _openFromSidebar(const StatisticsHistoryPage()),
            ),
            const SizedBox(height: 8),

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
            const Divider(height: 24),
            _DrawerTile(
              icon: Icons.help_outline_rounded,
              title: 'Help & User Manual',
              onTap: () =>
                  _openFromSidebar(const HelpPage(isTeacher: false)),
            ),
            const SizedBox(height: 8),
            _DrawerTile(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _classCountPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Activity Bar ───────────────────────────────────────────────────
class _ActivityBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  final ThemeData theme;

  const _ActivityBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ── Google Classroom-Style Feature Banner Card ─────────────────────
class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lighterColor = Color.lerp(color, Colors.cyanAccent, 0.25) ?? color;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, lighterColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                right: -12,
                bottom: -16,
                child: Icon(
                  icon,
                  size: 92,
                  color: Colors.white.withOpacity(0.11),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Drawer Tile ────────────────────────────────────────────────────
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
