import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/performance_service.dart';

class StatisticsHistoryPage extends StatefulWidget {
  const StatisticsHistoryPage({super.key});

  @override
  State< StatisticsHistoryPage > createState() => _StatisticsHistoryPageState();
}

class _StatisticsHistoryPageState extends State< StatisticsHistoryPage > {
  final ScrollController _scrollController = ScrollController();
  List< dynamic > _assessments = const < dynamic >[];
  StudentPerformanceSummary? _summary;
  StudentActivityCounts _counts = StudentActivityCounts.empty;
  bool _initialLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    DataService.moduleUpdateNotifier.addListener(_onUpdated);
    _loadData(showInitialSpinner: true);
  }

  @override
  void dispose() {
    DataService.moduleUpdateNotifier.removeListener(_onUpdated);
    _scrollController.dispose();
    super.dispose();
  }

  void _onUpdated() {
    if (mounted && !_isRefreshing) {
      _loadData(showInitialSpinner: false);
    }
  }

  Future< void > _loadData({bool showInitialSpinner = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (showInitialSpinner && mounted) {
      setState(() => _initialLoading = true);
    }

    try {
      final uid = AuthService.currentUser?.id;
      final results = await Future.wait< dynamic >(< Future< dynamic > >[
        PerformanceService.loadAssessmentHistory(uid: uid),
        PerformanceService.loadLatestSummary(uid: uid),
        PerformanceService.loadStudentActivityCounts(uid: uid),
      ]);
      if (!mounted) return;
      setState(() {
        _assessments = results[0] as List< dynamic >;
        _summary = results[1] as StudentPerformanceSummary?;
        _counts = results[2] as StudentActivityCounts;
        _initialLoading = false;
      });
    } catch (e) {
      debugPrint('StatisticsHistoryPage load error: $e');
      if (mounted && _initialLoading) {
        setState(() => _initialLoading = false);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  void _showAnswerDetailsModal(Map< String, dynamic > record) {
    final details = (record['answerDetails'] as List< dynamic >? ?? [])
        .map((e) => Map< String, dynamic >.from(e as Map))
        .toList();
    final title = (record['moduleTitle'] ?? record['subject'] ?? 'Assessment')
        .toString();

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
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Answer Review • $title',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: details.isEmpty
                      ? const Center(
                          child: Text(
                            'No individual question details recorded for this activity.',
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
                                  backgroundColor: ok
                                      ? Colors.green
                                      : Colors.red,
                                  child: Text(
                                    ok ? '✓' : '✗',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  'Q${i + 1}: ${item['question'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  'Your Answer: ${item['selectedChoice'] ?? ''}\nCorrect Answer: ${item['correctChoice'] ?? ''}',
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF0B3C5D)),
        title: const Text(
          'Activity & Performance History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B3C5D),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0B3C5D)),
            tooltip: 'Refresh History',
            onPressed: () => _loadData(showInitialSpinner: false),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (_initialLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final assessments = _assessments;
            final summary = _summary;
            final counts = _counts;

            return ListView(
              key: const PageStorageKey< String >(
                'activity_performance_history_scroll',
              ),
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // ── Deep-Ocean Gradient Summary Hero Banner ──
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: Colors.cyanAccent,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          ValueListenableBuilder< int >(
                            valueListenable: DataService.studySecondsNotifier,
                            builder: (_, __, ___) => Text(
                              DataService.studyTimeFormatted,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Text(
                            'Total Study Time',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 48,
                        color: Colors.white24,
                      ),
                      Column(
                        children: [
                          const Icon(
                            Icons.verified_outlined,
                            color: Colors.greenAccent,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${assessments.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'Saved Activities',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Upgraded Subject Performance Card (Moved from Home Page) ──
                _buildUpgradedSubjectPerformance(summary),
                const SizedBox(height: 16),

                // ── Upgraded Activity Overview Card (Moved from Home Page) ──
                _buildUpgradedActivityOverview(counts),
                const SizedBox(height: 22),

                const Text(
                  'Completed Quizzes, Mock Exams & Mini Games',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF0B3C5D),
                  ),
                ),
                const SizedBox(height: 10),

                if (assessments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'No completed activities yet. Take a Mini Quiz, Mock Exam, Flashcards session, or Word Hunt game—your results remain saved in the cloud even after logging out.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, height: 1.5),
                    ),
                  )
                else
                  ...assessments.map((raw) {
                    final record = Map< String, dynamic >.from(raw as Map);
                    final type = (record['type'] ?? 'quiz')
                        .toString()
                        .toUpperCase()
                        .replaceAll('_', ' ');
                    final title =
                        (record['moduleTitle'] ??
                                record['subject'] ??
                                'General')
                            .toString();
                    final score = (record['score'] as num?)?.toInt() ?? 0;
                    final total = (record['total'] as num?)?.toInt() ?? 0;
                    final wrong =
                        (record['wrong'] as num?)?.toInt() ?? (total - score);
                    final pct =
                        (record['percentage'] as num?)?.toDouble() ?? 0.0;
                    final hasDetails =
                        (record['answerDetails'] as List< dynamic >? ?? [])
                            .isNotEmpty;
                    final isExam = type.contains('EXAM');
                    final accentColor = isExam
                        ? Colors.deepPurple
                        : const Color(0xFF0277BD);
                    final badgeColor = pct >= 80
                        ? Colors.green
                        : pct >= 50
                            ? Colors.orange.shade800
                            : Colors.redAccent;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: hasDetails
                              ? () => _showAnswerDetailsModal(record)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: accentColor.withOpacity(
                                        0.12,
                                      ),
                                      child: Icon(
                                        isExam
                                            ? Icons.assignment_outlined
                                            : type.contains('QUIZ')
                                                ? Icons.quiz_outlined
                                                : Icons.games_outlined,
                                        color: accentColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Color(0xFF0B3C5D),
                                            ),
                                          ),
                                          Text(
                                            type,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
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
                                        color: badgeColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${pct.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: badgeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '✓ $score Correct',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '✗ $wrong Wrong',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (hasDetails)
                                      const Row(
                                        children: [
                                          Text(
                                            'Review Answers',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0277BD),
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(
                                            Icons.chevron_right,
                                            size: 16,
                                            color: Color(0xFF0277BD),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUpgradedSubjectPerformance(StudentPerformanceSummary? summary) {
    final subjects = summary?.subjects ?? const < SubjectPerformance >[];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5FE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF0277BD),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subject Performance Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.5,
                        color: Color(0xFF0B3C5D),
                      ),
                    ),
                    Text(
                      'Live accuracy across your active enrolled classes',
                      style: TextStyle(fontSize: 11.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (subjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F8FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'No active subject performance data yet. Complete a quiz or mock exam in your enrolled classes to see your mastery breakdown.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            )
          else ...[
            if (summary?.bestSubject != null)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STRONGEST SUBJECT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${summary!.bestSubject} (${summary.bestAverage!.toStringAsFixed(1)}%)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (summary.lowestSubject != null &&
                      summary.lowestSubject != summary.bestSubject) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NEEDS FOCUS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${summary.lowestSubject} (${summary.lowestAverage!.toStringAsFixed(1)}%)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 14),
            ...subjects.map((item) {
              final pct = item.averagePercent.clamp(0.0, 100.0);
              final barColor = pct >= 80
                  ? Colors.green.shade600
                  : pct >= 50
                      ? const Color(0xFF0288D1)
                      : Colors.orange.shade700;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FBFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.lightBlue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.subject,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xFF0B3C5D),
                            ),
                          ),
                        ),
                        Text(
                          '${item.totalScore}/${item.totalPossible} • ${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: barColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: pct / 100.0,
                        minHeight: 9,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation< Color >(barColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildUpgradedActivityOverview(StudentActivityCounts counts) {
    final total = counts.total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Colors.deepPurple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activity Overview',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.5,
                        color: Color(0xFF0B3C5D),
                      ),
                    ),
                    Text(
                      '$total Total Learning Activities Completed',
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _activityStatBox(
                  icon: Icons.quiz_rounded,
                  label: 'Mini-Quizzes',
                  count: counts.quizzes,
                  total: total,
                  color: const Color(0xFF0277BD),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _activityStatBox(
                  icon: Icons.assignment_rounded,
                  label: 'Mock Exams',
                  count: counts.mockExams,
                  total: total,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _activityStatBox(
                  icon: Icons.sports_esports_rounded,
                  label: 'Mini Games',
                  count: counts.games,
                  total: total,
                  color: const Color(0xFF00897B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityStatBox({
    required IconData icon,
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final ratio = total == 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0B3C5D),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation< Color >(color),
            ),
          ),
        ],
      ),
    );
  }
}