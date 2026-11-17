import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/performance_service.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State< FlashcardsScreen > createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State< FlashcardsScreen > {
  static final List< dynamic > _flashcards = [];
  static final List< dynamic > _recentlyDeleted = [];
  static final List< String > _subjects = [
    'General',
    'Aquaculture',
    'Capture Fisheries',
    'Post-Harvest Fisheries',
    'Aquatic Resources & Ecology',
  ];

  final Set< String > _reviewedCardIds = {};
  final TextEditingController _searchController = TextEditingController();

  String _selectedSubject = 'All';
  bool _isShuffle = false;
  bool _loadingCloud = true;
  int _correct = 0;
  int _wrong = 0;
  Map< String, dynamic >? _lastDeletedCard;

  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _loadFlashcardsFromFirestore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _scaffoldMessenger?.clearSnackBars();
    _searchController.dispose();
    super.dispose();
  }

  Future< void > _loadFlashcardsFromFirestore() async {
    var user = AuthService.currentUser;
    if (user == null) {
      user = await AuthService.restoreSession();
    }
    final uid = user?.id;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _loadingCloud = false);
      return;
    }

    final loadedActive = < Map< String, dynamic > >[];
    final loadedDeleted = < Map< String, dynamic > >[];

    // 1. First check parent user document for persistent backup list (fastest & bypasses Android Pigeon limits)
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data();
      final backupList =
          (userData?['savedFlashcardsList'] as List< dynamic >?) ?? [];
      for (final item in backupList) {
        if (item is Map) {
          loadedActive.add(Map< String, dynamic >.from(item));
        }
      }
      final backupDeleted =
          (userData?['deletedFlashcardsList'] as List< dynamic >?) ?? [];
      for (final item in backupDeleted) {
        if (item is Map) {
          loadedDeleted.add(Map< String, dynamic >.from(item));
        }
      }
    } catch (e) {
      debugPrint('Flashcards user doc backup read: $e');
    }

    // 2. Also check subcollections and merge without duplicates
    try {
      final activeSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('flashcards')
          .get();

      for (final doc in activeSnap.docs) {
        final data = doc.data();
        if (!loadedActive.any((c) => c['id'] == data['id'])) {
          loadedActive.add(data);
        }
      }

      final deletedSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('deleted_flashcards')
          .get();

      for (final doc in deletedSnap.docs) {
        final data = doc.data();
        if (!loadedDeleted.any((c) => c['id'] == data['id'])) {
          loadedDeleted.add(data);
        }
      }
    } catch (e) {
      debugPrint('Error loading flashcards from subcollections: $e');
    }

    _flashcards
      ..clear()
      ..addAll(loadedActive);

    _recentlyDeleted
      ..clear()
      ..addAll(loadedDeleted);

    for (final raw in _flashcards) {
      final card = Map< String, dynamic >.from(raw as Map);
      _addSubjectIfNeeded(_cardSubject(card));
    }

    if (mounted) {
      setState(() => _loadingCloud = false);
    }
  }

  Future< void > _saveCardToFirestore(Map< String, dynamic > card) async {
    final uid = AuthService.currentUser?.id;
    final id = (card['id'] ?? '').toString();
    if (uid == null || uid.isEmpty || id.isEmpty) return;
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      await userRef.collection('flashcards').doc(id).set(card);
      // Dual-persist to parent doc so cards never disappear on APK restart
      final allCards = _flashcards
          .map((c) => Map< String, dynamic >.from(c as Map))
          .toList();
      await userRef.set(< String, dynamic >{
        'savedFlashcardsList': allCards,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving flashcard: $e');
    }
  }

  Future< void > _moveCardToDeletedFirestore(Map< String, dynamic > card) async {
    final uid = AuthService.currentUser?.id;
    final id = (card['id'] ?? '').toString();
    if (uid == null || uid.isEmpty || id.isEmpty) return;
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      await userRef.collection('flashcards').doc(id).delete();
      await userRef.collection('deleted_flashcards').doc(id).set({
        ...card,
        'deletedAt': DateTime.now().toIso8601String(),
      });
      final allCards = _flashcards
          .map((c) => Map< String, dynamic >.from(c as Map))
          .toList();
      final allDeleted = _recentlyDeleted
          .map((c) => Map< String, dynamic >.from(c as Map))
          .toList();
      await userRef.set(< String, dynamic >{
        'savedFlashcardsList': allCards,
        'deletedFlashcardsList': allDeleted,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error moving flashcard to deleted: $e');
    }
  }

  String _cardSubject(Map< String, dynamic > card) {
    final subject = (card['subject'] ?? 'General').toString().trim();
    return subject.isEmpty ? 'General' : subject;
  }

  List< dynamic > get _filteredFlashcards {
    final query = _searchController.text.trim().toLowerCase();

    return _flashcards
        .map((raw) => Map< String, dynamic >.from(raw as Map))
        .where((card) {
          final subject = _cardSubject(card).toLowerCase();
          final front = (card['front'] ?? '').toString().toLowerCase();
          final back = (card['back'] ?? '').toString().toLowerCase();

          final matchesQuery =
              query.isEmpty ||
              front.contains(query) ||
              back.contains(query) ||
              subject.contains(query);

          final matchesSubject =
              _selectedSubject == 'All' ||
              subject == _selectedSubject.toLowerCase();

          return matchesQuery && matchesSubject;
        })
        .toList();
  }

  Map< String, dynamic > _buildFlashcard({
    required String front,
    required String back,
    String subject = 'General',
    String? imageBase64,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    final cleanSubject = subject.trim().isEmpty ? 'General' : subject.trim();
    return {
      'id':
          'flashcard_${now.microsecondsSinceEpoch}_${Random().nextInt(100000)}',
      'front': front.trim(),
      'back': back.trim(),
      'subject': cleanSubject,
      if (imageBase64 != null && imageBase64.isNotEmpty)
        'imageBase64': imageBase64,
      'createdAt': now.toUtc().toIso8601String(),
    };
  }

  void _addSubjectIfNeeded(String subject) {
    final label = subject.trim();
    if (label.isNotEmpty &&
        !_subjects.any((s) => s.toLowerCase() == label.toLowerCase())) {
      _subjects.add(label);
    }
  }

  // ── Create Flashcard Dialog (With Subject Input, Selector & Image Upload) ────
  void _openCreateDialog() {
    final List< dynamic > newCards = [];
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();
    final subjectCtrl = TextEditingController(
      text: _selectedSubject == 'All' ? 'General' : _selectedSubject,
    );
    String? pickedImageDataUri;
    Uint8List? pickedPreviewBytes;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Create Flashcards',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  if (newCards.isNotEmpty) {
                    setState(() {
                      for (final raw in newCards) {
                        final card = Map< String, dynamic >.from(raw as Map);
                        _flashcards.insert(0, card);
                        _addSubjectIfNeeded(_cardSubject(card));
                        unawaited(_saveCardToFirestore(card));
                      }
                    });
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (newCards.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 12,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BCD4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${newCards.length} card(s) added so far',
                      style: const TextStyle(
                        color: Color(0xFF00BCD4),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const Text(
                  'Subject / Category',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: subjectCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g., Aquaculture, Capture Fisheries...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    suffixIcon: PopupMenuButton< String >(
                      icon: const Icon(Icons.arrow_drop_down),
                      tooltip: 'Choose existing subject',
                      onSelected: (value) {
                        setDialogState(() {
                          subjectCtrl.text = value;
                        });
                      },
                      itemBuilder: (_) => _subjects
                          .map(
                            (s) => PopupMenuItem< String >(
                              value: s,
                              child: Text(s),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Front (Question / Description)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: frontCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter question or description...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (_) => setDialogState(() => error = null),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Back (Answer / Term)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: backCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter answer or term...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (_) => setDialogState(() => error = null),
                ),
                const SizedBox(height: 12),
                if (pickedPreviewBytes != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        pickedPreviewBytes!,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(
                    pickedImageDataUri != null
                        ? 'Change Flashcard Picture'
                        : 'Attach Picture (Optional)',
                  ),
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      withData: true,
                    );
                    if (res == null ||
                        res.files.isEmpty ||
                        res.files.first.bytes == null) {
                      return;
                    }
                    try {
                      final encoded = DataService.encodeAlumniImage(
                        res.files.first.bytes!,
                      );
                      setDialogState(() {
                        pickedImageDataUri = encoded;
                        pickedPreviewBytes = res.files.first.bytes;
                      });
                    } catch (e) {
                      setDialogState(() => error = 'Could not attach image: $e');
                    }
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.check),
              label: Text(newCards.isEmpty ? 'Save & Close' : 'Done'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                if (frontCtrl.text.trim().isNotEmpty &&
                    backCtrl.text.trim().isNotEmpty) {
                  newCards.add(
                    _buildFlashcard(
                      front: frontCtrl.text,
                      back: backCtrl.text,
                      subject: subjectCtrl.text,
                      imageBase64: pickedImageDataUri,
                    ),
                  );
                }
                if (newCards.isNotEmpty) {
                  setState(() {
                    for (final raw in newCards) {
                      final card = Map< String, dynamic >.from(raw as Map);
                      _flashcards.insert(0, card);
                      _addSubjectIfNeeded(_cardSubject(card));
                      unawaited(_saveCardToFirestore(card));
                    }
                  });
                }
                Navigator.pop(context);
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.navigate_next),
              label: const Text('Next Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                if (frontCtrl.text.trim().isEmpty ||
                    backCtrl.text.trim().isEmpty) {
                  setDialogState(
                    () => error = 'Both Front and Back fields are required.',
                  );
                  return;
                }
                setDialogState(() {
                  newCards.add(
                    _buildFlashcard(
                      front: frontCtrl.text,
                      back: backCtrl.text,
                      subject: subjectCtrl.text,
                      imageBase64: pickedImageDataUri,
                    ),
                  );
                  frontCtrl.clear();
                  backCtrl.clear();
                  pickedImageDataUri = null;
                  pickedPreviewBytes = null;
                  error = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete All Flashcards With Confirmation ────────────────────
  void _confirmDeleteAll() {
    if (_flashcards.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete All Flashcards?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete all ${_flashcards.length} flashcard(s)? They will be moved to Recently Deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_sweep),
            label: const Text('Delete All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              final allCards = _flashcards
                  .map((raw) => Map< String, dynamic >.from(raw as Map))
                  .toList();

              setState(() {
                for (final card in allCards) {
                  _recentlyDeleted.insert(0, {
                    ...card,
                    'deletedAt': DateTime.now().toIso8601String(),
                  });
                  unawaited(_moveCardToDeletedFirestore(card));
                }
                _flashcards.clear();
                _reviewedCardIds.clear();
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All flashcards moved to Recently Deleted.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _deleteFlashcardById(String id) {
    final index = _flashcards.indexWhere(
      (raw) => (raw as Map)['id']?.toString() == id,
    );
    if (index == -1) return;

    final card = Map< String, dynamic >.from(_flashcards[index] as Map);

    setState(() {
      _lastDeletedCard = card;
      _flashcards.removeAt(index);
      _recentlyDeleted.removeWhere((item) => (item as Map)['id'] == card['id']);
      _recentlyDeleted.insert(0, {
        ...card,
        'deletedAt': DateTime.now().toIso8601String(),
      });
      _reviewedCardIds.remove(card['id']);
    });

    unawaited(_moveCardToDeletedFirestore(card));

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Expanded(
              child: Text('Flashcard moved to Recently Deleted.'),
            ),
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                _restoreDeletedCard(id);
              },
              child: const Text(
                'UNDO',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _restoreDeletedCard(String id) {
    final index = _recentlyDeleted.indexWhere(
      (raw) => (raw as Map)['id']?.toString() == id,
    );
    if (index == -1) return;

    final deleted = Map< String, dynamic >.from(_recentlyDeleted[index] as Map);
    final card = Map< String, dynamic >.from(deleted)..remove('deletedAt');

    final alreadyActive = _flashcards.any(
      (active) => (active as Map)['id'] == id,
    );

    setState(() {
      if (!alreadyActive) {
        _flashcards.insert(0, card);
      }
      _recentlyDeleted.removeAt(index);
      if (_lastDeletedCard?['id'] == id) {
        _lastDeletedCard = null;
      }
    });

    final uid = AuthService.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      unawaited(
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('deleted_flashcards')
            .doc(id)
            .delete(),
      );
      unawaited(_saveCardToFirestore(card));
    }
  }

  void _confirmDelete(Map< String, dynamic > card) {
    final id = (card['id'] ?? '').toString();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Flashcard?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to delete this flashcard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteFlashcardById(id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRecentlyDeleted() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Recently Deleted',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              _recentlyDeleted.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No recently deleted flashcards.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: _recentlyDeleted.length,
                        itemBuilder: (_, i) {
                          final card = Map< String, dynamic >.from(
                            _recentlyDeleted[i] as Map,
                          );
                          final id = (card['id'] ?? '').toString();
                          return Card(
                            child: ListTile(
                              title: Text(card['front'] ?? ''),
                              subtitle: Text(
                                '${_cardSubject(card)} • ${card['back'] ?? ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.restore,
                                      color: Colors.green,
                                    ),
                                    onPressed: () {
                                      _restoreDeletedCard(id);
                                      setSheetState(() {});
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_forever,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _recentlyDeleted.removeAt(i),
                                      );
                                      setSheetState(() {});
                                      final uid = AuthService.currentUser?.id;
                                      if (uid != null && id.isNotEmpty) {
                                        FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(uid)
                                            .collection('deleted_flashcards')
                                            .doc(id)
                                            .delete();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Start Study Session ────────────────────────────────────────
  Future< void > _startStudySession() async {
    final activeDeck = _filteredFlashcards;
    if (activeDeck.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No flashcards found in this subject filter!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final List< dynamic > deck = List< dynamic >.from(activeDeck);
    if (_isShuffle) deck.shuffle(Random());

    final dynamic rawResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StudySession(
          deck: deck,
          onCardReviewed: (cardId) {
            setState(() {
              _reviewedCardIds.add(cardId);
            });
          },
          onFinish: (correct, wrong) {},
        ),
      ),
    );

    if (!mounted || rawResult == null) return;

    final result = Map< String, int >.from(rawResult as Map);
    final correct = result['correct'] ?? 0;
    final wrong = result['wrong'] ?? 0;
    final total = correct + wrong;

    setState(() {
      _correct = correct;
      _wrong = wrong;
    });

    if (total > 0) {
      DataService.addGamePlayed();
      unawaited(
        PerformanceService.recordAssessmentResult(
          type: 'game',
          score: correct,
          total: total,
          subject: _selectedSubject == 'All' ? 'Flashcards' : _selectedSubject,
          moduleTitle: 'Flashcards',
        ),
      );
    }

    _showResultDialog(correct, wrong);
  }

  // ── Performance Summary & Organized Learning Feedback Dialog ───
  void _showResultDialog(int correct, int wrong) {
    final total = correct + wrong;
    final accuracy = total == 0 ? 0.0 : (correct / total) * 100.0;
    final feedbackText = accuracy >= 80
        ? 'Excellent mastery! Keep up the great review pace.'
        : accuracy >= 50
        ? 'Good effort! Review the missed terms once more to boost your accuracy.'
        : 'Keep practicing! Flip through the cards again to reinforce these terms.';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.analytics_outlined, color: Color(0xFF00BCD4)),
              SizedBox(width: 8),
              Text(
                'Performance Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '${accuracy.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B3C5D),
                      ),
                    ),
                    const Text(
                      'Overall Accuracy Percentage',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _resultRow('Correct Answers', '$correct', Colors.green),
              const SizedBox(height: 8),
              _resultRow('Incorrect Answers', '$wrong', Colors.red),
              const SizedBox(height: 8),
              _resultRow('Total Reviewed', '$total', Colors.blueGrey),
              const Divider(height: 24),
              Text(
                feedbackText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text('Study Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _startStudySession();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _resultRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFlashcards;
    final availableSubjects = < String >['All', ..._subjects];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'Flashcards',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black),
            tooltip: 'Refresh Flashcards from Firebase',
            onPressed: () {
              setState(() => _loadingCloud = true);
              _loadFlashcardsFromFirestore();
            },
          ),
          if (_flashcards.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              tooltip: 'Delete All Flashcards',
              onPressed: _confirmDeleteAll,
            ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black),
            tooltip: 'Recently Deleted',
            onPressed: _showRecentlyDeleted,
          ),
        ],
      ),
      body: _loadingCloud
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Controls: Create, Shuffle, Delete All (Only shown when flashcards exist)
                  if (_flashcards.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Create Flashcard'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00BCD4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _openCreateDialog,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: _isShuffle
                                ? const Color(0xFF00BCD4)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF00BCD4)),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.shuffle,
                              color: _isShuffle
                                  ? Colors.white
                                  : const Color(0xFF00BCD4),
                            ),
                            tooltip: _isShuffle ? 'Shuffle ON' : 'Shuffle OFF',
                            onPressed: () {
                              setState(() {
                                _isShuffle = !_isShuffle;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _confirmDeleteAll,
                          icon: const Icon(
                            Icons.delete_forever,
                            size: 18,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Delete All',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Subject Organization Filter Bar
                  if (_flashcards.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.lightBlue.shade100),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton< String >(
                          value: availableSubjects.contains(_selectedSubject)
                              ? _selectedSubject
                              : 'All',
                          isExpanded: true,
                          icon: const Icon(Icons.filter_list),
                          items: availableSubjects
                              .map(
                                (s) => DropdownMenuItem< String >(
                                  value: s,
                                  child: Text(
                                    s == 'All'
                                        ? 'Subject Filter: All Subjects (${_flashcards.length})'
                                        : 'Subject: $s',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSubject = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (filtered.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${filtered.length} flashcard(s) ready',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                if (_correct + _wrong > 0)
                                  Text(
                                    'Last Session: $_correct Correct • $_wrong Wrong • ${((_correct / (_correct + _wrong)) * 100).toStringAsFixed(0)}% Accuracy',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: _startStudySession,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Expanded(
                    child: _flashcards.isEmpty
                        ? Center(
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxWidth: 380),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'No flashcards yet.\nTap "Create Flashcard" to get started.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: _openCreateDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Create Flashcard'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00BCD4),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final card = Map< String, dynamic >.from(
                                filtered[index] as Map,
                              );
                              final subject = _cardSubject(card);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(
                                      0xFF00BCD4,
                                    ).withOpacity(0.2),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Color(0xFF00BCD4),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.lightBlue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.lightBlue.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          subject,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0277BD),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          card['front'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      card['back'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _confirmDelete(card),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Study Session Screen (With 3D Flip Animation & Accuracy Tracking)
// ══════════════════════════════════════════════════════════════════
class _StudySession extends StatefulWidget {
  final List< dynamic > deck;
  final void Function(int correct, int wrong) onFinish;
  final ValueChanged< String > onCardReviewed;

  const _StudySession({
    required this.deck,
    required this.onFinish,
    required this.onCardReviewed,
  });

  @override
  State< _StudySession > createState() => _StudySessionState();
}

class _StudySessionState extends State< _StudySession > {
  int _index = 0;
  bool _showFront = true;
  int _correct = 0;
  int _wrong = 0;
  bool _answered = false;

  void _flip() => setState(() => _showFront = !_showFront);

  void _openFullCardImage(BuildContext context, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5.0,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white24,
                  ),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Text(
                  'Pinch to zoom • Drag to inspect diagram',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _record(bool isCorrect) {
    if (_answered) return;
    final currentCard = Map< String, dynamic >.from(
      widget.deck[_index] as Map,
    );
    final cardId = currentCard['id'];
    if (cardId != null) {
      widget.onCardReviewed(cardId.toString());
    }
    setState(() => _answered = true);

    if (isCorrect) {
      _correct++;
    } else {
      _wrong++;
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_index + 1 >= widget.deck.length) {
        Navigator.of(context).pop({'correct': _correct, 'wrong': _wrong});
      } else {
        setState(() {
          _index++;
          _showFront = true;
          _answered = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = Map< String, dynamic >.from(widget.deck[_index] as Map);
    final total = widget.deck.length;
    final subject = (card['subject'] ?? 'General').toString();
    final answeredCount = _correct + _wrong;
    final liveAccuracy = answeredCount == 0
        ? 0.0
        : (_correct / answeredCount) * 100.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: Colors.black,
          onPressed: () {
            Navigator.of(context).pop({'correct': _correct, 'wrong': _wrong});
          },
        ),
        title: Text(
          'Card ${_index + 1} of $total ($subject)',
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_index + 1) / total,
                minHeight: 8,
                backgroundColor: Colors.white,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF00BCD4)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '✓ $_correct Correct',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Accuracy: ${liveAccuracy.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF0B3C5D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '✕ $_wrong Wrong',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3D Flipping Flashcard
            Expanded(
              child: GestureDetector(
                onTap: _flip,
                child: TweenAnimationBuilder< double >(
                  key: ValueKey(_index),
                  tween: Tween< double >(begin: 0, end: _showFront ? 0 : pi),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeInOutBack,
                  builder: (context, angle, _) {
                    final isBack = angle >= (pi / 2);
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(angle),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..rotateY(isBack ? pi : 0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isBack
                                ? const Color(0xFFF0FAFF)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isBack
                                  ? Colors.orange.shade300
                                  : const Color(0xFF00BCD4).withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isBack
                                      ? Colors.orange.withOpacity(0.15)
                                      : const Color(
                                          0xFF00BCD4,
                                        ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isBack
                                      ? 'BACK (ANSWER / TERM)'
                                      : 'FRONT (QUESTION)',
                                  style: TextStyle(
                                    color: isBack
                                        ? Colors.deepOrange
                                        : const Color(0xFF00838F),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              if ((card['imageBase64'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () {
                                    try {
                                      final rawBytes = base64Decode(
                                        (card['imageBase64'] as String)
                                            .split(',')
                                            .last,
                                      );
                                      _openFullCardImage(context, rawBytes);
                                    } catch (_) {}
                                  },
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 230,
                                      maxWidth: 320,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.lightBlue.shade100,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          Image.memory(
                                            base64Decode(
                                              (card['imageBase64'] as String)
                                                  .split(',')
                                                  .last,
                                            ),
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.high,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox.shrink(),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.all(6),
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.zoom_in_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  isBack
                                      ? (card['back'] ?? '')
                                      : (card['front'] ?? ''),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.flip_camera_android_rounded,
                                    size: 16,
                                    color: Colors.black38,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _answered
                                        ? 'Moving to next card...'
                                        : 'Tap card to flip',
                                    style: const TextStyle(
                                      color: Colors.black45,
                                      fontSize: 13,
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
              ),
            ),
            const SizedBox(height: 12),
            // ── Backward & Forward Card Navigation Buttons (Section 10) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _index > 0
                      ? () {
                          setState(() {
                            _index--;
                            _showFront = true;
                            _answered = false;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
                  label: const Text('Previous Card'),
                ),
                OutlinedButton.icon(
                  onPressed: _index + 1 < total
                      ? () {
                          setState(() {
                            _index++;
                            _showFront = true;
                            _answered = false;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                  label: const Text('Next Card'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Wrong'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _answered ? Colors.grey : Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _answered ? null : () => _record(false),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Correct'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _answered ? Colors.grey : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _answered ? null : () => _record(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}