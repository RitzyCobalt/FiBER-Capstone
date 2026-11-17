import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'data_service.dart';

class StudentActivityCounts {
  final int quizzes;
  final int mockExams;
  final int games;

  const StudentActivityCounts({
    required this.quizzes,
    required this.mockExams,
    required this.games,
  });

  int get total => quizzes + mockExams + games;

  static const empty = StudentActivityCounts(
    quizzes: 0,
    mockExams: 0,
    games: 0,
  );
}
class SubjectPerformance {
  final String subject;
  final double averagePercent;
  final int attempts;
  final int totalScore;
  final int totalPossible;
  final double passingRate;
  final int passedAttempts;
  final int quizAttempts;
  final int quizScore;
  final int quizPossible;
  final double quizAveragePercent;
  final int mockExamAttempts;
  final int mockExamScore;
  final int mockExamPossible;
  final double mockExamAveragePercent;

  const SubjectPerformance({
    required this.subject,
    required this.averagePercent,
    required this.attempts,
    required this.totalScore,
    required this.totalPossible,
    this.passingRate = 0.0,
    this.passedAttempts = 0,
    this.quizAttempts = 0,
    this.quizScore = 0,
    this.quizPossible = 0,
    this.quizAveragePercent = 0.0,
    this.mockExamAttempts = 0,
    this.mockExamScore = 0,
    this.mockExamPossible = 0,
    this.mockExamAveragePercent = 0.0,
  });

  Map< String, dynamic > toMap() => < String, dynamic >{
    'subject': subject,
    'averagePercent': averagePercent,
    'attempts': attempts,
    'totalScore': totalScore,
    'totalPossible': totalPossible,
    'passingRate': passingRate,
    'passedAttempts': passedAttempts,
    'quizAttempts': quizAttempts,
    'quizScore': quizScore,
    'quizPossible': quizPossible,
    'quizAveragePercent': quizAveragePercent,
    'mockExamAttempts': mockExamAttempts,
    'mockExamScore': mockExamScore,
    'mockExamPossible': mockExamPossible,
    'mockExamAveragePercent': mockExamAveragePercent,
  };
}

class StudentPerformanceSummary {
  final List< SubjectPerformance > subjects;
  final List< SubjectPerformance > categorizedSubjects;
  final double overallAverage;
  final double passingRate;
  final int passedAssessments;
  final String? bestSubject;
  final double? bestAverage;
  final String? lowestSubject;
  final double? lowestAverage;
  final int completedAssessments;
  final int quizAttempts;
  final int quizTotalScore;
  final int quizTotalPossible;
  final double quizAveragePercent;
  final int mockExamAttempts;
  final int mockExamTotalScore;
  final int mockExamTotalPossible;
  final double mockExamAveragePercent;
  final int miniGameAttempts;
  final int miniGameTotalScore;
  final int miniGameCompletedLevels;
  final double miniGameProgressPercent;
  final int totalLearningActivities;
  final double overallProgressPercent;
  final DateTime? capturedAt;

  const StudentPerformanceSummary({
    required this.subjects,
    this.categorizedSubjects = const < SubjectPerformance >[],
    required this.overallAverage,
    this.passingRate = 0.0,
    this.passedAssessments = 0,
    this.bestSubject,
    this.bestAverage,
    this.lowestSubject,
    this.lowestAverage,
    required this.completedAssessments,
    this.quizAttempts = 0,
    this.quizTotalScore = 0,
    this.quizTotalPossible = 0,
    this.quizAveragePercent = 0.0,
    this.mockExamAttempts = 0,
    this.mockExamTotalScore = 0,
    this.mockExamTotalPossible = 0,
    this.mockExamAveragePercent = 0.0,
    this.miniGameAttempts = 0,
    this.miniGameTotalScore = 0,
    this.miniGameCompletedLevels = 0,
    this.miniGameProgressPercent = 0.0,
    this.totalLearningActivities = 0,
    this.overallProgressPercent = 0.0,
    this.capturedAt,
  });

  bool get hasData =>
      subjects.isNotEmpty ||
      completedAssessments > 0 ||
      totalLearningActivities > 0;

  String get summaryLabel {
    if (!hasData) return 'No subject data yet';
    final best = bestSubject ?? 'N/A';
    final lowest = lowestSubject ?? 'N/A';
    return 'Best: $best • Lowest: $lowest';
  }

