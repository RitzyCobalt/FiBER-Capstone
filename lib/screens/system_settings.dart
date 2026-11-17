import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/sound_service.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State< SystemSettingsScreen > createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State< SystemSettingsScreen > {
  bool _loadingAudioSettings = true;

  @override
  void initState() {
    super.initState();
    _loadSavedGameSettings();
  }

  Future< void > _loadSavedGameSettings() async {
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
    setState(() => _loadingAudioSettings = false);
  }

  Future< void > _saveAudioAndVibrationSettings() async {
    await DataService.saveMiniGameSettings(
      uid: AuthService.currentUser?.id,
      bgmEnabled: SoundService.bgmEnabled,
      sfxEnabled: SoundService.soundEffectsEnabled,
      vibrationEnabled: SoundService.vibrationEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTheme = DataService.themeMode;
    final currentFont = DataService.fontFamilyNotifier.value;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'System Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.tune_rounded,
                    color: Colors.cyanAccent,
                    size: 26,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display & Reading Preferences',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Adjust the global text scaling across all modules, quizzes, and mock exams.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Font Settings ─────────────────────────────────────
          _SectionHeader(icon: Icons.text_fields, title: 'Font Settings'),
          const SizedBox(height: 12),
          _OptionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Font Size',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: DataService.fontSizeNotifier,
                  builder: (_, fontSize, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.text_decrease,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        Expanded(
                          child: Slider(
                            value: fontSize,
                            min: 12,
                            max: 22,
                            divisions: 5,
                            label: fontSize.toStringAsFixed(0),
                            onChanged: (value) {
                              DataService.setFontSize(value);
                            },
                          ),
                        ),
                        Icon(
                          Icons.text_increase,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${fontSize.toStringAsFixed(0)}px',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ValueListenableBuilder< double >(
                    valueListenable: DataService.fontSizeNotifier,
                    builder: (_, fontSize, __) => Text(
                      'Preview: The quick brown fox jumps over the lazy dog',
                      style: TextStyle(
                        fontSize: fontSize,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Game Audio & Haptic Settings (Relocated from Mini Games) ──
          _SectionHeader(
            icon: Icons.sports_esports_rounded,
            title: 'Game Audio & Haptic Settings',
          ),
          const SizedBox(height: 12),
          _OptionCard(
            child: _loadingAudioSettings
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: [
                      SwitchListTile(
                        secondary: CircleAvatar(
                          backgroundColor: const Color(0xFFE1F5FE),
                          child: Icon(
                            SoundService.bgmEnabled
                                ? Icons.music_note_rounded
                                : Icons.music_off_rounded,
                            color: const Color(0xFF0277BD),
                          ),
                        ),
                        title: const Text(
                          'Background Music (BGM)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          SoundService.bgmEnabled
                              ? 'ON • Plays ambient melody during mini games'
                              : 'OFF • Background music is muted',
                          style: const TextStyle(fontSize: 12),
                        ),
                        activeColor: const Color(0xFF00BCD4),
                        value: SoundService.bgmEnabled,
                        onChanged: (val) {
                          setState(() {
                            SoundService.applySavedSettings(bgm: val);
                          });
                          _saveAudioAndVibrationSettings();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: CircleAvatar(
                          backgroundColor: const Color(0xFFE1F5FE),
                          child: Icon(
                            SoundService.soundEffectsEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: const Color(0xFF0277BD),
                          ),
                        ),
                        title: const Text(
                          'Sound Effects (SFX)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          SoundService.soundEffectsEnabled
                              ? 'ON • Plays chimes for taps, correct words & level unlocks'
                              : 'OFF • Game sound effects are muted',
                          style: const TextStyle(fontSize: 12),
                        ),
                        activeColor: const Color(0xFF00BCD4),
                        value: SoundService.soundEffectsEnabled,
                        onChanged: (val) {
                          setState(() {
                            SoundService.applySavedSettings(sfx: val);
                            if (val) SoundService.playTap();
                          });
                          _saveAudioAndVibrationSettings();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: CircleAvatar(
                          backgroundColor: const Color(0xFFE1F5FE),
                          child: Icon(
                            SoundService.vibrationEnabled
                                ? Icons.vibration_rounded
                                : Icons.phone_android_rounded,
                            color: const Color(0xFF0277BD),
                          ),
                        ),
                        title: const Text(
                          'Vibration & Haptic Feedback',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          SoundService.vibrationEnabled
                              ? 'ON • Vibrates on letter selection and game alerts'
                              : 'OFF • Device vibration is disabled',
                          style: const TextStyle(fontSize: 12),
                        ),
                        activeColor: const Color(0xFF00BCD4),
                        value: SoundService.vibrationEnabled,
                        onChanged: (val) {
                          setState(() {
                            SoundService.applySavedSettings(vibration: val);
                            if (val) SoundService.playTap();
                          });
                          _saveAudioAndVibrationSettings();
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final Widget child;
  const _OptionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
