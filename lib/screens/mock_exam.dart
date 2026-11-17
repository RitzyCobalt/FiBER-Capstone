import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../services/performance_service.dart';
import '../models/module_model.dart';

class MockExam extends StatefulWidget {
  final Module? initialModule;

  const MockExam({super.key, this.initialModule});

  @override
  State< MockExam > createState() => _MockExamState();
}

class _MockExamState extends State< MockExam > {
  final Random _random = Random();
  int _currentIndex = 0;
  int _score = 0;
  List< Question > _questions = [];
  final Map< int, int > _selectedAnswers = < int, int >{};
  Module? _activeModule;
  bool _finished = false;
  bool _resultSaved = false;
  bool _isRefreshing = false;

  // Board Exam Simulation Timer (longer duration than mini quizzes)
  Timer? _examTimer;
  int _totalExamSeconds = 1800; // 30 mins minimum or 90s per question
  int _remainingSeconds = 1800;
  DateTime _startedAt = DateTime.now();
  final List< dynamic > _answerLog = [];

  @override
  void initState() {
    super.initState();
    DataService.beginLearningActivity('mock_exam');
    DataService.moduleUpdateNotifier.addListener(_onModuleUpdated);
    _loadQuestions(preferred: widget.initialModule);
  }

  @override
  void dispose() {
    DataService.endLearningActivity('mock_exam');
    _examTimer?.cancel();
    DataService.moduleUpdateNotifier.removeListener(_onModuleUpdated);
    super.dispose();
  }

  List< Module > get _availableExamModules {
    final enrolledExams = DataService.getStudentEnrolledModules(
      category: 'mock_exam',
    ).where((m) => m.questions.isNotEmpty).toList();
    if (widget.initialModule != null &&
        !enrolledExams.any((m) => m.id == widget.initialModule!.id)) {
      return < Module >[widget.initialModule!, ...enrolledExams];
    }
    return enrolledExams;
  }

  void _onModuleUpdated() {
    if (!mounted) return;
    if (_questions.isEmpty) {
      setState(() {
        _loadQuestions(preferred: _activeModule ?? widget.initialModule);
      });
    } else {
      setState(() {});
    }
  }

