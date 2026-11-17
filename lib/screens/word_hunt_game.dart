import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/performance_service.dart';
import '../services/sound_service.dart';

class WordHuntGame extends StatefulWidget {
  const WordHuntGame({super.key});

  @override
  State< WordHuntGame > createState() => _WordHuntGameState();
}

class WordHuntLevel {
  final int level;
  final int gridSize;
  final int wordCount;
  final int minWordLength;
  final int maxWordLength;
  final int timeLimit;

  const WordHuntLevel({
    required this.level,
    required this.gridSize,
    required this.wordCount,
    required this.minWordLength,
    required this.maxWordLength,
    required this.timeLimit,
  });

  /// Dynamically generates progressive difficulty across all 100 levels.
  factory WordHuntLevel.forLevel(int levelNumber) {
    final lvl = levelNumber.clamp(1, 100);
    if (lvl <= 10) {
      return WordHuntLevel(
        level: lvl,
        gridSize: 6,
        wordCount: 3 + (lvl >= 6 ? 1 : 0),
        minWordLength: 3,
        maxWordLength: 5 + (lvl >= 5 ? 1 : 0),
        timeLimit: 180,
      );
    } else if (lvl <= 25) {
      return WordHuntLevel(
        level: lvl,
        gridSize: 7,
        wordCount: 4 + (lvl >= 18 ? 1 : 0),
        minWordLength: 3,
        maxWordLength: 7,
        timeLimit: 195,
      );
    } else if (lvl <= 50) {
      return WordHuntLevel(
        level: lvl,
        gridSize: 8,
        wordCount: 5 + (lvl >= 38 ? 1 : 0),
        minWordLength: 3,
        maxWordLength: 8,
        timeLimit: 210,
      );
    } else if (lvl <= 75) {
      return WordHuntLevel(
        level: lvl,
        gridSize: 9,
        wordCount: 6 + (lvl >= 62 ? 1 : 0),
        minWordLength: 4,
        maxWordLength: 9,
        timeLimit: 225,
      );
    } else {
      return WordHuntLevel(
        level: lvl,
        gridSize: 10,
        wordCount: 7 + (lvl >= 90 ? 1 : 0),
        minWordLength: 4,
        maxWordLength: 10,
        timeLimit: 240,
      );
    }
  }
}

class _CellPosition {
  final int row;
  final int col;

  const _CellPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is _CellPosition && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

class _GridCell {
  final int row;
  final int col;
  String? letter;

  _GridCell(this.row, this.col, [this.letter]);
}

class _WordHuntGameState extends State<WordHuntGame> {
  static const List<String> _ignoredWords = [
    'THE',
    'AND',
    'FOR',
    'WITH',
    'THIS',
    'THAT',
    'FROM',
    'ARE',
    'WAS',
    'WERE',
    'HAVE',
    'HAS',
    'YOUR',
    'THEIR',
    'THERE',
    'WOULD',
    'SHOULD',
    'ABOUT',
    'WHICH',
    'WHEN',
    'WHERE',
    'THEN',
    'THEM',
    'THOSE',
    'THROUGH',
  ];

  static const int _totalLevels = 100;

  // Comprehensive FBLE Fisheries vocabulary bank (3 to 10 letters) for all 100 levels
  static const List< String > _fisheriesFallbackWords = [
    // 3-letter fisheries & aquatic terms
    'FRY', 'FIN', 'ROE', 'NET', 'COD', 'EEL', 'BAY', 'SEA', 'SAC', 'TOW',
    'ICE', 'GUT', 'ROD', 'SUB', 'LOW', 'EBB', 'riP',
    // 4-letter fisheries terms
    'POND', 'REEF', 'GILL', 'CAGE', 'BAIT', 'TUNA', 'CARP', 'KELP', 'CRAB',
    'CLAM', 'WEIR', 'TIDE', 'WAVE', 'BOAT', 'HULL', 'DECK', 'HOOK', 'LINE',
    'MESH', 'SILT', 'ALGA', 'SALT', 'FISH', 'PREY', 'FEED', 'LURE', 'DOCK',
    // 5-letter fisheries terms
    'SPAWN', 'PRAWN', 'SHARK', 'SQUID', 'CORAL', 'TRAWL', 'SEINE', 'ALGAE',
    'BRINE', 'SMELT', 'BREAM', 'PERCH', 'TROUT', 'LARVA', 'DEPTH', 'OCEAN',
    'SHOAL', 'SONAR', 'CRAFT', 'FLEET', 'CATCH', 'STOCK', 'SCALE', 'MUCUS',
    // 6-letter fisheries terms
    'BANGUS', 'SURIMI', 'OYSTER', 'MUSSEL', 'SHRIMP', 'SALMON', 'GROUPA',
    'BYKILN', 'LONGER', 'DREDGE', 'BENTHIC', 'PELAGIC', 'MARINE', 'LAGOON',
    'ANOXIA', 'BIOTIC', 'TROPHIC', 'GAMETE', 'ZYGOTE', 'FILLET', 'FROZEN',
    // 7-to-10 letter FBLE board exam terms
    'TILAPIA', 'ESTUARY', 'PELAGIC', 'BENTHIC', 'SALINITY', 'PLANKTON',
    'HATCHERY', 'TRAWLING', 'GILLNET', 'BYCATCH', 'BRINING', 'SMOKING',
    'CANNING', 'SPOILAGE', 'HISTAMINE', 'LONGLINE', 'PURSESEINE', 'FISHPOND',
    'PENAEUS', 'MILKFISH', 'CATFISH', 'SNAPPER', 'GROUPER', 'HALIBUT',
    'SARDINE', 'ANCHOVY', 'MACKEREL', 'MOLLUSK', 'BIVALVE', 'COPEPOD',
    'ROTIFER', 'ARTEMIA', 'BIOFLOC', 'AERATOR', 'SECCHI', 'TURBIDITY',
    'UPWELLING', 'MANGROVE', 'SEAGRASS', 'DETRITUS', 'NEKTONIC', 'LITTORAL',
    'LIMNOLOGY', 'FECUNDITY', 'GONADAL', 'FINFISH', 'SHELLFISH', 'BROODSTOCK',
    'FINGERLING', 'AQUACULTURE', 'MARICULTURE',
  ];

