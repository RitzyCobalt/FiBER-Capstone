import 'package:flutter/material.dart';

// Update this import to the actual location of your Module model
// and ModuleViewer in your project.
import '../models/module_model.dart';
import 'module_viewer.dart';

import '../services/data_service.dart';

class ModuleLibraryPage extends StatefulWidget {
  final List< Module > modules;

  const ModuleLibraryPage({super.key, required this.modules});

  @override
  State< ModuleLibraryPage > createState() => _ModuleLibraryPageState();
}

class _ModuleLibraryPageState extends State< ModuleLibraryPage > {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    DataService.moduleUpdateNotifier.addListener(_onModulesUpdated);
  }

  @override
  void dispose() {
    DataService.moduleUpdateNotifier.removeListener(_onModulesUpdated);
    super.dispose();
  }

  void _onModulesUpdated() {
    if (mounted) setState(() {});
  }

  Future< void > _refreshModules() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await DataService.loadModules();
    if (!mounted) return;
    setState(() => _isRefreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Synced latest modules from Firebase.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final liveModules =
        DataService.getStudentEnrolledModules(category: 'module');
    final modules = liveModules.isNotEmpty ? liveModules : widget.modules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Module Library'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Modules',
            onPressed: _isRefreshing ? null : _refreshModules,
          ),
        ],
      ),
      body: modules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.library_books_outlined,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No modules available yet',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Wait for your teacher to upload a module.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];
                final isQuiz = module.category == 'quiz';
                final isExam = module.category == 'mock_exam';
                final badgeText = isQuiz
                    ? 'MINI QUIZ'
                    : isExam
                        ? 'MOCK EXAM'
                        : 'STUDY MODULE';
                final accentColor = isExam
                    ? Colors.deepPurple
                    : isQuiz
                        ? const Color(0xFF0277BD)
                        : Colors.teal.shade700;

                final cleanFileName = DataService.cleanOriginalFileName(module);
                final fileTypeLabel = DataService.formatTypeLabel(module);
                final fileSizeLabel =
                    DataService.formatBytesLabel(module.fileSize);
                final classLabel =
                    DataService.resolveClassDisplayName(module.classCode);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
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
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: accentColor,
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
                                  'Class: $classLabel • $badgeText (${module.questions.length} Qs)',
                                  softWrap: true,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ModuleViewer(module: module),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('Open Material'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
