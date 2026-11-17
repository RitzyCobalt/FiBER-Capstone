import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/performance_service.dart';
import '../services/sound_service.dart';

class WordSharkQuestionItem {
  final String term;
  final String clue;
  final String subject;

  const WordSharkQuestionItem({
    required this.term,
    required this.clue,
    required this.subject,
  });
}

class _TileData {
  final int id;
  final String letter;

  const _TileData({required this.id, required this.letter});
}

class WordSharkGame extends StatefulWidget {
  const WordSharkGame({super.key});

  @override
  State< WordSharkGame > createState() => _WordSharkGameState();
}

class _WordSharkGameState extends State< WordSharkGame > {
  static const int _maxLevel = 100;

  // Expanded Fisheries Technologist Licensure Exam (FBLE) Glossary across all 4 board subjects
  // Ordered from shorter beginner-friendly terms (3-6 letters) to advanced technical terms (7-12 letters)
  static const List< WordSharkQuestionItem > _fbleGlossary = [
    WordSharkQuestionItem(
      term: 'FRY',
      clue:
          'Newly hatched fish that have absorbed their yolk sac and are ready to actively feed.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'ROE',
      clue:
          'Fully ripe internal egg masses in the ovaries of female fish or aquatic invertebrates.',
      subject: 'Post-Harvest Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'FIN',
      clue:
          'External appendage on a fish body (such as dorsal, pectoral, pelvic, anal, or caudal) used for locomotion and balance.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'NET',
      clue:
          'Webbed mesh gear made of twine or monofilament fibers used in capture fisheries and pond harvesting.',
      subject: 'Capture Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'POND',
      clue:
          'Enclosed earthen or lined water impoundment used for controlled culture of bangus, tilapia, or shrimp.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'GILL',
      clue:
          ' feathery respiratory organ of fish responsible for dissolved oxygen uptake and carbon dioxide release.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'REEF',
      clue:
          'Underwater ridge of calcium carbonate built by hermatypic corals that provides habitat for coastal fishes.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'WEIR',
      clue:
          'Stationary fish trap or barrier (such as a baklad) set in tidal waters to guide fish into a catching chamber.',
      subject: 'Capture Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'CAGE',
      clue:
          'Floating or fixed mesh enclosure suspended in lakes, reservoirs, or coastal waters to rear fish.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'KELP',
      clue:
          'Large brown marine macroalgae belonging to the order Laminariales that forms dense underwater forests.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'TUNA',
      clue:
          'High-value pelagic scombrid fish (such as yellowfin and skipjack) caught by handline and purse seine in the Philippines.',
      subject: 'Capture Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'BAIT',
      clue:
          'Natural or artificial food attractant placed on hooks or inside traps to lure target fish species.',
      subject: 'Capture Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'SPAWN',
      clue:
          'The act of releasing and fertilizing eggs and sperm by aquatic animals such as fish, crabs, and mollusks.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'SEINE',
      clue:
          'Surrounding fishing net that hangs vertically in the water with floats at the top and sinkers along the bottom edge.',
      subject: 'Capture Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'TRAWL',
      clue:
          'Cone-shaped bag net towed through the water column or along the seabed by a powered fishing vessel.',
      subject: 'Capture Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'ALGAE',
      clue:
          'Photosynthetic aquatic organisms ranging from microscopic phytoplankton to macro-seaweeds like Kappaphycus.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'BRINE',
      clue:
          'Concentrated solution of salt (NaCl) in water used for fish salting, smoking pre-treatment, and chilling.',
      subject: 'Post-Harvest Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'PRAWN',
      clue:
          'Decapod crustacean (such as Macrobrachium rosenbergii or Penaeus monodon) prized in brackish and freshwater aquaculture.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'CORAL',
      clue:
          'Colonial marine cnidarian polyps that secrete calcium carbonate skeletons and build tropical reef ecosystems.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'SONAR',
      clue:
          'Acoustic navigation and fish-finding system that uses sound propagation underwater to detect fish schools and bottom depth.',
      subject: 'Capture Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'BANGUS',
      clue:
          'National fish of the Philippines (Chanos chanos), an euryhaline herbivorous species widely cultured in brackishwater ponds and marine cages.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'GAMETE',
      clue:
          'Mature haploid reproductive cell (either spermatozoa/milt in males or ova/eggs in females).',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'ANOXIA',
      clue:
          'Complete depletion of dissolved oxygen in pond or bottom waters, leading to severe fish kills.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'SECCHI',
      clue:
          'Black-and-white circular disk lowered into pond or lake water to measure transparency and plankton turbidity.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'FILLET',
      clue:
          'Boneless longitudinal slice of fish flesh cut parallel to the backbone during post-harvest processing.',
      subject: 'Post-Harvest Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'TILAPIA',
      clue:
          'Hardy freshwater cichlid fish (such as Oreochromis niloticus) extensively farmed in Philippine ponds and cages.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'ARTEMIA',
      clue:
          'Brine shrimp whose newly hatched nauplii serve as an essential live feed for marine fish and shrimp larvae.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'ROTIFER',
      clue:
          'Microscopicwheel-animalcule (such as Brachionus plicatilis) used as a first live starter feed for small-mouthed marine fish larvae.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'BIOFLOC',
      clue:
          'Zero-water-exchange aquaculture system that converts nitrogenous waste into microbial protein aggregates eaten by fish or shrimp.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'HATCHERY',
      clue:
          'Facility where fish or shellfish broodstock are spawned and eggs are incubated and reared to fry or post-larval stages.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'MANGROVE',
      clue:
          'Salt-tolerant coastal forest trees and shrubs that serve as critical nursery grounds for juvenile fish and crustaceans.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'UPWELLING',
      clue:
          'Oceanographic phenomenon where wind-driven currents bring cold, nutrient-rich deep water up to the sunlit surface zone.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'LIMNOLOGY',
      clue:
          'Scientific study of inland aquatic ecosystems including lakes, reservoirs, rivers, streams, and freshwater wetlands.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'FECUNDITY',
      clue:
          'The total number of ripening eggs in the ovary of a female fish prior to the next spawning period.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'AQUACULTURE',
      clue:
          'What is the process of raising and breeding aquatic organisms (fish, crustaceans, mollusks, and aquatic plants) for food or commercial purposes?',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'BROODSTOCK',
      clue:
          'Mature fish or crustaceans kept in hatcheries specifically for breeding and egg production.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'FINGERLING',
      clue:
          'Juvenile fish stage that has developed scales and working fins, typically about the size of a human finger.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'MARICULTURE',
      clue:
          'Specialized branch of aquaculture involving the cultivation of marine organisms in the open ocean or coastal cages.',
      subject: 'Aquaculture',
    ),
    WordSharkQuestionItem(
      term: 'ESTUARY',
      clue:
          'Partially enclosed coastal water body where freshwater from rivers and streams mixes with salty ocean water.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'PLANKTON',
      clue:
          'Microscopic organisms (phytoplankton and zooplankton) that drift in water currents and form the base of the aquatic food web.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'BENTHIC',
      clue:
          'Ecological region at the lowest level of a body of water, including the sediment surface and sub-surface layers.',
      subject: 'Aquatic Resources & Ecology',
    ),
    WordSharkQuestionItem(
      term: 'PELAGIC',
      clue:
          'Open-ocean zone or fish species (such as tuna and sardines) that live and feed in the water column away from the bottom.',
      subject: 'Capture Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'GILLNET',
      clue:
          'Passive fishing gear consisting of vertical panels of netting that entangle fish by their opercula (gills).',
      subject: 'Capture Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'LONGLINE',
      clue:
          'Commercial fishing gear that uses a main line with hundreds of baited hooks attached at intervals via branch lines (snoods).',
      subject: 'Capture Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'BYCATCH',
      clue:
          'Unintended fish or marine species caught during commercial fishing targeting a different species.',
      subject: 'Capture Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'SURIMI',
      clue:
          'Minced, washed, and stabilized fish myofibrillar protein paste used to manufacture crab sticks and fish balls.',
      subject: 'Post-Harvest Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'HISTAMINE',
      clue:
          'Biogenic amine toxin formed in scombroid fish (like tuna and mackerel) when improperly chilled after harvest.',
      subject: 'Post-Harvest Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'BRINING',
      clue:
          'Pre-treatment step in fish smoking and drying where fish are immersed in a concentrated salt solution.',
      subject: 'Post-Harvest Fisheries',
    ),
    WordSharkQuestionItem(
      term: 'SALINITY',
      clue:
          'Measure of the total concentration of dissolved inorganic salts in seawater or brackish pond water (expressed in ppt).',
      subject: 'Aquaculture',
    ),
  ];