  final Random _random = Random();
  final List< _CellPosition > _selectedPositions = [];
  final Set< String > _foundWords = < String >{};
  final Map< String, Set< _CellPosition > > _foundWordCells =
      < String, Set< _CellPosition > >{};

  List< String > _targetWords = [];
  Map< String, List< _CellPosition > > _wordPositions = {};
  List< List< _GridCell > > _grid = [];

  Timer? _gameTimer;
  int _currentLevel = 1;
  int _unlockedLevel = 1;
  Set< int > _completedLevels = < int >{};
  Map< String, int > _levelScores = < String, int >{};
  Map< String, int > _levelStars = < String, int >{};
  int _highestScore = 0;
  int _bestLevelScore = 0;

  bool _inGameplay = false;
  bool _loadingProgress = true;
  String _leaderboardScope = 'all'; // 'all' or classCode
  Future< List< Map< String, dynamic > > >? _openingLeaderboardFuture;

  bool _isPaused = false;
  int _score = 0;
  int _secondsElapsed = 0;
  int _syncedStudySeconds = 0;
  bool _invalidModule = false;
  String _currentWord = '';
  bool _sessionLogged = false;
  bool _scorePulse = false;

  @override
  void initState() {
    super.initState();
    DataService.moduleUpdateNotifier.addListener(_onModuleUpdated);
    DataService.startStudyTimer(uid: AuthService.currentUser?.id);
    _initializeWordHuntHub();
  }

  Future< void > _initializeWordHuntHub() async {
    final uid = AuthService.currentUser?.id;
    final progress = await DataService.loadMiniGameProgress(
      gameType: 'word_hunt',
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
        _totalLevels,
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
      gameType: 'word_hunt',
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

  @override
  void dispose() {
    _gameTimer?.cancel();
    SoundService.stopBgm();
    _syncRemainingStudyTime();
    DataService.moduleUpdateNotifier.removeListener(_onModuleUpdated);
    super.dispose();
  }

  void _syncRemainingStudyTime() {
    final unsynced = _secondsElapsed - _syncedStudySeconds;
    if (unsynced > 0) {
      DataService.addStudyTime(unsynced);
      _syncedStudySeconds = _secondsElapsed;
      DataService.stopStudyTimer(uid: AuthService.currentUser?.id);
      DataService.startStudyTimer(uid: AuthService.currentUser?.id);
    }
  }

  void _onModuleUpdated() {
    if (mounted) setState(() {});
  }

  WordHuntLevel get _currentLevelConfig {
    return WordHuntLevel.forLevel(_currentLevel);
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _invalidModule || _isPaused) return;

      final timeLimit = _currentLevelConfig.timeLimit;
      if (_secondsElapsed >= timeLimit) {
        _gameTimer?.cancel();
        SoundService.playWrongWord();
        _syncRemainingStudyTime();
        if (mounted) {
          setState(() {
            _selectedPositions.clear();
            _currentWord = '';
          });
          _showGameEndDialog(completed: false);
        }
        return;
      }

      setState(() {
        _secondsElapsed++;
        _syncedStudySeconds = _secondsElapsed;
      });
    });
  }

  void _startSelectedLevel(int levelNumber) {
    if (levelNumber > _unlockedLevel) {
      SoundService.playWrongWord();
      _showFeedback(
        '🔒 Level $levelNumber is locked! Complete Level $_unlockedLevel first.',
        Colors.amber.shade900,
      );
      return;
    }
    SoundService.playTap();
    SoundService.startBgmIfNeeded();
    setState(() {
      _inGameplay = true;
    });
    _loadLevel(levelNumber, restartTimer: true);
  }

