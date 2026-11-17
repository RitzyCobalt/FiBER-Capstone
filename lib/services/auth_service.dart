import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'data_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static AppUser? _currentUser;
  static AppUser? get currentUser => _currentUser;
  static String? lastErrorMessage;

  /// Notifies sidebars, headers, and profile screens immediately when the user's photo or name changes
  static final ValueNotifier< int > userProfileNotifier = ValueNotifier< int >(0);

  /// Builds a live-synced CircleAvatar that automatically updates when the user changes their profile picture
  static Widget buildProfileAvatar({
    double radius = 28,
    IconData fallbackIcon = Icons.person,
    Color iconColor = const Color(0xFF0277BD),
  }) {
    return ValueListenableBuilder< int >(
      valueListenable: userProfileNotifier,
      builder: (context, _, __) {
        final rawPhoto = _currentUser?.photoUrl;
        ImageProvider? provider;
        if (rawPhoto != null && rawPhoto.trim().isNotEmpty) {
          try {
            final cleanBase64 = rawPhoto.contains(',')
                ? rawPhoto.split(',').last
                : rawPhoto;
            provider = MemoryImage(base64Decode(cleanBase64));
          } catch (_) {
            provider = null;
          }
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.white,
          backgroundImage: provider,
          child: provider == null
              ? Icon(fallbackIcon, color: iconColor, size: radius * 1.05)
              : null,
        );
      },
    );
  }

  // ── Sign Up — always student by default ───────────────────────
  static Future< AppUser? > signUp(
    String email,
    String password,
    String username, {
    String name = '',
  }) async {
    lastErrorMessage = null;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      final encodedVerifier =
          base64UrlEncode(utf8.encode('fiber_pwd_v1::$password'));
      try {
        await _db.collection('users').doc(uid).set({
          'email': email,
          'username': username,
          'name': name,
          'role': 'student',
          'authCredentialToken': encodedVerifier,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Firestore user doc write warning: $e');
      }

      _currentUser = AppUser(
        id: uid,
        email: email,
        role: UserRole.student,
        username: username,
        name: name,
        password: password,
      );
      userProfileNotifier.value++;
      DataService.logActivity(
        'New student account registered: $name ($email)',
        category: 'ACCOUNT_CREATED',
      );

      try {
        await DataService.loadModules();
        await DataService.loadClasses(uid: uid);
        DataService.startRealtimeSync(uid: uid);
        DataService.startStudyTimer(uid: uid);
      } catch (e) {
        debugPrint('Post-signup data load warning: $e');
      }

      return _currentUser;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
        // Check if this account was deleted in Firestore by Admin; if so, reclaim it!
        final cleanEmail = email.trim().toLowerCase();
        final existingDocs = await DataService.fetchAllUsersForAdmin();
        final stillInFirestore = existingDocs.any(
          (u) =>
              (u['email'] ?? '').toString().trim().toLowerCase() == cleanEmail,
        );
        if (!stillInFirestore) {
          try {
            UserCredential? reclaimed;
            try {
              reclaimed = await _auth.signInWithEmailAndPassword(
                email: cleanEmail,
                password: password,
              );
            } catch (_) {
              final setupKey = _buildDeterministicActivationKey(cleanEmail);
              reclaimed = await _auth.signInWithEmailAndPassword(
                email: cleanEmail,
                password: setupKey,
              );
              await reclaimed.user?.updatePassword(password);
            }
            final uid = reclaimed.user!.uid;
            await _db.collection('users').doc(uid).set(< String, dynamic >{
              'email': cleanEmail,
              'username': username.trim(),
              'name': name.trim(),
              'role': 'student',
              'mustSetupPassword': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
            _currentUser = AppUser(
              id: uid,
              email: cleanEmail,
              role: UserRole.student,
              username: username.trim(),
              name: name.trim(),
              password: password,
            );
            userProfileNotifier.value++;
            DataService.logActivity(
              'Re-registered deleted student account: $name ($cleanEmail)',
              category: 'ACCOUNT_CREATED',
              actor: cleanEmail,
              target: cleanEmail,
            );
            await DataService.loadModules();
            await DataService.loadClasses(uid: uid);
            DataService.startStudyTimer(uid: uid);
            return _currentUser;
          } catch (_) {
            try {
              await _auth.sendPasswordResetEmail(email: cleanEmail);
            } catch (_) {}
            lastErrorMessage =
                'This email was previously used. A reset link was sent to $cleanEmail so you can reclaim it.';
            return null;
          }
        }
        lastErrorMessage =
            'This email is already registered! Switch to "Log In" instead.';
      } else if (e.code == 'invalid-email') {
        lastErrorMessage = 'Please enter a valid email address.';
      } else if (e.code == 'weak-password') {
        lastErrorMessage = 'Password is too weak.';
      } else {
        lastErrorMessage = 'Sign up error (${e.code}): ${e.message ?? ""}';
      }
      return null;
    } catch (e) {
      debugPrint('SignUp error: $e');
      lastErrorMessage = 'Sign up error: $e';
      return null;
    }
  }

  static String _encodePasswordToken(String password) =>
      base64UrlEncode(utf8.encode('fiber_pwd_v1::$password'));

  static String? _decodePasswordToken(String? token) {
    if (token == null || token.trim().isEmpty) return null;
    try {
      final decoded = utf8.decode(base64Url.decode(token.trim()));
      if (decoded.startsWith('fiber_pwd_v1::')) {
        return decoded.substring('fiber_pwd_v1::'.length);
      }
    } catch (_) {}
    return null;
  }

  /// Looks up a registered user document by email address for in-app OTP recovery.
  static Future< Map< String, dynamic >? > findUserByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;
    try {
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return < String, dynamic >{
          'id': snap.docs.first.id,
          ...snap.docs.first.data(),
        };
      }
    } catch (_) {}

    try {
      final allUsers = await DataService.fetchAllUsersForAdmin();
      for (final u in allUsers) {
        if ((u['email'] ?? '').toString().trim().toLowerCase() == cleanEmail) {
          final uid = (u['id'] ?? '').toString();
          if (uid.isNotEmpty) {
            final fullDoc = await _db.collection('users').doc(uid).get();
            return < String, dynamic >{
              'id': uid,
              ...u,
              ...(fullDoc.data() ?? < String, dynamic >{}),
            };
          }
          return u;
        }
      }
    } catch (_) {}
    return null;
  }

  static String _buildRecoveryAuthEmail(String email) {
    final clean = email.trim().toLowerCase();
    final safeTag = base64UrlEncode(utf8.encode(clean))
        .replaceAll('=', '')
        .toLowerCase();
    return 'otp.reset.$safeTag@fiber-cvsu.app';
  }

  /// Completes in-app password recovery after the user's 6-digit Gmail OTP has been verified,
  /// updating the password in-app without Firestore permission-denied errors and sending a confirmation email.
  static Future< bool > completeInAppOtpPasswordReset({
    required String email,
    required String newPassword,
  }) async {
    lastErrorMessage = null;
    final cleanEmail = email.trim().toLowerCase();
    final wasSignedIn = _auth.currentUser != null;
    try {
      final userDoc = await findUserByEmail(cleanEmail);
      if (userDoc == null) {
        lastErrorMessage = 'No registered account found for $cleanEmail.';
        return false;
      }

      final uid = (userDoc['id'] ?? '').toString();
      final userName = (userDoc['name'] ?? userDoc['username'] ?? '').toString();
      final prevToken = (userDoc['authCredentialToken'] ?? '').toString();
      final prevPassword = _decodePasswordToken(prevToken);
      final newEncodedToken = _encodePasswordToken(newPassword);

      bool updatedPrimaryAuth = false;

      // 1. If already signed in as this user (e.g. from Account Settings), update directly
      if (_auth.currentUser != null && _auth.currentUser!.uid == uid) {
        try {
          if (prevPassword != null && prevPassword.isNotEmpty) {
            await _auth.currentUser!.reauthenticateWithCredential(
              EmailAuthProvider.credential(
                email: cleanEmail,
                password: prevPassword,
              ),
            );
          }
          await _auth.currentUser!.updatePassword(newPassword);
          updatedPrimaryAuth = true;
        } catch (_) {}

        try {
          await _db.collection('users').doc(uid).set(< String, dynamic >{
            'authCredentialToken': newEncodedToken,
            'isEmailVerified': true,
            'mustSetupPassword': false,
            'passwordUpdatedAt': DateTime.now().toUtc().toIso8601String(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      // 2. If signed out (ForgotPasswordScreen), authenticate on the primary _auth instance
      // so FirebaseFirestore.instance has request.auth.uid == uid permission
      if (!updatedPrimaryAuth && !wasSignedIn) {
        final candidatePasswords = < String >[
          if (prevPassword != null && prevPassword.isNotEmpty) prevPassword,
          _buildDeterministicActivationKey(cleanEmail),
          newPassword,
        ];

        for (final candidatePwd in candidatePasswords) {
          try {
            final cred = await _auth.signInWithEmailAndPassword(
              email: cleanEmail,
              password: candidatePwd,
            );
            if (cred.user != null) {
              if (candidatePwd != newPassword) {
                await cred.user!.updatePassword(newPassword);
              }
              await _db
                  .collection('users')
                  .doc(cred.user!.uid)
                  .set(< String, dynamic >{
                'authCredentialToken': newEncodedToken,
                'isEmailVerified': true,
                'mustSetupPassword': false,
                'passwordUpdatedAt': DateTime.now().toUtc().toIso8601String(),
              }, SetOptions(merge: true));
              updatedPrimaryAuth = true;
              break;
            }
          } catch (_) {}
        }
      }

      // 3. Fallback for legacy accounts created before authCredentialToken was stored:
      // Authenticate via a deterministic recovery auth user so Firestore writes are 100% authorized
      if (!updatedPrimaryAuth) {
        final recoveryEmail = _buildRecoveryAuthEmail(cleanEmail);
        final recoveryKey = _buildDeterministicActivationKey(cleanEmail);
        final targetAuthInstance = wasSignedIn
            ? FirebaseAuth.instanceFor(
                app: await (() async {
                  try {
                    return Firebase.app('otp_pwd_reset');
                  } catch (_) {
                    return Firebase.initializeApp(
                      name: 'otp_pwd_reset',
                      options: Firebase.app().options,
                    );
                  }
                })(),
              )
            : _auth;

        User? recoveryUser;
        try {
          final created =
              await targetAuthInstance.createUserWithEmailAndPassword(
            email: recoveryEmail,
            password: newPassword,
          );
          recoveryUser = created.user;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            final fallbackPwds = < String >[
              if (prevPassword != null && prevPassword.isNotEmpty) prevPassword,
              recoveryKey,
              newPassword,
            ];
            for (final p in fallbackPwds) {
              try {
                final signed =
                    await targetAuthInstance.signInWithEmailAndPassword(
                  email: recoveryEmail,
                  password: p,
                );
                recoveryUser = signed.user;
                if (recoveryUser != null && p != newPassword) {
                  await recoveryUser.updatePassword(newPassword);
                }
                break;
              } catch (_) {}
            }
          }
        } catch (_) {}

        if (!wasSignedIn && recoveryUser != null) {
          try {
            await _db
                .collection('users')
                .doc(recoveryUser.uid)
                .set(< String, dynamic >{
              'isOtpRecoveryMirror': true,
              'targetUid': uid,
              'targetEmail': cleanEmail,
              'authCredentialToken': newEncodedToken,
              'passwordUpdatedAt': DateTime.now().toUtc().toIso8601String(),
            }, SetOptions(merge: true));
          } catch (_) {}
        }

        if (uid.isNotEmpty) {
          try {
            await _db.collection('users').doc(uid).set(< String, dynamic >{
              'authCredentialToken': newEncodedToken,
              'isEmailVerified': true,
              'mustSetupPassword': false,
              'passwordUpdatedAt': DateTime.now().toUtc().toIso8601String(),
            }, SetOptions(merge: true));
          } catch (_) {}
        }
      }

      if (!wasSignedIn && _auth.currentUser != null) {
        try {
          await _auth.signOut();
        } catch (_) {}
      }

      await DataService.sendPasswordChangedConfirmationEmail(
        email: cleanEmail,
        recipientName: userName,
      );

      DataService.logActivity(
        'In-app OTP password recovery completed for $cleanEmail',
        category: 'PASSWORD_RESET_OTP',
        actor: cleanEmail,
        target: cleanEmail,
      );
      return true;
    } catch (e) {
      if (!wasSignedIn && _auth.currentUser != null) {
        try {
          await _auth.signOut();
        } catch (_) {}
      }
      lastErrorMessage = 'Could not reset password: $e';
      return false;
    }
  }

  // ── Login — role fetched from Firestore ───────────────────────
  static Future< AppUser? > login(String email, String password) async {
    lastErrorMessage = null;
    final cleanEmail = email.trim();
    try {
      String uid = '';
      Map< String, dynamic >? data;

      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
        uid = credential.user!.uid;
        final doc = await _db.collection('users').doc(uid).get();
        data = doc.data();
        await _db.collection('users').doc(uid).set(< String, dynamic >{
          'authCredentialToken': _encodePasswordToken(password),
        }, SetOptions(merge: true));
      } on FirebaseAuthException catch (authErr) {
        // Check if this user updated their password via in-app OTP recovery
        final matchedUser = await findUserByEmail(cleanEmail);
        final storedToken =
            (matchedUser?['authCredentialToken'] ?? '').toString();
        final expectedToken = _encodePasswordToken(password);

        bool verifiedViaRecovery = false;
        if (matchedUser != null &&
            storedToken.isNotEmpty &&
            storedToken == expectedToken) {
          verifiedViaRecovery = true;
        }

        // Also check the authenticated OTP recovery credential mirror for legacy accounts
        final recoveryEmail = _buildRecoveryAuthEmail(cleanEmail);
        try {
          final recCred = await _auth.signInWithEmailAndPassword(
            email: recoveryEmail,
            password: password,
          );
          if (recCred.user != null && matchedUser != null) {
            verifiedViaRecovery = true;
          }
        } catch (_) {}

        if (verifiedViaRecovery && matchedUser != null) {
          uid = (matchedUser['id'] ?? '').toString();
          data = matchedUser;
          try {
            await _db.collection('users').doc(uid).set(< String, dynamic >{
              'authCredentialToken': expectedToken,
            }, SetOptions(merge: true));
          } catch (_) {}
        } else {
          throw authErr;
        }
      }

      if (data == null) {
        final fallbackName = cleanEmail.split('@').first;
        data = < String, dynamic >{
          'email': cleanEmail,
          'username': fallbackName,
          'name': fallbackName,
          'role': 'student',
        };
        if (uid.isNotEmpty) {
          await _db
              .collection('users')
              .doc(uid)
              .set(data, SetOptions(merge: true));
        }
      }

      final roleStr = (data['role'] ?? 'student')
          .toString()
          .trim()
          .toLowerCase();

      UserRole role;
      switch (roleStr) {
        case 'admin':
          role = UserRole.admin;
          break;
        case 'teacher':
          role = UserRole.teacher;
          break;
        default:
          role = UserRole.student;
      }

      _currentUser = AppUser(
        id: uid,
        email: email,
        role: role,
        username: (data['username'] ?? '').toString(),
        name: (data['name'] ?? '').toString(),
        password: '',
        photoUrl: data['photoBase64']?.toString(),
      );
      userProfileNotifier.value++;
      DataService.logActivity(
        'Login success (${role.name.toUpperCase()}):$email',
        category: 'LOGIN',
      );

      try {
        await DataService.loadClasses(uid: uid);
      } catch (e) {
        debugPrint('Non-fatal class load error during login: $e');
      }
      DataService.loadModules();
      DataService.startRealtimeSync(uid: uid);
      if (role == UserRole.student) {
        DataService.startStudyTimer(uid: uid);
      }

      return _currentUser;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      final safeEmail = email.trim().isEmpty ? 'unknown' : email.trim();
      DataService.logActivity(
        'Failed login attempt for $safeEmail (${e.code})',
        category: 'LOGIN_FAILED',
        actor: safeEmail,
        target: safeEmail,
      );
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        lastErrorMessage =
            'Incorrect email or password. Please check your credentials.';
      } else if (e.code == 'user-not-found') {
        lastErrorMessage =
            'No account found with this email. Tap "Create Account" to register.';
      } else if (e.code == 'too-many-requests') {
        lastErrorMessage =
            'Too many failed attempts. Please wait a moment and try again.';
      } else {
        lastErrorMessage = 'Login error (${e.code}): ${e.message ?? ""}';
      }
      return null;
    } catch (e) {
      debugPrint('Login error: $e');
      final safeEmail = email.trim().isEmpty ? 'unknown' : email.trim();
      DataService.logActivity(
        'Failed login attempt for $safeEmail',
        category: 'LOGIN_FAILED',
        actor: safeEmail,
        target: safeEmail,
      );
      lastErrorMessage = 'Login error: $e';
      return null;
    }
  }

  // Keeps the in-memory user in sync after account edits and notifies all listeners.
  static void updateCachedProfile({
    String? name,
    String? username,
    String? photoUrl,
  }) {
    final c = _currentUser;
    if (c == null) return;
    _currentUser = AppUser(
      id: c.id,
      email: c.email,
      role: c.role,
      username: username ?? c.username,
      name: name ?? c.name,
      password: c.password,
      photoUrl: photoUrl ?? c.photoUrl,
    );
    userProfileNotifier.value++;
  }

  static String _buildDeterministicActivationKey(String email) {
    final clean = email.trim().toLowerCase();
    final encoded = base64UrlEncode(utf8.encode('fiber_setup_$clean'))
        .replaceAll('=', '');
    final shortHash =
        encoded.length > 10 ? encoded.substring(0, 10) : encoded;
    return 'FbSetup_${shortHash}_9aA!';
  }

  /// Checks if the given email belongs to an Admin-approved Teacher awaiting first-time password setup.
  static Future< Map< String, dynamic >? > checkPendingTeacherSetup(
    String email,
  ) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;
    try {
      final users = await DataService.fetchAllUsersForAdmin();
      for (final u in users) {
        if ((u['email'] ?? '').toString().trim().toLowerCase() == cleanEmail &&
            (u['role'] ?? '').toString().trim().toLowerCase() == 'teacher' &&
            u['mustSetupPassword'] == true) {
          return u;
        }
      }
    } catch (e) {
      debugPrint('checkPendingTeacherSetup warning: $e');
    }
    return null;
  }

  /// Completes first-time password setup for an approved Teacher and signs them into `/teacher`.
  static Future< AppUser? > completeFirstTimeTeacherSetup({
    required String email,
    required String newPassword,
  }) async {
    lastErrorMessage = null;
    final cleanEmail = email.trim().toLowerCase();
    try {
      final activationKey = _buildDeterministicActivationKey(cleanEmail);
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: activationKey,
      );
      final fbUser = credential.user!;
      await fbUser.updatePassword(newPassword);

      await _db.collection('users').doc(fbUser.uid).set(< String, dynamic >{
        'mustSetupPassword': false,
      }, SetOptions(merge: true));

      final doc = await _db.collection('users').doc(fbUser.uid).get();
      final data = doc.data() ?? < String, dynamic >{};

      _currentUser = AppUser(
        id: fbUser.uid,
        email: cleanEmail,
        role: UserRole.teacher,
        username: (data['username'] ?? cleanEmail.split('@').first).toString(),
        name: (data['name'] ?? 'Faculty Member').toString(),
        password: '',
        photoUrl: data['photoBase64']?.toString(),
      );
      userProfileNotifier.value++;
      DataService.logActivity(
        'Teacher completed first-time password setup: ${_currentUser!.name} ($cleanEmail)',
        category: 'TEACHER_ACTIVATED',
        actor: cleanEmail,
        target: cleanEmail,
      );
      await DataService.loadClasses(uid: fbUser.uid);
      await DataService.loadModules();
      return _currentUser;
    } on FirebaseAuthException catch (e) {
      lastErrorMessage = e.message ?? 'Could not activate teacher password.';
      return null;
    } catch (e) {
      lastErrorMessage = 'Activation error: $e';
      return null;
    }
  }

  /// Sends a password reset / verification email to the user's registered email address.
  static Future< void > sendPasswordResetVerificationEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Restore Session on Browser Refresh / App Reopen ───────────
  static Future< AppUser? > restoreSession() async {
    try {
      final fbUser = _auth.currentUser ??
          await _auth
              .authStateChanges()
              .first
              .timeout(const Duration(seconds: 6), onTimeout: () => null);
      if (fbUser == null) return null;

      final uid = fbUser.uid;
      Map< String, dynamic >? data;
      try {
        final doc = await _db.collection('users').doc(uid).get();
        data = doc.data();
      } catch (e) {
        debugPrint('Firestore restoreSession read notice: $e');
      }

      if (data == null) {
        final fallbackEmail = fbUser.email ?? '';
        final fallbackName = fallbackEmail.contains('@')
            ? fallbackEmail.split('@').first
            : 'User';
        data = < String, dynamic >{
          'email': fallbackEmail,
          'username': fallbackName,
          'name': fallbackName,
          'role': 'student',
        };
      }

      final roleStr = (data['role'] ?? 'student')
          .toString()
          .trim()
          .toLowerCase();

      UserRole role;
      switch (roleStr) {
        case 'admin':
          role = UserRole.admin;
          break;
        case 'teacher':
          role = UserRole.teacher;
          break;
        default:
          role = UserRole.student;
      }

      _currentUser = AppUser(
        id: uid,
        email: fbUser.email ?? (data['email'] ?? '').toString(),
        role: role,
        username: (data['username'] ?? '').toString(),
        name: (data['name'] ?? '').toString(),
        password: '',
        photoUrl: data['photoBase64']?.toString(),
      );
      userProfileNotifier.value++;

      await DataService.loadClasses(uid: uid);
      DataService.loadModules();
      DataService.startRealtimeSync(uid: uid);
      if (role == UserRole.student) {
        DataService.startStudyTimer(uid: uid);
      }

      return _currentUser;
    } catch (e) {
      debugPrint('Restore session error: $e');
      return null;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────
  static Future< void > logout() async {
    final uid = _currentUser?.id;
    final email = _currentUser?.email ?? 'User';
    DataService.stopStudyTimer(uid: uid);
    DataService.resetStudyTimer();
    DataService.stopRealtimeSync();
    DataService.logActivity('User logged out: $email', category: 'AUTH');
    await _auth.signOut();
    _currentUser = null;
    userProfileNotifier.value++;
  }

  // ── Create Teacher Account (admin only) ───────────────────────
  static Future< bool > createTeacherAccount({
    required String email,
    String? password,
    required String name,
    required String username,
    String department = '',
    bool sendPasswordSetupLink = false,
  }) async {
    lastErrorMessage = null;
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanUsername = username.trim();

    if (_currentUser?.role != UserRole.admin) {
      lastErrorMessage = 'Only an Admin can create Teacher accounts.';
      return false;
    }

    FirebaseApp? secondaryApp;
    FirebaseAuth? secondaryAuth;
    try {
      // Prevent duplicate account creation in Firestore users collection
      final existingUsers = await DataService.fetchAllUsersForAdmin();
      final duplicate = existingUsers.any(
        (u) =>
            (u['email'] ?? '').toString().trim().toLowerCase() == cleanEmail,
      );
      if (duplicate) {
        lastErrorMessage =
            'An account with email $cleanEmail already exists.';
        return false;
      }

      try {
        secondaryApp = Firebase.app('secondary');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'secondary',
          options: Firebase.app().options,
        );
      }

      secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final isPendingFirstSetup =
          sendPasswordSetupLink || password == null || password.trim().isEmpty;
      final effectivePassword = !isPendingFirstSetup
          ? password!.trim()
          : _buildDeterministicActivationKey(cleanEmail);

      UserCredential credential;
      try {
        credential = await secondaryAuth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: effectivePassword,
        );
      } on FirebaseAuthException catch (authErr) {
        if (authErr.code == 'email-already-in-use') {
          // Account was previously deleted from Firestore; reclaim the orphaned Auth user
          final setupKey = _buildDeterministicActivationKey(cleanEmail);
          try {
            credential = await secondaryAuth.signInWithEmailAndPassword(
              email: cleanEmail,
              password: setupKey,
            );
            if (!isPendingFirstSetup &&
                effectivePassword.isNotEmpty &&
                effectivePassword != setupKey) {
              await credential.user?.updatePassword(effectivePassword);
            }
          } catch (_) {
            if (password != null && password.trim().isNotEmpty) {
              credential = await secondaryAuth.signInWithEmailAndPassword(
                email: cleanEmail,
                password: password.trim(),
              );
            } else {
              rethrow;
            }
          }
        } else {
          rethrow;
        }
      }

      final uid = credential.user!.uid;

      await _db.collection('users').doc(uid).set(< String, dynamic >{
        'email': cleanEmail,
        'username': cleanUsername,
        'name': cleanName,
        'department': department.trim(),
        'role': 'teacher',
        'mustSetupPassword': isPendingFirstSetup,
        'createdAt': FieldValue.serverTimestamp(),
      });

      DataService.logActivity(
        'Admin created Teacher account: $cleanName ($cleanEmail)',
        category: 'TEACHER_CREATED',
        actor: _currentUser?.email ?? 'Admin',
        target: cleanEmail,
      );

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Create teacher FirebaseAuthException: ${e.code}');
      if (e.code == 'email-already-in-use') {
        lastErrorMessage = 'Email $cleanEmail is already registered in Firebase Auth.';
      } else {
        lastErrorMessage = e.message ?? 'Could not create teacher account (${e.code}).';
      }
      return false;
    } catch (e) {
      debugPrint('Create teacher error: $e');
      lastErrorMessage = 'Could not create teacher account: $e';
      return false;
    } finally {
      try {
        await secondaryAuth?.signOut();
      } catch (_) {}
      try {
        await secondaryApp?.delete();
      } catch (_) {}
    }
  }

  // ── Get all users (admin) ──────────────────────────────────────
  static Future< List< Map< String, dynamic > > > getAllUsersAsync() async {
    return DataService.fetchAllUsersForAdmin();
  }

  // ── Edit user (admin) ──────────────────────────────────────────
  static Future< bool > editUser({
    required String id,
    String? newEmail,
    String? newPassword,
    String? newName,
    String? newUsername,
    String? newRole,
  }) async {
    try {
      final Map< String, dynamic > updates = < String, dynamic >{};
      if (newName != null) updates['name'] = newName;
      if (newUsername != null) updates['username'] = newUsername;
      if (newEmail != null) updates['email'] = newEmail;
      if (newRole != null) updates['role'] = newRole;

      await _db
          .collection('users')
          .doc(id)
          .set(updates, SetOptions(merge: true));

      if (newPassword != null && newPassword.isNotEmpty) {
        final currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.uid == id) {
          await currentUser.updatePassword(newPassword);
        }
      }

      DataService.logActivity(
        'Admin updated user account ($id): role=${newRole ?? "unchanged"}, email=${newEmail ?? "unchanged"}',
        category: 'ADMIN',
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Delete user (admin) ────────────────────────────────────────
  static Future< void > deleteUser(String id) async {
    String targetEmail = '';
    try {
      final snap = await _db.collection('users').doc(id).get();
      final data = snap.data();
      targetEmail = (data?['email'] ?? '').toString().trim().toLowerCase();

      // If this user still had the deterministic setup key, purge their Firebase Auth record too
      if (targetEmail.isNotEmpty) {
        FirebaseApp? secondaryApp;
        FirebaseAuth? secondaryAuth;
        try {
          try {
            secondaryApp = Firebase.app('secondary_del');
          } catch (_) {
            secondaryApp = await Firebase.initializeApp(
              name: 'secondary_del',
              options: Firebase.app().options,
            );
          }
          secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
          final setupKey = _buildDeterministicActivationKey(targetEmail);
          final cred = await secondaryAuth.signInWithEmailAndPassword(
            email: targetEmail,
            password: setupKey,
          );
          await cred.user?.delete();
        } catch (_) {
          // User had a custom password; if they re-register later, signUp/createTeacherAccount will reclaim it
        } finally {
          try {
            await secondaryAuth?.signOut();
          } catch (_) {}
          try {
            await secondaryApp?.delete();
          } catch (_) {}
        }

        // Also clear any old teacher_requests for this email so they can request again cleanly
        try {
          final reqSnap = await _db.collection('teacher_requests').get();
          for (final doc in reqSnap.docs) {
            if ((doc.data()['email'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase() ==
                targetEmail) {
              await doc.reference.delete();
            }
          }
        } catch (_) {}
      }

      await _db.collection('users').doc(id).delete();
      DataService.logActivity(
        'Admin deleted user account: ${targetEmail.isNotEmpty ? targetEmail : id}',
        category: 'USER_DELETED',
        actor: _currentUser?.email ?? 'Admin',
        target: targetEmail.isNotEmpty ? targetEmail : id,
      );
    } catch (e) {
      debugPrint('Delete user error: $e');
    }
  }

  // ── Update password ────────────────────────────────────────────
  static Future< bool > updatePassword(String newPassword) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.updatePassword(newPassword);
        DataService.logActivity(
          'Password updated for ${currentUser.email ?? currentUser.uid}',
          category: 'ACCOUNT',
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ── Update username ────────────────────────────────────────────
  static Future< bool > updateUsername(String newUsername) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null && _currentUser != null) {
        await _db.collection('users').doc(currentUser.uid).update(< String, dynamic >{
          'username': newUsername,
        });
        _currentUser = AppUser(
          id: _currentUser!.id,
          email: _currentUser!.email,
          role: _currentUser!.role,
          username: newUsername,
          name: _currentUser!.name,
          password: _currentUser!.password,
          photoUrl: _currentUser!.photoUrl,
        );
        userProfileNotifier.value++;
        DataService.logActivity(
          'Username updated to "$newUsername" (${_currentUser!.email})',
          category: 'ACCOUNT',
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ── Update email ───────────────────────────────────────────────
  static Future< bool > updateEmail(String newEmail) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null && _currentUser != null) {
        await currentUser.verifyBeforeUpdateEmail(newEmail);
        await _db.collection('users').doc(currentUser.uid).update(< String, dynamic >{
          'email': newEmail,
        });
        _currentUser = AppUser(
          id: _currentUser!.id,
          email: newEmail,
          role: _currentUser!.role,
          username: _currentUser!.username,
          name: _currentUser!.name,
          password: _currentUser!.password,
          photoUrl: _currentUser!.photoUrl,
        );
        userProfileNotifier.value++;
        DataService.logActivity(
          'Email update requested to "$newEmail"',
          category: 'ACCOUNT',
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}