  final Random _random = Random();
  List< WordSharkQuestionItem > _levelQuestions = [];
  int _currentLevel = 1;
  int _unlockedLevel = 1;
  Set< int > _completedLevels = < int >{};
  Map< String, int > _levelScores = < String, int >{};
  Map< String, int > _levelStars = < String, int >{};
  int _highestScore = 0;
  int _bestLevelScore = 0;

  bool _inGameplay = false;
  bool _loadingProgress = true;
  String _leaderboardScope = 'all';
  Future< List< Map< String, dynamic > > >? _openingLeaderboardFuture;

  int _questionIndex = 0;

  // Lives reset to 3 on every new question
  int _livesRemaining = 3;
  int _score = 0;
  int _correctCount = 0;
  int _totalQuestionsAnswered = 0;
  int _secondsElapsed = 0;
  Timer? _timer;

  List< _TileData? > _answerSlots = [];
  List< _TileData > _availableTiles = [];
  String? _feedbackBanner;
  bool _feedbackIsPositive = true;
  bool _questionLocked = false;
  String _sessionAttemptKey = '';

  @override
  void initState() {
    super.initState();
    DataService.startStudyTimer(uid: AuthService.currentUser?.id);
    _initializeWordSharkHub();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SoundService.stopBgm();
    super.dispose();
  }