  void _loadLevel(int levelNumber, {bool restartTimer = false}) {
    final safeLevel = levelNumber.clamp(1, _totalLevels);
    _currentLevel = safeLevel;
    _secondsElapsed = 0;
    _syncedStudySeconds = 0;
    _score = 0;
    _selectedPositions.clear();
    _currentWord = '';
    _foundWords.clear();
    _foundWordCells.clear();
    _wordPositions.clear();
    _sessionLogged = false;

    final level = WordHuntLevel.forLevel(safeLevel);
    final words = _extractWordsForLevel(level);
    if (words.isEmpty) {
      _invalidModule = true;
      _targetWords = [];
      _grid = _buildEmptyGrid(level.gridSize);
      if (restartTimer) _startTimer();
      if (mounted) setState(() {});
      return;
    }

    // Ensure the grid size can always accommodate the longest word assigned to this level
    final longestWordLen = words.map((w) => w.length).reduce(max);
    final effectiveGridSize = max(level.gridSize, longestWordLen);

    final generated = _generateGridForWords(words, effectiveGridSize);
    if (generated == null) {
      _invalidModule = true;
      _targetWords = [];
      _grid = _buildEmptyGrid(effectiveGridSize);
      if (restartTimer) _startTimer();
      if (mounted) setState(() {});
      return;
    }

    _invalidModule = false;
    _targetWords = words;
    _grid = generated;

    if (restartTimer || _gameTimer == null || !_gameTimer!.isActive) {
      _startTimer();
    }

    if (mounted) setState(() {});
  }

  List< String > _extractWordsForLevel(WordHuntLevel level) {
    final validWords = < String >{};
    final modules = DataService.getStudentEnrolledModules().isNotEmpty
        ? DataService.getStudentEnrolledModules()
        : DataService.modules;

    for (final module in modules) {
      final content = module.content.toUpperCase();
      final tokens = content
          .split(RegExp(r'[^A-Z]+'))
          .map((value) => value.trim())
          .where((value) => value.length >= 3)
          .where((value) => value.length >= level.minWordLength)
          .where((value) => value.length <= level.maxWordLength)
          .where((value) => value.length <= level.gridSize)
          .where((value) => RegExp(r'^[A-Z]+$').hasMatch(value))
          .where((value) => !_ignoredWords.contains(value))
          .toList();

      for (final token in tokens) {
        validWords.add(token);
      }
    }

    for (final raw in _fisheriesFallbackWords) {
      final fallback = raw.trim().toUpperCase();
      if (fallback.length >= 3 &&
          fallback.length >= level.minWordLength &&
          fallback.length <= level.maxWordLength &&
          fallback.length <= level.gridSize) {
        validWords.add(fallback);
      }
    }

    final words = validWords.toList()..shuffle(Random());
    final selected = words.take(level.wordCount).toList();
    selected.sort((a, b) => a.length.compareTo(b.length));
    return selected;
  }

  List<List<_GridCell>> _buildEmptyGrid(int size) {
    return List.generate(
      size,
      (row) => List.generate(size, (col) => _GridCell(row, col, null)),
    );
  }

  /// Improved word-shuffling & grid placement algorithm:
  /// 1. Places every character of each target word deterministically without missing or duplicating letters.
  /// 2. Records the exact cell coordinates of every placed target word.
  /// 3. Fills remaining cells using a balanced letter pool derived from the target words' letters so decoys match the target distribution without accidentally duplicating full target words.
  List<List<_GridCell>>? _generateGridForWords(
    List<String> words,
    int gridSize,
  ) {
    // Sort longest words first so they always fit cleanly
    final orderedWords = [...words]
      ..sort((a, b) => b.length.compareTo(a.length));

    final targetLetterPool = orderedWords.join().split('');
    if (targetLetterPool.isEmpty) return null;

    for (int attempt = 0; attempt < 400; attempt++) {
      final grid = _buildEmptyGrid(gridSize);
      final exactPlacements = <String, List<_CellPosition>>{};
      bool placedAll = true;

      for (final rawWord in orderedWords) {
        final word = rawWord.trim().toUpperCase();
        final placement = _findPlacementForWord(grid, word);
        if (placement == null || placement.length != word.length) {
          placedAll = false;
          break;
        }

        for (int index = 0; index < word.length; index++) {
          final point = placement[index];
          grid[point.row][point.col].letter = word[index];
        }
        exactPlacements[word] = placement;
      }

      if (!placedAll) continue;

      // Fill empty cells with shuffled letters drawn from the target words' own character set
      for (int row = 0; row < gridSize; row++) {
        for (int col = 0; col < gridSize; col++) {
          if (grid[row][col].letter == null) {
            grid[row][col].letter =
                targetLetterPool[_random.nextInt(targetLetterPool.length)];
          }
        }
      }

      // Verify every target word matches its exact placed letters character-for-character
      bool verified = true;
      for (final word in orderedWords) {
        final coords = exactPlacements[word];
        if (coords == null || coords.length != word.length) {
          verified = false;
          break;
        }
        final reconstructed = coords
            .map((c) => grid[c.row][c.col].letter ?? '')
            .join();
        if (reconstructed != word) {
          verified = false;
          break;
        }
      }

      if (verified) {
        _wordPositions = exactPlacements;
        return grid;
      }
    }

    return null;
  }

