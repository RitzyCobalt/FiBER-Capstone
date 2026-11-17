import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'widgets/fish_background.dart';
import 'screens/front_page.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/teacher_dashboard.dart';
import 'screens/student_dashboard.dart';
import 'screens/firestore_test.dart';
import 'screens/admin_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService.restoreSession();
  runApp(const FiBER());
}

class FiBER extends StatelessWidget {
  const FiBER({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: DataService.fontFamilyNotifier,
      builder: (context, selectedFont, _) {
        return ValueListenableBuilder<double>(
          valueListenable: DataService.fontSizeNotifier,
          builder: (context, fontSize, _) {
            final lightTheme = ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
              // Transparent so the shared FishBackground shows through.
              scaffoldBackgroundColor: Colors.transparent,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              drawerTheme: const DrawerThemeData(
                backgroundColor: Color(0xFFE6FAFF),
              ),
              cardColor: Colors.white,
              dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
              fontFamily: selectedFont,
              textTheme: ThemeData.light().textTheme.apply(
                fontFamily: selectedFont,
              ),
            );

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Fisheries Board Exam Reviewer',
              themeMode: ThemeMode.light,
              theme: lightTheme,
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(fontSize / 14),
                  ),
                  child: FishBackground(
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
              initialRoute: '/',
              routes: {
                '/': (context) => const _SessionRedirectHome(),
                '/login': (context) => const LoginScreen(),
                '/signup': (context) => const SignupScreen(),
                '/teacher': (context) => const _RoleGuard(
                  allowedRole: UserRole.teacher,
                  child: TeacherDashboard(),
                ),
                '/student': (context) => const _RoleGuard(
                  allowedRole: UserRole.student,
                  child: StudentHome(),
                ),
                '/firestore_test': (context) => const FirestoreTest(),
                '/admin': (context) => const _RoleGuard(
                  allowedRole: UserRole.admin,
                  child: AdminPanel(),
                ),
              },
            );
          },
        );
      },
    );
  }
}

class _RoleGuard extends StatefulWidget {
  final UserRole allowedRole;
  final Widget child;

  const _RoleGuard({
    required this.allowedRole,
    required this.child,
  });

  @override
  State< _RoleGuard > createState() => _RoleGuardState();
}

class _RoleGuardState extends State< _RoleGuard > {
  bool _checking = true;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _verifyAccess();
  }

  Future< void > _verifyAccess() async {
    var user = AuthService.currentUser;
    user ??= await AuthService.restoreSession();

    if (!mounted) return;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
      return;
    }

    if (user.role != widget.allowedRole) {
      final targetRoute = user.role == UserRole.admin
          ? '/admin'
          : user.role == UserRole.teacher
              ? '/teacher'
              : '/student';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          targetRoute,
          (route) => false,
        );
      });
      return;
    }

    setState(() {
      _authorized = true;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_authorized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}

class _SessionRedirectHome extends StatefulWidget {
  const _SessionRedirectHome();

  @override
  State< _SessionRedirectHome > createState() => _SessionRedirectHomeState();
}

class _SessionRedirectHomeState extends State< _SessionRedirectHome > {
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future< void > _checkExistingSession() async {
    var user = AuthService.currentUser;
    user ??= await AuthService.restoreSession();
    DataService.startRealtimeSync(uid: user?.id);

    if (!mounted) return;
    if (user != null) {
      final targetRoute = user.role == UserRole.admin
          ? '/admin'
          : user.role == UserRole.teacher
              ? '/teacher'
              : '/student';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          targetRoute,
          (route) => false,
        );
      });
      return;
    }

    setState(() => _checkingSession = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const FrontPage();
  }
}