  Future< void > _initializeWordSharkHub() async {
    final uid = AuthService.currentUser?.id;
    final progress = await DataService.loadMiniGameProgress(
      gameType: 'word_shark',
      uid: uid,
    );
    SoundService.applySavedSettings(
      bgm: progress['bgmEnabled'] as bool?,
      sfx: progress['sfxEnabled'] as bool?,
      vibration: progress['vibrationEnabled'] as bool?,
    );
    if (!mounted) return;
    setState(() {
      _unlockedLevel = ((progress['unlockedLevel'] as int?) ?? 1).clamp(
        1,
        _maxLevel,
      );
      _currentLevel = _unlockedLevel;
      _completedLevels = Set< int >.from(
        (progress['completedLevels'] as List< dynamic >? ?? const [])
            .map((e) => (e as num).toInt()),
      );
      _levelScores = Map< String, int >.from(
        (progress['levelScores'] as Map? ?? const {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ),
      );
      _levelStars = Map< String, int >.from(
        (progress['levelStars'] as Map? ?? const {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ),
      );
      _highestScore = (progress['highestScore'] as int?) ?? 0;
      _bestLevelScore = (progress['bestLevelScore'] as int?) ?? 0;
      _loadingProgress = false;
      _refreshOpeningLeaderboard();
    });
  }

  void _refreshOpeningLeaderboard() {
    final classFilter = _leaderboardScope == 'all' ? null : _leaderboardScope;
    _openingLeaderboardFuture = DataService.loadMiniGameLeaderboard(
      gameType: 'word_shark',
      classCode: classFilter,
    );
  }

  void _persistAudioVibrationSettings() {
    DataService.saveMiniGameSettings(
      uid: AuthService.currentUser?.id,
      bgmEnabled: SoundService.bgmEnabled,
      sfxEnabled: SoundService.soundEffectsEnabled,
      vibrationEnabled: SoundService.vibrationEnabled,
    );
  }

  void _startSelectedLevel(int level) {
    if (level > _unlockedLevel) {
      SoundService.playWrongWord();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔒 Level $level is locked! Complete Level $_unlockedLevel first.',
          ),
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    SoundService.playTap();
    SoundService.startBgmIfNeeded();
    setState(() => _inGameplay = true);
    _startNewGameSession(level: level);
  }

  void _startNewGameSession({required int level}) {
    _timer?.cancel();
    _currentLevel = level.clamp(1, _maxLevel);
    _score = 0;
    _correctCount = 0;
    _totalQuestionsAnswered = 0;
    _secondsElapsed = 0;
    _sessionAttemptKey =
        'word_shark_${_currentLevel}_${DateTime.now().millisecondsSinceEpoch}';

    _levelQuestions = _buildQuestionsForLevel(_currentLevel);
    _questionIndex = 0;
    _setupCurrentQuestion();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _inGameplay) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  List< WordSharkQuestionItem > _buildQuestionsForLevel(int level) {
    final pool = < WordSharkQuestionItem >[..._fbleGlossary];

    final enrolledModules = DataService.getStudentEnrolledModules();
    for (final mod in enrolledModules) {
      for (final q in mod.questions) {
        if (q.correctIndex >= 0 && q.correctIndex < q.choices.length) {
          final ans = q.choices[q.correctIndex]
              .trim()
              .toUpperCase()
              .replaceAll(RegExp(r'[^A-Z]'), '');
          if (ans.length >= 3 &&
              ans.length <= 12 &&
              !pool.any((item) => item.term == ans)) {
            pool.add(
              WordSharkQuestionItem(
                term: ans,
                clue: q.question.replaceAll('_____', '________'),
                subject: mod.title,
              ),
            );
          }
        }
      }
    }

    // Progressive word length & round count across all 100 levels (Sections 3.2 & 3.3)
    int minLen;
    int maxLen;
    int questionsPerLevel;
    if (level <= 15) {
      minLen = 3;
      maxLen = 5;
      questionsPerLevel = 3;
    } else if (level <= 35) {
      minLen = 4;
      maxLen = 7;
      questionsPerLevel = 4;
    } else if (level <= 65) {
      minLen = 5;
      maxLen = 9;
      questionsPerLevel = 4;
    } else {
      minLen = 6;
      maxLen = 12;
      questionsPerLevel = 5;
    }

    var filtered = pool
        .where(
          (item) => item.term.length >= minLen && item.term.length <= maxLen,
        )
        .toList();
    if (filtered.length < questionsPerLevel) {
      filtered = List< WordSharkQuestionItem >.from(pool);
    }
    filtered.shuffle(Random());
    return filtered.take(questionsPerLevel).toList();
  }

  /// Shuffles the letter blocks in the choices field whenever a new round/level begins (Section 3.1),
  /// ensuring all required letters are preserved and the shuffled order is never identical to the unshuffled word.
  void _setupCurrentQuestion() {
    final current = _levelQuestions[_questionIndex];
    final word = current.term.trim().toUpperCase();

    _livesRemaining = 3;
    _questionLocked = false;
    _feedbackBanner = null;
    _answerSlots = List< _TileData? >.filled(word.length, null);

    final requiredLetters = word.split('');
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final decoyCount = _currentLevel <= 15
        ? 1
        : _currentLevel <= 45
            ? 2
            : _currentLevel <= 75
                ? 3
                : 4;

    final combinedLetters = < String >[...requiredLetters];
    for (int i = 0; i < decoyCount; i++) {
      combinedLetters.add(alphabet[_random.nextInt(alphabet.length)]);
    }

    final rng = Random();
    for (int attempt = 0; attempt < 12; attempt++) {
      combinedLetters.shuffle(rng);
      if (combinedLetters.take(word.length).join() != word) {
        break;
      }
    }

    _availableTiles = List< _TileData >.generate(
      combinedLetters.length,
      (i) => _TileData(id: i, letter: combinedLetters[i]),
    );
    if (mounted) setState(() {});
  }

  bool _isTilePlaced(_TileData tile) {
    return _answerSlots.any((slot) => slot?.id == tile.id);
  }

  void _placeTileInSlot(_TileData tile, int slotIndex) {
    if (_questionLocked) return;
    if (slotIndex < 0 || slotIndex >= _answerSlots.length) return;

    SoundService.playTap();
    setState(() {
      // Remove from previous slot if moved
      for (int i = 0; i < _answerSlots.length; i++) {
        if (_answerSlots[i]?.id == tile.id) {
          _answerSlots[i] = null;
        }
      }
      _answerSlots[slotIndex] = tile;
      _feedbackBanner = null;
    });

    if (!_answerSlots.contains(null)) {
      _checkSubmittedWord();
    }
  }

  void _tapTileToNextEmptySlot(_TileData tile) {
    if (_questionLocked) return;
    if (_isTilePlaced(tile)) return;
    final emptyIdx = _answerSlots.indexWhere((s) => s == null);
    if (emptyIdx == -1) return;
    _placeTileInSlot(tile, emptyIdx);
  }

  void _removeTileFromSlot(int slotIndex) {
    if (_questionLocked) return;
    if (_answerSlots[slotIndex] == null) return;
    SoundService.playTap();
    setState(() {
      _answerSlots[slotIndex] = null;
      _feedbackBanner = null;
    });
  }

  void _clearAllSlots() {
    if (_questionLocked) return;
    SoundService.playTap();
    setState(() {
      for (int i = 0; i < _answerSlots.length; i++) {
        _answerSlots[i] = null;
      }
      _feedbackBanner = null;
    });
  }

  void _checkSubmittedWord() {
    final target = _levelQuestions[_questionIndex].term.toUpperCase();
    final formed = _answerSlots.map((t) => t?.letter ?? '').join();

    if (formed == target) {
      SoundService.playCorrectWord();
      // Award points based on word length and remaining lives (attempts)
      final earnedPoints = (target.length * 10) + (_livesRemaining * 15);
      setState(() {
        _questionLocked = true;
        _score += earnedPoints;
        _correctCount++;
        _totalQuestionsAnswered++;
        _feedbackIsPositive = true;
        _feedbackBanner =
            '✓ Correct! "$target" (+$earnedPoints pts)';
      });

      Future< void >.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        _advanceToNextQuestion();
      });
    } else {
      SoundService.playWrongWord();
      setState(() {
        _livesRemaining = (_livesRemaining - 1).clamp(0, 3);
        _feedbackIsPositive = false;
        if (_livesRemaining > 0) {
          _feedbackBanner =
              '✗ Incorrect arrangement! Shark moved closer ($_livesRemaining ${(_livesRemaining == 1) ? "attempt" : "attempts"} left). Try again!';
        } else {
          // Out of attempts: reveal the correct answer and allow student to proceed
          _questionLocked = true;
          _totalQuestionsAnswered++;
          _feedbackBanner =
              '🦈 Out of attempts! Correct Answer: $target';
          final correctChars = target.split('');
          _answerSlots = List< _TileData? >.generate(
            correctChars.length,
            (i) => _TileData(id: 900 + i, letter: correctChars[i]),
          );
        }
      });
    }
  }

