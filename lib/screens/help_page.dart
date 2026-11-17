import 'package:flutter/material.dart';

const _brand = Color(0xFF00BCD4);
const _ink = Color(0xFF0B3C5D);

class HelpStep {
  const HelpStep({required this.title, required this.body});

  final String title;
  final String body;
}

const studentHelpSteps = <HelpStep>[
  HelpStep(
    title: 'Explore Learning Features',
    body:
        'Explore the learning modules, take mini quizzes and mock '
        'exams, and track your performance analytics to identify areas for '
        'improvement.',
  ),
  HelpStep(
    title: 'Join a Class',
    body:
        "For students, join your teacher's class by entering the class code "
        'provided by your teacher.',
  ),
  HelpStep(
    title: 'Take a Study Break',
    body:
        'For a short study break, play the available mini games to relax and '
        'refresh your mind.',
  ),
  HelpStep(
    title: 'Create Flashcards',
    body:
        'Create your own flashcards for self studying and memorizing '
        'some hard terms.',
  ),
];

const teacherHelpSteps = <HelpStep>[
  HelpStep(
    title: 'Uploading Module',
    body:
        'Upload a module such as pdf, docx, and pptx for the students to start '
        'their reviewing session.',
  ),
  HelpStep(
    title: 'Create a Class',
    body:
        'Create a class and share the class code with students so they can join '
        "there. Monitor the student's performance with their performance stats.",
  ),
];

class HelpPage extends StatelessWidget {
  const HelpPage({super.key, this.isTeacher = false});

  final bool isTeacher;

  @override
  Widget build(BuildContext context) {
    final steps = isTeacher ? teacherHelpSteps : studentHelpSteps;
    final pageTitle = isTeacher
        ? 'Teacher Help & App Manual'
        : 'Student Help & App Manual';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          pageTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B3C5D), Color(0xFF0288D1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.menu_book_rounded,
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
                              'How to Use FiBER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Step-by-step guide to navigating modules, quizzes, classes, and analytics.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _sectionCard(
                  title: 'Complete System User Manual',
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StepTile(
                        number: 1,
                        step: HelpStep(
                          title: 'Account Registration & Sign-In',
                          body:
                              'Tap "Start Learning" on the landing page. Use "Create Account" to register as a student with a strong case-sensitive password (8–20 characters, uppercase, lowercase, and number), or use "Log In" to access your Student, Teacher, or Admin portal.',
                        ),
                      ),
                      SizedBox(height: 12),
                      _StepTile(
                        number: 2,
                        step: HelpStep(
                          title: 'Joining & Managing Classes (FIBER-XXXX)',
                          body:
                              'Teachers can create classes in Class Management to generate a unique FIBER-XXXX class code and monitor student analytics. Students can enter that class code under "My Classes" -> "Join Class" to unlock class-specific Mini Quizzes, Mock Exams, and Module Folders.',
                        ),
                      ),
                      SizedBox(height: 12),
                      _StepTile(
                        number: 3,
                        step: HelpStep(
                          title: 'Accessing Learning Modules',
                          body:
                              'Open the Module Library or your class Module Folders to read extracted study materials from PDF, DOCX, PPTX, and TXT files while preserving the original uploaded file metadata.',
                        ),
                      ),
                      SizedBox(height: 12),
                      _StepTile(
                        number: 4,
                        step: HelpStep(
                          title: 'Answering Mini Quizzes',
                          body:
                              'Select a Mini Quiz to practice 15-item topic drills. Each answer immediately displays a green check (✓) for correct or red X (✗) for incorrect in the pinned bottom bar and automatically advances after 2.4 seconds, ending with a full Performance Summary.',
                        ),
                      ),
                      SizedBox(height: 12),
                      _StepTile(
                        number: 5,
                        step: HelpStep(
                          title: 'Taking Mock Examinations',
                          body:
                              'Simulate the Fisheries Technologist Licensure Examination with a countdown timer, up to 40 board exam items, instant ✓/✗ verification, and a Try Again option to master missed questions.',
                        ),
                      ),
                      SizedBox(height: 12),
                      _StepTile(
                        number: 6,
                        step: HelpStep(
                          title: 'Using Mini Games (Flashcards & Word Hunt)',
                          body:
                              'In Flashcards, organize cards by fisheries subject, tap to flip in 3D, mark Correct/Wrong for accuracy tracking, or restore deleted cards. In Word Hunt, drag across letters on a responsive single-screen grid with audio chimes and background music.',
                        ),
                      ),
                      SizedBox(height: 12),
                      _StepTile(
                        number: 7,
                        step: HelpStep(
                          title: 'Profile Sync, Security & Statistics History',
                          body:
                              'Update your profile photo, username, or password in Profile & Account Settings (changes sync immediately to your sidebar). Open Statistics History anytime to review your completed quizzes, mock exams, and question-by-question answer logs.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'Frequently Asked Questions (FAQs)',
                  child: const Column(
                    children: [
                      _FaqTile(
                        question: 'How do I join my teacher\'s class?',
                        answer:
                            'Ask your teacher for the unique FIBER-XXXX class code generated in their Class Management page. Then go to your Student Dashboard -> My Classes -> Join Class, and enter the code.',
                      ),
                      _FaqTile(
                        question:
                            'Will my study time, flashcards, and quiz scores reset if I log out?',
                        answer:
                            'No. All study time, flashcards, joined classes, and quiz/mock exam history are persistently saved in Firebase Cloud Firestore under your account.',
                      ),
                      _FaqTile(
                        question:
                            'How do I change my password or recover my account?',
                        answer:
                            'Open the left sidebar -> Profile & Account Settings. Under "2. Account and Security", you can either enter your current password and a new password, or click "Send Verification / Reset Link to Email" to receive a reset link in your inbox.',
                      ),
                      _FaqTile(
                        question:
                            'Can teachers edit the automatically extracted quiz questions?',
                        answer:
                            'Yes! When a teacher uploads a PDF, Word, PowerPoint, or TXT file, the "Review & Edit Extracted Questions" modal opens automatically so the teacher can edit, delete, or add new questions before clicking Publish Now.',
                      ),
                      _FaqTile(
                        question:
                            'Where can I review my correct and wrong answers from past quizzes?',
                        answer:
                            'Open the left sidebar on the Student Dashboard and tap "Statistics History" (or tap the "History" button in the top banner). Tap any completed quiz or mock exam card to view your question-by-question Answer Review.',
                      ),
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

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.number, required this.step});

  final int number;
  final HelpStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightBlue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _brand,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.body,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightBlue.shade100),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: const Icon(Icons.help_outline_rounded, color: _brand),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