  Future< void > _refreshExamsFromFirebase() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await DataService.loadModules();
    if (!mounted) return;
    setState(() {
      _isRefreshing = false;
      if (_questions.isEmpty && _availableExamModules.isNotEmpty) {
        _loadQuestions(preferred: _activeModule ?? widget.initialModule);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Synced latest mock exams from Firebase.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Shuffles the answer choices of a question while keeping `correctIndex` accurately mapped to the original correct choice.
  Question _shuffleQuestionChoices(Question original) {
    if (original.choices.length <= 1) return original;
    final indexedChoices = List< MapEntry< int, String > >.generate(
      original.choices.length,
      (i) => MapEntry< int, String >(i, original.choices[i]),
    )..shuffle(_random);

    final newChoices = indexedChoices.map((e) => e.value).toList();
    final newCorrectIdx = indexedChoices.indexWhere(
      (e) => e.key == original.correctIndex,
    );

    return Question(
      question: original.question,
      choices: newChoices,
      correctIndex: newCorrectIdx >= 0 ? newCorrectIdx : 0,
    );
  }

  void _startExamTimer() {
    _examTimer?.cancel();
    _totalExamSeconds = (_questions.length * 90).clamp(900, 7200);
    _remainingSeconds = _totalExamSeconds;
    _examTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _finished) return;
      if (_remainingSeconds <= 1) {
        _examTimer?.cancel();
        _remainingSeconds = 0;
        _submitExam();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  String get _formattedRemainingTime {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _loadQuestions({Module? preferred}) {
    final candidates = _availableExamModules;
    if (candidates.isEmpty) {
      _activeModule = null;
      _questions = [];
      _selectedAnswers.clear();
      return;
    }

    _activeModule = preferred ?? candidates.first;

    // Shuffle questions and shuffle choices for every question
    final combined = < Question >[..._activeModule!.questions]..shuffle(_random);

    _questions = combined.take(40).map(_shuffleQuestionChoices).toList();
    _currentIndex = 0;
    _score = 0;
    _selectedAnswers.clear();
    _finished = false;
    _resultSaved = false;
    _startedAt = DateTime.now();
    _answerLog.clear();
    _startExamTimer();
  }

  void _selectAnswer(int index) {
    if (_finished) return;
    setState(() {
      _selectedAnswers[_currentIndex] = index;
    });
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _next() {
    if (_currentIndex + 1 < _questions.length) {
      setState(() => _currentIndex++);
    } else {
      _submitExam();
    }
  }

  void _submitExam() {
    _examTimer?.cancel();
    int computedScore = 0;
    final log = < Map< String, dynamic > >[];

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final selectedIdx = _selectedAnswers[i];
      final isCorrect = selectedIdx != null && selectedIdx == q.correctIndex;
      if (isCorrect) computedScore++;

      final selectedText = (selectedIdx != null &&
              selectedIdx >= 0 &&
              selectedIdx < q.choices.length)
          ? q.choices[selectedIdx]
          : 'No answer selected';
      final correctText =
          (q.correctIndex >= 0 && q.correctIndex < q.choices.length)
              ? q.choices[q.correctIndex]
              : '';

      log.add(< String, dynamic >{
        'question': q.question,
        'selectedChoice': selectedText,
        'correctChoice': correctText,
        'isCorrect': isCorrect,
      });
    }

    setState(() {
      _score = computedScore;
      _answerLog
        ..clear()
        ..addAll(log);
      _finished = true;
      _resultSaved = false;
    });
  }

  void _restart() {
    setState(() {
      _loadQuestions(preferred: _activeModule);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final examModules = _availableExamModules;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 0,
        leading: BackButton(color: theme.colorScheme.onSurface),
        title: Text(
          _activeModule != null
              ? 'Mock Exam • ${_activeModule!.title}'
              : 'Mock Exam',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
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
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Mock Exams from Firebase',
            onPressed: _isRefreshing ? null : _refreshExamsFromFirebase,
          ),
          if (!_finished && _questions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _remainingSeconds <= 60
                    ? Colors.red.shade50
                    : Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _remainingSeconds <= 60
                      ? Colors.red
                      : Colors.deepPurple,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: _remainingSeconds <= 60
                        ? Colors.red
                        : Colors.deepPurple,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formattedRemainingTime,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _remainingSeconds <= 60
                          ? Colors.red
                          : Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _questions.isEmpty
            ? Center(
                child: Text(
                  'No mock examination questions available.\nAsk your teacher to upload a Mock Exam or Module.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            : _finished
            ? _buildResults(theme)
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (examModules.length > 1 && widget.initialModule == null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepPurple.shade100),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton< String >(
                            value: _activeModule?.id ?? examModules.first.id,
                            isExpanded: true,
                            items: examModules
                                .map(
                                  (m) => DropdownMenuItem< String >(
                                    value: m.id,
                                    child: Text(
                                      'Mock Exam: ${m.title}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (selectedId) {
                              final found = examModules.firstWhere(
                                (m) => m.id == selectedId,
                                orElse: () => examModules.first,
                              );
                              setState(() => _loadQuestions(preferred: found));
                            },
                          ),
                        ),
                      ),
                    Expanded(child: _buildQuestion(theme)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildQuestion(ThemeData theme) {
    final q = _questions[_currentIndex];
    final selectedChoiceIndex = _selectedAnswers[_currentIndex];
    final isLastQuestion = _currentIndex + 1 >= _questions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Board Exam Item ${_currentIndex + 1} of ${_questions.length}',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Answered: ${_selectedAnswers.length} / ${_questions.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation(Colors.deepPurpleAccent),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.deepPurple.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    q.question,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ...q.choices.asMap().entries.map((entry) {
                  final i = entry.key;
                  final choice = entry.value;
                  final isSelectedOption = i == selectedChoiceIndex;
                  final letter = String.fromCharCode(65 + i);

                  final Color bgColor = isSelectedOption
                      ? Colors.deepPurple.shade50
                      : theme.colorScheme.surface;
                  final Color borderColor = isSelectedOption
                      ? Colors.deepPurple
                      : theme.colorScheme.outline.withOpacity(0.3);

                  return GestureDetector(
                    onTap: () => _selectAnswer(i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: borderColor,
                          width: isSelectedOption ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: isSelectedOption
                                ? Colors.deepPurple
                                : Colors.deepPurple.shade50,
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelectedOption
                                    ? Colors.white
                                    : Colors.deepPurple,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              choice,
                              style: TextStyle(
                                fontWeight: isSelectedOption
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSelectedOption)
                            const Icon(
                              Icons.radio_button_checked_rounded,
                              color: Colors.deepPurple,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        // ── Bottom Navigation & Submit Bar (No Immediate Feedback) ──
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.deepPurple.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _currentIndex > 0 ? _previous : null,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Previous'),
              ),
              ElevatedButton.icon(
                onPressed: selectedChoiceIndex == null ? null : _next,
                icon: Icon(
                  isLastQuestion
                      ? Icons.check_circle_outline_rounded
                      : Icons.arrow_forward_rounded,
                  size: 16,
                ),
                label: Text(isLastQuestion ? 'Submit Exam' : 'Next Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastQuestion
                      ? Colors.green.shade700
                      : Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(ThemeData theme) {
    final total = _questions.length;
    final wrong = total - _score;
    final accuracy = total == 0 ? 0.0 : (_score / total) * 100.0;
    final durationSec = DateTime.now().difference(_startedAt).inSeconds;

    if (!_resultSaved) {
      _resultSaved = true;
      DataService.addExamTaken();
      final moduleTitle = _activeModule?.title ?? 'General';
      unawaited(
        PerformanceService.recordAssessmentResult(
          type: 'mock_exam',
          score: _score,
          total: total,
          subject: moduleTitle,
          moduleId: _activeModule?.id,
          moduleTitle: moduleTitle,
          durationSeconds: durationSec,
          answerDetails: List< dynamic >.from(_answerLog),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.emoji_events, size: 68, color: Colors.amber),
              const SizedBox(height: 10),
              Text(
                'Mock Examination Results',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '$_score / $total (${accuracy.toStringAsFixed(1)}%)',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const Text(
                      'Total Score & Overall Percentage',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _summaryRow('Total Score', '$_score / $total', Colors.deepPurple),
              const SizedBox(height: 8),
              _summaryRow('Correct Answers', '$_score', Colors.green),
              const SizedBox(height: 8),
              _summaryRow('Incorrect Answers', '$wrong', Colors.red),
              const SizedBox(height: 8),
              _summaryRow(
                'Overall Percentage',
                '${accuracy.toStringAsFixed(1)}%',
                Colors.deepPurple,
              ),
              const SizedBox(height: 8),
              _summaryRow(
                'Time Taken',
                DataService.formatStudySeconds(durationSec),
                Colors.teal,
              ),
              const Divider(height: 28),
              const Text(
                'Complete Question & Answer Review',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B3C5D),
                ),
              ),
              const SizedBox(height: 10),
              ...List< Widget >.generate(_answerLog.length, (i) {
                final item = Map< String, dynamic >.from(_answerLog[i] as Map);
                final isCorrect = item['isCorrect'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCorrect
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item ${i + 1}. ${item['question'] ?? ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: Color(0xFF0B3C5D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your Selected Answer: ${item['selectedChoice'] ?? ''}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isCorrect
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Correct Answer: ${item['correctChoice'] ?? ''}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again (New Shuffled Order)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _restart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}