  void _advanceToNextQuestion() {
    if (_questionIndex + 1 < _levelQuestions.length) {
      setState(() {
        _questionIndex++;
      });
      _setupCurrentQuestion();
    } else {
      _onLevelCompleted();
    }
  }

  Future< void > _onLevelCompleted() async {
    _timer?.cancel();
    SoundService.playGameComplete();

    final total = _totalQuestionsAnswered == 0 ? 1 : _totalQuestionsAnswered;
    final accuracy = (_correctCount / total) * 100.0;
    final passedLevel = _correctCount > 0;
    final earnedStars = accuracy >= 90
        ? 3
        : accuracy >= 60
            ? 2
            : 1;

    DataService.addGamePlayed();

    if (passedLevel) {
      final updated = await DataService.saveMiniGameLevelCompletion(
        gameType: 'word_shark',
        level: _currentLevel,
        score: _score,
        stars: earnedStars,
        uid: AuthService.currentUser?.id,
      );
      if (updated['unlockedNewLevel'] == true) {
        SoundService.playLevelUnlock();
      }
      if (mounted) {
        setState(() {
          _unlockedLevel =
              (updated['unlockedLevel'] as int?) ?? _unlockedLevel;
          _completedLevels = Set< int >.from(
            (updated['completedLevels'] as List< dynamic >? ?? const [])
                .map((e) => (e as num).toInt()),
          );
          _levelScores = Map< String, int >.from(
            (updated['levelScores'] as Map? ?? const {}).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ),
          );
          _levelStars = Map< String, int >.from(
            (updated['levelStars'] as Map? ?? const {}).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ),
          );
          _highestScore = (updated['highestScore'] as int?) ?? _highestScore;
          _bestLevelScore =
              (updated['bestLevelScore'] as int?) ?? _bestLevelScore;
          _refreshOpeningLeaderboard();
        });
      }
    }

    unawaited(
      PerformanceService.recordAssessmentResult(
        type: 'word_shark',
        score: _correctCount,
        total: total,
        subject: 'Word Shark',
        moduleTitle: 'Word Shark (Level $_currentLevel • $_score pts)',
        durationSeconds: _secondsElapsed,
      ),
    );

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Word Shark Complete',
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim.value),
          child: Opacity(
            opacity: anim.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (passedLevel)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: _WordSharkConfettiOverlay(),
                    ),
                  ),
                Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
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
                          color: passedLevel
                              ? Colors.amberAccent
                              : Colors.redAccent,
                          width: 1.8,
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            passedLevel
                                ? Icons.emoji_events_rounded
                                : Icons.replay_circle_filled_rounded,
                            size: 60,
                            color: passedLevel
                                ? Colors.amberAccent
                                : Colors.redAccent,
                          ),
                          const SizedBox(height: 8),
                          if (passedLevel)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List< Widget >.generate(3, (i) {
                                final earned = i < earnedStars;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Icon(
                                    earned
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: earned
                                        ? Colors.amberAccent
                                        : Colors.white30,
                                    size: 32,
                                  ),
                                );
                              }),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            passedLevel
                                ? 'Congratulations! Level $_currentLevel Complete!'
                                : 'Level $_currentLevel Finished!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            passedLevel
                                ? (_currentLevel < _maxLevel
                                    ? 'Level ${_currentLevel + 1} is now unlocked!'
                                    : 'You conquered all 100 levels of Word Shark!')
                                : 'Spell at least 1 word correctly to unlock the next level!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF031C32).withOpacity(0.75),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$_score PTS',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amberAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Accuracy: ${accuracy.toStringAsFixed(0)}% ($_correctCount/$total) • Total Best: $_highestScore pts',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _inGameplay = false;
                                    _refreshOpeningLeaderboard();
                                  });
                                },
                                icon: const Icon(Icons.map_rounded, size: 17),
                                label: const Text('Level Map'),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.cyanAccent,
                                  side: const BorderSide(
                                    color: Colors.cyanAccent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _startNewGameSession(level: _currentLevel);
                                },
                                icon:
                                    const Icon(Icons.replay_rounded, size: 17),
                                label: const Text('Replay'),
                              ),
                              if (passedLevel && _currentLevel < _maxLevel)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00BCD4),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _startNewGameSession(
                                      level: _currentLevel + 1,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.navigate_next_rounded,
                                    size: 20,
                                  ),
                                  label: Text(
                                    'Next (Level ${_currentLevel + 1})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showClassLeaderboardModal() {
    final joinedCodes = DataService.joinedClassCodes;
    String selectedClass = joinedCodes.isNotEmpty ? joinedCodes.first : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: 440,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE1F5FE),
                        child: Icon(
                          Icons.leaderboard_rounded,
                          color: Color(0xFF0277BD),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Word Shark Class Leaderboard',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B3C5D),
                              ),
                            ),
                            Text(
                              'Rankings among classmates in your enrolled class',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (joinedCodes.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Join a class first using your teacher\'s FIBER-XXXX code to view your class leaderboard!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    )
                  else ...[
                    if (joinedCodes.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField< String >(
                          initialValue: selectedClass,
                          decoration: InputDecoration(
                            labelText: 'Select Class',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: joinedCodes
                              .map(
                                (c) => DropdownMenuItem< String >(
                                  value: c,
                                  child: Text('Class $c'),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => selectedClass = val);
                            }
                          },
                        ),
                      ),
                    Expanded(
                      child: FutureBuilder< List< Map< String, dynamic > > >(
                        future: DataService.loadClassGameLeaderboard(
                          classCode: selectedClass,
                          gameType: 'word_shark',
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final rankings = snapshot.data ?? [];
                          if (rankings.isEmpty) {
                            return const Center(
                              child: Text('No classmates found in this class.'),
                            );
                          }
                          return ListView.builder(
                            itemCount: rankings.length,
                            itemBuilder: (_, idx) {
                              final row = rankings[idx];
                              final isMe =
                                  row['uid'] == AuthService.currentUser?.id;
                              final bestScore = row['bestScore'] as int;
                              final bestAcc = row['bestAccuracy'] as double;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFFE1F5FE)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isMe
                                        ? const Color(0xFF0288D1)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: idx == 0
                                        ? Colors.amber
                                        : idx == 1
                                            ? Colors.blueGrey.shade300
                                            : idx == 2
                                                ? Colors.brown.shade300
                                                : const Color(0xFF0277BD),
                                    child: Text(
                                      '#${idx + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    '${row['name']}${isMe ? " (You)" : ""}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0B3C5D),
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Best Accuracy: ${bestAcc.toStringAsFixed(0)}% • Attempts: ${row['attempts']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Text(
                                    '$bestScore Correct',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF0277BD),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_inGameplay) {
      return _buildOpeningScreen(context);
    }

    final currentQ = _levelQuestions[_questionIndex];
    final sharkDanger = ((3 - _livesRemaining) / 3.0).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF041C32),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Back to Level Map',
          onPressed: () {
            _timer?.cancel();
            setState(() {
              _inGameplay = false;
              _refreshOpeningLeaderboard();
            });
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00BCD4), Color(0xFF0288D1)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'LEVEL $_currentLevel / $_maxLevel',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Word Shark',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.leaderboard_rounded,
              color: Colors.amberAccent,
            ),
            tooltip: 'Leaderboard',
            onPressed: _showClassLeaderboardModal,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF041C32),
              Color(0xFF0B3C5D),
              Color(0xFF0277BD),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenW = constraints.maxWidth;
              final screenH = constraints.maxHeight;
              final isCompactPhone = screenH < 640;
              // Dynamically size slot & tile blocks so long words fit on any phone width
              final wordLen = max(1, _answerSlots.length);
              final maxTileWidth =
                  ((screenW - 48) / min(wordLen, 8) - 6).clamp(32.0, 44.0);
              final tileHeight = (maxTileWidth * 1.12).clamp(36.0, 48.0);

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenW > 600 ? 24 : 14,
                  vertical: isCompactPhone ? 6 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Top Status Bar: Round Progress, Score, Lives ──
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isCompactPhone ? 7 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Word ${_questionIndex + 1}/${_levelQuestions.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Score: $_score pts',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          Row(
                            children: List< Widget >.generate(3, (i) {
                              final alive = i < _livesRemaining;
                              return Padding(
                                padding: const EdgeInsets.only(left: 3),
                                child: Icon(
                                  alive
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color:
                                      alive ? Colors.redAccent : Colors.white38,
                                  size: 19,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isCompactPhone ? 8 : 10),

                    // ── Animated Underwater Shark Tracker Bar ──
                    Container(
                      height: isCompactPhone ? 44 : 52,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF032539),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _livesRemaining == 1
                              ? Colors.redAccent
                              : Colors.cyanAccent.withOpacity(0.35),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, barConstraints) {
                          final maxTravel =
                              (barConstraints.maxWidth - 84).clamp(0.0, 600.0);
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeOutBack,
                                left: maxTravel * sharkDanger,
                                child: Row(
                                  children: [
                                    Text(
                                      '🦈',
                                      style: TextStyle(
                                        fontSize: isCompactPhone ? 24 : 28,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.double_arrow_rounded,
                                      color: Colors.cyanAccent,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 4,
                                child: Text(
                                  '🐟',
                                  style: TextStyle(
                                    fontSize: isCompactPhone ? 22 : 26,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: isCompactPhone ? 8 : 12),

                    // ── Dynamic Scrollable Clue, Slots & Shuffled Letter Bank ──
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: EdgeInsets.all(isCompactPhone ? 14 : 18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE1F5FE),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${currentQ.subject.toUpperCase()} • ${currentQ.term.length} LETTERS',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0277BD),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    currentQ.clue,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isCompactPhone ? 14 : 15.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0B3C5D),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isCompactPhone ? 12 : 16),

                            const Text(
                              'Drag or tap randomized letters into the answer blocks:',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 5,
                              runSpacing: 7,
                              alignment: WrapAlignment.center,
                              children: List< Widget >.generate(
                                _answerSlots.length,
                                (slotIdx) {
                                  final placedTile = _answerSlots[slotIdx];
                                  return DragTarget< _TileData >(
                                    onWillAcceptWithDetails: (_) =>
                                        !_questionLocked,
                                    onAcceptWithDetails: (details) =>
                                        _placeTileInSlot(details.data, slotIdx),
                                    builder: (context, candidateData, _) {
                                      final isHovering =
                                          candidateData.isNotEmpty;
                                      return GestureDetector(
                                        onTap: () =>
                                            _removeTileFromSlot(slotIdx),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          width: maxTileWidth,
                                          height: tileHeight,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: placedTile != null
                                                ? const Color(0xFF00BCD4)
                                                : isHovering
                                                    ? Colors.cyanAccent
                                                        .withOpacity(0.35)
                                                    : Colors.white
                                                        .withOpacity(0.14),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: placedTile != null
                                                  ? Colors.white
                                                  : Colors.cyanAccent,
                                              width: 1.8,
                                            ),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              placedTile?.letter ?? '_',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: placedTile != null
                                                    ? Colors.white
                                                    : Colors.white54,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),

                            if (_feedbackBanner != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _feedbackIsPositive
                                      ? Colors.green.shade600
                                      : Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _feedbackIsPositive
                                          ? Icons.check_circle_rounded
                                          : Icons.warning_amber_rounded,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _feedbackBanner!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                    if (_questionLocked && !_feedbackIsPositive)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor:
                                              const Color(0xFF0B3C5D),
                                        ),
                                        onPressed: _advanceToNextQuestion,
                                        child: const Text('Next Word'),
                                      ),
                                  ],
                                ),
                              ),
                            ],

                            SizedBox(height: isCompactPhone ? 12 : 18),

                            // ── Randomized Letter Blocks Choices Field (Section 3.1) ──
                            Container(
                              padding: EdgeInsets.all(isCompactPhone ? 10 : 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(
                                children: [
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 7,
                                    alignment: WrapAlignment.center,
                                    children: _availableTiles.map((tile) {
                                      final used = _isTilePlaced(tile);
                                      final tileWidget = Container(
                                        width: maxTileWidth + 2,
                                        height: tileHeight,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          gradient: used
                                              ? null
                                              : const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFFB300),
                                                    Color(0xFFF57C00),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                          color: used ? Colors.white12 : null,
                                          borderRadius:
                                              BorderRadius.circular(11),
                                          boxShadow: used
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.2),
                                                    blurRadius: 4,
                                                    offset:
                                                        const Offset(0, 2),
                                                  ),
                                                ],
                                        ),
                                        child: Text(
                                          used ? '' : tile.letter,
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );

                                      if (used || _questionLocked) {
                                        return tileWidget;
                                      }

                                      return Draggable< _TileData >(
                                        data: tile,
                                        feedback: Material(
                                          color: Colors.transparent,
                                          child: Transform.scale(
                                            scale: 1.15,
                                            child: tileWidget,
                                          ),
                                        ),
                                        childWhenDragging: Opacity(
                                          opacity: 0.3,
                                          child: tileWidget,
                                        ),
                                        child: GestureDetector(
                                          onTap: () =>
                                              _tapTileToNextEmptySlot(tile),
                                          child: tileWidget,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      TextButton.icon(
                                        onPressed: _questionLocked
                                            ? null
                                            : _clearAllSlots,
                                        icon: const Icon(
                                          Icons.backspace_outlined,
                                          size: 16,
                                          color: Colors.cyanAccent,
                                        ),
                                        label: const Text(
                                          'Clear Letters',
                                          style: TextStyle(
                                            color: Colors.cyanAccent,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: _questionLocked
                                            ? null
                                            : () {
                                                SoundService.playTap();
                                                setState(() {
                                                  _availableTiles
                                                      .shuffle(_random);
                                                });
                                              },
                                        icon: const Icon(
                                          Icons.shuffle_rounded,
                                          size: 16,
                                          color: Colors.amberAccent,
                                        ),
                                        label: const Text(
                                          'Shuffle Choices',
                                          style: TextStyle(
                                            color: Colors.amberAccent,
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
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  WORD SHARK OPENING SCREEN (Section 4: Title, Instructions,
  //  Current Level, Candy Crush 100-Level Map, Locked/Unlocked,
  //  Highest Score, Leaderboard, Play/Continue, Sound & Vibration)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildOpeningScreen(BuildContext context) {
    final joinedClasses = DataService.joinedClassCodes;

    return Scaffold(
      backgroundColor: const Color(0xFF041C32),
      appBar: AppBar(
        backgroundColor: const Color(0xFF041C32),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Word Shark',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 1),
            Text(
              '100 Levels',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.cyanAccent,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.leaderboard_rounded,
              color: Colors.cyanAccent,
            ),
            tooltip: 'Full Leaderboard',
            onPressed: _showClassLeaderboardModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Sync Progress',
            onPressed: _initializeWordSharkHub,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF041C32),
              Color(0xFF082D49),
              Color(0xFF004D40),
            ],
          ),
        ),
        child: _loadingProgress
            ? const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              )
            : SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth > 680
                        ? 640.0
                        : constraints.maxWidth;
                    return Center(
                      child: SizedBox(
                        width: maxW,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          children: [
                            // 1, 2, 3, 6 & 8: Title, Instructions, Current Level, Highest Score & Play/Continue
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF004D40),
                                    Color(0xFF0277BD),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.cyanAccent.withOpacity(0.35),
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
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
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.cyanAccent.withOpacity(
                                            0.16,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.cyanAccent
                                                .withOpacity(0.4),
                                          ),
                                        ),
                                        child: const Text(
                                          '🦈',
                                          style: TextStyle(fontSize: 26),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'WORD SHARK CHALLENGE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 19,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Current Level: $_unlockedLevel / $_maxLevel • Completed: ${_completedLevels.length}/$_maxLevel',
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
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF031C32)
                                          .withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: const Text(
                                      'How to Play: Read the Fisheries Board Exam clue and tap or drag the shuffled letter blocks to spell the correct term before the shark catches the fish (3 lives per word)!',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _sharkStatTile(
                                          icon: Icons.workspace_premium_rounded,
                                          label: 'Highest Score',
                                          value: '$_highestScore pts',
                                          color: Colors.amberAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _sharkStatTile(
                                          icon: Icons.flag_circle_rounded,
                                          label: 'Current Level',
                                          value: 'Level $_unlockedLevel',
                                          color: Colors.cyanAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _sharkStatTile(
                                          icon: Icons.star_rounded,
                                          label: 'Best Single',
                                          value: '$_bestLevelScore pts',
                                          color: Colors.greenAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _startSelectedLevel(_unlockedLevel),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 24,
                                      ),
                                      label: Text(
                                        _completedLevels.isEmpty
                                            ? 'PLAY LEVEL 1'
                                            : 'CONTINUE LEVEL $_unlockedLevel',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF00BCD4),
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Relocated Audio & Haptic Settings Notice
                            const SizedBox(height: 2),

                            // 4 & 5: Candy Crush-Style 100-Level Selection Map
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF082D49).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.cyanAccent.withOpacity(0.28),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.route_rounded,
                                            color: Colors.cyanAccent,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '100-Level Shark Reef Map',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 28,
                                        ),
                                        child: Text(
                                          'Tap any unlocked level',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.65),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 310,
                                    child: _buildCandyCrushSharkMap(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 7: Leaderboard on Opening Screen
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF082D49).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.amberAccent.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.leaderboard_rounded,
                                        color: Colors.amberAccent,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Word Shark Leaderboard',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15.5,
                                          ),
                                        ),
                                      ),
                                      if (joinedClasses.isNotEmpty)
                                        DropdownButtonHideUnderline(
                                          child: DropdownButton< String >(
                                            value: _leaderboardScope,
                                            dropdownColor:
                                                const Color(0xFF082D49),
                                            style: const TextStyle(
                                              color: Colors.cyanAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            items: [
                                              const DropdownMenuItem(
                                                value: 'all',
                                                child: Text('All Players'),
                                              ),
                                              ...joinedClasses.map(
                                                (c) => DropdownMenuItem(
                                                  value: c,
                                                  child: Text('Class $c'),
                                                ),
                                              ),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _leaderboardScope = val;
                                                  _refreshOpeningLeaderboard();
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  FutureBuilder<
                                    List< Map< String, dynamic > >
                                  >(
                                    future: _openingLeaderboardFuture,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.cyanAccent,
                                            ),
                                          ),
                                        );
                                      }
                                      final rows = snapshot.data ?? [];
                                      if (rows.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Text(
                                            'Complete Level 1 to post your first score on the leaderboard!',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12.5,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      }
                                      return Column(
                                        children: rows.take(5).toList().asMap().entries.map((entry) {
                                          final idx = entry.key;
                                          final r = entry.value;
                                          final isMe = r['uid'] ==
                                              AuthService.currentUser?.id;
                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isMe
                                                  ? Colors.cyanAccent
                                                      .withOpacity(0.16)
                                                  : const Color(0xFF031C32)
                                                      .withOpacity(0.65),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isMe
                                                    ? Colors.cyanAccent
                                                    : Colors.white10,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: idx == 0
                                                      ? Colors.amber
                                                      : idx == 1
                                                          ? Colors.blueGrey
                                                              .shade300
                                                          : idx == 2
                                                              ? Colors.brown
                                                                  .shade300
                                                              : const Color(
                                                                  0xFF0277BD,
                                                                ),
                                                  child: Text(
                                                    '#${idx + 1}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '${r['name']}${isMe ? " (You)" : ""}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Level ${r['unlockedLevel']} • ${r['completedCount']} Completed',
                                                        style: const TextStyle(
                                                          color: Colors.white60,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  '${r['highestScore']} pts',
                                                  style: const TextStyle(
                                                    color: Colors.amberAccent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
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
              ),
      ),
    );
  }

  Widget _sharkStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF031C32).withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sharkSettingToggleChip({
    required String label,
    required bool enabled,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF00BCD4).withOpacity(0.22)
              : const Color(0xFF031C32),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled ? Colors.cyanAccent : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? activeIcon : inactiveIcon,
              size: 16,
              color: enabled ? Colors.cyanAccent : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              '$label: ${enabled ? "ON" : "OFF"}',
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandyCrushSharkMap() {
    const alignments = < double >[-0.65, -0.22, 0.22, 0.65, 0.22, -0.22];

    return ListView.builder(
      itemCount: _maxLevel,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemBuilder: (context, index) {
        final lvl = index + 1;
        final isCompleted = _completedLevels.contains(lvl);
        final isUnlocked = lvl <= _unlockedLevel;
        final isCurrent = lvl == _unlockedLevel;
        final stars = _levelStars['$lvl'] ?? (isCompleted ? 3 : 0);
        final bestScore = _levelScores['$lvl'] ?? 0;
        final alignX = alignments[index % alignments.length];

        String? zoneBanner;
        if (lvl == 1) zoneBanner = '🐠 Zone 1: Nursery Lagoon (Levels 1–15)';
        if (lvl == 16) zoneBanner = '🪸 Zone 2: Reef Drop-Off (Levels 16–40)';
        if (lvl == 41) zoneBanner = '🌊 Zone 3: Open Pelagic (Levels 41–70)';
        if (lvl == 71) zoneBanner = '🦈 Zone 4: Great Shark Trench (Levels 71–100)';

        final Color nodeBg = isCurrent
            ? const Color(0xFFFFB300)
            : isCompleted
                ? const Color(0xFF00897B)
                : const Color(0xFF031C32);
        final Color borderColor = isCurrent
            ? Colors.white
            : isCompleted
                ? Colors.tealAccent
                : Colors.white24;

        return Column(
          children: [
            if (zoneBanner != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.cyanAccent.withOpacity(0.35),
                  ),
                ),
                child: Text(
                  zoneBanner,
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Align(
              alignment: Alignment(alignX, 0),
              child: GestureDetector(
                onTap: () => _startSelectedLevel(lvl),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: nodeBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: borderColor,
                      width: isCurrent ? 2.4 : 1.4,
                    ),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: nodeBg.withOpacity(0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        !isUnlocked
                            ? Icons.lock_rounded
                            : isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.play_circle_fill_rounded,
                        size: 18,
                        color: !isUnlocked ? Colors.white38 : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Level $lvl${isCurrent ? " • NEXT" : ""}',
                            style: TextStyle(
                              color: !isUnlocked
                                  ? Colors.white54
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (isCompleted)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...List< Widget >.generate(3, (sIdx) {
                                  return Icon(
                                    sIdx < stars
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 13,
                                    color: Colors.amberAccent,
                                  );
                                }),
                                if (bestScore > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '$bestScore pts',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WordSharkConfettiOverlay extends StatefulWidget {
  const _WordSharkConfettiOverlay();

  @override
  State< _WordSharkConfettiOverlay > createState() =>
      _WordSharkConfettiOverlayState();
}

class _WordSharkConfettiOverlayState extends State< _WordSharkConfettiOverlay >
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _SharkConfettiPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _SharkConfettiPainter extends CustomPainter {
  final double progress;

  const _SharkConfettiPainter({required this.progress});

  static const List< Color > _colors = [
    Colors.amberAccent,
    Colors.cyanAccent,
    Colors.greenAccent,
    Colors.pinkAccent,
    Colors.lightBlueAccent,
    Colors.orangeAccent,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 42; i++) {
      final seed = (i * 37) % 100 / 100.0;
      final x = ((seed + sin(progress * 2 * pi + i) * 0.08) % 1.0) * size.width;
      final y = ((progress + seed) % 1.0) * size.height;
      paint.color = _colors[i % _colors.length];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 2 * pi + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4, -2.5, 8, 5),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SharkConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}