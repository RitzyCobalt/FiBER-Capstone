import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/module_model.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'about_us.dart';
import 'account_settings.dart';
import 'class_management.dart';
import 'help_page.dart';
import 'module_viewer.dart';
import 'system_settings.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State< TeacherDashboard > createState() => _TeacherDashboardState();
}

class _ReviewDecision {
  final List< Question > questions;
  final bool isPublished;

  const _ReviewDecision({
    required this.questions,
    required this.isPublished,
  });
}

class _TeacherDashboardState extends State< TeacherDashboard > {
  final GlobalKey< ScaffoldState > _scaffoldKey = GlobalKey< ScaffoldState >();
  bool _isUploading = false;
  String _selectedCategoryFilter = 'all';
  String _selectedStatusFilter = 'all';
  final TextEditingController _materialSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    DataService.moduleUpdateNotifier.addListener(_onModuleUpdated);
    AuthService.userProfileNotifier.addListener(_onModuleUpdated);
    _initTeacherData();
  }

  Future< void > _initTeacherData() async {
    if (AuthService.currentUser == null) {
      await AuthService.restoreSession();
    }
    final uid = AuthService.currentUser?.id;
    DataService.startRealtimeSync(uid: uid);
    await DataService.loadModules();
    await DataService.loadClasses(uid: uid);
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
    DataService.moduleUpdateNotifier.removeListener(_onModuleUpdated);
    AuthService.userProfileNotifier.removeListener(_onModuleUpdated);
    super.dispose();
  }

  void _onModuleUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

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

  void _openLearningMaterialsManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LearningMaterialsManagementScreen(),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  // Legacy unused helper placeholder kept only so existing methods below can be replaced cleanly
  Future< Map< String, String? >? > _showUploadCategoryDialog(
    String defaultTitle, {
    String? preselectedClassCode,
  }) async {
    final teacherClasses = DataService.getClassesForTeacher(
      AuthService.currentUser?.id,
    );
    if (teacherClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please create a class in Class Management first before uploading materials.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }

    final titleCtrl = TextEditingController(text: defaultTitle);
    String selectedCategory = 'module';
    String selectedClassCode = (preselectedClassCode != null &&
            teacherClasses.any((c) => c.id == preselectedClassCode))
        ? preselectedClassCode
        : teacherClasses.first.id;

    return showDialog< Map< String, String? > >(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Configure Upload & Class Assignment',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Material Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField< String >(
                    isExpanded: true,
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Class Section / Category',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'module',
                        child: Text(
                          'Module Library (Study Material / Media)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'quiz',
                        child: Text(
                          'Mini Quizzes (15-Item Topic Drill)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'mock_exam',
                        child: Text(
                          'Mock Exams (Board Exam Simulation)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField< String >(
                    isExpanded: true,
                    initialValue: selectedClassCode,
                    decoration: const InputDecoration(
                      labelText: 'Assign to Class (Required)',
                      border: OutlineInputBorder(),
                    ),
                    items: teacherClasses
                        .map(
                          (c) => DropdownMenuItem< String >(
                            value: c.id,
                            child: Text(
                              '${c.name} (${c.id})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null && val.isNotEmpty) {
                        setModalState(() => selectedClassCode = val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0277BD),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final finalTitle = titleCtrl.text.trim().isEmpty
                    ? defaultTitle
                    : titleCtrl.text.trim();
                Navigator.pop(ctx, < String, String? >{
                  'title': finalTitle,
                  'category': selectedCategory,
                  'classCode': selectedClassCode,
                });
              },
              child: const Text('Continue to Review'),
            ),
          ],
        ),
      ),
    );
  }

  Future< _ReviewDecision? > _showReviewQuestionsDialog({
    required String title,
    required String category,
    required List< Question > initialQuestions,
  }) async {
    final editableQuestions = initialQuestions
        .map(
          (q) => Question(
            question: q.question,
            choices: List< String >.from(q.choices),
            correctIndex: q.correctIndex,
          ),
        )
        .toList();

    return showDialog< _ReviewDecision >(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future< void > openQuestionEditor({int? index}) async {
            final isEditing = index != null;
            final current = isEditing ? editableQuestions[index] : null;
            final qCtrl = TextEditingController(text: current?.question ?? '');
            final choiceCtrls = List< TextEditingController >.generate(
              4,
              (i) => TextEditingController(
                text: (current != null && i < current.choices.length)
                    ? current.choices[i]
                    : '',
              ),
            );
            int correctIdx = (current?.correctIndex ?? 0).clamp(0, 3);
            String? errorMsg;

            final savedQuestion = await showDialog< Question >(
              context: ctx,
              barrierDismissible: false,
              builder: (editCtx) => StatefulBuilder(
                builder: (editCtx, setEditState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFE1F5FE),
                        child: Icon(
                          isEditing ? Icons.edit_note : Icons.add_task,
                          color: const Color(0xFF0277BD),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isEditing
                              ? 'Edit Question #${index + 1}'
                              : 'Add New Question #${editableQuestions.length + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: qCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Question Stem',
                              hintText: 'Enter the question here...',
                              filled: true,
                              fillColor: const Color(0xFFF8FBFF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (_) {
                              if (errorMsg != null) {
                                setEditState(() => errorMsg = null);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Answer Choices (Tap the radio circle to mark the correct answer):',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List< Widget >.generate(4, (cIdx) {
                            final letter = String.fromCharCode(65 + cIdx);
                            final isSelected = correctIdx == cIdx;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.green.shade50
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.green
                                      : Colors.grey.shade300,
                                  width: isSelected ? 1.6 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Radio< int >(
                                    value: cIdx,
                                    groupValue: correctIdx,
                                    activeColor: Colors.green.shade700,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setEditState(() => correctIdx = val);
                                      }
                                    },
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: choiceCtrls[cIdx],
                                      decoration: InputDecoration(
                                        labelText:
                                            'Choice $letter ${isSelected ? "✓ (Correct Answer)" : ""}',
                                        hintText: 'Enter option $letter...',
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (errorMsg != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              errorMsg!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(editCtx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        isEditing ? 'Save Changes' : 'Add to Question Bank',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0277BD),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final cleanQ = qCtrl.text.trim();
                        if (cleanQ.isEmpty) {
                          setEditState(
                            () => errorMsg = 'Please enter a question first.',
                          );
                          return;
                        }
                        final cleanChoices = List< String >.generate(4, (i) {
                          final txt = choiceCtrls[i].text.trim();
                          final letter = String.fromCharCode(65 + i);
                          return txt.isEmpty ? 'Choice $letter' : txt;
                        });
                        Navigator.pop(
                          editCtx,
                          Question(
                            question: cleanQ,
                            choices: cleanChoices,
                            correctIndex: correctIdx,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );

            if (savedQuestion != null) {
              setModalState(() {
                if (isEditing) {
                  editableQuestions[index] = savedQuestion;
                } else {
                  editableQuestions.insert(0, savedQuestion);
                }
              });
            }
          }

          final categoryLabel = category == 'quiz'
              ? 'Mini Quiz'
              : category == 'mock_exam'
                  ? 'Mock Exam'
                  : 'Module Folder';

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.fact_check_rounded,
                        color: Colors.cyanAccent,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Review & Edit Extracted Questions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${editableQuestions.length} Qs',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$title • $categoryLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            content: SizedBox(
              width: 540,
              height: 430,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => openQuestionEditor(),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add New Question'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE1F5FE),
                      foregroundColor: const Color(0xFF0B3C5D),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.lightBlue.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: editableQuestions.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No questions in this set yet.\nTap "Add New Question" above to compose one, or click "Publish Now".',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.blueGrey.shade600,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: editableQuestions.length,
                            itemBuilder: (itemCtx, idx) {
                              final q = editableQuestions[idx];
                              final safeIdx = q.correctIndex.clamp(
                                0,
                                q.choices.isEmpty ? 0 : q.choices.length - 1,
                              );
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FBFF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.lightBlue.shade100,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0277BD),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            'Q${idx + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            q.question,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Color(0xFF0B3C5D),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: Color(0xFF0277BD),
                                            size: 20,
                                          ),
                                          tooltip: 'Edit question',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          onPressed: () =>
                                              openQuestionEditor(index: idx),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          tooltip: 'Remove question',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          onPressed: () {
                                            setModalState(() {
                                              editableQuestions.removeAt(idx);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: List< Widget >.generate(
                                        q.choices.length,
                                        (cIdx) {
                                          final isAns = cIdx == safeIdx;
                                          final letter = String.fromCharCode(
                                            65 + cIdx,
                                          );
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isAns
                                                  ? Colors.green.shade50
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isAns
                                                    ? Colors.green
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Text(
                                              '${isAns ? "✓ " : ""}$letter. ${q.choices[cIdx]}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isAns
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isAns
                                                    ? Colors.green.shade800
                                                    : Colors.black87,
                                              ),
                                            ),
                                          );
                                        },
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.pending_actions_rounded, size: 18),
                label: const Text('Save as Pending'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber.shade900,
                  side: BorderSide(color: Colors.amber.shade700),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(
                  ctx,
                  _ReviewDecision(
                    questions: editableQuestions,
                    isPublished: false,
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Publish Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(
                  ctx,
                  _ReviewDecision(
                    questions: editableQuestions,
                    isPublished: true,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future< void > _pickAndUploadModule() async {
    final teacherClasses = DataService.getClassesForTeacher(
      AuthService.currentUser?.id,
    );
    if (teacherClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create a class in Class Management first before uploading learning materials.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'txt',
        'pptx',
        'ppt',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'mp4',
        'webm',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final fileName = file.name;
    final fileBytes = file.bytes;
    final filePath = kIsWeb ? null : file.path;

    final defaultTitle = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final config = await _showUploadCategoryDialog(defaultTitle);
    if (config == null) return;

    // Allow dialog close animation to finish before extraction/upload runs
    await Future< void >.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final title = config['title'] ?? defaultTitle;
    final category = config['category'] ?? 'module';
    final classCode = config['classCode'];
    final teacherId = AuthService.currentUser?.id;

    setState(() => _isUploading = true);

    try {
      final draft = await DataService.prepareModuleDraft(
        title: title,
        fileName: fileName,
        bytes: fileBytes,
        filePath: filePath,
        pickedFileSize: file.size,
        category: category,
        classCode: classCode,
        teacherId: teacherId,
      );

      if (!mounted) return;
      setState(() => _isUploading = false);

      final decision = await _showReviewQuestionsDialog(
        title: draft.title,
        category: draft.category,
        initialQuestions: draft.questions,
      );

      if (decision == null || !mounted) return;

      setState(() => _isUploading = true);

      final finalModule = Module(
        title: draft.title,
        content: draft.content,
        questions: decision.questions,
        isValid: true,
        isPublished: decision.isPublished,
        fileName: draft.fileName,
        fileType: draft.fileType,
        mimeType: draft.mimeType,
        fileUrl: draft.fileUrl,
        fileSize: draft.fileSize,
        pageCount: draft.pageCount,
        uploadedAt: DateTime.now(),
        category: draft.category,
        classCode: draft.classCode,
        teacherId: teacherId,
      );

      await DataService.publishReviewedModule(
        finalModule,
        rawBytes: fileBytes,
        filePath: filePath,
      );
      await DataService.loadModules();

      if (!mounted) return;
      setState(() => _isUploading = false);
      DataService.notifyModuleUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision.isPublished
                ? '✅ "$title" published to ${draft.classCode} (${decision.questions.length} questions)!'
                : '📌 "$title" saved as Pending (Unpublished) in ${draft.classCode}.',
          ),
          backgroundColor:
              decision.isPublished ? Colors.green : Colors.amber.shade800,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Upload failed: ${e.toString().replaceFirst("Exception: ", "")}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDeleteModule(Module module) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Module'),
        content: Text('Are you sure you want to delete "${module.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DataService.deleteModule(
                DataService.modules.indexOf(module),
              );
              if (mounted) {
                setState(() {});
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future< void > _editExistingMaterialQuestions(Module module) async {
    final decision = await _showReviewQuestionsDialog(
      title: module.title,
      category: module.category,
      initialQuestions: module.questions,
    );
    if (decision == null || !mounted) return;

    final updated = module.copyWith(
      questions: decision.questions,
      isPublished: decision.isPublished,
    );
    await DataService.updateExistingModule(
      updated,
      actorEmail: AuthService.currentUser?.email,
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          decision.isPublished
              ? '✅ Updated and published "${module.title}" (${decision.questions.length} Qs).'
              : '📌 Updated "${module.title}" and saved as Pending.',
        ),
        backgroundColor:
            decision.isPublished ? Colors.green.shade700 : Colors.amber.shade800,
      ),
    );
  }

  Widget _buildMaterialFilterChip(String label, String value) {
    final selected = _selectedCategoryFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF0288D1),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF0B3C5D),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedCategoryFilter = value),
    );
  }

  Widget _buildStatusFilterChip(String label, String value) {
    final selected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF00897B),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF0B3C5D),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedStatusFilter = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = AuthService.currentUser;
    final currentUserName = currentUser?.name;
    final displayName = (currentUserName?.isNotEmpty ?? false)
        ? currentUserName!
        : 'FiBER Instructor';
    final teacherId = currentUser?.id;
    final teacherClasses = DataService.getClassesForTeacher(teacherId);
    final teacherModules = DataService.getModulesForTeacher(teacherId);
    final totalClasses = teacherClasses.length;
    final totalModules = teacherModules.length;

    final publishedCount =
        teacherModules.where((m) => m.isPublished).length;
    final pendingCount =
        teacherModules.where((m) => !m.isPublished).length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 0,
        title: const Text(
          'FiBER Faculty Portal',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B3C5D),
          ),
        ),
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
                        fallbackIcon: Icons.school_rounded,
                      ),
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
                        currentUser?.email ?? 'Teacher Portal',
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
              const Divider(height: 24),
              _DrawerTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & User Manual',
                onTap: () =>
                    _openFromSidebar(const HelpPage(isTeacher: true)),
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
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Deep-Ocean Gradient Teacher Hero Banner ──
                Container(
                  padding: const EdgeInsets.all(22),
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
                        right: -12,
                        top: -12,
                        child: Icon(
                          Icons.school_rounded,
                          size: 110,
                          color: Colors.white.withOpacity(0.09),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, $displayName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Manage review classes, upload fisheries modules, and review extracted exam items.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    const Icon(
                                      Icons.class_outlined,
                                      color: Colors.cyanAccent,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$totalClasses',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Active Classes',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.white24,
                                ),
                                Column(
                                  children: [
                                    const Icon(
                                      Icons.library_books_outlined,
                                      color: Colors.greenAccent,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$totalModules',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Published Materials',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Google Classroom-Style Action Banner 1: Class Management ──
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A237E).withOpacity(0.22),
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClassManagement(),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -10,
                            bottom: -14,
                            child: Icon(
                              Icons.groups_rounded,
                              size: 96,
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.class_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Class Management & Analytics',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Create FIBER-XXXX classes and monitor student dashboards',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Google Classroom-Style Action Banner 2: Learning Materials Management ──
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF004D40), Color(0xFF00897B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF004D40).withOpacity(0.22),
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
                      onTap: _openLearningMaterialsManagement,
                      child: Stack(
                        children: [
                          Positioned(
                            right: -10,
                            bottom: -14,
                            child: Icon(
                              Icons.folder_copy_rounded,
                              size: 96,
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.folder_copy_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Learning Materials Management',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Upload, review, search & manage materials ($publishedCount Published • $pendingCount Pending)',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (false)
                  Container(
                    child: Column(
                      children: [
                      // Upload Action & Live Upload Progress Bar
                      if (_isUploading)
                        ValueListenableBuilder< double >(
                          valueListenable: DataService.uploadProgressNotifier,
                          builder: (context, progress, _) {
                            return ValueListenableBuilder< String >(
                              valueListenable: DataService.uploadStatusNotifier,
                              builder: (context, statusText, __) {
                                final pct = (progress * 100).round();
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F8FF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.lightBlue.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              statusText.isNotEmpty
                                                  ? statusText
                                                  : 'Processing & uploading learning material...',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: Color(0xFF0B3C5D),
                                              ),
                                            ),
                                          ),
                                          if (progress > 0)
                                            Text(
                                              '$pct%',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0277BD),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: progress > 0 ? progress : null,
                                          minHeight: 8,
                                          backgroundColor:
                                              Colors.lightBlue.shade100,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                            Color(0xFF0288D1),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF004D40), Color(0xFF00897B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _pickAndUploadModule,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.upload_file_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Upload New Learning Material',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Preserves original PDF, DOC/DOCX, PPT/PPTX, TXT, Image & Video formats',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),

                      // Search & Filters (Status + Category)
                      TextField(
                        controller: _materialSearchCtrl,
                        decoration: InputDecoration(
                          hintText:
                              'Search uploaded or pending materials by title, class, or format...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: Color(0xFF0277BD),
                          ),
                          suffixIcon: _materialSearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _materialSearchCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8FBFF),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.lightBlue.shade100,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.lightBlue.shade100,
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatusFilterChip(
                              'All Status (${teacherModules.length})',
                              'all',
                            ),
                            const SizedBox(width: 8),
                            _buildStatusFilterChip(
                              'Published ($publishedCount)',
                              'published',
                            ),
                            const SizedBox(width: 8),
                            _buildStatusFilterChip(
                              'Pending / Unpublished ($pendingCount)',
                              'pending',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildMaterialFilterChip('All Categories', 'all'),
                            const SizedBox(width: 8),
                            _buildMaterialFilterChip('Modules', 'module'),
                            const SizedBox(width: 8),
                            _buildMaterialFilterChip('Mini Quizzes', 'quiz'),
                            const SizedBox(width: 8),
                            _buildMaterialFilterChip('Mock Exams', 'mock_exam'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (teacherModules.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FBFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              if (DataService.isLoadingModules) ...[
                                const CircularProgressIndicator(),
                                const SizedBox(height: 12),
                                const Text(
                                  'Syncing learning materials from Firebase...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF0B3C5D),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  DataService.lastLoadError != null
                                      ? '⚠️ Sync notice: ${DataService.lastLoadError}'
                                      : 'No learning materials uploaded yet.\nTap "Upload New Learning Material" above to upload or stage your first material.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _initTeacherData,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Retry Sync from Firebase'),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        ...teacherModules.where((m) {
                          if (_selectedStatusFilter == 'published' &&
                              !m.isPublished) {
                            return false;
                          }
                          if (_selectedStatusFilter == 'pending' &&
                              m.isPublished) {
                            return false;
                          }
                          final matchesCategory =
                              _selectedCategoryFilter == 'all' ||
                                  m.category == _selectedCategoryFilter;
                          if (!matchesCategory) return false;
                          final query =
                              _materialSearchCtrl.text.trim().toLowerCase();
                          if (query.isEmpty) return true;
                          final title = m.title.toLowerCase();
                          final code = (m.classCode ?? '').toLowerCase();
                          final type = (m.fileType ?? '').toLowerCase();
                          return title.contains(query) ||
                              code.contains(query) ||
                              type.contains(query);
                        }).map((m) {
                          final isQuiz = m.category == 'quiz';
                          final isExam = m.category == 'mock_exam';
                          final categoryBadge = isQuiz
                              ? 'MINI QUIZ'
                              : isExam
                                  ? 'MOCK EXAM'
                                  : 'MODULE';
                          final accentColor = isExam
                              ? Colors.deepPurple
                              : isQuiz
                                  ? const Color(0xFF0277BD)
                                  : Colors.teal.shade700;
                          final classBadge =
                              (m.classCode != null && m.classCode!.isNotEmpty)
                                  ? m.classCode!
                                  : 'All Classes';
                          final formatBadge =
                              (m.fileType ?? 'doc').toUpperCase();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FBFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: m.isPublished
                                    ? Colors.lightBlue.shade100
                                    : Colors.amber.shade300,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 21,
                                      backgroundColor:
                                          accentColor.withOpacity(0.12),
                                      child: Icon(
                                        isQuiz
                                            ? Icons.quiz_outlined
                                            : isExam
                                                ? Icons.fact_check_outlined
                                                : Icons.menu_book_rounded,
                                        color: accentColor,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Color(0xFF0B3C5D),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$categoryBadge • Class: $classBadge • .$formatBadge • ${m.questions.length} Qs',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: accentColor,
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
                                        color: m.isPublished
                                            ? Colors.green.shade50
                                            : Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: m.isPublished
                                              ? Colors.green.shade300
                                              : Colors.amber.shade400,
                                        ),
                                      ),
                                      child: Text(
                                        m.isPublished
                                            ? '● Published'
                                            : '● Pending',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: m.isPublished
                                              ? Colors.green.shade800
                                              : Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Open & Preview',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ModuleViewer(module: m),
                                        ),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.edit_note_rounded,
                                        size: 16,
                                        color: Color(0xFF0277BD),
                                      ),
                                      label: const Text(
                                        'Manage Qs',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF0277BD),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: Colors.lightBlue.shade200,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _editExistingMaterialQuestions(m),
                                    ),
                                    OutlinedButton.icon(
                                      icon: Icon(
                                        m.isPublished
                                            ? Icons.unpublished_outlined
                                            : Icons.publish_rounded,
                                        size: 16,
                                        color: m.isPublished
                                            ? Colors.amber.shade900
                                            : Colors.green.shade700,
                                      ),
                                      label: Text(
                                        m.isPublished
                                            ? 'Move to Pending'
                                            : 'Publish Now',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: m.isPublished
                                              ? Colors.amber.shade900
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: m.isPublished
                                              ? Colors.amber.shade400
                                              : Colors.green.shade300,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final nextState = !m.isPublished;
                                        await DataService
                                            .toggleModulePublishStatus(
                                          m,
                                          nextState,
                                          actorEmail:
                                              AuthService.currentUser?.email,
                                        );
                                        if (!mounted) return;
                                        setState(() {});
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              nextState
                                                  ? '✅ Published "${m.title}" to students.'
                                                  : '📌 Moved "${m.title}" to Pending (Unpublished).',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _confirmDeleteModule(m),
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
                                        side: BorderSide(
                                          color: Colors.red.shade200,
                                        ),
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
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Dedicated Learning Materials Management Screen
//  (With Deep-Ocean Glass Modals matching Faculty Account Request)
// ══════════════════════════════════════════════════════════════════
class LearningMaterialsManagementScreen extends StatefulWidget {
  const LearningMaterialsManagementScreen({super.key});

  @override
  State< LearningMaterialsManagementScreen > createState() =>
      _LearningMaterialsManagementScreenState();
}

class _LearningMaterialsManagementScreenState
    extends State< LearningMaterialsManagementScreen > {
  bool _isUploading = false;
  bool _isRefreshing = false;
  String _selectedCategoryFilter = 'all'; // 'all', 'module', 'quiz', 'mock_exam'
  String _selectedStatusFilter = 'all'; // 'all', 'published', 'pending'
  final TextEditingController _materialSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    DataService.moduleUpdateNotifier.addListener(_onUpdated);
  }

  @override
  void dispose() {
    _materialSearchCtrl.dispose();
    DataService.moduleUpdateNotifier.removeListener(_onUpdated);
    super.dispose();
  }

  void _onUpdated() {
    if (mounted) setState(() {});
  }

  Future< void > _refreshMaterials() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await DataService.loadModules();
    await DataService.loadClasses(uid: AuthService.currentUser?.id);
    if (!mounted) return;
    setState(() => _isRefreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Synced latest learning materials from Firebase.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  InputDecoration _darkModalInputDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
      floatingLabelStyle: const TextStyle(
        color: Colors.cyanAccent,
        fontWeight: FontWeight.bold,
      ),
      filled: true,
      fillColor: const Color(0xFF031C32).withOpacity(0.65),
      prefixIcon:
          icon != null ? Icon(icon, color: Colors.cyanAccent, size: 19) : null,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.8),
      ),
    );
  }

  Future< Map< String, String? >? > _showUploadCategoryDialog(
    String defaultTitle,
  ) async {
    final teacherClasses = DataService.getClassesForTeacher(
      AuthService.currentUser?.id,
    );
    if (teacherClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please create a class in Class Management first before uploading materials.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }

    final titleCtrl = TextEditingController(text: defaultTitle);
    String selectedCategory = 'module';
    String selectedClassCode = teacherClasses.first.id;

    return showDialog< Map< String, String? > >(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF082D49), Color(0xFF0B3C5D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.cyanAccent.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_rounded,
                            color: Colors.cyanAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Configure Learning Material',
                                style: GoogleFonts.playfairDisplay(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Assign Title, Category & Target Class',
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _darkModalInputDecoration(
                        label: 'Material Title',
                        icon: Icons.title_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField< String >(
                      isExpanded: true,
                      initialValue: selectedCategory,
                      dropdownColor: const Color(0xFF082D49),
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: _darkModalInputDecoration(
                        label: 'Class Section / Category',
                        icon: Icons.category_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'module',
                          child: Text(
                            'Module Library (Study Material / Media)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'quiz',
                          child: Text(
                            'Mini Quizzes (15-Item Topic Drill)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'mock_exam',
                          child: Text(
                            'Mock Exams (Board Exam Simulation)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField< String >(
                      isExpanded: true,
                      initialValue: selectedClassCode,
                      dropdownColor: const Color(0xFF082D49),
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: _darkModalInputDecoration(
                        label: 'Assign to Class (Required)',
                        icon: Icons.class_outlined,
                      ),
                      items: teacherClasses
                          .map(
                            (c) => DropdownMenuItem< String >(
                              value: c.id,
                              child: Text(
                                '${c.name} (${c.id})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null && val.isNotEmpty) {
                          setModalState(() => selectedClassCode = val);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00BCD4), Color(0xFF0288D1)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Continue to Question Review',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                        onPressed: () {
                          final finalTitle = titleCtrl.text.trim().isEmpty
                              ? defaultTitle
                              : titleCtrl.text.trim();
                          Navigator.pop(ctx, < String, String? >{
                            'title': finalTitle,
                            'category': selectedCategory,
                            'classCode': selectedClassCode,
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future< _ReviewDecision? > _showReviewQuestionsDialog({
    required String title,
    required String category,
    required List< Question > initialQuestions,
  }) async {
    final editableQuestions = initialQuestions
        .map(
          (q) => Question(
            question: q.question,
            choices: List< String >.from(q.choices),
            correctIndex: q.correctIndex,
          ),
        )
        .toList();

    return showDialog< _ReviewDecision >(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future< void > openQuestionEditor({int? index}) async {
            final isEditing = index != null;
            final current = isEditing ? editableQuestions[index] : null;
            final qCtrl = TextEditingController(text: current?.question ?? '');
            final choiceCtrls = List< TextEditingController >.generate(
              4,
              (i) => TextEditingController(
                text: (current != null && i < current.choices.length)
                    ? current.choices[i]
                    : '',
              ),
            );
            int correctIdx = (current?.correctIndex ?? 0).clamp(0, 3);
            String? errorMsg;

            final savedQuestion = await showDialog< Question >(
              context: ctx,
              barrierDismissible: false,
              builder: (editCtx) => StatefulBuilder(
                builder: (editCtx, setEditState) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF082D49), Color(0xFF0B3C5D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.cyanAccent.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isEditing
                                        ? Icons.edit_note_rounded
                                        : Icons.add_task_rounded,
                                    color: Colors.cyanAccent,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isEditing
                                        ? 'Edit Question #${index + 1}'
                                        : 'Add Question #${editableQuestions.length + 1}',
                                    style: GoogleFonts.playfairDisplay(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => Navigator.pop(editCtx),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: qCtrl,
                              maxLines: 3,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: _darkModalInputDecoration(
                                label: 'Question Stem',
                                hint: 'Enter the question here...',
                              ),
                              onChanged: (_) {
                                if (errorMsg != null) {
                                  setEditState(() => errorMsg = null);
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Answer Choices (Tap radio circle to mark correct answer):',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.cyanAccent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...List< Widget >.generate(4, (cIdx) {
                              final letter = String.fromCharCode(65 + cIdx);
                              final isSelected = correctIdx == cIdx;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.greenAccent.withOpacity(0.14)
                                      : const Color(0xFF031C32)
                                          .withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.greenAccent
                                        : Colors.white24,
                                    width: isSelected ? 1.6 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Radio< int >(
                                      value: cIdx,
                                      groupValue: correctIdx,
                                      activeColor: Colors.greenAccent,
                                      onChanged: (val) {
                                        if (val != null) {
                                          setEditState(() => correctIdx = val);
                                        }
                                      },
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: choiceCtrls[cIdx],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.5,
                                        ),
                                        decoration: InputDecoration(
                                          labelText:
                                              'Choice $letter ${isSelected ? "✓ (Correct)" : ""}',
                                          labelStyle: TextStyle(
                                            color: isSelected
                                                ? Colors.greenAccent
                                                : Colors.white70,
                                            fontSize: 12,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (errorMsg != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                errorMsg!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Container(
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00BCD4),
                                    Color(0xFF0288D1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: Text(
                                  isEditing
                                      ? 'Save Question Changes'
                                      : 'Add to Question Bank',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  final cleanQ = qCtrl.text.trim();
                                  if (cleanQ.isEmpty) {
                                    setEditState(
                                      () => errorMsg =
                                          'Please enter a question first.',
                                    );
                                    return;
                                  }
                                  final cleanChoices =
                                      List< String >.generate(4, (i) {
                                    final txt = choiceCtrls[i].text.trim();
                                    final letter = String.fromCharCode(65 + i);
                                    return txt.isEmpty ? 'Choice $letter' : txt;
                                  });
                                  Navigator.pop(
                                    editCtx,
                                    Question(
                                      question: cleanQ,
                                      choices: cleanChoices,
                                      correctIndex: correctIdx,
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
                ),
              ),
            );

            if (savedQuestion != null) {
              setModalState(() {
                if (isEditing) {
                  editableQuestions[index] = savedQuestion;
                } else {
                  editableQuestions.insert(0, savedQuestion);
                }
              });
            }
          }

          final categoryLabel = category == 'quiz'
              ? 'Mini Quiz'
              : category == 'mock_exam'
                  ? 'Mock Exam'
                  : 'Study Module';

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 620),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF082D49), Color(0xFF0B3C5D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.cyanAccent.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.fact_check_rounded,
                            color: Colors.cyanAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Review & Edit Questions',
                                style: GoogleFonts.playfairDisplay(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$title • $categoryLabel (${editableQuestions.length} Qs)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => openQuestionEditor(),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.cyanAccent,
                      ),
                      label: const Text(
                        'Add New Question',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF031C32).withOpacity(0.65),
                        side: BorderSide(
                          color: Colors.cyanAccent.withOpacity(0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: editableQuestions.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'No questions in this set yet.\nTap "Add New Question" above or choose Save as Pending / Publish Now below.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: editableQuestions.length,
                              itemBuilder: (itemCtx, idx) {
                                final q = editableQuestions[idx];
                                final safeIdx = q.correctIndex.clamp(
                                  0,
                                  q.choices.isEmpty ? 0 : q.choices.length - 1,
                                );
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF031C32)
                                        .withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.14),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.cyanAccent
                                                  .withOpacity(0.16),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Q${idx + 1}',
                                              style: const TextStyle(
                                                color: Colors.cyanAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              q.question,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13.5,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              color: Colors.cyanAccent,
                                              size: 19,
                                            ),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            onPressed: () =>
                                                openQuestionEditor(index: idx),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                              size: 19,
                                            ),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            onPressed: () {
                                              setModalState(() {
                                                editableQuestions.removeAt(idx);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: List< Widget >.generate(
                                          q.choices.length,
                                          (cIdx) {
                                            final isAns = cIdx == safeIdx;
                                            final letter = String.fromCharCode(
                                              65 + cIdx,
                                            );
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isAns
                                                    ? Colors.greenAccent
                                                        .withOpacity(0.16)
                                                    : Colors.white
                                                        .withOpacity(0.06),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isAns
                                                      ? Colors.greenAccent
                                                      : Colors.white24,
                                                ),
                                              ),
                                              child: Text(
                                                '${isAns ? "✓ " : ""}$letter. ${q.choices[cIdx]}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isAns
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: isAns
                                                      ? Colors.greenAccent
                                                      : Colors.white70,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.pending_actions_rounded,
                              size: 17,
                              color: Colors.amberAccent,
                            ),
                            label: const Text(
                              'Save Pending',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF031C32).withOpacity(0.65),
                              side: const BorderSide(color: Colors.amberAccent),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () => Navigator.pop(
                              ctx,
                              _ReviewDecision(
                                questions: editableQuestions,
                                isPublished: false,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00BCD4), Color(0xFF0288D1)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF00BCD4).withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(
                                Icons.cloud_upload_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
                              label: const Text(
                                'Publish Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              onPressed: () => Navigator.pop(
                                ctx,
                                _ReviewDecision(
                                  questions: editableQuestions,
                                  isPublished: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future< void > _pickAndUploadModule() async {
    final teacherClasses = DataService.getClassesForTeacher(
      AuthService.currentUser?.id,
    );
    if (teacherClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create a class in Class Management first before uploading learning materials.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'txt',
        'pptx',
        'ppt',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'mp4',
        'webm',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final fileName = file.name;
    final fileBytes = file.bytes;
    final filePath = kIsWeb ? null : file.path;

    final defaultTitle = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final config = await _showUploadCategoryDialog(defaultTitle);
    if (config == null) return;

    await Future< void >.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final title = config['title'] ?? defaultTitle;
    final category = config['category'] ?? 'module';
    final classCode = config['classCode'];
    final teacherId = AuthService.currentUser?.id;

    setState(() => _isUploading = true);

    try {
      final draft = await DataService.prepareModuleDraft(
        title: title,
        fileName: fileName,
        bytes: fileBytes,
        filePath: filePath,
        pickedFileSize: file.size,
        category: category,
        classCode: classCode,
        teacherId: teacherId,
      );

      if (!mounted) return;
      setState(() => _isUploading = false);

      final decision = await _showReviewQuestionsDialog(
        title: draft.title,
        category: draft.category,
        initialQuestions: draft.questions,
      );

      if (decision == null || !mounted) return;

      setState(() => _isUploading = true);

      final finalModule = Module(
        title: draft.title,
        content: draft.content,
        questions: decision.questions,
        isValid: true,
        isPublished: decision.isPublished,
        fileName: draft.fileName,
        fileType: draft.fileType,
        mimeType: draft.mimeType,
        fileUrl: draft.fileUrl,
        fileSize: draft.fileSize,
        pageCount: draft.pageCount,
        uploadedAt: DateTime.now(),
        category: draft.category,
        classCode: draft.classCode,
        teacherId: teacherId,
      );

      await DataService.publishReviewedModule(
        finalModule,
        rawBytes: fileBytes,
        filePath: filePath,
      );
      await DataService.loadModules();

      if (!mounted) return;
      setState(() => _isUploading = false);
      DataService.notifyModuleUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision.isPublished
                ? '✅ "$title" published to ${draft.classCode} (${decision.questions.length} questions)!'
                : '📌 "$title" saved as Pending (Unpublished) in ${draft.classCode}.',
          ),
          backgroundColor:
              decision.isPublished ? Colors.green : Colors.amber.shade800,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Upload failed: ${e.toString().replaceFirst("Exception: ", "")}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future< void > _editExistingMaterialQuestions(Module module) async {
    final decision = await _showReviewQuestionsDialog(
      title: module.title,
      category: module.category,
      initialQuestions: module.questions,
    );
    if (decision == null || !mounted) return;

    final updated = module.copyWith(
      questions: decision.questions,
      isPublished: decision.isPublished,
    );
    await DataService.updateExistingModule(
      updated,
      actorEmail: AuthService.currentUser?.email,
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          decision.isPublished
              ? '✅ Updated and published "${module.title}" (${decision.questions.length} Qs).'
              : '📌 Updated "${module.title}" and saved as Pending.',
        ),
        backgroundColor:
            decision.isPublished ? Colors.green.shade700 : Colors.amber.shade800,
      ),
    );
  }

  void _confirmDeleteModule(Module module) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Delete Learning Material?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to delete "${module.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await DataService.deleteModuleById(
                module.id,
                actorEmail: AuthService.currentUser?.email,
              );
              if (mounted) setState(() {});
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, String value) {
    final selected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF00BCD4),
      backgroundColor: const Color(0xFF082D49),
      labelStyle: TextStyle(
        color: Colors.white,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedStatusFilter = value),
    );
  }

  Widget _buildCategoryFilterChip(String label, String value) {
    final selected = _selectedCategoryFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF0288D1),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF0B3C5D),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedCategoryFilter = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacherId = AuthService.currentUser?.id;
    final teacherModules = DataService.getModulesForTeacher(teacherId);
    final publishedCount = teacherModules.where((m) => m.isPublished).length;
    final pendingCount = teacherModules.where((m) => !m.isPublished).length;

    final filteredModules = teacherModules.where((m) {
      if (_selectedStatusFilter == 'published' && !m.isPublished) return false;
      if (_selectedStatusFilter == 'pending' && m.isPublished) return false;
      final matchesCategory = _selectedCategoryFilter == 'all' ||
          m.category == _selectedCategoryFilter;
      if (!matchesCategory) return false;
      final query = _materialSearchCtrl.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      final title = m.title.toLowerCase();
      final code = (m.classCode ?? '').toLowerCase();
      final type = (m.fileType ?? '').toLowerCase();
      return title.contains(query) ||
          code.contains(query) ||
          type.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Learning Materials Management',
          style: TextStyle(
            color: Color(0xFF0B3C5D),
            fontWeight: FontWeight.bold,
            fontSize: 17,
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
                : const Icon(Icons.refresh_rounded, color: Color(0xFF0B3C5D)),
            tooltip: 'Refresh Materials from Firebase',
            onPressed: _isRefreshing ? null : _refreshMaterials,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Deep-Ocean Header & Upload Card (Matches Request Teacher Account UI) ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF082D49), Color(0xFF0B3C5D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.cyanAccent.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF082D49).withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.cyanAccent.withOpacity(0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.folder_copy_rounded,
                              color: Colors.cyanAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Learning Materials Hub',
                                  style: GoogleFonts.playfairDisplay(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${teacherModules.length} Total • $publishedCount Published • $pendingCount Pending',
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isUploading)
                        ValueListenableBuilder< double >(
                          valueListenable: DataService.uploadProgressNotifier,
                          builder: (context, progress, _) {
                            return ValueListenableBuilder< String >(
                              valueListenable: DataService.uploadStatusNotifier,
                              builder: (context, statusText, __) {
                                final pct = (progress * 100).round();
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF031C32)
                                        .withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          Colors.cyanAccent.withOpacity(0.35),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.cyanAccent,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              statusText.isNotEmpty
                                                  ? statusText
                                                  : 'Uploading & extracting learning material...',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (progress > 0)
                                            Text(
                                              '$pct%',
                                              style: const TextStyle(
                                                color: Colors.cyanAccent,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: progress > 0 ? progress : null,
                                          minHeight: 8,
                                          backgroundColor: Colors.white12,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                            Colors.cyanAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00BCD4),
                                      Color(0xFF0288D1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00BCD4)
                                          .withOpacity(0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.upload_file_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                  label: const Text(
                                    'Upload New Learning Material',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  onPressed: _pickAndUploadModule,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed:
                                  _isRefreshing ? null : _refreshMaterials,
                              icon: const Icon(
                                Icons.sync_rounded,
                                color: Colors.cyanAccent,
                                size: 18,
                              ),
                              label: const Text(
                                'Sync',
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF031C32).withOpacity(0.65),
                                side: BorderSide(
                                  color: Colors.cyanAccent.withOpacity(0.4),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Search & Sort/Filter Controls ──
                TextField(
                  controller: _materialSearchCtrl,
                  decoration: InputDecoration(
                    hintText:
                        'Search materials by title, class code, or format (.PDF, .DOCX, .PPTX)...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF0277BD),
                    ),
                    suffixIcon: _materialSearchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _materialSearchCtrl.clear();
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
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip(
                        'All Status (${teacherModules.length})',
                        'all',
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        'Published ($publishedCount)',
                        'published',
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        'Pending / Unpublished ($pendingCount)',
                        'pending',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryFilterChip('All Categories', 'all'),
                      const SizedBox(width: 8),
                      _buildCategoryFilterChip('Modules', 'module'),
                      const SizedBox(width: 8),
                      _buildCategoryFilterChip('Mini Quizzes', 'quiz'),
                      const SizedBox(width: 8),
                      _buildCategoryFilterChip('Mock Exams', 'mock_exam'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Uploaded & Pending Materials List ──
                if (filteredModules.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.folder_open_rounded,
                          size: 46,
                          color: Color(0xFF0277BD),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          teacherModules.isEmpty
                              ? 'No learning materials uploaded yet.\nTap "Upload New Learning Material" above to get started.'
                              : 'No materials match your current search or filter.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black54,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredModules.map((m) {
                    final isQuiz = m.category == 'quiz';
                    final isExam = m.category == 'mock_exam';
                    final categoryBadge = isQuiz
                        ? 'MINI QUIZ'
                        : isExam
                            ? 'MOCK EXAM'
                            : 'MODULE';
                    final accentColor = isExam
                        ? Colors.deepPurple
                        : isQuiz
                            ? const Color(0xFF0277BD)
                            : Colors.teal.shade700;
                    final cleanFileName = DataService.cleanOriginalFileName(m);
                    final fileTypeLabel = DataService.formatTypeLabel(m);
                    final fileSizeLabel = DataService.formatBytesLabel(m.fileSize);
                    final classLabel =
                        DataService.resolveClassDisplayName(m.classCode);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: m.isPublished
                              ? Colors.lightBlue.shade100
                              : Colors.amber.shade400,
                          width: 1.2,
                        ),
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
                                child: Icon(
                                  isQuiz
                                      ? Icons.quiz_outlined
                                      : isExam
                                          ? Icons.fact_check_outlined
                                          : Icons.menu_book_rounded,
                                  color: accentColor,
                                  size: 22,
                                ),
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
                                      'File Type: $fileTypeLabel ($categoryBadge)',
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
                                      'Class: $classLabel • ${m.questions.length} Qs',
                                      softWrap: true,
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
                                  color: m.isPublished
                                      ? Colors.green.shade50
                                      : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: m.isPublished
                                        ? Colors.green.shade300
                                        : Colors.amber.shade400,
                                  ),
                                ),
                                child: Text(
                                  m.isPublished ? '● Published' : '● Pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: m.isPublished
                                        ? Colors.green.shade800
                                        : Colors.amber.shade900,
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
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 17,
                                  ),
                                  label: const Text(
                                    'Open & Preview',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ModuleViewer(module: m),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F8FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.lightBlue.shade200,
                                  ),
                                ),
                                child: PopupMenuButton< String >(
                                  tooltip: 'More Material Actions',
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: Color(0xFF0B3C5D),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  color: Colors.white,
                                  elevation: 8,
                                  onSelected: (action) async {
                                    if (action == 'manage_questions') {
                                      await _editExistingMaterialQuestions(m);
                                    } else if (action == 'toggle_publish') {
                                      final nextState = !m.isPublished;
                                      await DataService
                                          .toggleModulePublishStatus(
                                        m,
                                        nextState,
                                        actorEmail:
                                            AuthService.currentUser?.email,
                                      );
                                      if (!mounted) return;
                                      setState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            nextState
                                                ? '✅ Published "${m.title}" to students.'
                                                : '📌 Moved "${m.title}" to Pending (Unpublished).',
                                          ),
                                        ),
                                      );
                                    } else if (action == 'delete') {
                                      _confirmDeleteModule(m);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem< String >(
                                      value: 'manage_questions',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F8FF),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.lightBlue.shade200,
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.edit_note_rounded,
                                              size: 18,
                                              color: Color(0xFF0277BD),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Manage Questions',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF0277BD),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    PopupMenuItem< String >(
                                      value: 'toggle_publish',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: m.isPublished
                                              ? Colors.amber.shade50
                                              : Colors.green.shade50,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: m.isPublished
                                                ? Colors.amber.shade400
                                                : Colors.green.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              m.isPublished
                                                  ? Icons.unpublished_outlined
                                                  : Icons.publish_rounded,
                                              size: 18,
                                              color: m.isPublished
                                                  ? Colors.amber.shade900
                                                  : Colors.green.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              m.isPublished
                                                  ? 'Move to Pending'
                                                  : 'Publish Now',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: m.isPublished
                                                    ? Colors.amber.shade900
                                                    : Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    PopupMenuItem< String >(
                                      value: 'delete',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.red.shade200,
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: Colors.redAccent,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
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
                  }),
              ],
            ),
          ),
        ),
      ),
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
              color: theme.shadowColor.withValues(alpha: 0.08),
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
                style:
                    theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ) ??
                    TextStyle(
                      fontWeight: FontWeight.w500,
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