import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/alumni_model.dart';
import '../services/data_service.dart';
import '../widgets/alumni_avatar.dart';

const _brandBlue = Color(0xFF00BCD4);
const _deepBlue = Color(0xFF0B3C5D);
const _oceanDark = Color(0xFF041C32);
const _oceanMid = Color(0xFF064663);

class FrontPage extends StatefulWidget {
  const FrontPage({super.key});

  @override
  State<FrontPage> createState() => _FrontPageState();
}

class _FrontPageState extends State< FrontPage > {
  late Future< List< AlumniProfile > > _alumniFuture;
  final PageController _alumniPageController = PageController(
    viewportFraction: 0.90,
  );
  int _currentAlumniPage = 0;
  int _activeSectionTab = 0; // 0 = BFAS Alumni Spotlight, 1 = System Features

  @override
  void initState() {
    super.initState();
    DataService.moduleUpdateNotifier.addListener(_onAlumniUpdated);
    _alumniFuture = DataService.loadAlumniProfiles();
  }

  @override
  void dispose() {
    _alumniPageController.dispose();
    DataService.moduleUpdateNotifier.removeListener(_onAlumniUpdated);
    super.dispose();
  }

  void _onAlumniUpdated() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF03192E),
              Color(0xFF0B3C5D),
              Color(0xFF042940),
              Color(0xFF0277BD),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'lib/assets/images/Minimalist Blue Fish Pattern.png',
                  fit: BoxFit.cover,
                  color: Colors.cyanAccent,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
            // Ambient glowing gradient orbs
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00BCD4).withOpacity(0.18),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -70,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.lightBlueAccent.withOpacity(0.14),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildHero(),
                      const SizedBox(height: 20),
                      _buildSectionSwitcher(),
                      const SizedBox(height: 16),
                      if (_activeSectionTab == 0)
                        _buildAlumniSection()
                      else
                        _buildFeatureHighlightsGrid(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B3C5D).withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'lib/assets/Logo/fiber_logo.png',
              height: 28,
              width: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.set_meal_rounded,
                color: Colors.cyanAccent,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'FiBER',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'CvSU-Naic',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Fisheries Board Exam Reviewer',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            icon: const Icon(Icons.login_rounded, size: 15),
            label: const Text(
              'Sign In',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF0B3C5D).withOpacity(0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.playfairDisplay(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.25,
              ),
              children: const [
                TextSpan(text: 'Ace Your '),
                TextSpan(
                  text: 'Fisheries',
                  style: TextStyle(color: Color(0xFF00E5FF)),
                ),
                TextSpan(text: ' Board Exam'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Interactive FBLE review modules, topic drills, mock exams, and vocabulary games built for CvSU-Naic.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              icon: const Icon(Icons.school_rounded, size: 18),
              label: const Text(
                'Start Reviewing Now',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF031C32).withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSectionTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _activeSectionTab == 0
                      ? const LinearGradient(
                          colors: [Color(0xFF00BCD4), Color(0xFF0288D1)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      size: 16,
                      color: _activeSectionTab == 0
                          ? Colors.white
                          : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'BFAS Alumni',
                      style: TextStyle(
                        color: _activeSectionTab == 0
                            ? Colors.white
                            : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSectionTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _activeSectionTab == 1
                      ? const LinearGradient(
                          colors: [Color(0xFF00BCD4), Color(0xFF0288D1)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 16,
                      color: _activeSectionTab == 1
                          ? Colors.white
                          : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'System Features',
                      style: TextStyle(
                        color: _activeSectionTab == 1
                            ? Colors.white
                            : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlightsGrid() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B3C5D).withOpacity(0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _featureRowTile(
            icon: Icons.menu_book_rounded,
            title: 'Class Module Library',
            subtitle:
                'Study PDFs, PowerPoint slides, documents, images, and lecture videos organized by class.',
            color: Colors.tealAccent,
          ),
          const SizedBox(height: 12),
          _featureRowTile(
            icon: Icons.quiz_rounded,
            title: 'Mini Quizzes & Instant Feedback',
            subtitle:
                'Practice 15-item topic drills with instant answer verification and question review.',
            color: Colors.lightBlueAccent,
          ),
          const SizedBox(height: 12),
          _featureRowTile(
            icon: Icons.assignment_rounded,
            title: 'Timed Board Exam Simulations',
            subtitle:
                'Experience full-length mock examinations modeled after the Fisheries Licensure Exam.',
            color: Colors.amberAccent,
          ),
          const SizedBox(height: 12),
          _featureRowTile(
            icon: Icons.water_rounded,
            title: 'Flashcards, Word Hunt & Word Shark',
            subtitle:
                'Master FBLE terminology through 3D flashcards, word puzzles, and class leaderboards.',
            color: Colors.cyanAccent,
          ),
        ],
      ),
    );
  }

  Widget _featureRowTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.16),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCtaBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00BCD4), Color(0xFF0288D1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BCD4).withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'Ready to Start Your FBLE Review?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sign in with your student credentials or join your instructor\'s review class.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: const Text(
                  'Launch FiBER Reviewer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B3C5D),
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
      ),
    );
  }

  Widget _buildAlumniSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B3C5D).withOpacity(0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: FutureBuilder< List< AlumniProfile > >(
        future: _alumniFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final profiles =
              (snapshot.data ?? const < AlumniProfile >[])
                  .where((a) => a.isVisible)
                  .toList()
                ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

          return Column(
            children: [
              _buildSectionTitle(),
              const SizedBox(height: 16),
              if (profiles.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No alumni profiles available yet.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 375,
                      child: PageView.builder(
                        controller: _alumniPageController,
                        itemCount: profiles.length,
                        onPageChanged: (idx) =>
                            setState(() => _currentAlumniPage = idx),
                        itemBuilder: (context, idx) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Center(
                              child: _AlumniCard(alumni: profiles[idx]),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.cyanAccent,
                            size: 18,
                          ),
                          onPressed: _currentAlumniPage > 0
                              ? () => _alumniPageController.previousPage(
                                    duration:
                                        const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                  )
                              : null,
                        ),
                        ...List< Widget >.generate(profiles.length, (i) {
                          final active = i == _currentAlumniPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.cyanAccent
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          );
                        }),
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.cyanAccent,
                            size: 18,
                          ),
                          onPressed: _currentAlumniPage < profiles.length - 1
                              ? () => _alumniPageController.nextPage(
                                    duration:
                                        const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                  )
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Column(
      children: [
        Text(
          'Our Successful BFAS Alumni',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.lightBlueAccent,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 56,
          height: 3,
          decoration: BoxDecoration(
            color: _brandBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Proud graduates who turned their passion for fisheries into meaningful careers and real impact.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
        ),
      ],
    );
  }
}

class _AlumniCard extends StatelessWidget {
  final AlumniProfile alumni;

  const _AlumniCard({required this.alumni});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.lightBlue.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            alumniAvatar(alumni.imageUrl, size: 84),
            const SizedBox(height: 12),
            Text(
              alumni.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: _deepBlue,
              ),
            ),
            if (alumni.company.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                alumni.company,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0277BD),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                if (alumni.batchYear.isNotEmpty)
                  _pill('Batch ${alumni.batchYear}'),
                if ((alumni.position.trim().isNotEmpty
                        ? alumni.position.trim()
                        : alumni.title.trim())
                    .isNotEmpty)
                  _pill(
                    'Position: ${alumni.position.trim().isNotEmpty ? alumni.position.trim() : alumni.title.trim()}',
                    bold: true,
                  ),
              ],
            ),
            if (alumni.highlight.trim().isNotEmpty) ...[
              const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    color: _brandBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      alumni.highlight.trim(),
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: _deepBlue,
        ),
      ),
    );
  }
}