  List< _CellPosition >? _findPlacementForWord(
    List< List< _GridCell > > grid,
    String word,
  ) {
    // All 8 Directions (Horizontal, Vertical, and all 4 Diagonal directions):
    final directions = < _CellPosition >[
      const _CellPosition(0, 1),   // Horizontal: Left to Right
      const _CellPosition(0, -1),  // Horizontal: Right to Left
      const _CellPosition(1, 0),   // Vertical: Top to Bottom
      const _CellPosition(-1, 0),  // Vertical: Bottom to Top
      const _CellPosition(1, 1),   // Diagonal: Top-Left to Bottom-Right
      const _CellPosition(-1, -1), // Diagonal: Bottom-Right to Top-Left
      const _CellPosition(1, -1),  // Diagonal: Top-Right to Bottom-Left
      const _CellPosition(-1, 1),  // Diagonal: Bottom-Left to Top-Right
    ]..shuffle(_random);

    final size = grid.length;
    final candidateStarts = <_CellPosition>[];
    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        candidateStarts.add(_CellPosition(row, col));
      }
    }
    candidateStarts.shuffle(_random);

    for (final direction in directions) {
      for (final start in candidateStarts) {
        final endRow = start.row + direction.row * (word.length - 1);
        final endCol = start.col + direction.col * (word.length - 1);
        if (endRow < 0 || endRow >= size || endCol < 0 || endCol >= size) {
          continue;
        }

        final positions = <_CellPosition>[];
        var valid = true;
        for (int index = 0; index < word.length; index++) {
          final row = start.row + direction.row * index;
          final col = start.col + direction.col * index;
          final cell = grid[row][col];
          final character = word[index];

          // Valid if cell is empty OR contains the exact same overlapping letter
          if (cell.letter != null && cell.letter != character) {
            valid = false;
            break;
          }

          positions.add(_CellPosition(row, col));
        }

        if (valid) {
          return positions;
        }
      }
    }

    return null;
  }

  int _scoreForWord(String word) => word.length * 10;

  bool _isPositionInsideGrid(_CellPosition position) {
    return position.row >= 0 &&
        position.row < _grid.length &&
        position.col >= 0 &&
        position.col < _grid.length;
  }

  bool _canExtendSelection(_CellPosition candidate) {
    if (_selectedPositions.isEmpty) return true;

    final last = _selectedPositions.last;
    if (last == candidate) return false;
    if (_selectedPositions.contains(candidate)) return false;

    final deltaRow = candidate.row - last.row;
    final deltaCol = candidate.col - last.col;

    if (deltaRow.abs() > 1 || deltaCol.abs() > 1) {
      return false;
    }

    if (_selectedPositions.length == 1) {
      final first = _selectedPositions.first;
      final rowDelta = candidate.row - first.row;
      final colDelta = candidate.col - first.col;
      return rowDelta == 0 ||
          colDelta == 0 ||
          rowDelta.abs() == colDelta.abs();
    }

    final previous = _selectedPositions[_selectedPositions.length - 2];
    final previousDeltaRow = last.row - previous.row;
    final previousDeltaCol = last.col - previous.col;
    final candidateDeltaRow = candidate.row - last.row;
    final candidateDeltaCol = candidate.col - last.col;

    final previousDirection = _directionVector(
      previousDeltaRow,
      previousDeltaCol,
    );
    final candidateDirection = _directionVector(
      candidateDeltaRow,
      candidateDeltaCol,
    );

    return previousDirection == candidateDirection;
  }

  _CellPosition _directionVector(int deltaRow, int deltaCol) {
    final row = deltaRow == 0 ? 0 : (deltaRow > 0 ? 1 : -1);
    final col = deltaCol == 0 ? 0 : (deltaCol > 0 ? 1 : -1);
    return _CellPosition(row, col);
  }

  void _handleSelectionEnd() {
    if (_selectedPositions.isEmpty) return;

    final selectedWord = _currentWord.trim().toUpperCase();
    final reversedWord = selectedWord.split('').reversed.join();
    final candidates = <String>{selectedWord, reversedWord};

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;

      if (_foundWords.contains(candidate)) {
        SoundService.playWrongWord();
        setState(_clearSelection);
        _showFeedback('Already found "$candidate"', Colors.orange);
        return;
      }

      if (_targetWords.contains(candidate)) {
        SoundService.playCorrectWord();
        final wordPoints = _scoreForWord(candidate);
        final positions = _selectedPositions
            .map((p) => _CellPosition(p.row, p.col))
            .toList();

        setState(() {
          _foundWords.add(candidate);
          _foundWordCells[candidate] = positions.toSet();
          _score += wordPoints;
          _scorePulse = true;
          _selectedPositions.clear();
          _currentWord = '';
        });

        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) setState(() => _scorePulse = false);
        });

        if (!_sessionLogged) {
          DataService.addGamePlayed();
          _sessionLogged = true;
        }

        if (_foundWords.length == _targetWords.length) {
          _gameTimer?.cancel();
          SoundService.playGameComplete();
          _syncRemainingStudyTime();
          _handleLevelCompleted();
        } else {
          _showFeedback('✓ Found $candidate (+$wordPoints pts)', Colors.green);
        }
        return;
      }
    }

    if (selectedWord.length >= 2) {
      SoundService.playWrongWord();
    }
    setState(_clearSelection);
  }

  int _calculateEarnedStars() {
    final limit = _currentLevelConfig.timeLimit;
    final remainingRatio = (limit - _secondsElapsed) / max(1, limit);
    if (remainingRatio >= 0.45) return 3;
    if (remainingRatio >= 0.20) return 2;
    return 1;
  }

  Future< void > _handleLevelCompleted() async {
    final stars = _calculateEarnedStars();
    final timeBonus =
        ((_currentLevelConfig.timeLimit - _secondsElapsed).clamp(0, 300)) ~/ 3;
    final finalLevelScore = _score + timeBonus;
    _score = finalLevelScore;

    final updated = await DataService.saveMiniGameLevelCompletion(
      gameType: 'word_hunt',
      level: _currentLevel,
      score: finalLevelScore,
      stars: stars,
      uid: AuthService.currentUser?.id,
    );

    if (updated['unlockedNewLevel'] == true) {
      SoundService.playLevelUnlock();
    }

    unawaited(
      PerformanceService.recordAssessmentResult(
        type: 'word_hunt',
        score: _foundWords.length,
        total: _targetWords.length,
        subject: 'Word Hunt',
        moduleTitle: 'Word Hunt Level $_currentLevel ($finalLevelScore pts)',
        durationSeconds: _secondsElapsed,
      ),
    );

    if (!mounted) return;
    setState(() {
      _unlockedLevel = (updated['unlockedLevel'] as int?) ?? _unlockedLevel;
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
      _bestLevelScore = (updated['bestLevelScore'] as int?) ?? _bestLevelScore;
      _refreshOpeningLeaderboard();
    });

    _showGameEndDialog(completed: true, earnedStars: stars);
  }

  void _showFeedback(String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  // ── Animated Celebration & Confetti Dialog (Section 1.8) ─────────
  void _showGameEndDialog({required bool completed, int earnedStars = 3}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Game End',
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, anim, _, __) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim.value),
          child: Opacity(
            opacity: anim.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (completed)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: _WordHuntConfettiOverlay(),
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
                          color: completed
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
                            completed
                                ? Icons.emoji_events_rounded
                                : Icons.timer_off_outlined,
                            size: 60,
                            color: completed
                                ? Colors.amberAccent
                                : Colors.redAccent,
                          ),
                          const SizedBox(height: 8),
                          if (completed)
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
                            completed
                                ? 'Congratulations! Level $_currentLevel Complete!'
                                : 'Time Is Up on Level $_currentLevel!',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            completed
                                ? (_currentLevel < _totalLevels
                                    ? 'Level ${_currentLevel + 1} is now unlocked!'
                                    : 'You conquered all 100 levels of Word Hunt!')
                                : 'Don\'t give up — replay with a fresh randomized grid!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.cyanAccent,
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
                                  'Words Found: ${_foundWords.length}/${_targetWords.length} • Total Best: $_highestScore pts',
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
                                icon: const Icon(Icons.map_rounded, size: 17),
                                label: const Text('Level Map'),
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  setState(() {
                                    _inGameplay = false;
                                    _refreshOpeningLeaderboard();
                                  });
                                },
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
                                icon: const Icon(Icons.replay_rounded, size: 17),
                                label: const Text('Replay'),
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  _loadLevel(_currentLevel, restartTimer: true);
                                },
                              ),
                              if (completed && _currentLevel < _totalLevels)
                                ElevatedButton.icon(
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
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00BCD4),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    _loadLevel(
                                      _currentLevel + 1,
                                      restartTimer: true,
                                    );
                                  },
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

  String get _formattedTimeRemaining {
    final remaining = (_currentLevelConfig.timeLimit - _secondsElapsed).clamp(
      0,
      _currentLevelConfig.timeLimit,
    );
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  _CellPosition? _cellFromLocalPosition(
    Offset localPosition,
    double boardSize,
  ) {
    if (_grid.isEmpty || boardSize <= 0) return null;
    final clampedX = localPosition.dx.clamp(0.0, boardSize - 0.001);
    final clampedY = localPosition.dy.clamp(0.0, boardSize - 0.001);
    final step = boardSize / _grid.length;
    final row = (clampedY / step).floor().clamp(0, _grid.length - 1);
    final col = (clampedX / step).floor().clamp(0, _grid.length - 1);

    return _CellPosition(row, col);
  }

  void _clearSelection() {
    _selectedPositions.clear();
    _currentWord = '';
  }

  void _beginSelection(_CellPosition cell) {
    if (!_isPositionInsideGrid(cell)) return;
    final cellLetter = _grid[cell.row][cell.col].letter;
    if (cellLetter == null || cellLetter.trim().isEmpty) return;

    SoundService.playTap();
    _selectedPositions
      ..clear()
      ..add(cell);
    _currentWord = cellLetter.toUpperCase();
    setState(() {});
  }

  /// Smoothly builds a horizontal, vertical, or diagonal selection line
  /// (supporting all 8 directions) from the starting anchor cell to the user's current drag position.
  void _updateSelection(_CellPosition cell) {
    if (!_isPositionInsideGrid(cell)) return;
    if (_selectedPositions.isEmpty) {
      _beginSelection(cell);
      return;
    }

    final anchor = _selectedPositions.first;
    if (cell == anchor) {
      if (_selectedPositions.length > 1) {
        SoundService.playTap();
        setState(() {
          _selectedPositions
            ..clear()
            ..add(anchor);
          _currentWord = (_grid[anchor.row][anchor.col].letter ?? '')
              .toUpperCase();
        });
      }
      return;
    }

    final deltaRow = cell.row - anchor.row;
    final deltaCol = cell.col - anchor.col;
    final absRow = deltaRow.abs();
    final absCol = deltaCol.abs();

    int stepRow;
    int stepCol;
    int steps;

    if (absRow == 0) {
      // Purely horizontal
      stepRow = 0;
      stepCol = deltaCol.sign;
      steps = absCol;
    } else if (absCol == 0) {
      // Purely vertical
      stepRow = deltaRow.sign;
      stepCol = 0;
      steps = absRow;
    } else if ((absRow - absCol).abs() <= 1 &&
        absRow >= 1 &&
        absCol >= 1 &&
        !(absRow == 1 && absCol >= 2) &&
        !(absCol == 1 && absRow >= 2)) {
      // Diagonal in any of the 4 diagonal directions
      if (absRow != absCol) {
        // Only snap to diagonal if already moving diagonally; otherwise wait until cell is on exact diagonal
        if (_selectedPositions.length >= 2) {
          final second = _selectedPositions[1];
          final prevDr = second.row - anchor.row;
          final prevDc = second.col - anchor.col;
          if (prevDr == 0 && absRow <= 1) {
            stepRow = 0;
            stepCol = deltaCol.sign;
            steps = absCol;
          } else if (prevDc == 0 && absCol <= 1) {
            stepRow = deltaRow.sign;
            stepCol = 0;
            steps = absRow;
          } else {
            return;
          }
        } else {
          return;
        }
      } else {
        stepRow = deltaRow.sign;
        stepCol = deltaCol.sign;
        steps = absRow;
      }
    } else if (absCol > absRow && absRow <= 1) {
      // Horizontal with slight 1-cell finger drift
      stepRow = 0;
      stepCol = deltaCol.sign;
      steps = absCol;
    } else if (absRow > absCol && absCol <= 1) {
      // Vertical with slight 1-cell finger drift
      stepRow = deltaRow.sign;
      stepCol = 0;
      steps = absRow;
    } else {
      return;
    }

    final newLine = < _CellPosition >[anchor];
    for (int i = 1; i <= steps; i++) {
      final pos = _CellPosition(
        anchor.row + (stepRow * i),
        anchor.col + (stepCol * i),
      );
      if (_isPositionInsideGrid(pos)) {
        newLine.add(pos);
      } else {
        return;
      }
    }

    bool changed = newLine.length != _selectedPositions.length;
    if (!changed) {
      for (int i = 0; i < newLine.length; i++) {
        if (newLine[i] != _selectedPositions[i]) {
          changed = true;
          break;
        }
      }
    }
    if (!changed) return;

    SoundService.playTap();
    setState(() {
      _selectedPositions
        ..clear()
        ..addAll(newLine);
      _currentWord = _selectedPositions
          .map((position) => _grid[position.row][position.col].letter ?? '')
          .join()
          .toUpperCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_inGameplay) {
      return _buildOpeningScreen(context);
    }

    final theme = Theme.of(context);
    final remaining = (_currentLevelConfig.timeLimit - _secondsElapsed).clamp(
      0,
      _currentLevelConfig.timeLimit,
    );
    final lowTime = remaining <= 30;

    return Scaffold(
      backgroundColor: const Color(0xFF041C32),
      appBar: AppBar(
        backgroundColor: const Color(0xFF041C32),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Back to Level Map',
          onPressed: () {
            _gameTimer?.cancel();
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
                'LEVEL $_currentLevel / $_totalLevels',
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
                'Word Hunt',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPaused
                  ? Icons.play_circle_fill_rounded
                  : Icons.pause_circle_filled_rounded,
              color: Colors.white,
            ),
            tooltip: 'Pause Game',
            onPressed: _togglePauseGame,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'New Randomized Grid',
            onPressed: () => _loadLevel(_currentLevel, restartTimer: true),
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
              Color(0xFF0B3C5D),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gridSize = _grid.isEmpty ? 6 : _grid.length;
              final screenH = constraints.maxHeight;
              final isCompactPhone = screenH < 640;
              final wordDashboardMaxHeight =
                  (screenH * (isCompactPhone ? 0.16 : 0.19)).clamp(72.0, 128.0);

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth > 600 ? 24 : 12,
                  vertical: isCompactPhone ? 4 : 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Top Status Row (Level, Score, Timer, Found) ──
                    Row(
                      children: [
                        Expanded(
                          child: _animatedMetricCard(
                            label: 'Level',
                            value: '$_currentLevel/$_totalLevels',
                            color: Colors.amberAccent,
                            context: context,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AnimatedScale(
                            scale: _scorePulse ? 1.12 : 1.0,
                            duration: const Duration(milliseconds: 220),
                            child: _animatedMetricCard(
                              label: 'Score',
                              value: '$_score',
                              color: Colors.cyanAccent,
                              context: context,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _animatedMetricCard(
                            label: 'Time Left',
                            value: _formattedTimeRemaining,
                            color: lowTime
                                ? Colors.redAccent
                                : Colors.greenAccent,
                            context: context,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _animatedMetricCard(
                            label: 'Found',
                            value:
                                '${_foundWords.length}/${_targetWords.length}',
                            color: Colors.lightBlueAccent,
                            context: context,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompactPhone ? 6 : 8),

                    // ── Target Words List Container ──
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: wordDashboardMaxHeight,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isCompactPhone ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF031C32).withOpacity(0.82),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.checklist_rtl_rounded,
                                    size: 15,
                                    color: Colors.cyanAccent,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'TARGET WORDS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.cyanAccent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${_foundWords.length} of ${_targetWords.length} found',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.center,
                                children: _targetWords.map((word) {
                                  final found = _foundWords.contains(word);
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: found
                                          ? Colors.greenAccent.withOpacity(0.2)
                                          : Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: found
                                            ? Colors.greenAccent
                                            : Colors.cyanAccent.withOpacity(
                                                0.35,
                                              ),
                                      ),
                                    ),
                                    child: Text(
                                      found ? '✓ $word' : word,
                                      style: TextStyle(
                                        fontSize: isCompactPhone ? 11.5 : 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: found
                                            ? Colors.greenAccent
                                            : Colors.white,
                                        decoration: found
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isCompactPhone ? 4 : 6),

                    // ── Combined Word Hunt Instruction Container (Positioned Directly Below Target Words) ──
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isCompactPhone ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF031C32).withOpacity(0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _currentWord.isNotEmpty
                              ? Colors.cyanAccent
                              : Colors.white24,
                        ),
                      ),
                      child: _currentWord.isNotEmpty
                          ? Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00BCD4),
                                      Color(0xFF0288D1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _currentWord,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.swipe_rounded,
                                      size: 15,
                                      color: Colors.cyanAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Find the Hidden Words!',
                                      style: TextStyle(
                                        fontSize: isCompactPhone ? 11.5 : 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.cyanAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Drag across letters horizontally, vertically, or diagonally to find the target words.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isCompactPhone ? 10.5 : 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    SizedBox(height: isCompactPhone ? 4 : 6),

                    // ── Dynamic Responsive Square Letter Grid (Scales to ANY Phone) ──
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, gridConstraints) {
                          final availableSide = min(
                            gridConstraints.maxWidth,
                            gridConstraints.maxHeight,
                          );
                          final boardSize =
                              (availableSide - 16.0).clamp(140.0, 560.0);
                          final cellFontSize =
                              (boardSize / gridSize * 0.44).clamp(11.0, 22.0);

                          return Center(
                            child: Container(
                              width: boardSize + 14,
                              height: boardSize + 14,
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.cyanAccent.withOpacity(0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.28),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanDown: (details) {
                                  final cell = _cellFromLocalPosition(
                                    details.localPosition,
                                    boardSize,
                                  );
                                  if (cell != null) _beginSelection(cell);
                                },
                                onPanStart: (details) {
                                  final cell = _cellFromLocalPosition(
                                    details.localPosition,
                                    boardSize,
                                  );
                                  if (cell != null) _beginSelection(cell);
                                },
                                onPanUpdate: (details) {
                                  final cell = _cellFromLocalPosition(
                                    details.localPosition,
                                    boardSize,
                                  );
                                  if (cell != null) _updateSelection(cell);
                                },
                                onPanEnd: (_) => _handleSelectionEnd(),
                                onPanCancel: () => _handleSelectionEnd(),
                                child: SizedBox(
                                  width: boardSize,
                                  height: boardSize,
                                  child: GridView.builder(
                                    padding: EdgeInsets.zero,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: gridSize,
                                      crossAxisSpacing: gridSize >= 9 ? 2 : 3,
                                      mainAxisSpacing: gridSize >= 9 ? 2 : 3,
                                      childAspectRatio: 1,
                                    ),
                                    itemCount: gridSize * gridSize,
                                    itemBuilder: (context, index) {
                                      final row = index ~/ gridSize;
                                      final col = index % gridSize;
                                      final cell = _grid[row][col];
                                      final key = _CellPosition(row, col);
                                      final isSelected =
                                          _selectedPositions.contains(key);
                                      final foundCount = _foundWordCells.values
                                          .where((pos) => pos.contains(key))
                                          .length;

                                      final cellColor = isSelected
                                          ? const Color(0xFF00BCD4)
                                          : foundCount > 0
                                              ? Colors.green.shade600
                                              : const Color(0xFFF0F8FF);

                                      final textColor =
                                          (isSelected || foundCount > 0)
                                              ? Colors.white
                                              : const Color(0xFF0B3C5D);

                                      return AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 110),
                                        decoration: BoxDecoration(
                                          color: cellColor,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF0B3C5D)
                                                : foundCount > 0
                                                    ? Colors.green.shade800
                                                    : Colors.lightBlue.shade100,
                                            width: isSelected || foundCount > 0
                                                ? 1.5
                                                : 1,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding: const EdgeInsets.all(2),
                                            child: Text(
                                              cell.letter ?? '',
                                              style: TextStyle(
                                                fontSize: cellFontSize,
                                                fontWeight: FontWeight.bold,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
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
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  MINI GAME OPENING SCREEN (Section 4: Title, Instructions,
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
              'Word Hunt',
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
            onPressed: _showWordHuntLeaderboard,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Sync Progress',
            onPressed: _initializeWordHuntHub,
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
              Color(0xFF0B3C5D),
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
                                    Color(0xFF082D49),
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
                                        child: const Icon(
                                          Icons.grid_on_rounded,
                                          color: Colors.cyanAccent,
                                          size: 30,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'WORD HUNT ADVENTURE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 19,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Current Level: $_unlockedLevel / $_totalLevels • Completed: ${_completedLevels.length}/$_totalLevels',
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
                                      'Find the Hidden Words! Drag across letters horizontally, vertically, or diagonally to find the target words (3+ letters). Complete each level to unlock the next!',
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
                                        child: _openingStatTile(
                                          icon: Icons.workspace_premium_rounded,
                                          label: 'Highest Score',
                                          value: '$_highestScore pts',
                                          color: Colors.amberAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _openingStatTile(
                                          icon: Icons.flag_circle_rounded,
                                          label: 'Current Level',
                                          value: 'Level $_unlockedLevel',
                                          color: Colors.cyanAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _openingStatTile(
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

                            // 4 & 5: Candy Crush-Style 100-Level Selection Map (Locked, Unlocked & Completed)
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
                                              '100-Level Ocean Saga Map',
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
                                    child: _buildCandyCrushLevelMap(),
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
                                          'Word Hunt Leaderboard',
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

  Widget _openingStatTile({
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

  Widget _settingToggleChip({
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

  /// Builds a Candy Crush-style winding ocean path for Levels 1 to 100.
  Widget _buildCandyCrushLevelMap() {
    const alignments = < double >[-0.65, -0.22, 0.22, 0.65, 0.22, -0.22];

    return ListView.builder(
      itemCount: _totalLevels,
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
        if (lvl == 1) zoneBanner = '🌊 Zone 1: Coastal Shallows (Levels 1–25)';
        if (lvl == 26) zoneBanner = '🪸 Zone 2: Coral Reefs (Levels 26–50)';
        if (lvl == 51) zoneBanner = '🐟 Zone 3: Pelagic Currents (Levels 51–75)';
        if (lvl == 76) zoneBanner = '🦈 Zone 4: Abyssal Trench (Levels 76–100)';

        final Color nodeBg = isCurrent
            ? const Color(0xFFFFB300)
            : isCompleted
                ? const Color(0xFF00BCD4)
                : const Color(0xFF031C32);
        final Color borderColor = isCurrent
            ? Colors.white
            : isCompleted
                ? Colors.cyanAccent
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

  void _togglePauseGame() {
    setState(() => _isPaused = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF082D49),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: Colors.cyanAccent.withOpacity(0.4)),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.pause_circle_filled_rounded,
                color: Colors.cyanAccent,
              ),
              SizedBox(width: 8),
              Text(
                'Game Paused',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Level $_currentLevel / $_totalLevels • Time Remaining: $_formattedTimeRemaining\nFound ${_foundWords.length} of ${_targetWords.length} words.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _gameTimer?.cancel();
                setState(() {
                  _isPaused = false;
                  _inGameplay = false;
                  _refreshOpeningLeaderboard();
                });
              },
              child: const Text(
                'Level Map',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _isPaused = false);
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWordHuntLeaderboard() {
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
              height: 420,
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
                        child: Text(
                          'Word Hunt Class Leaderboard',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B3C5D),
                          ),
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
                          'Join a class first to view your class Word Hunt rankings!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else ...[
                    if (joinedCodes.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DropdownButtonFormField< String >(
                          initialValue: selectedClass,
                          decoration: const InputDecoration(
                            labelText: 'Select Class',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: joinedCodes
                              .map(
                                (c) => DropdownMenuItem< String >(
                                  value: c,
                                  child: Text('Class $c'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setSheetState(() => selectedClass = v);
                            }
                          },
                        ),
                      ),
                    Expanded(
                      child: FutureBuilder< List< Map< String, dynamic > > >(
                        future: DataService.loadClassGameLeaderboard(
                          classCode: selectedClass,
                          gameType: 'word_hunt',
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final list = snapshot.data ?? [];
                          if (list.isEmpty) {
                            return const Center(
                              child: Text('No classmates found in this class.'),
                            );
                          }
                          return ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, idx) {
                              final row = list[idx];
                              final isMe =
                                  row['uid'] == AuthService.currentUser?.id;
                              return Card(
                                color: isMe
                                    ? const Color(0xFFE1F5FE)
                                    : Colors.white,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: idx == 0
                                        ? Colors.amber
                                        : const Color(0xFF0277BD),
                                    child: Text(
                                      '#${idx + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    '${row['name']}${isMe ? " (You)" : ""}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Attempts: ${row['attempts']} • Accuracy: ${(row['bestAccuracy'] as double).toStringAsFixed(0)}%',
                                  ),
                                  trailing: Text(
                                    '${row['bestScore']} Words',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
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

  Widget _animatedMetricCard({
    required String label,
    required String value,
    required Color color,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF031C32).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: FittedBox(
              key: ValueKey('$label-$value'),
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordHuntConfettiOverlay extends StatefulWidget {
  const _WordHuntConfettiOverlay();

  @override
  State< _WordHuntConfettiOverlay > createState() =>
      _WordHuntConfettiOverlayState();
}

class _WordHuntConfettiOverlayState extends State< _WordHuntConfettiOverlay >
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
          painter: _ConfettiPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;

  const _ConfettiPainter({required this.progress});

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
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}