  static StudentPerformanceSummary empty() => const StudentPerformanceSummary(
    subjects: < SubjectPerformance >[],
    categorizedSubjects: < SubjectPerformance >[
      SubjectPerformance(
        subject: 'Aquaculture',
        averagePercent: 0,
        attempts: 0,
        totalScore: 0,
        totalPossible: 0,
      ),
      SubjectPerformance(
        subject: 'Post-Harvest Fisheries',
        averagePercent: 0,
        attempts: 0,
        totalScore: 0,
        totalPossible: 0,
      ),
      SubjectPerformance(
        subject: 'Fisheries Ecology and Capture Fisheries',
        averagePercent: 0,
        attempts: 0,
        totalScore: 0,
        totalPossible: 0,
      ),
      SubjectPerformance(
        subject: 'Fisheries Resource Management',
        averagePercent: 0,
        attempts: 0,
        totalScore: 0,
        totalPossible: 0,
      ),
    ],
    overallAverage: 0,
    completedAssessments: 0,
  );
}

class StatisticsHistoryEntry {
  final String? id;
  final DateTime savedAt;
  final Map<String, double> subjectAverages;
  final String? bestSubject;
  final double? bestAverage;
  final String? lowestSubject;
  final double? lowestAverage;
  final double overallAverage;
  final int completedAssessments;

  const StatisticsHistoryEntry({
    this.id,
    required this.savedAt,
    required this.subjectAverages,
    this.bestSubject,
    this.bestAverage,
    this.lowestSubject,
    this.lowestAverage,
    required this.overallAverage,
    required this.completedAssessments,
  });

  String get formattedTimestamp {
    final local = savedAt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} • '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() => {
    'savedAt': Timestamp.fromDate(savedAt.toUtc()),
    'subjectAverages': subjectAverages.map(
      (key, value) => MapEntry(key, value),
    ),
    'bestSubject': bestSubject,
    'bestAverage': bestAverage,
    'lowestSubject': lowestSubject,
    'lowestAverage': lowestAverage,
    'overallAverage': overallAverage,
    'completedAssessments': completedAssessments,
  };

  factory StatisticsHistoryEntry.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    final subjectAverages = <String, double>{};
    final rawSubjects = map['subjectAverages'];
    if (rawSubjects is Map) {
      rawSubjects.forEach((key, value) {
        final parsed = value is num
            ? value.toDouble()
            : double.tryParse(value.toString()) ?? 0.0;
        subjectAverages[key.toString()] = parsed;
      });
    }

    final rawSavedAt = map['savedAt'];
    final savedAt = rawSavedAt is Timestamp
        ? rawSavedAt.toDate()
        : DateTime.tryParse(rawSavedAt?.toString() ?? '') ?? DateTime.now();

    return StatisticsHistoryEntry(
      id: id,
      savedAt: savedAt,
      subjectAverages: subjectAverages,
      bestSubject: map['bestSubject']?.toString(),
      bestAverage: (map['bestAverage'] is num)
          ? (map['bestAverage'] as num).toDouble()
          : null,
      lowestSubject: map['lowestSubject']?.toString(),
      lowestAverage: (map['lowestAverage'] is num)
          ? (map['lowestAverage'] as num).toDouble()
          : null,
      overallAverage: (map['overallAverage'] is num)
          ? (map['overallAverage'] as num).toDouble()
          : 0.0,
      completedAssessments: (map['completedAssessments'] is num)
          ? (map['completedAssessments'] as num).toInt()
          : 0,
    );
  }
}

class PerformanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String? _cachedSummaryUid;
  static StudentPerformanceSummary? _cachedSummary;
  static String? _cachedCountsUid;
  static StudentActivityCounts? _cachedCounts;

  static const List< String > canonicalFbleSubjects = < String >[
    'Aquaculture',
    'Post-Harvest Fisheries',
    'Fisheries Ecology and Capture Fisheries',
    'Fisheries Resource Management',
  ];

  static String mapToCanonicalFbleSubject(
    String? rawSubject, {
    String? moduleTitle,
    String? classCode,
  }) {
    final combined = < String >[
      rawSubject ?? '',
      moduleTitle ?? '',
      DataService.resolveClassDisplayName(classCode),
    ].join(' ').toLowerCase();

    if (combined.contains('post-harvest') ||
        combined.contains('post harvest') ||
        combined.contains('postharvest') ||
        combined.contains('processing') ||
        combined.contains('preservation') ||
        combined.contains('canning') ||
        combined.contains('smoking') ||
        combined.contains('drying') ||
        combined.contains('surimi') ||
        combined.contains('histamine') ||
        combined.contains('freezing') ||
        combined.contains('chilling') ||
        combined.contains('fermentation') ||
        combined.contains('quality') ||
        combined.contains('spoilage') ||
        combined.contains('packaging')) {
      return 'Post-Harvest Fisheries';
    }

    if (combined.contains('ecology') ||
        combined.contains('capture') ||
        combined.contains('aquatic') ||
        combined.contains('gear') ||
        combined.contains('trawl') ||
        combined.contains('seine') ||
        combined.contains('gillnet') ||
        combined.contains('longline') ||
        combined.contains('pelagic') ||
        combined.contains('benthic') ||
        combined.contains('oceanography') ||
        combined.contains('limnology') ||
        combined.contains('ichthyology') ||
        combined.contains('navigation') ||
        combined.contains('seamanship') ||
        combined.contains('marine') ||
        combined.contains('estuary') ||
        combined.contains('reef') ||
        combined.contains('mangrove')) {
      return 'Fisheries Ecology and Capture Fisheries';
    }

    if (combined.contains('resource') ||
        combined.contains('management') ||
        combined.contains('law') ||
        combined.contains('policy') ||
        combined.contains('8550') ||
        combined.contains('10654') ||
        combined.contains('conservation') ||
        combined.contains('economics') ||
        combined.contains('extension') ||
        combined.contains('governance') ||
        combined.contains('stock') ||
        combined.contains('ordinance') ||
        combined.contains('bfar')) {
      return 'Fisheries Resource Management';
    }

    if (combined.contains('aquaculture') ||
        combined.contains('hatchery') ||
        combined.contains('pond') ||
        combined.contains('cage') ||
        combined.contains('bangus') ||
        combined.contains('tilapia') ||
        combined.contains('broodstock') ||
        combined.contains('fingerling') ||
        combined.contains('mariculture') ||
        combined.contains('breeding') ||
        combined.contains('feeding') ||
        combined.contains('culture') ||
        combined.contains('shrimp') ||
        combined.contains('prawn')) {
      return 'Aquaculture';
    }

    // Fallback: inspect matching module content keywords if title was generic (e.g. "Quiz 1")
    for (final mod in DataService.modules) {
      if (mod.title.trim().toLowerCase() ==
              (moduleTitle ?? rawSubject ?? '').trim().toLowerCase() &&
          mod.content.isNotEmpty) {
        final contentLower = mod.content
            .substring(0, mod.content.length > 1500 ? 1500 : mod.content.length)
            .toLowerCase();
        if (contentLower.contains('post-harvest') ||
            contentLower.contains('processing') ||
            contentLower.contains('canning')) {
          return 'Post-Harvest Fisheries';
        }
        if (contentLower.contains('capture') ||
            contentLower.contains('ecology') ||
            contentLower.contains('fishing gear')) {
          return 'Fisheries Ecology and Capture Fisheries';
        }
        if (contentLower.contains('resource management') ||
            contentLower.contains('8550') ||
            contentLower.contains('conservation')) {
          return 'Fisheries Resource Management';
        }
      }
    }

    return 'Aquaculture';
  }

  /// Multi-listener stream safe for multiple StreamBuilders and ListView scrolling
  static Stream< StudentPerformanceSummary > watchSummary({String? uid}) {
    return Stream< StudentPerformanceSummary >.multi((controller) async {
      final userId = uid ?? AuthService.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        controller.add(StudentPerformanceSummary.empty());
        return;
      }

      if (_cachedSummary != null && _cachedSummaryUid == userId) {
        controller.add(_cachedSummary!);
      }

      final initial =
          (await loadLatestSummary(uid: userId)) ??
          StudentPerformanceSummary.empty();
      _cachedSummaryUid = userId;
      _cachedSummary = initial;
      if (!controller.isClosed) {
        controller.add(initial);
      }

      StreamSubscription< QuerySnapshot< Map< String, dynamic > > >? sub;
      StreamSubscription< DocumentSnapshot< Map< String, dynamic > > >? userSub;
      Future< void > emitUpdated() async {
        final updated =
            (await loadLatestSummary(uid: userId)) ??
            StudentPerformanceSummary.empty();
        _cachedSummaryUid = userId;
        _cachedSummary = updated;
        if (!controller.isClosed) {
          controller.add(updated);
        }
      }

      try {
        sub = _firestore
            .collection('users')
            .doc(userId)
            .collection('assessment_results')
            .snapshots()
            .listen(
              (_) => emitUpdated(),
              onError: (Object e) {
                debugPrint('watchSummary listener error: $e');
              },
            );
        userSub = _firestore
            .collection('users')
            .doc(userId)
            .snapshots()
            .listen(
              (_) => emitUpdated(),
              onError: (_) {},
            );
      } catch (e) {
        debugPrint('watchSummary setup error: $e');
      }

      controller.onCancel = () {
        sub?.cancel();
        userSub?.cancel();
      };
    });
  }

  /// Multi-listener stream safe for ListView scrolling up and down
  static Stream< StudentActivityCounts > watchActivityCounts({String? uid}) {
    return Stream< StudentActivityCounts >.multi((controller) async {
      final userId = uid ?? AuthService.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        controller.add(StudentActivityCounts.empty);
        return;
      }

      if (_cachedCounts != null) {
        controller.add(_cachedCounts!);
      }

      final initial = await loadStudentActivityCounts(uid: userId);
      _cachedCounts = initial;
      if (!controller.isClosed) {
        controller.add(initial);
      }

      StreamSubscription< QuerySnapshot< Map< String, dynamic > > >? sub;
      try {
        sub = _firestore
            .collection('users')
            .doc(userId)
            .collection('assessment_results')
            .snapshots()
            .listen(
              (_) async {
                final updated = await loadStudentActivityCounts(uid: userId);
                _cachedCounts = updated;
                if (!controller.isClosed) {
                  controller.add(updated);
                }
              },
              onError: (Object e) {
                debugPrint('watchActivityCounts listener error: $e');
              },
            );
      } catch (e) {
        debugPrint('watchActivityCounts setup error: $e');
      }

      controller.onCancel = () {
        sub?.cancel();
      };
    });
  }

  static String _normalizeSubject(String? subject, {String? fallback}) {
    final value = (subject ?? fallback ?? 'General').trim();
    return value.isEmpty ? 'General' : value;
  }

  static double _toPercent(int score, int total) {
    if (total <= 0) return 0;
    return ((score / total) * 100.0).clamp(0.0, 100.0);
  }

  /// Reads assessment records from both users/{uid} and users/{uid}/assessment_results
  /// and automatically mirrors subcollection items into users/{uid} for cross-device APK sync.
  static Future< List< Map< String, dynamic > > > _fetchAllAssessmentEntries(
    String userId,
  ) async {
    final Map< String, Map< String, dynamic > > merged = {};
    List< Map< String, dynamic > > fromUserDoc = [];

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final rawList =
          userDoc.data()?['assessmentResultsList'] as List< dynamic >? ?? [];
      for (final item in rawList) {
        if (item is Map) {
          final map = Map< String, dynamic >.from(item);
          final key =
              (map['attemptKey'] ?? map['completedAtIso'] ?? map.hashCode)
                  .toString();
          merged[key] = map;
          fromUserDoc.add(map);
        }
      }
    } catch (e) {
      debugPrint('Error reading assessmentResultsList from user doc: $e');
    }

    bool foundUnsyncedSubcollectionDocs = false;
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('assessment_results')
          .get();

      for (final doc in snapshot.docs) {
        final data = Map< String, dynamic >.from(doc.data());
        data['id'] = doc.id;
        data.remove('savedAt');
        if (data['completedAt'] is Timestamp) {
          data['completedAt'] = (data['completedAt'] as Timestamp)
              .toDate()
              .toUtc()
              .toIso8601String();
        }
        final key = (data['attemptKey'] ?? doc.id).toString();
        if (!merged.containsKey(key)) {
          foundUnsyncedSubcollectionDocs = true;
        }
        merged[key] = data;
      }
    } catch (_) {}

    final resultList = merged.values.toList();

    if (foundUnsyncedSubcollectionDocs && resultList.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(userId).set({
          'assessmentResultsList': resultList,
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    return resultList;
  }

  static Future< StudentActivityCounts > loadStudentActivityCounts({
    String? uid,
  }) async {
    final userId = uid ?? AuthService.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return StudentActivityCounts(
        quizzes: DataService.quizzesTaken,
        mockExams: DataService.examsTaken,
        games: DataService.gamesPlayed,
      );
    }

    try {
      final entries = await _fetchAllAssessmentEntries(userId);

      int quizzes = 0;
      int mockExams = 0;
      int games = 0;

      for (final data in entries) {
        final type = (data['type'] ?? '').toString().toLowerCase();

        switch (type) {
          case 'quiz':
            quizzes++;
            break;
          case 'mock_exam':
            mockExams++;
            break;
          case 'game':
          case 'word_hunt':
          case 'word_shark':
            games++;
            break;
          default:
            break;
        }
      }

      return StudentActivityCounts(
        quizzes: quizzes == 0 ? DataService.quizzesTaken : quizzes,
        mockExams: mockExams == 0 ? DataService.examsTaken : mockExams,
        games: games == 0 ? DataService.gamesPlayed : games,
      );
    } catch (e) {
      debugPrint('Error loading activity counts: $e');
      return StudentActivityCounts(
        quizzes: DataService.quizzesTaken,
        mockExams: DataService.examsTaken,
        games: DataService.gamesPlayed,
      );
    }
  }

  static Future< StudentPerformanceSummary? > loadLatestSummary({
    String? uid,
  }) async {
    final userId = uid ?? AuthService.currentUser?.id;
    if (userId == null || userId.isEmpty) return null;

    try {
      final entries = await _fetchAllAssessmentEntries(userId);
      final wordHuntProg = await DataService.loadMiniGameProgress(
        gameType: 'word_hunt',
        uid: userId,
      );
      final wordSharkProg = await DataService.loadMiniGameProgress(
        gameType: 'word_shark',
        uid: userId,
      );

      final whCompleted =
          (wordHuntProg['completedLevels'] as List< dynamic >? ?? const [])
              .length;
      final wsCompleted =
          (wordSharkProg['completedLevels'] as List< dynamic >? ?? const [])
              .length;
      final whScore = (wordHuntProg['highestScore'] as int?) ?? 0;
      final wsScore = (wordSharkProg['highestScore'] as int?) ?? 0;
      final whAttempts = (wordHuntProg['attempts'] as int?) ?? whCompleted;
      final wsAttempts = (wordSharkProg['attempts'] as int?) ?? wsCompleted;

      final grouped = < String, List< double > >{};
      final aggregatedPossible = < String, int >{};
      final aggregatedScore = < String, int >{};
      final allAssessmentPercentages = < double >[];

      // Per-canonical-subject accumulators
      final Map< String, List< double > > catAllPcts = < String, List< double > >{
        for (final s in canonicalFbleSubjects) s: < double >[],
      };
      final Map< String, int > catPassed = < String, int >{
        for (final s in canonicalFbleSubjects) s: 0,
      };
      final Map< String, int > catQuizAttempts = < String, int >{
        for (final s in canonicalFbleSubjects) s: 0,
      };
      final Map< String, int > catQuizScore = < String, int >{
        for (final s in canonicalFbleSubjects) s: 0,
      };
      final Map< String, int > catQuizPossible = < String, int >{
        for (final s in canonicalFbleSubjects) s: 0,
      };
      final Map< String, List< double > > catQuizPcts =
          < String, List< double > >{
        for (final s in canonicalFbleSubjects) s: < double >[],
      };
      final Map< String, int > catExamAttempts = < String, int >{
        for (final s in canonicalFbleSubjects) s: 0,
      };
      final Map< String, int > catExamScore = < String, int >{
        for (final s in canonicalFbleSubjects) s: 0,
      };
      final Map< String, int > catExamPossible = < String, int >{
        for (final s in canonicalFbleSubjects) s: 0,
      };
      final Map< String, List< double > > catExamPcts =
          < String, List< double > >{
        for (final s in canonicalFbleSubjects) s: < double >[],
      };

      int quizAttempts = 0;
      int quizTotalScore = 0;
      int quizTotalPossible = 0;
      final List< double > quizPcts = < double >[];

      int mockExamAttempts = 0;
      int mockExamTotalScore = 0;
      int mockExamTotalPossible = 0;
      final List< double > mockExamPcts = < double >[];

      int gameEntriesCount = 0;
      int gameEntriesScore = 0;
      int passedAssessments = 0;

      final allModules = DataService.modules;

      for (final entry in entries) {
        final scoreValue = entry['score'];
        final totalValue = entry['total'];
        final score = scoreValue is num ? scoreValue.toInt() : 0;
        final total = totalValue is num ? totalValue.toInt() : 0;
        if (total <= 0) continue;

        final rawType = (entry['type'] ?? 'quiz').toString().toLowerCase();
        final entryModuleId = (entry['moduleId'] ?? '').toString().trim();
        final entrySubject =
            (entry['subject'] ?? entry['moduleTitle'] ?? '').toString().trim();

        String? matchedClassCode;
        if (allModules.isNotEmpty) {
          final matchingMods = allModules.where((m) {
            if (entryModuleId.isNotEmpty && m.id == entryModuleId) return true;
            return m.title.trim().toLowerCase() == entrySubject.toLowerCase();
          }).toList();
          if (matchingMods.isNotEmpty) {
            matchedClassCode = matchingMods.first.classCode;
          }
        }

        final percent = _toPercent(score, total);
        final isPass = percent >= 50.0;

        if (rawType == 'quiz' || rawType == 'mock_exam') {
          allAssessmentPercentages.add(percent);
          if (isPass) passedAssessments++;

          final subject = _normalizeSubject(
            entry['subject']?.toString(),
            fallback: entry['moduleTitle']?.toString(),
          );
          grouped.putIfAbsent(subject, () => < double >[]).add(percent);
          aggregatedScore[subject] = (aggregatedScore[subject] ?? 0) + score;
          aggregatedPossible[subject] =
              (aggregatedPossible[subject] ?? 0) + total;

          final canonical = mapToCanonicalFbleSubject(
            entry['subject']?.toString(),
            moduleTitle: entry['moduleTitle']?.toString(),
            classCode: matchedClassCode,
          );
          catAllPcts[canonical]!.add(percent);
          if (isPass) {
            catPassed[canonical] = (catPassed[canonical] ?? 0) + 1;
          }

          if (rawType == 'quiz') {
            quizAttempts++;
            quizTotalScore += score;
            quizTotalPossible += total;
            quizPcts.add(percent);

            catQuizAttempts[canonical] = (catQuizAttempts[canonical] ?? 0) + 1;
            catQuizScore[canonical] = (catQuizScore[canonical] ?? 0) + score;
            catQuizPossible[canonical] =
                (catQuizPossible[canonical] ?? 0) + total;
            catQuizPcts[canonical]!.add(percent);
          } else {
            mockExamAttempts++;
            mockExamTotalScore += score;
            mockExamTotalPossible += total;
            mockExamPcts.add(percent);

            catExamAttempts[canonical] = (catExamAttempts[canonical] ?? 0) + 1;
            catExamScore[canonical] = (catExamScore[canonical] ?? 0) + score;
            catExamPossible[canonical] =
                (catExamPossible[canonical] ?? 0) + total;
            catExamPcts[canonical]!.add(percent);
          }
        } else {
          gameEntriesCount++;
          gameEntriesScore += score * 10;
        }
      }

      final categorizedSubjects = canonicalFbleSubjects.map((subj) {
        final pcts = catAllPcts[subj] ?? const < double >[];
        final avg = pcts.isEmpty
            ? 0.0
            : pcts.reduce((a, b) => a + b) / pcts.length;
        final qPcts = catQuizPcts[subj] ?? const < double >[];
        final qAvg = qPcts.isEmpty
            ? 0.0
            : qPcts.reduce((a, b) => a + b) / qPcts.length;
        final ePcts = catExamPcts[subj] ?? const < double >[];
        final eAvg = ePcts.isEmpty
            ? 0.0
            : ePcts.reduce((a, b) => a + b) / ePcts.length;
        final totalAtt = pcts.length;
        final passCnt = catPassed[subj] ?? 0;
        final passRate = totalAtt == 0 ? 0.0 : (passCnt / totalAtt) * 100.0;
        final qScore = catQuizScore[subj] ?? 0;
        final qPoss = catQuizPossible[subj] ?? 0;
        final eScore = catExamScore[subj] ?? 0;
        final ePoss = catExamPossible[subj] ?? 0;

        return SubjectPerformance(
          subject: subj,
          averagePercent: avg,
          attempts: totalAtt,
          totalScore: qScore + eScore,
          totalPossible: qPoss + ePoss,
          passingRate: passRate,
          passedAttempts: passCnt,
          quizAttempts: catQuizAttempts[subj] ?? 0,
          quizScore: qScore,
          quizPossible: qPoss,
          quizAveragePercent: qAvg,
          mockExamAttempts: catExamAttempts[subj] ?? 0,
          mockExamScore: eScore,
          mockExamPossible: ePoss,
          mockExamAveragePercent: eAvg,
        );
      }).toList();

      final subjects = grouped.entries.map((entry) {
        final values = entry.value;
        final avg = values.reduce((a, b) => a + b) / values.length;
        final subjectName = entry.key;
        final totalScore = aggregatedScore[subjectName] ?? 0;
        final totalPossibleValue = aggregatedPossible[subjectName] ?? 0;
        return SubjectPerformance(
          subject: subjectName,
          averagePercent: avg,
          attempts: values.length,
          totalScore: totalScore,
          totalPossible: totalPossibleValue,
        );
      }).toList()
        ..sort(
          (a, b) => a.subject.toLowerCase().compareTo(b.subject.toLowerCase()),
        );

      final activeCategorized =
          categorizedSubjects.where((s) => s.attempts > 0).toList();
      final best = activeCategorized.isNotEmpty
          ? activeCategorized.reduce(
              (a, b) => a.averagePercent >= b.averagePercent ? a : b,
            )
          : (subjects.isNotEmpty
              ? subjects.reduce(
                  (a, b) => a.averagePercent >= b.averagePercent ? a : b,
                )
              : null);
      final lowest = activeCategorized.isNotEmpty
          ? activeCategorized.reduce(
              (a, b) => a.averagePercent <= b.averagePercent ? a : b,
            )
          : (subjects.isNotEmpty
              ? subjects.reduce(
                  (a, b) => a.averagePercent <= b.averagePercent ? a : b,
                )
              : null);

      final overallAverage = allAssessmentPercentages.isEmpty
          ? 0.0
          : allAssessmentPercentages.reduce((a, b) => a + b) /
              allAssessmentPercentages.length;
      final totalAssessments = allAssessmentPercentages.length;
      final passingRate = totalAssessments == 0
          ? 0.0
          : (passedAssessments / totalAssessments) * 100.0;

      final quizAvg = quizPcts.isEmpty
          ? 0.0
          : quizPcts.reduce((a, b) => a + b) / quizPcts.length;
      final examAvg = mockExamPcts.isEmpty
          ? 0.0
          : mockExamPcts.reduce((a, b) => a + b) / mockExamPcts.length;

      final completedLevels = whCompleted + wsCompleted;
      final combinedGameAttempts =
          (whAttempts + wsAttempts) > gameEntriesCount
              ? (whAttempts + wsAttempts)
              : gameEntriesCount;
      final combinedGameScore =
          (whScore + wsScore) > 0 ? (whScore + wsScore) : gameEntriesScore;
      final miniGameProgressPct =
          ((completedLevels / 200.0) * 100.0).clamp(0.0, 100.0);

      final totalActivities =
          quizAttempts + mockExamAttempts + combinedGameAttempts;
      final enrolledMaterialsCount =
          DataService.getStudentEnrolledModules().length;
      final targetActivities =
          (enrolledMaterialsCount > 0 ? enrolledMaterialsCount + 4 : 10);
      final overallProgressPct = totalActivities == 0
          ? 0.0
          : ((totalActivities / targetActivities) * 100.0).clamp(5.0, 100.0);

      return StudentPerformanceSummary(
        subjects: subjects.isNotEmpty ? subjects : activeCategorized,
        categorizedSubjects: categorizedSubjects,
        overallAverage: overallAverage,
        passingRate: passingRate,
        passedAssessments: passedAssessments,
        bestSubject: best?.subject,
        bestAverage: best?.averagePercent,
        lowestSubject: lowest?.subject,
        lowestAverage: lowest?.averagePercent,
        completedAssessments: totalAssessments,
        quizAttempts: quizAttempts,
        quizTotalScore: quizTotalScore,
        quizTotalPossible: quizTotalPossible,
        quizAveragePercent: quizAvg,
        mockExamAttempts: mockExamAttempts,
        mockExamTotalScore: mockExamTotalScore,
        mockExamTotalPossible: mockExamTotalPossible,
        mockExamAveragePercent: examAvg,
        miniGameAttempts: combinedGameAttempts,
        miniGameTotalScore: combinedGameScore,
        miniGameCompletedLevels: completedLevels,
        miniGameProgressPercent: miniGameProgressPct,
        totalLearningActivities: totalActivities,
        overallProgressPercent: overallProgressPct,
        capturedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error loading performance summary: $e');
      return StudentPerformanceSummary.empty();
    }
  }

  static Future<List<StatisticsHistoryEntry>> loadStatisticsHistory({
    String? uid,
  }) async {
    final userId = uid ?? AuthService.currentUser?.id;
    if (userId == null || userId.isEmpty) return const [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('statistics_history')
          .orderBy('savedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => StatisticsHistoryEntry.fromMap(doc.data(), id: doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error loading history: $e');
      return const [];
    }
  }

  static Future<StudentPerformanceSummary?> refreshStudentPerformance({
    String? uid,
  }) async {
    final userId = uid ?? AuthService.currentUser?.id;
    if (userId == null || userId.isEmpty) return null;

    try {
      final current = await loadLatestSummary(uid: userId);
      if (current == null || !current.hasData) {
        return current;
      }

      final historyQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('statistics_history')
          .orderBy('savedAt', descending: true)
          .limit(1)
          .get();

      final newestDoc = historyQuery.docs.isNotEmpty
          ? historyQuery.docs.first
          : null;
      final lastBest = newestDoc?.data()['bestSubject']?.toString();
      final lastWorst = newestDoc?.data()['lowestSubject']?.toString();
      final lastAverage = (newestDoc?.data()['overallAverage'] is num)
          ? (newestDoc!.data()['overallAverage'] as num).toDouble()
          : null;

      final sameSummary =
          lastBest == current.bestSubject &&
          lastWorst == current.lowestSubject &&
          lastAverage != null &&
          (lastAverage - current.overallAverage).abs() < 0.01;

      if (sameSummary) {
        return current;
      }

      final newHistoryEntry = StatisticsHistoryEntry(
        savedAt: DateTime.now(),
        subjectAverages: {
          for (final subject in current.subjects)
            subject.subject: subject.averagePercent,
        },
        bestSubject: current.bestSubject,
        bestAverage: current.bestAverage,
        lowestSubject: current.lowestSubject,
        lowestAverage: current.lowestAverage,
        overallAverage: current.overallAverage,
        completedAssessments: current.completedAssessments,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('statistics_history')
          .add(newHistoryEntry.toMap());

      return current;
    } catch (e) {
      debugPrint('Error refreshing performance history: $e');
      return null;
    }
  }

  static Future< void > recordAssessmentResult({
    required String type,
    required int score,
    required int total,
    String? subject,
    String? moduleId,
    String? moduleTitle,
    int? durationSeconds,
    List< dynamic >? answerDetails,
    DateTime? completedAt,
  }) async {
    final userId = AuthService.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    if (total <= 0 || score < 0 || score > total) return;

    final safeSubject = _normalizeSubject(subject, fallback: moduleTitle);
    final timestamp = (completedAt ?? DateTime.now()).toUtc();
    final wrong = total - score;
    final accuracy = _toPercent(score, total);

    final payload = {
      'type': type,
      'subject': safeSubject,
      'moduleId': moduleId ?? '',
      'moduleTitle': moduleTitle ?? safeSubject,
      'score': score,
      'wrong': wrong,
      'total': total,
      'percentage': accuracy,
      'durationSeconds': durationSeconds ?? 0,
      'studySecondsSnapshot': DataService.studySeconds,
      'answerDetails': answerDetails ?? const [],
      'completedAt': Timestamp.fromDate(timestamp),
      'completedAtIso': timestamp.toIso8601String(),
      'savedAt': FieldValue.serverTimestamp(),
      'attemptKey':
          '${type}_${safeSubject}_${timestamp.millisecondsSinceEpoch}',
    };

    final userDocPayload = < String, dynamic >{
      'type': type,
      'subject': safeSubject,
      'moduleId': moduleId ?? '',
      'moduleTitle': moduleTitle ?? safeSubject,
      'score': score,
      'wrong': wrong,
      'total': total,
      'percentage': accuracy,
      'durationSeconds': durationSeconds ?? 0,
      'studySecondsSnapshot': DataService.studySeconds,
      'answerDetails': answerDetails ?? const [],
      'completedAtIso': timestamp.toIso8601String(),
      'attemptKey':
          '${type}_${safeSubject}_${timestamp.millisecondsSinceEpoch}',
    };

    try {
      await _firestore.collection('users').doc(userId).set({
        'assessmentResultsList': FieldValue.arrayUnion([userDocPayload]),
        'lastAssessmentAt': timestamp.toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving assessment to user doc: $e');
    }

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('assessment_results')
          .add(payload);
    } catch (_) {}

    DataService.notifyModuleUpdated();
    unawaited(refreshStudentPerformance(uid: userId));
  }

  /// Loads all saved assessment attempts & study records from Firestore (persists across logouts/restarts)
  static Future< List< dynamic > > loadAssessmentHistory({String? uid}) async {
    final userId = uid ?? AuthService.currentUser?.id;
    if (userId == null || userId.isEmpty) return const [];

    try {
      final list = await _fetchAllAssessmentEntries(userId);

      list.sort((a, b) {
        final aKey = (a['completedAtIso'] ?? a['attemptKey'] ?? '').toString();
        final bKey = (b['completedAtIso'] ?? b['attemptKey'] ?? '').toString();
        return bKey.compareTo(aKey);
      });
      return list;
    } catch (e) {
      debugPrint('Error loading assessment history: $e');
      return const [];
    }
  }
}
