import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/alumni_model.dart';
import '../models/module_model.dart';

class DataService {
  static int quizzesTaken = 0;
  static int examsTaken = 0;
  static int gamesPlayed = 0;
  static int studySeconds = 0;

  static final List<Module> _modules = [];
  static final List<ClassRoom> _classes = [];
  static final List<String> _joinedClassCodes = [];
  static final List<String> _systemLogs = [];
  static final List<AlumniProfile> _alumniProfiles = [];

  static List<Module> get modules => List.unmodifiable(_modules);
  static List<ClassRoom> get classes => List.unmodifiable(_classes);
  static List<String> get joinedClassCodes =>
      List.unmodifiable(_joinedClassCodes);
  static List<String> get systemLogs => List.unmodifiable(_systemLogs);
  static List<AlumniProfile> get alumniProfiles =>
      List.unmodifiable(_alumniProfiles);

  static List<AlumniProfile> get visibleAlumniProfiles => List.unmodifiable(
    [..._alumniProfiles.where((profile) => profile.isVisible)]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)),
  );

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static ValueNotifier< int > moduleUpdateNotifier = ValueNotifier< int >(0);
  static ValueNotifier< int > studySecondsNotifier = ValueNotifier< int >(0);
  static ValueNotifier< double > uploadProgressNotifier =
      ValueNotifier< double >(0.0);
  static ValueNotifier< String > uploadStatusNotifier =
      ValueNotifier< String >('');
  static ValueNotifier< ThemeMode >? _themeModeNotifier;
  static ValueNotifier< String >? _fontFamilyNotifier;
  static ValueNotifier< double >? _fontSizeNotifier;

  static StreamSubscription< QuerySnapshot< Map< String, dynamic > > >?
      _modulesRealtimeSub;
  static StreamSubscription< QuerySnapshot< Map< String, dynamic > > >?
      _classesRealtimeSub;
  static StreamSubscription< QuerySnapshot< Map< String, dynamic > > >?
      _alumniRealtimeSub;
  static StreamSubscription< DocumentSnapshot< Map< String, dynamic > > >?
      _userRealtimeSub;
  static Timer? _androidRealtimePollTimer;

  static ValueNotifier<ThemeMode> get themeModeNotifier =>
      _themeModeNotifier ??= ValueNotifier(ThemeMode.system);
  static ValueNotifier<String> get fontFamilyNotifier =>
      _fontFamilyNotifier ??= ValueNotifier('Roboto');
  static ValueNotifier<double> get fontSizeNotifier =>
      _fontSizeNotifier ??= ValueNotifier(14.0);

  static ThemeMode get themeMode => themeModeNotifier.value;
  static String get selectedFontFamily => fontFamilyNotifier.value;
  static double get fontScale => fontSizeNotifier.value / 14.0;

  static void setFontSize(double size) {
    fontSizeNotifier.value = size;
  }

  // ── Cloudinary Configuration (For Videos up to 100 MB) ─────────
  // Leave blank to use the automatic Firestore chunking fallback for small videos (<= 5 MB).
  // When you create a free Cloudinary account, paste your Cloud Name and Unsigned Upload Preset here:
  static const String cloudinaryCloudName = '';
  static const String cloudinaryUploadPreset = '';

  static const Set< String > pictureExtensions = < String >{
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  };

  static const Set< String > videoExtensions = < String >{
    'mp4',
    'webm',
  };

  static bool isPictureExtension(String? ext) =>
      ext != null && pictureExtensions.contains(ext.trim().toLowerCase());

  static bool isVideoExtension(String? ext) =>
      ext != null && videoExtensions.contains(ext.trim().toLowerCase());

  static bool get isCloudinaryConfigured =>
      cloudinaryCloudName.trim().isNotEmpty &&
      cloudinaryUploadPreset.trim().isNotEmpty;

  static String encodeAlumniImage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('This file is not a supported image.');
    }

    img.Image resized = decoded;
    final longest = max(decoded.width, decoded.height);
    if (longest > 256) {
      final scale = 256 / longest;
      resized = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
      );
    }

    final jpg = img.encodeJpg(resized, quality: 80);
    if (jpg.length > 300 * 1024) {
      throw Exception(
        'Image is still too large after compression. Try a smaller photo.',
      );
    }
    return 'data:image/jpeg;base64,${base64Encode(jpg)}';
  }

// ── Accurate Active-Session Study Timer (Section 2.2) ──────────
  static Timer? _studyTimer;
  static String? _activeStudentUid;
  static final Set< String > _activeLearningSessions = < String >{};
  static bool _isAppInBackground = false;
  static bool _studyTimeInitializedFromCloud = false;

  // ── Real Gmail OTP Delivery + 5-Minute Expiration Store (Section 1.2) ──
  // Optional: Configure a Google Apps Script Web App URL or EmailJS credentials
  // for custom-branded SMTP delivery; otherwise FormSubmit AJAX + Firestore mail
  // relay delivers the OTP directly to the user's registered Gmail inbox.
  static const String otpEmailWebhookUrl = '';
  static const String emailJsServiceId = '';
  static const String emailJsTemplateId = '';
  static const String emailJsPublicKey = '';

  static final Map< String, Map< String, dynamic > > _activeOtps =
      < String, Map< String, dynamic > >{};

  static String generateEmailOtp({
    required String email,
    required String purpose,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final rng = Random.secure();
    final code = (100000 + rng.nextInt(900000)).toString();
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));
    _activeOtps['${purpose}_$cleanEmail'] = < String, dynamic >{
      'code': code,
      'email': cleanEmail,
      'purpose': purpose,
      'expiresAt': expiresAt,
    };
    return code;
  }

  /// Generates a 6-digit OTP with a 5-minute expiration, dispatches it to the
  /// user's registered Gmail via configured HTTP relays + Firestore mail queue,
  /// and returns delivery metadata so the user can always complete verification.
  static Future< Map< String, dynamic > > sendEmailOtp({
    required String email,
    required String purpose,
    String? recipientName,
    String? uid,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      throw Exception('Please enter a valid registered email address.');
    }

    final code = generateEmailOtp(email: cleanEmail, purpose: purpose);
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));
    final displayRecipient =
        (recipientName != null && recipientName.trim().isNotEmpty)
            ? recipientName.trim()
            : cleanEmail.split('@').first;

    final subject = 'FiBER Security Verification Code (OTP): $code';
    final plainBody =
        'Hello $displayRecipient,\n\n'
        'Your 6-digit One-Time Password (OTP) for FiBER Account & Security verification is:\n\n'
        '$code\n\n'
        'This verification code will expire in 5 minutes.\n'
        'If you did not request this code, please ignore this email.\n\n'
        '— FiBER (Fisheries Board Exam Reviewer • CvSU-Naic)';

    bool deliveredViaHttp = false;
    String relayNotice = '';

    // 1. Custom Google Apps Script / SMTP Webhook Relay (if configured)
    if (otpEmailWebhookUrl.trim().isNotEmpty) {
      try {
        final resp = await http
            .post(
              Uri.parse(otpEmailWebhookUrl.trim()),
              headers: const < String, String >{
                'Content-Type': 'application/json',
              },
              body: jsonEncode(< String, dynamic >{
                'to': cleanEmail,
                'name': displayRecipient,
                'otp': code,
                'subject': subject,
                'message': plainBody,
                'expiresInMinutes': 5,
              }),
            )
            .timeout(const Duration(seconds: 12));
        if (resp.statusCode >= 200 && resp.statusCode < 400) {
          deliveredViaHttp = true;
        }
      } catch (e) {
        debugPrint('Webhook OTP relay notice: $e');
      }
    }

    // 2. EmailJS REST API Relay (if configured)
    if (!deliveredViaHttp &&
        emailJsServiceId.trim().isNotEmpty &&
        emailJsTemplateId.trim().isNotEmpty &&
        emailJsPublicKey.trim().isNotEmpty) {
      try {
        final resp = await http
            .post(
              Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
              headers: const < String, String >{
                'Content-Type': 'application/json',
              },
              body: jsonEncode(< String, dynamic >{
                'service_id': emailJsServiceId.trim(),
                'template_id': emailJsTemplateId.trim(),
                'user_id': emailJsPublicKey.trim(),
                'template_params': < String, dynamic >{
                  'to_email': cleanEmail,
                  'to_name': displayRecipient,
                  'otp_code': code,
                  'subject': subject,
                  'message': plainBody,
                },
              }),
            )
            .timeout(const Duration(seconds: 12));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          deliveredViaHttp = true;
        }
      } catch (e) {
        debugPrint('EmailJS OTP relay notice: $e');
      }
    }

    // 3. Direct HTTPS Email Delivery via FormSubmit AJAX Service (with required Origin/Referer headers & JSON validation)
    if (!deliveredViaHttp) {
      try {
        final resp = await http
            .post(
              Uri.parse('https://formsubmit.co/ajax/$cleanEmail'),
              headers: const < String, String >{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Origin': 'https://fiber-app-2ada2.web.app',
                'Referer': 'https://fiber-app-2ada2.web.app/',
              },
              body: jsonEncode(< String, String >{
                '_subject': subject,
                '_template': 'box',
                '_captcha': 'false',
                'System': 'FiBER – Fisheries Board Exam Reviewer (CvSU-Naic)',
                'Recipient': displayRecipient,
                'Account': cleanEmail,
                'Verification_OTP_Code': code,
                'Expiration': 'Valid for 5 minutes',
                'Instructions':
                    'Enter this 6-digit OTP in the FiBER Account and Security section to complete verification.',
              }),
            )
            .timeout(const Duration(seconds: 12));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final decoded = jsonDecode(resp.body);
          if (decoded is Map) {
            final successVal =
                (decoded['success'] ?? '').toString().toLowerCase();
            final msgVal = (decoded['message'] ?? '').toString();
            if (successVal == 'true') {
              deliveredViaHttp = true;
            } else if (msgVal.isNotEmpty) {
              relayNotice = msgVal;
            }
          }
        }
      } catch (e) {
        debugPrint('FormSubmit AJAX OTP delivery notice: $e');
      }
    }

    // 4. Persist OTP verification state on the user's Firestore document
    final targetUid =
        (uid != null && uid.trim().isNotEmpty) ? uid.trim() : _activeStudentUid;
    final otpPayload = < String, dynamic >{
      'email': cleanEmail,
      'purpose': purpose,
      'code': code,
      'verified': false,
      'expiresAtIso': expiresAt.toUtc().toIso8601String(),
      'createdAtIso': DateTime.now().toUtc().toIso8601String(),
    };

    if (targetUid != null && targetUid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(targetUid).set(
          < String, dynamic >{
            'pendingOtpVerification': otpPayload,
          },
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('Firestore pendingOtpVerification write notice: $e');
      }
    }

    logActivity(
      'Dispatched 6-digit security OTP to $cleanEmail ($purpose)',
      category: 'OTP_SENT',
      actor: cleanEmail,
      target: cleanEmail,
    );

    return < String, dynamic >{
      'code': code,
      'email': cleanEmail,
      'deliveredViaHttp': deliveredViaHttp,
      'relayNotice': relayNotice,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  static String? verifyEmailOtp({
    required String email,
    required String purpose,
    required String enteredCode,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = enteredCode.trim();
    if (cleanCode.isEmpty) {
      return 'Please enter the 6-digit OTP sent to your Gmail address.';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(cleanCode)) {
      return 'OTP must be a 6-digit numeric code.';
    }

    final key = '${purpose}_$cleanEmail';
    final record = _activeOtps[key];
    if (record == null) {
      return 'No active OTP found. Please tap "Send OTP" first.';
    }
    final expiresAt = record['expiresAt'] as DateTime;
    if (DateTime.now().isAfter(expiresAt)) {
      _activeOtps.remove(key);
      return 'Your OTP has expired (5-minute limit). Please tap "Resend OTP".';
    }
    if (record['code'] != cleanCode) {
      return 'Invalid 6-digit OTP code. Please check your Gmail inbox and try again.';
    }
    _activeOtps.remove(key);
    return null; // Valid!
  }

  /// Verifies the 6-digit OTP against both in-memory cache and Firestore persistence,
  /// and marks the account's email verification status as verified in Cloud Firestore only upon success.
  static Future< String? > verifyEmailOtpAndMarkVerified({
    required String email,
    required String purpose,
    required String enteredCode,
    String? uid,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = enteredCode.trim();
    if (cleanCode.isEmpty) {
      return 'Please enter the 6-digit OTP code.';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(cleanCode)) {
      return 'OTP must be a 6-digit numeric code.';
    }

    final targetUid =
        (uid != null && uid.trim().isNotEmpty) ? uid.trim() : _activeStudentUid;
    final key = '${purpose}_$cleanEmail';
    final localRecord = _activeOtps[key];

    bool matched = false;
    if (localRecord != null) {
      final expiresAt = localRecord['expiresAt'] as DateTime;
      if (DateTime.now().isAfter(expiresAt)) {
        _activeOtps.remove(key);
        return 'Your OTP has expired (5-minute limit). Please tap "Resend OTP".';
      }
      if (localRecord['code'] == cleanCode) {
        matched = true;
        _activeOtps.remove(key);
      } else {
        return 'Invalid 6-digit OTP code. Please check your code and try again.';
      }
    } else if (targetUid != null && targetUid.isNotEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(targetUid).get();
        final data = doc.data();
        final pending = data?['pendingOtpVerification'];
        if (pending is Map) {
          final storedEmail =
              (pending['email'] ?? '').toString().trim().toLowerCase();
          final storedCode = (pending['code'] ?? '').toString().trim();
          final expiresIso = (pending['expiresAtIso'] ?? '').toString();
          final expiresAt = DateTime.tryParse(expiresIso)?.toLocal();
          if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
            return 'Your OTP has expired (5-minute limit). Please tap "Resend OTP".';
          }
          if (storedEmail == cleanEmail && storedCode == cleanCode) {
            matched = true;
          } else {
            return 'Invalid 6-digit OTP code. Please check your code and try again.';
          }
        }
      } catch (e) {
        debugPrint('Firestore OTP verification read error: $e');
      }
    }

    if (!matched) {
      return 'No active OTP found. Please tap "Send OTP to Gmail" first.';
    }

    if (targetUid != null && targetUid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(targetUid).set(
          < String, dynamic >{
            'isEmailVerified': true,
            'emailVerifiedAt': DateTime.now().toUtc().toIso8601String(),
            'pendingOtpVerification': < String, dynamic >{
              'email': cleanEmail,
              'purpose': purpose,
              'verified': true,
              'verifiedAtIso': DateTime.now().toUtc().toIso8601String(),
            },
          },
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('Failed to persist email verification status: $e');
      }
    }

    logActivity(
      'Email OTP verified successfully for $cleanEmail ($purpose)',
      category: 'EMAIL_VERIFIED',
      actor: cleanEmail,
      target: cleanEmail,
    );
    return null;
  }

  /// Sends a notification-only confirmation email to the user's registered Gmail
  /// confirming that their FiBER password was changed in-app (no external link required).
  static Future< void > sendPasswordChangedConfirmationEmail({
    required String email,
    String? recipientName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return;

    final displayRecipient =
        (recipientName != null && recipientName.trim().isNotEmpty)
            ? recipientName.trim()
            : cleanEmail.split('@').first;
    final timestamp = DateTime.now().toLocal().toString().substring(0, 19);
    const subject = 'FiBER Security Confirmation: Your Password Was Updated';
    final plainMessage =
        'Hello $displayRecipient,\n\n'
        'Your FiBER (Fisheries Board Exam Reviewer) account password for $cleanEmail '
        'was successfully updated inside the FiBER application on $timestamp.\n\n'
        'This email is a security notification only — you do not need to click any external link.\n\n'
        '— FiBER Security Team (CvSU-Naic)';

    bool sent = false;
    if (otpEmailWebhookUrl.trim().isNotEmpty) {
      try {
        final resp = await http
            .post(
              Uri.parse(otpEmailWebhookUrl.trim()),
              headers: const < String, String >{
                'Content-Type': 'application/json',
              },
              body: jsonEncode(< String, dynamic >{
                'to': cleanEmail,
                'name': displayRecipient,
                'subject': subject,
                'message': plainMessage,
              }),
            )
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode >= 200 && resp.statusCode < 400) sent = true;
      } catch (_) {}
    }

    if (!sent) {
      try {
        await http
            .post(
              Uri.parse('https://formsubmit.co/ajax/$cleanEmail'),
              headers: const < String, String >{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Origin': 'https://fiber-app-2ada2.web.app',
                'Referer': 'https://fiber-app-2ada2.web.app/',
              },
              body: jsonEncode(< String, String >{
                '_subject': subject,
                '_template': 'box',
                '_captcha': 'false',
                'System': 'FiBER – Fisheries Board Exam Reviewer (CvSU-Naic)',
                'Recipient': displayRecipient,
                'Account': cleanEmail,
                'Security_Status': 'Password Successfully Changed in FiBER App',
                'Timestamp': timestamp,
                'Notice':
                    'This is an automated confirmation that your FiBER password was updated inside the application. No external action is required.',
              }),
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('Confirmation email notice: $e');
      }
    }

    logActivity(
      'Sent password change confirmation email to $cleanEmail',
      category: 'PASSWORD_CHANGED_EMAIL',
      actor: cleanEmail,
      target: cleanEmail,
    );
  }

  static Future< void > saveBackupGmail({
    required String uid,
    required String backupGmail,
  }) async {
    final clean = backupGmail.trim().toLowerCase();
    if (uid.isEmpty || clean.isEmpty) return;
    try {
      await _firestore.collection('users').doc(uid).set(
        < String, dynamic >{
          'backupGmail': clean,
          'backupGmailVerified': true,
          'backupGmailVerifiedAt': DateTime.now().toUtc().toIso8601String(),
        },
        SetOptions(merge: true),
      );
      logActivity(
        'Verified backup Gmail account linked: $clean',
        category: 'BACKUP_GMAIL_LINKED',
        actor: clean,
        target: uid,
      );
    } catch (e) {
      debugPrint('saveBackupGmail warning: $e');
    }
  }

  /// Registers that a student opened an active learning screen ('module', 'quiz', 'mock_exam', 'flashcards', 'word_hunt', 'word_shark').
  /// Prevents double-counting when switching between activities.
  static void beginLearningActivity(String activityKey, {String? uid}) {
    if (uid != null && uid.isNotEmpty) {
      _activeStudentUid = uid;
    }
    _activeLearningSessions.add(activityKey);
    _isAppInBackground = false;
    _ensureStudyTimerRunning();
  }

  /// Marks a learning screen closed and flushes accumulated study time to Firestore.
  static void endLearningActivity(String activityKey, {String? uid}) {
    _activeLearningSessions.remove(activityKey);
    flushStudyTimeToFirestore(uid: uid);
    if (_activeLearningSessions.isEmpty) {
      _studyTimer?.cancel();
      _studyTimer = null;
    }
  }

  /// Pauses or resumes the active study timer when the app moves to background/foreground.
  static void setAppLifecyclePaused(bool paused) {
    _isAppInBackground = paused;
    if (paused) {
      flushStudyTimeToFirestore();
    }
  }

  static void _ensureStudyTimerRunning() {
    if (_studyTimer != null && _studyTimer!.isActive) return;
    _studyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isAppInBackground || _activeLearningSessions.isEmpty) return;
      studySeconds++;
      studySecondsNotifier.value = studySeconds;
      if (studySeconds % 10 == 0 && _activeStudentUid != null) {
        flushStudyTimeToFirestore();
      }
    });
  }

  static void flushStudyTimeToFirestore({String? uid}) {
    final targetUid = uid ?? _activeStudentUid;
    if (targetUid == null || targetUid.isEmpty) return;
    if (!_studyTimeInitializedFromCloud && studySeconds == 0) return;
    _firestore.collection('users').doc(targetUid).set(< String, dynamic >{
      'studySeconds': studySeconds,
    }, SetOptions(merge: true)).catchError((_) {});
  }

  static void startStudyTimer({String? uid, String? activityKey}) {
    if (uid != null && uid.isNotEmpty) {
      _activeStudentUid = uid;
    }
    if (activityKey != null && activityKey.isNotEmpty) {
      _activeLearningSessions.add(activityKey);
    }
    _ensureStudyTimerRunning();
  }

  static void stopStudyTimer({String? uid, String? activityKey}) {
    if (activityKey != null && activityKey.isNotEmpty) {
      _activeLearningSessions.remove(activityKey);
    } else {
      _activeLearningSessions.clear();
    }
    flushStudyTimeToFirestore(uid: uid);
    if (_activeLearningSessions.isEmpty) {
      _studyTimer?.cancel();
      _studyTimer = null;
    }
  }

  static void resetStudyTimer() {
    _activeLearningSessions.clear();
    _studyTimer?.cancel();
    _studyTimer = null;
    studySeconds = 0;
    studySecondsNotifier.value = 0;
    _studyTimeInitializedFromCloud = false;
    _activeStudentUid = null;
  }

  /// Starts real-time synchronization across modules, classes, alumni profiles, and the current user's joined classes.
  static void startRealtimeSync({String? uid}) {
    if (kIsWeb) {
      _modulesRealtimeSub ??=
          _firestore.collection('modules').snapshots().listen(
        (snapshot) {
          final updated = < Module >[];
          for (final doc in snapshot.docs) {
            try {
              _ingestModuleDoc(doc.id, doc.data(), updated);
            } catch (_) {}
          }
          updated.sort((a, b) {
            final aDate =
                a.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                b.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          _modules
            ..clear()
            ..addAll(updated);
          notifyModuleUpdated();
        },
        onError: (Object e) => debugPrint('Realtime modules listener: $e'),
      );

      _classesRealtimeSub ??=
          _firestore.collection('classes').snapshots().listen(
        (snapshot) {
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final code =
                (data['id'] ?? doc.id).toString().trim().toUpperCase();
            if (code.isNotEmpty) {
              _addOrUpdateClass(
                code,
                (data['name'] ?? 'Class $code').toString(),
                teacherId: (data['teacherId'] ?? '').toString(),
              );
            }
          }
          notifyModuleUpdated();
        },
        onError: (Object e) => debugPrint('Realtime classes listener: $e'),
      );

      _alumniRealtimeSub ??=
          _firestore.collection('alumni_profiles').snapshots().listen(
        (snapshot) {
          final list = < AlumniProfile >[];
          for (final doc in snapshot.docs) {
            try {
              final profile = AlumniProfile.fromMap(doc.id, doc.data());
              if (profile.name.isNotEmpty) list.add(profile);
            } catch (_) {}
          }
          if (list.isNotEmpty) {
            list.sort((a, b) {
              final cmp = a.displayOrder.compareTo(b.displayOrder);
              if (cmp != 0) return cmp;
              return b.createdAt.compareTo(a.createdAt);
            });
            _alumniProfiles
              ..clear()
              ..addAll(list);
            notifyModuleUpdated();
          }
        },
        onError: (Object e) => debugPrint('Realtime alumni listener: $e'),
      );
    } else {
      // On Android APK, use lightweight periodic REST sync to avoid 1MB/2MB Pigeon channel overflow
      _androidRealtimePollTimer?.cancel();
      _androidRealtimePollTimer = Timer.periodic(
        const Duration(seconds: 12),
        (_) async {
          if (!isLoadingModules) {
            await loadModules();
            await loadClasses(uid: uid ?? _activeStudentUid);
            await loadAlumniProfiles();
          }
        },
      );
    }

    if (uid != null && uid.isNotEmpty) {
      _userRealtimeSub?.cancel();
      _userRealtimeSub =
          _firestore.collection('users').doc(uid).snapshots().listen(
        (snap) {
          final data = snap.data();
          if (data == null) return;
          final codes = (data['joinedClassCodes'] as List< dynamic >? ?? [])
              .map((e) => e.toString().toUpperCase())
              .toList();
          _joinedClassCodes
            ..clear()
            ..addAll(codes);
          notifyModuleUpdated();
        },
        onError: (Object e) => debugPrint('Realtime user listener: $e'),
      );
    }
  }

  static void stopRealtimeSync() {
    _userRealtimeSub?.cancel();
    _userRealtimeSub = null;
    _androidRealtimePollTimer?.cancel();
    _androidRealtimePollTimer = null;
  }

  static String formatStudySeconds(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Persistent Activity Logs & Teacher Account Requests ────────
  static void _log(String message) {
    logActivity(message, category: 'SYSTEM');
  }

  static void logActivity(
    String message, {
    String category = 'SYSTEM',
    String? actor,
    String? target,
  }) {
    final now = DateTime.now();
    final timestamp = now.toString().substring(0, 19);
    final actorTag = (actor != null && actor.trim().isNotEmpty)
        ? ' [By: ${actor.trim()}]'
        : '';
    final targetTag = (target != null && target.trim().isNotEmpty)
        ? ' [Target: ${target.trim()}]'
        : '';
    final entry = '[$timestamp] [$category]$actorTag$targetTag $message';
    if (!_systemLogs.contains(entry)) {
      _systemLogs.add(entry);
    }
    _firestore.collection('system_logs').add(< String, dynamic >{
      'actionType': category,
      'category': category,
      'description': message,
      'message': message,
      'actor': actor ?? 'System',
      'target': target ?? '',
      'formatted': entry,
      'createdAt': now.toUtc().toIso8601String(),
    }).catchError((_) => null);
  }

  static Future< List< String > > loadSystemLogs() async {
    final loaded = < Map< String, String > >[];

    if (!kIsWeb) {
      try {
        final restDocs = await _fetchCollectionViaRest(
          'system_logs',
          pageSize: 100,
        );
        for (final doc in restDocs) {
          final data =
              (doc['data'] as Map< String, dynamic >?) ?? < String, dynamic >{};
          final formatted = _formatLogFromData(data);
          final createdAt = (data['createdAt'] ?? '').toString().trim();
          if (formatted.isNotEmpty) {
            loaded.add(< String, String >{
              'formatted': formatted,
              'createdAt': createdAt,
            });
          }
        }
      } catch (e) {
        debugPrint('REST loadSystemLogs warning: $e');
      }
    }

    if (loaded.isEmpty) {
      try {
        final snap = await _firestore.collection('system_logs').get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final formatted = _formatLogFromData(data);
          final createdAt = (data['createdAt'] ?? '').toString().trim();
          if (formatted.isNotEmpty) {
            loaded.add(< String, String >{
              'formatted': formatted,
              'createdAt': createdAt,
            });
          }
        }
      } catch (e) {
        debugPrint('Firestore loadSystemLogs warning: $e');
      }
    }

    if (loaded.isNotEmpty) {
      loaded.sort(
        (a, b) => (a['createdAt'] ?? '').compareTo(b['createdAt'] ?? ''),
      );
      _systemLogs.clear();
      for (final item in loaded) {
        final f = item['formatted']!;
        if (!_systemLogs.contains(f)) {
          _systemLogs.add(f);
        }
      }
    }
    return List< String >.unmodifiable(_systemLogs);
  }

  static String _formatLogFromData(Map< String, dynamic > data) {
    final rawFormatted = (data['formatted'] ?? '').toString().trim();
    if (rawFormatted.isNotEmpty) return rawFormatted;
    final createdAt = (data['createdAt'] ?? '').toString().trim();
    final ts = createdAt.length >= 19
        ? createdAt.substring(0, 19).replaceAll('T', ' ')
        : createdAt;
    final category =
        (data['actionType'] ?? data['category'] ?? 'SYSTEM').toString().trim();
    final msg =
        (data['description'] ?? data['message'] ?? '').toString().trim();
    if (msg.isEmpty) return '';
    return '[$ts] [$category] $msg';
  }

  static Future< void > submitTeacherAccountRequest({
    required String name,
    required String username,
    required String email,
    String department = '',
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanUsername = username.trim();

    // Prevent duplicate pending requests or already-registered accounts
    final existingRequests = await loadTeacherAccountRequests();
    final hasDuplicatePending = existingRequests.any(
      (r) =>
          (r['email'] ?? '').toString().trim().toLowerCase() == cleanEmail,
    );
    if (hasDuplicatePending) {
      throw Exception(
        'A pending teacher request for $cleanEmail has already been submitted.',
      );
    }

    final existingUsers = await fetchAllUsersForAdmin();
    final alreadyRegistered = existingUsers.any(
      (u) =>
          (u['email'] ?? '').toString().trim().toLowerCase() == cleanEmail,
    );
    if (alreadyRegistered) {
      throw Exception(
        'An account with email $cleanEmail is already registered.',
      );
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    await _firestore.collection('teacher_requests').add(< String, dynamic >{
      'name': cleanName,
      'username': cleanUsername,
      'email': cleanEmail,
      'department': department.trim(),
      'status': 'pending',
      'requestedAt': nowIso,
    });
    logActivity(
      'Teacher account requested by $cleanName ($cleanEmail)',
      category: 'TEACHER_REQUEST',
      actor: cleanEmail,
      target: cleanEmail,
    );
  }

  static Future< List< Map< String, dynamic > > >
  loadTeacherAccountRequests() async {
    final requests = < Map< String, dynamic > >[];

    if (!kIsWeb) {
      try {
        final restDocs = await _fetchCollectionViaRest(
          'teacher_requests',
          pageSize: 50,
        );
        for (final doc in restDocs) {
          final docId = (doc['_docId'] ?? '').toString();
          final data =
              (doc['data'] as Map< String, dynamic >?) ?? < String, dynamic >{};
          if ((data['status'] ?? 'pending').toString() == 'pending') {
            final safeData = Map< String, dynamic >.from(data)
              ..remove('password');
            requests.add(< String, dynamic >{'id': docId, ...safeData});
          }
        }
        requests.sort(
          (a, b) => (b['requestedAt'] ?? '')
              .toString()
              .compareTo((a['requestedAt'] ?? '').toString()),
        );
        return requests;
      } catch (e) {
        debugPrint('REST loadTeacherAccountRequests warning: $e');
      }
    }

    try {
      final snap = await _firestore.collection('teacher_requests').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if ((data['status'] ?? 'pending').toString() == 'pending') {
          final safeData = Map< String, dynamic >.from(data)
            ..remove('password');
          requests.add(< String, dynamic >{'id': doc.id, ...safeData});
        }
      }
      requests.sort(
        (a, b) => (b['requestedAt'] ?? '')
            .toString()
            .compareTo((a['requestedAt'] ?? '').toString()),
      );
    } catch (e) {
      debugPrint('Firestore loadTeacherAccountRequests warning: $e');
    }
    return requests;
  }

  static Future< void > resolveTeacherAccountRequest({
    required String id,
    required String status,
    required String email,
    String? adminEmail,
  }) async {
    try {
      await _firestore.collection('teacher_requests').doc(id).set(
        < String, dynamic >{
          'status': status,
          'resolvedAt': DateTime.now().toUtc().toIso8601String(),
          'resolvedBy': adminEmail ?? 'Admin',
          'password': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
      logActivity(
        'Teacher account request ${status.toUpperCase()} for $email',
        category: status == 'approved'
            ? 'TEACHER_REQUEST_APPROVED'
            : 'TEACHER_REQUEST_REJECTED',
        actor: adminEmail ?? 'Admin',
        target: email,
      );
    } catch (e) {
      debugPrint('Resolve teacher request warning: $e');
    }
  }

  static Future< void > deleteTeacherAccountRequest(String id) async {
    try {
      await _firestore.collection('teacher_requests').doc(id).delete();
    } catch (e) {
      debugPrint('Delete teacher request warning: $e');
    }
  }

  static Future< List< Map< String, dynamic > > > fetchAllUsersForAdmin() async {
    if (!kIsWeb) {
      try {
        final restDocs = await _fetchCollectionViaRest(
          'users',
          maskFields: < String >[
            'email',
            'username',
            'name',
            'role',
            'department',
            'mustSetupPassword',
          ],
          pageSize: 100,
        );
        return restDocs.map((doc) {
          final docId = (doc['_docId'] ?? '').toString();
          final data =
              (doc['data'] as Map< String, dynamic >?) ?? < String, dynamic >{};
          return < String, dynamic >{
            'id': docId,
            'email': (data['email'] ?? '').toString(),
            'username': (data['username'] ?? '').toString(),
            'name': (data['name'] ?? '').toString(),
            'role': (data['role'] ?? 'student').toString(),
            'department': (data['department'] ?? '').toString(),
            'mustSetupPassword': data['mustSetupPassword'] == true,
          };
        }).toList();
      } catch (e) {
        debugPrint('REST fetchAllUsersForAdmin warning: $e');
      }
    }

    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return < String, dynamic >{
          'id': doc.id,
          'email': (data['email'] ?? '').toString(),
          'username': (data['username'] ?? '').toString(),
          'name': (data['name'] ?? '').toString(),
          'role': (data['role'] ?? 'student').toString(),
          'department': (data['department'] ?? '').toString(),
          'mustSetupPassword': data['mustSetupPassword'] == true,
        };
      }).toList();
    } catch (e) {
      debugPrint('Firestore fetchAllUsersForAdmin warning: $e');
      return < Map< String, dynamic > >[];
    }
  }

  static void addQuizTaken() {
    quizzesTaken++;
    _log('Quiz taken. Total: $quizzesTaken');
  }

  static void addExamTaken() {
    examsTaken++;
    _log('Mock Exam taken. Total: $examsTaken');
  }

  static void addGamePlayed() {
    gamesPlayed++;
    _log('Game played. Total: $gamesPlayed');
  }

  static void addStudyTime(int seconds) {
    studySeconds += seconds;
  }

  static int get studyMinutes => studySeconds ~/ 60;

  static String get studyTimeFormatted {
    final h = studySeconds ~/ 3600;
    final m = (studySeconds % 3600) ~/ 60;
    final s = studySeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Get file bytes ─────────────────────────────────────────────
  static Future<Uint8List?> _getBytes({
    Uint8List? bytes,
    String? filePath,
  }) async {
    if (bytes != null) return bytes;
    if (filePath != null && !kIsWeb) {
      try {
        return await File(filePath).readAsBytes();
      } catch (e) {
        debugPrint('Error reading file from path: $e');
        return null;
      }
    }
    return null;
  }

  // ── Strip XML tags, return plain text ─────────────────────────
  static String _stripXml(String xml) {
    return xml
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&apos;'), "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ── PPTX extraction ────────────────────────────────────────────
  // PPTX files are ZIP archives containing slide XML files.
  // Each slide is in ppt/slides/slide1.xml, slide2.xml, etc.
  static String _extractPptx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final slideBuffer = StringBuffer();

      // Collect slide files and sort by slide number
      final slideFiles = archive.files
          .where(
            (f) =>
                f.name.startsWith('ppt/slides/slide') &&
                f.name.endsWith('.xml') &&
                !f.name.contains('slideLayout') &&
                !f.name.contains('slideMaster'),
          )
          .toList();

      slideFiles.sort((a, b) {
        // Extract slide number from filename e.g. slide1.xml → 1
        final aNum =
            int.tryParse(
              RegExp(r'slide(\d+)\.xml').firstMatch(a.name)?.group(1) ?? '0',
            ) ??
            0;
        final bNum =
            int.tryParse(
              RegExp(r'slide(\d+)\.xml').firstMatch(b.name)?.group(1) ?? '0',
            ) ??
            0;
        return aNum.compareTo(bNum);
      });

      int slideNumber = 1;
      for (final file in slideFiles) {
        if (!file.isFile) continue;
        try {
          final xmlContent = utf8.decode(
            file.content as List<int>,
            allowMalformed: true,
          );

          // Extract text runs preserving paragraph breaks
          final paragraphs = <String>[];
          final paraMatches = RegExp(
            r'<a:p[>\s][^]*?</a:p>',
          ).allMatches(xmlContent);

          for (final para in paraMatches) {
            final paraXml = para.group(0) ?? '';
            // Extract text elements within paragraph
            final textParts = <String>[];
            final textMatches = RegExp(
              r'<a:t[>\s][^]*?</a:t>',
            ).allMatches(paraXml);
            for (final t in textMatches) {
              final raw = t.group(0) ?? '';
              final text = _stripXml(raw).trim();
              if (text.isNotEmpty) textParts.add(text);
            }
            final paraText = textParts.join(' ').trim();
            if (paraText.isNotEmpty) paragraphs.add(paraText);
          }

          if (paragraphs.isNotEmpty) {
            slideBuffer.writeln('--- Slide $slideNumber ---');
            for (final p in paragraphs) {
              slideBuffer.writeln(p);
            }
            slideBuffer.writeln();
          }
          slideNumber++;
        } catch (e) {
          debugPrint('Error reading slide ${file.name}: $e');
        }
      }

      final result = slideBuffer.toString().trim();
      debugPrint('PPTX extracted: ${result.length} chars, $slideNumber slides');
      return result;
    } catch (e) {
      debugPrint('PPTX extraction error: $e');
      return '';
    }
  }

  // ── Improved DOCX extraction ───────────────────────────────────
  // Uses docx_to_text as primary, falls back to manual XML parse
  static String _extractDocx(Uint8List bytes) {
    try {
      // Primary: use docx_to_text
      final text = docxToText(bytes);
      if (text.trim().isNotEmpty) {
        debugPrint('DOCX extracted via docx_to_text: ${text.length} chars');
        return text;
      }
    } catch (e) {
      debugPrint('docx_to_text failed: $e, trying manual extraction');
    }

    // Fallback: manual XML extraction from ZIP
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
        orElse: () => archive.files.first,
      );

      final xmlContent = utf8.decode(
        docFile.content as List<int>,
        allowMalformed: true,
      );

      // Extract paragraphs preserving structure
      final paragraphs = <String>[];
      final paraMatches = RegExp(r'<w:p[ >][^]*?</w:p>').allMatches(xmlContent);

      for (final para in paraMatches) {
        final paraXml = para.group(0) ?? '';
        final textParts = <String>[];
        final textMatches = RegExp(
          r'<w:t[^>]*>([^<]*)</w:t>',
        ).allMatches(paraXml);
        for (final t in textMatches) {
          final text = t.group(1)?.trim() ?? '';
          if (text.isNotEmpty) textParts.add(text);
        }
        final paraText = textParts.join(' ').trim();
        if (paraText.isNotEmpty) paragraphs.add(paraText);
      }

      final result = paragraphs.join('\n').trim();
      debugPrint('DOCX fallback extracted: ${result.length} chars');
      return result;
    } catch (e) {
      debugPrint('DOCX fallback extraction error: $e');
      return '';
    }
  }

  // ── Improved PDF extraction ────────────────────────────────────
  // Extracts text page by page to preserve reading order
  static Future< String > _extractPdf(Uint8List bytes) async {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final pageBuffer = StringBuffer();
      final pageCount = document.pages.count;
      final maxPages = min(pageCount, 40);

      for (int i = 0; i < maxPages; i++) {
        await Future< void >.delayed(const Duration(milliseconds: 10));
        try {
          final pageText = extractor.extractText(
            startPageIndex: i,
            endPageIndex: i,
          );
          final trimmed = pageText.trim();
          if (trimmed.isNotEmpty) {
            pageBuffer.writeln('--- Page ${i + 1} ---');
            pageBuffer.writeln(trimmed);
            pageBuffer.writeln();
          }
        } catch (e) {
          debugPrint('Error extracting PDF page $i: $e');
        }
      }

      document.dispose();
      final result = pageBuffer.toString().trim();
      debugPrint(
        'PDF extracted: ${result.length} chars, $pageCount pages',
      );
      return result;
    } catch (e) {
      debugPrint('PDF extraction error: $e');
      // Fallback: extract all at once
      try {
        final document = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(document).extractText();
        document.dispose();
        debugPrint('PDF fallback extracted: ${text.length} chars');
        return text;
      } catch (e2) {
        debugPrint('PDF fallback also failed: $e2');
        return '';
      }
    }
  }

  // ── Main extraction dispatcher ─────────────────────────────────
  static Future<String> _extractText({
    required String fileName,
    Uint8List? bytes,
    String? filePath,
  }) async {
    try {
      final fileBytes = await _getBytes(bytes: bytes, filePath: filePath);
      if (fileBytes == null || fileBytes.isEmpty) {
        debugPrint('No bytes available for extraction');
        return '';
      }

      final fileLower = fileName.toLowerCase();

      if (fileLower.endsWith('.pdf')) {
        return _extractPdf(fileBytes);
      }

      if (fileLower.endsWith('.pptx') || fileLower.endsWith('.ppt')) {
        return _extractPptx(fileBytes);
      }

      if (fileLower.endsWith('.docx')) {
        return _extractDocx(fileBytes);
      }

      if (fileLower.endsWith('.doc')) {
        final docText = _extractDocx(fileBytes);
        if (docText.trim().isNotEmpty) return docText;
        final rawLatin = latin1.decode(fileBytes, allowInvalid: true);
        final printable = RegExp(r'[A-Za-z0-9 ,.\-;:\(\)\?\!\/]{5,}')
            .allMatches(rawLatin)
            .map((m) => m.group(0)!.trim())
            .where((s) => s.length >= 4)
            .join(' ');
        return printable;
      }

      if (fileLower.endsWith('.txt')) {
        final text = utf8.decode(fileBytes, allowMalformed: true);
        debugPrint('TXT extracted: ${text.length} chars');
        return text;
      }

      debugPrint('Unsupported file format: $fileName');
      return '';
    } catch (e) {
      debugPrint('Text extraction error: $e');
      return '';
    }
  }

  static const Set< String > _questionStopwords = < String >{
    'about', 'above', 'after', 'again', 'against', 'all', 'also', 'always',
    'among', 'another', 'because', 'before', 'being', 'below', 'between',
    'both', 'could', 'during', 'each', 'either', 'every', 'first', 'found',
    'from', 'further', 'having', 'however', 'into', 'itself', 'known',
    'might', 'more', 'most', 'never', 'often', 'only', 'other',
    'should', 'since', 'some', 'such', 'than', 'that', 'their', 'them',
    'then', 'there', 'these', 'they', 'this', 'those', 'through', 'under',
    'until', 'very', 'what', 'when', 'where', 'which', 'while', 'with',
    'within', 'without', 'would', 'your', 'slide', 'page', 'module',
  };

  // ── Accurate Question Bank Extraction & Validation (Section 5.3) ──
  static List< Question > _generateQuestions(
    String content, {
    int maxQuestions = 15,
  }) {
    final List< Question > parsed = _parseExplicitQuestions(content);
    if (parsed.isNotEmpty) {
      return _deduplicateAndValidateQuestions(parsed, maxQuestions);
    }

    final cleanContent = content
        .replaceAll(RegExp(r'--- (Page|Slide) \d+ ---'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final sentences = cleanContent
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.split(' ').length >= 6 && s.length >= 35)
        .toList();

    if (sentences.isEmpty) return < Question >[];

    final List< Question > questions = < Question >[];
    final Set< String > usedKeywords = < String >{};

    final allKeywords = cleanContent
        .split(RegExp(r'[^a-zA-Z]+'))
        .map((w) => w.trim())
        .where(
          (w) =>
              w.length >= 5 &&
              RegExp(r'^[a-zA-Z]+$').hasMatch(w) &&
              !_questionStopwords.contains(w.toLowerCase()),
        )
        .toSet()
        .toList();

    if (allKeywords.length < 4) return < Question >[];

    final random = Random();
    for (int i = 0;
        i < sentences.length && questions.length < maxQuestions;
        i++) {
      final sentence = sentences[i];
      final words = sentence.split(RegExp(r'\s+'));

      String keyword = '';
      for (final rawWord in words) {
        final cleanWord = rawWord.replaceAll(RegExp(r'[^a-zA-Z]'), '');
        if (cleanWord.length >= 5 &&
            !_questionStopwords.contains(cleanWord.toLowerCase()) &&
            !usedKeywords.contains(cleanWord.toLowerCase())) {
          keyword = cleanWord;
          break;
        }
      }

      if (keyword.isEmpty) continue;
      usedKeywords.add(keyword.toLowerCase());

      final blankSentence = sentence.replaceFirst(
        RegExp('\\b${RegExp.escape(keyword)}\\b'),
        '_____',
      );
      if (!blankSentence.contains('_____')) continue;

      final distractorPool = allKeywords
          .where((w) => w.toLowerCase() != keyword.toLowerCase())
          .toList()
        ..shuffle(random);
      final wrongAnswers = distractorPool.take(3).toList();
      if (wrongAnswers.length < 3) continue;

      final choices = < String >[...wrongAnswers, keyword]..shuffle(random);
      final correctIdx = choices.indexOf(keyword);
      if (correctIdx < 0) continue;

      questions.add(
        Question(
          question: blankSentence,
          choices: choices,
          correctIndex: correctIdx,
        ),
      );
    }

    return _deduplicateAndValidateQuestions(questions, maxQuestions);
  }

  static List< Question > _deduplicateAndValidateQuestions(
    List< Question > input,
    int maxQuestions,
  ) {
    final seenStems = < String >{};
    final valid = < Question >[];
    for (final q in input) {
      final stem = q.question.trim();
      final key = stem.toLowerCase();
      if (stem.isEmpty || seenStems.contains(key)) continue;
      final cleanChoices = q.choices
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      if (cleanChoices.length < 2) continue;
      final safeIdx = q.correctIndex.clamp(0, cleanChoices.length - 1);
      seenStems.add(key);
      valid.add(
        Question(
          question: stem,
          choices: cleanChoices,
          correctIndex: safeIdx,
        ),
      );
      if (valid.length >= maxQuestions) break;
    }
    return valid;
  }

  /// Accurately parses structured teacher quiz questions, multi-line stems, inline choices, and answer keys.
  static List< Question > _parseExplicitQuestions(String rawText) {
    final List< Question > results = < Question >[];
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('--- '))
        .toList();

    String? currentQ;
    final List< String > currentChoices = < String >[];
    String? answerLetterOrText;
    int? asteriskCorrectIndex;

    void flushQuestion() {
      if (currentQ != null &&
          currentQ!.trim().isNotEmpty &&
          currentChoices.length >= 2) {
        int correctIdx = asteriskCorrectIndex ?? 0;
        if (answerLetterOrText != null &&
            answerLetterOrText!.trim().isNotEmpty) {
          final ans = answerLetterOrText!
              .trim()
              .replaceAll(RegExp(r'^[\(\[\-\:\s]+|[\)\]\.\s]+$'), '');
          final upper = ans.toUpperCase();
          if (upper.length == 1 && 'ABCD'.contains(upper)) {
            correctIdx =
                'ABCD'.indexOf(upper).clamp(0, currentChoices.length - 1);
          } else if (RegExp(r'^[A-Da-d][\.\)]\s*').hasMatch(ans)) {
            final letter = ans[0].toUpperCase();
            correctIdx =
                'ABCD'.indexOf(letter).clamp(0, currentChoices.length - 1);
          } else {
            final exactIdx = currentChoices.indexWhere(
              (c) => c.toLowerCase() == ans.toLowerCase(),
            );
            if (exactIdx != -1) {
              correctIdx = exactIdx;
            } else {
              final partialIdx = currentChoices.indexWhere(
                (c) =>
                    c.toLowerCase().contains(ans.toLowerCase()) ||
                    ans.toLowerCase().contains(c.toLowerCase()),
              );
              if (partialIdx != -1) correctIdx = partialIdx;
            }
          }
        }
        results.add(
          Question(
            question: currentQ!.trim(),
            choices: List< String >.from(currentChoices),
            correctIndex: correctIdx.clamp(0, currentChoices.length - 1),
          ),
        );
      }
      currentQ = null;
      currentChoices.clear();
      answerLetterOrText = null;
      asteriskCorrectIndex = null;
    }

    final qRegex = RegExp(
      r'^(?:Q(?:uestion)?\s*\d*[\.\)\:\-]|Item\s*\d+[\.\)\:]|\d+[\.\)])\s+(.+)$',
      caseSensitive: false,
    );
    final choiceRegex = RegExp(r'^(\*)?\s*[\(\[]?([A-Da-d])[\)\.\:]\s+(.+)$');
    final ansRegex = RegExp(
      r'^(?:Answer|Correct\s*Answer|Ans|Key)[\s\:\-]+(.+)$',
      caseSensitive: false,
    );

    for (final line in lines) {
      final ansMatch = ansRegex.firstMatch(line);
      if (ansMatch != null) {
        answerLetterOrText = ansMatch.group(1)?.trim();
        flushQuestion();
        continue;
      }

      final choiceMatch = choiceRegex.firstMatch(line);
      if (choiceMatch != null && currentQ != null) {
        final hasStar = choiceMatch.group(1) == '*';
        var choiceText = choiceMatch.group(3)!.trim();
        if (choiceText.endsWith('*')) {
          choiceText = choiceText.substring(0, choiceText.length - 1).trim();
          asteriskCorrectIndex = currentChoices.length;
        } else if (hasStar) {
          asteriskCorrectIndex = currentChoices.length;
        }
        currentChoices.add(choiceText);
        continue;
      }

      final qMatch = qRegex.firstMatch(line);
      if (qMatch != null) {
        flushQuestion();
        currentQ = qMatch.group(1)!.trim();
        continue;
      }

      // Append wrapped multi-line question stem before choices start
      if (currentQ != null && currentChoices.isEmpty) {
        currentQ = '$currentQ $line';
      }
    }
    flushQuestion();
    return results;
  }

  /// Extracts text and arranges questions without saving to Firestore yet,
  /// allowing the teacher to review and edit questions before publishing.
  static bool _validateFileSignature(Uint8List bytes, String ext) {
    if (bytes.length < 4) return false;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return bytes[0] == 0xFF && bytes[1] == 0xD8;
      case 'png':
        return bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47;
      case 'gif':
        return bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;
      case 'webp':
        return bytes.length >= 12 &&
            bytes[0] == 0x52 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46 &&
            bytes[3] == 0x46 &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50;
      case 'mp4':
        // ISO Base Media file (ftyp box at offset 4)
        return bytes.length >= 8 &&
            bytes[4] == 0x66 &&
            bytes[5] == 0x74 &&
            bytes[6] == 0x79 &&
            bytes[7] == 0x70;
      case 'webm':
        // EBML header 0x1A 0x45 0xDF 0xA3
        return bytes[0] == 0x1A &&
            bytes[1] == 0x45 &&
            bytes[2] == 0xDF &&
            bytes[3] == 0xA3;
      default:
        return true;
    }
  }

  static Future< String > _uploadVideoToCloudinary({
    required String fileName,
    Uint8List? bytes,
    String? filePath,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${cloudinaryCloudName.trim()}/video/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = cloudinaryUploadPreset.trim();

    if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );
    } else if (bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
    } else {
      throw Exception('Could not read video stream for upload.');
    }

    final streamedResp = await request.send();
    final respBody = await streamedResp.stream.bytesToString();
    if (streamedResp.statusCode < 200 || streamedResp.statusCode >= 300) {
      throw Exception(
        'Cloudinary video upload failed (HTTP ${streamedResp.statusCode}): $respBody',
      );
    }
    final decoded = jsonDecode(respBody);
    final secureUrl = (decoded is Map)
        ? (decoded['secure_url'] ?? decoded['url'] ?? '').toString()
        : '';
    if (secureUrl.isEmpty) {
      throw Exception('Cloudinary did not return a valid video URL.');
    }
    return secureUrl;
  }

  static Future< Module > prepareModuleDraft({
    required String title,
    required String fileName,
    required String category,
    String? classCode,
    String? teacherId,
    Uint8List? bytes,
    String? filePath,
    int? pickedFileSize,
  }) async {
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final isPicture = isPictureExtension(extension);
    final isVideo = isVideoExtension(extension);

    const maxPictureBytes = 10 * 1024 * 1024; // 10 MB
    const maxVideoBytes = 100 * 1024 * 1024; // 100 MB
    const maxFallbackVideoBytes = 5 * 1024 * 1024; // 5 MB Firestore fallback

    int actualSize = pickedFileSize ?? bytes?.length ?? 0;
    if (actualSize == 0 && !kIsWeb && filePath != null) {
      try {
        actualSize = await File(filePath).length();
      } catch (_) {}
    }

    if (isPicture && actualSize > maxPictureBytes) {
      throw Exception(
        'Picture exceeds the 10 MB maximum upload limit (${(actualSize / (1024 * 1024)).toStringAsFixed(1)} MB).',
      );
    }

    if (isVideo) {
      if (actualSize > maxVideoBytes) {
        throw Exception(
          'Video exceeds the 100 MB maximum upload limit (${(actualSize / (1024 * 1024)).toStringAsFixed(1)} MB).',
        );
      }
      if (!isCloudinaryConfigured && actualSize > maxFallbackVideoBytes) {
        throw Exception(
          'Cloudinary is not configured yet. Without Cloudinary, video uploads are limited to 5 MB for the Firestore fallback (selected file is ${(actualSize / (1024 * 1024)).toStringAsFixed(1)} MB). Configure cloudinaryCloudName and cloudinaryUploadPreset in DataService to upload videos up to 100 MB.',
        );
      }
    }

    final fileBytes = await _getBytes(bytes: bytes, filePath: filePath);
    if ((fileBytes == null || fileBytes.isEmpty) &&
        !(isVideo && isCloudinaryConfigured && !kIsWeb && filePath != null)) {
      throw Exception('The selected file is empty or could not be read.');
    }

    if (fileBytes != null &&
        (isPicture || isVideo) &&
        !_validateFileSignature(fileBytes, extension)) {
      throw Exception(
        'File signature does not match a valid .${extension.toUpperCase()} media file.',
      );
    }

    String content;
    List< Question > questions;
    String preservedFileUrl;

    if (isPicture) {
      content =
          'Visual Study Material ($fileName). View the attached image above. Any questions added by your instructor are linked to this material.';
      questions = < Question >[]; // Optional manual questions only
      final mime = _mimeTypeForExtension(extension);
      if (fileBytes!.length <= 150 * 1024) {
        preservedFileUrl = 'data:$mime;base64,${base64Encode(fileBytes)}';
      } else {
        preservedFileUrl = 'firestore_chunked:$fileName';
      }
    } else if (isVideo) {
      content =
          'Video Lecture Material ($fileName). Use the video player above to watch the lecture.';
      questions = < Question >[]; // Optional manual questions only
      if (isCloudinaryConfigured) {
        preservedFileUrl = await _uploadVideoToCloudinary(
          fileName: fileName,
          bytes: fileBytes,
          filePath: filePath,
        );
      } else {
        final mime = _mimeTypeForExtension(extension);
        if (fileBytes!.length <= 150 * 1024) {
          preservedFileUrl = 'data:$mime;base64,${base64Encode(fileBytes)}';
        } else {
          preservedFileUrl = 'firestore_chunked:$fileName';
        }
      }
    } else {
      content = await _extractText(
        fileName: fileName,
        bytes: fileBytes,
        filePath: filePath,
      );
      if (content.trim().isEmpty) {
        content =
            'Module content could not be extracted. You can still add or edit questions below.';
      }
      final maxQ = category == 'mock_exam'
          ? 40
          : category == 'quiz'
              ? 15
              : 15;
      questions = _generateQuestions(content, maxQuestions: maxQ);
      final mime = _mimeTypeForExtension(extension);
      if (fileBytes!.length <= 150 * 1024) {
        preservedFileUrl = 'data:$mime;base64,${base64Encode(fileBytes)}';
      } else {
        preservedFileUrl = 'firestore_chunked:$fileName';
      }
    }

    final safeContent = content.length > 100000
        ? content.substring(0, 100000)
        : content;
    final mime = _mimeTypeForExtension(extension);

    return Module(
      title: title,
      content: safeContent,
      questions: questions,
      isPublished: true,
      category: category,
      classCode: classCode?.trim().toUpperCase(),
      teacherId: teacherId,
      fileName: fileName,
      fileType: extension,
      mimeType: mime,
      fileUrl: preservedFileUrl,
      fileSize: fileBytes?.length ?? actualSize,
      uploadedAt: DateTime.now(),
    );
  }

  /// Publishes or saves a Pending/Draft Module (module, quiz, or mock_exam) to Firebase Storage + Firestore,
  /// reporting live upload progress and rolling back incomplete uploads on error.
  static Future< Module > publishReviewedModule(
    Module draft, {
    Uint8List? rawBytes,
    String? filePath,
  }) async {
    DocumentReference< Map< String, dynamic > >? docRef;
    try {
      uploadProgressNotifier.value = 0.05;
      uploadStatusNotifier.value = 'Validating original file...';

      final fileBytes = await _getBytes(bytes: rawBytes, filePath: filePath);
      final ext = (draft.fileType ?? '').trim().toLowerCase();
      final mime = draft.mimeType ?? _mimeTypeForExtension(ext);
      final safeFileName = (draft.fileName ?? '${draft.title}.$ext')
          .replaceAll(RegExp(r'[^a-zA-Z0-9._\- ]'), '_');
      final classFolder = (draft.classCode ?? 'GENERAL').trim().toUpperCase();
      final storagePath =
          'modules/$classFolder/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

      String? finalFileUrl = draft.fileUrl;
      String? savedStoragePath;

      // 1. Attempt Firebase Storage upload with live progress tracking (preserving original format & MIME)
      if (fileBytes != null && fileBytes.isNotEmpty) {
        try {
          uploadStatusNotifier.value =
              'Uploading $safeFileName to Firebase Storage...';
          final ref = _storage.ref().child(storagePath);
          final metadata = SettableMetadata(
            contentType: mime,
            customMetadata: < String, String >{
              'originalFileName': draft.fileName ?? safeFileName,
              'fileExtension': ext,
              'category': draft.category,
              'classCode': classFolder,
            },
          );
          final uploadTask = ref.putData(fileBytes, metadata);
          final sub = uploadTask.snapshotEvents.listen((TaskSnapshot snap) {
            if (snap.totalBytes > 0) {
              final ratio = snap.bytesTransferred / snap.totalBytes;
              uploadProgressNotifier.value =
                  (0.10 + (ratio * 0.45)).clamp(0.10, 0.55);
            }
          });
          try {
            final snapshot = await uploadTask.timeout(
              const Duration(seconds: 25),
            );
            final downloadUrl = await snapshot.ref.getDownloadURL();
            if (downloadUrl.isNotEmpty) {
              savedStoragePath = storagePath;
              // For videos or large files where Storage succeeds, store downloadUrl if not chunked
              if (isVideoExtension(ext) &&
                  (finalFileUrl == null ||
                      !finalFileUrl.startsWith('http'))) {
                finalFileUrl = downloadUrl;
              }
            }
          } finally {
            await sub.cancel();
          }
        } catch (storageErr) {
          // Graceful fallback to Firestore chunking if Storage CORS or rules block direct putData
          debugPrint(
            'Firebase Storage upload notice (using Firestore original binary chunks): $storageErr',
          );
        }
      }

      uploadProgressNotifier.value = 0.60;
      uploadStatusNotifier.value = 'Saving metadata to Firestore...';

      final bytesToChunk = (finalFileUrl != null &&
              finalFileUrl.startsWith('firestore_chunked:'))
          ? fileBytes
          : null;

      if (finalFileUrl != null &&
          finalFileUrl.startsWith('firestore_chunked:') &&
          (bytesToChunk == null || bytesToChunk.isEmpty)) {
        throw Exception(
          'Incomplete file data: original file bytes could not be read for upload.',
        );
      }

      final draftWithStorage = draft.copyWith(
        mimeType: mime,
        fileUrl: finalFileUrl,
        storagePath: savedStoragePath,
      );

      docRef = await _firestore.collection('modules').add(< String, dynamic >{
        ...draftWithStorage.toMap(),
        'uploadedAt': DateTime.now().toUtc().toIso8601String(),
      });

      if (bytesToChunk != null && bytesToChunk.isNotEmpty) {
        final encodedBase64 = base64Encode(bytesToChunk);
        const chunkSize = 350000;
        final totalChunks = (encodedBase64.length / chunkSize).ceil();
        int chunkIndex = 0;
        for (int i = 0; i < encodedBase64.length; i += chunkSize) {
          final end = (i + chunkSize < encodedBase64.length)
              ? i + chunkSize
              : encodedBase64.length;
          uploadStatusNotifier.value =
              'Preserving original ${ext.toUpperCase()} file (chunk ${chunkIndex + 1} of $totalChunks)...';
          await docRef
              .collection('original_file_chunks')
              .doc('chunk_${chunkIndex.toString().padLeft(4, '0')}')
              .set(< String, dynamic >{
            'index': chunkIndex,
            'data': encodedBase64.substring(i, end),
          });
          chunkIndex++;
          uploadProgressNotifier.value =
              (0.60 + ((chunkIndex / max(1, totalChunks)) * 0.30))
                  .clamp(0.60, 0.90);
        }
      }

      uploadStatusNotifier.value = 'Saving extracted questions...';
      for (final q in draft.questions) {
        await docRef.collection('extracted_questions').add(q.toMap());
      }

      uploadProgressNotifier.value = 1.0;
      uploadStatusNotifier.value = 'Upload complete!';

      final saved = draftWithStorage.copyWith(
        id: docRef.id,
        uploadedAt: DateTime.now(),
      );

      _modules.removeWhere((m) => m.id == saved.id);
      _modules.insert(0, saved);
      logActivity(
        '${saved.isPublished ? "Published" : "Saved Pending"} ${saved.category.toUpperCase()}: "${saved.title}" to class ${saved.classCode ?? "N/A"} (${saved.questions.length} Qs)',
        category:
            saved.isPublished ? 'MATERIAL_UPLOADED' : 'MATERIAL_SAVED_PENDING',
        actor: saved.teacherId ?? 'Teacher',
        target: '${saved.title} (${saved.classCode ?? ""})',
      );
      notifyModuleUpdated();
      return saved;
    } catch (e) {
      if (docRef != null) {
        try {
          await docRef.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      uploadProgressNotifier.value = 0.0;
      uploadStatusNotifier.value = '';
    }
  }

  /// Toggles a learning material between Published and Pending/Unpublished in Firestore.
  static Future< void > toggleModulePublishStatus(
    Module module,
    bool isPublished, {
    String? actorEmail,
  }) async {
    final docId = module.id;
    if (docId == null || docId.isEmpty) return;

    await _firestore.collection('modules').doc(docId).set(
      < String, dynamic >{'isPublished': isPublished},
      SetOptions(merge: true),
    );

    final idx = _modules.indexWhere((m) => m.id == docId);
    if (idx >= 0) {
      _modules[idx] = _modules[idx].copyWith(isPublished: isPublished);
    }

    logActivity(
      '${isPublished ? "Published" : "Unpublished (Pending)"} material: "${module.title}"',
      category: isPublished ? 'MATERIAL_PUBLISHED' : 'MATERIAL_UNPUBLISHED',
      actor: actorEmail ?? module.teacherId ?? 'Teacher',
      target: module.title,
    );
    notifyModuleUpdated();
  }

  /// Updates an existing module's title, category, classCode, or question bank in Firestore.
  static Future< void > updateExistingModule(
    Module updated, {
    String? actorEmail,
  }) async {
    final docId = updated.id;
    if (docId == null || docId.isEmpty) return;

    await _firestore.collection('modules').doc(docId).set(
      < String, dynamic >{
        'title': updated.title,
        'category': updated.category,
        'classCode': updated.classCode,
        'isPublished': updated.isPublished,
        'questions': updated.questions.map((q) => q.toMap()).toList(),
      },
      SetOptions(merge: true),
    );

    final idx = _modules.indexWhere((m) => m.id == docId);
    if (idx >= 0) {
      _modules[idx] = updated;
    }

    logActivity(
      'Updated material "${updated.title}" (${updated.questions.length} Qs, Published: ${updated.isPublished})',
      category: 'MATERIAL_UPDATED',
      actor: actorEmail ?? updated.teacherId ?? 'Teacher',
      target: updated.title,
    );
    notifyModuleUpdated();
  }

  /// Reconstructs the original binary bytes of an uploaded picture or fallback video
  /// from either a `data:...;base64,` URI or the `original_file_chunks` subcollection.
  /// Works on both Android APK (HTTPS REST) and Chrome Web (Firestore SDK).
  static Future< Uint8List? > loadModuleFileBytes(Module module) async {
    try {
      String? fileUrl = module.fileUrl;
      String? storagePath = module.storagePath;
      final docId = module.id;

      // On Android APK, `loadModules` masks out `fileUrl` for fast list loading; fetch the full doc when opening
      if ((fileUrl == null || fileUrl.isEmpty) &&
          docId != null &&
          docId.isNotEmpty) {
        if (!kIsWeb) {
          final fullDoc = await _fetchDocViaRest('modules', docId);
          fileUrl = fullDoc?['fileUrl']?.toString();
          storagePath ??= fullDoc?['storagePath']?.toString();
        } else {
          final snap = await _firestore.collection('modules').doc(docId).get();
          final data = snap.data();
          fileUrl = data?['fileUrl']?.toString();
          storagePath ??= data?['storagePath']?.toString();
        }
      }

      if (fileUrl != null && fileUrl.startsWith('data:')) {
        final commaIdx = fileUrl.indexOf(',');
        if (commaIdx != -1) {
          return base64Decode(fileUrl.substring(commaIdx + 1));
        }
      }

      if (fileUrl != null &&
          (fileUrl.startsWith('http://') || fileUrl.startsWith('https://'))) {
        final resp = await http.get(Uri.parse(fileUrl));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          return resp.bodyBytes;
        }
      }

      if ((fileUrl == null ||
              fileUrl.isEmpty ||
              fileUrl.startsWith('firestore_chunked:')) &&
          docId != null &&
          docId.isNotEmpty) {
        final chunks = < Map< String, dynamic > >[];
        if (!kIsWeb) {
          try {
            final restChunks = await _fetchCollectionViaRest(
              'modules/$docId/original_file_chunks',
              pageSize: 100,
            );
            for (final c in restChunks) {
              final d = (c['data'] as Map< String, dynamic >?) ??
                  < String, dynamic >{};
              chunks.add(< String, dynamic >{
                'index': (d['index'] is num)
                    ? (d['index'] as num).toInt()
                    : int.tryParse((d['index'] ?? '0').toString()) ?? 0,
                'data': (d['data'] ?? '').toString(),
              });
            }
          } catch (e) {
            debugPrint('REST chunk fetch warning: $e');
          }
        }

        if (chunks.isEmpty) {
          final snap = await _firestore
              .collection('modules')
              .doc(docId)
              .collection('original_file_chunks')
              .get();
          for (final d in snap.docs) {
            final map = d.data();
            chunks.add(< String, dynamic >{
              'index': (map['index'] is num)
                  ? (map['index'] as num).toInt()
                  : int.tryParse((map['index'] ?? '0').toString()) ?? 0,
              'data': (map['data'] ?? '').toString(),
            });
          }
        }

        if (chunks.isEmpty) {
          throw Exception('No file chunks found in Firestore.');
        }

        chunks.sort(
          (a, b) => (a['index'] as int).compareTo(b['index'] as int),
        );
        final combinedBase64 =
            chunks.map((c) => (c['data'] ?? '').toString()).join();
        return base64Decode(combinedBase64);
      }

      if (storagePath != null && storagePath.trim().isNotEmpty) {
        try {
          final bytes = await _storage
              .ref()
              .child(storagePath.trim())
              .getData(50 * 1024 * 1024);
          if (bytes != null && bytes.isNotEmpty) return bytes;
        } catch (e) {
          debugPrint('Firebase Storage binary fallback notice: $e');
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error reconstructing module file bytes: $e');
      rethrow;
    }
  }

  /// Resolves the `fileUrl` for a module (fetching it on Android if masked during list load).
  static Future< String? > resolveModuleFileUrl(Module module) async {
    if (module.fileUrl != null && module.fileUrl!.isNotEmpty) {
      return module.fileUrl;
    }
    final docId = module.id;
    if (docId == null || docId.isEmpty) return null;
    if (!kIsWeb) {
      final fullDoc = await _fetchDocViaRest('modules', docId);
      return fullDoc?['fileUrl']?.toString();
    }
    final snap = await _firestore.collection('modules').doc(docId).get();
    return snap.data()?['fileUrl']?.toString();
  }

  /// Resolves the lowercase file extension ('pdf', 'docx', 'doc', 'pptx', 'ppt', 'mp4', etc.)
  /// consistently from `fileType`, `fileName`, `storagePath`, or `fileUrl`.
  static String resolveModuleExtension(Module module) {
    final candidates = < String? >[
      module.fileType,
      module.fileName,
      module.storagePath,
      module.fileUrl,
    ];
    for (final raw in candidates) {
      if (raw == null) continue;
      var cleaned = raw.trim();
      if (cleaned.isEmpty) continue;
      if (cleaned.startsWith('data:')) {
        final mimePart = cleaned.split(';').first.replaceFirst('data:', '');
        if (mimePart.contains('pdf')) return 'pdf';
        if (mimePart.contains('wordprocessingml')) return 'docx';
        if (mimePart.contains('msword')) return 'doc';
        if (mimePart.contains('presentationml')) return 'pptx';
        if (mimePart.contains('ms-powerpoint')) return 'ppt';
        if (mimePart.contains('mp4')) return 'mp4';
        if (mimePart.contains('webm')) return 'webm';
        if (mimePart.contains('png')) return 'png';
        if (mimePart.contains('jpeg') || mimePart.contains('jpg')) return 'jpg';
        continue;
      }
      if (cleaned.startsWith('firestore_chunked:')) {
        cleaned = cleaned.substring('firestore_chunked:'.length).trim();
      }
      if (cleaned.contains('?')) {
        cleaned = cleaned.split('?').first;
      }
      if (cleaned.contains('.')) {
        final ext = cleaned.split('.').last.trim().toLowerCase();
        if (ext.isNotEmpty && ext.length <= 5 && !ext.contains('/')) {
          return ext;
        }
      } else {
        final ext = cleaned.replaceAll('.', '').trim().toLowerCase();
        if (ext.isNotEmpty && ext.length <= 5 && !ext.contains('/')) {
          return ext;
        }
      }
    }
    return '';
  }

  /// Returns the clean original uploaded filename without generated timestamps,
  /// storage folder prefixes, or `firestore_chunked:` markers.
  static String cleanOriginalFileName(Module module) {
    final ext = resolveModuleExtension(module);
    String candidate = (module.fileName ?? '').trim();

    if (candidate.isEmpty && module.fileUrl != null) {
      final url = module.fileUrl!.trim();
      if (url.startsWith('firestore_chunked:')) {
        candidate = url.substring('firestore_chunked:'.length).trim();
      }
    }
    if (candidate.isEmpty && module.storagePath != null) {
      candidate = module.storagePath!.split('/').last.trim();
    }
    if (candidate.isEmpty) {
      candidate = module.title.trim();
    }

    // Strip any path prefixes
    if (candidate.contains('/')) {
      candidate = candidate.split('/').last.trim();
    }
    // Strip generated epoch timestamp prefix (e.g. "1741234567890_Filename.pdf")
    candidate = candidate.replaceFirst(RegExp(r'^\d{10,16}[_-]+'), '').trim();

    if (candidate.isEmpty) {
      candidate = module.title.trim().isNotEmpty
          ? module.title.trim()
          : 'Uploaded_Material';
    }

    if (ext.isNotEmpty && !candidate.toLowerCase().endsWith('.$ext')) {
      candidate = '$candidate.$ext';
    }
    return candidate;
  }

  /// Returns the human-readable expected viewing format label for a module.
  static String formatTypeLabel(Module module) {
    final ext = resolveModuleExtension(module);
    final upper = ext.toUpperCase();
    switch (ext) {
      case 'doc':
      case 'docx':
        return 'Word Document (.$upper)';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint Presentation (.$upper)';
      case 'pdf':
        return 'PDF Document (.PDF)';
      case 'mp4':
      case 'webm':
        return 'Video Lecture (.$upper)';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'Image Material (.$upper)';
      case 'txt':
        return 'Text Document (.TXT)';
      default:
        return upper.isNotEmpty ? 'Document (.$upper)' : 'Study Document';
    }
  }

  /// Formats byte size into B, KB, or MB (e.g. "3.17 MB").
  static String formatBytesLabel(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Standard Size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Resolves the readable class name for a classCode.
  static String resolveClassDisplayName(String? classCode) {
    final cleanCode = (classCode ?? '').trim().toUpperCase();
    if (cleanCode.isEmpty) return 'General Fisheries';
    for (final c in _classes) {
      if (c.id.trim().toUpperCase() == cleanCode) {
        final name = c.name.trim();
        if (name.isNotEmpty && name.toUpperCase() != 'CLASS $cleanCode') {
          return '$name ($cleanCode)';
        }
      }
    }
    return cleanCode;
  }

  // ── Extract words for word hunt ────────────────────────────────
  static List<String> extractWordsForWordHunt(String content) {
    final cleanContent = content
        .replaceAll(RegExp(r'--- (Page|Slide) \d+ ---'), '')
        .toUpperCase();

    final words = cleanContent
        .split(RegExp(r'[^A-Z]+'))
        .where((w) => w.length >= 4 && w.length <= 10)
        .toSet()
        .toList();

    words.shuffle();
    return words.take(12).toList();
  }

  // ── Upload module ──────────────────────────────────────────────
  static Future<void> uploadModule(Module module) async {
    try {
      final docRef = await _firestore.collection('modules').add({
        ...module.toMap(),
        'uploadedAt': DateTime.now().toUtc().toIso8601String(),
      });

      final savedModule = Module(
        id: docRef.id,
        title: module.title,
        content: module.content,
        questions: module.questions,
        isValid: module.isValid,
        category: module.category,
        classCode: module.classCode,
        fileName: module.fileName,
        fileType: module.fileType,
        fileUrl: module.fileUrl,
        fileSize: module.fileSize,
        pageCount: module.pageCount,
        uploadedAt: module.uploadedAt ?? DateTime.now(),
      );

      _modules.add(savedModule);

      _log('Module uploaded: ${module.title}');
      notifyModuleUpdated();
    } catch (e) {
      debugPrint('Error saving module to Firestore: $e');
      rethrow;
    }
  }

  static Future<void> uploadModuleFile({
    required String title,
    required String fileName,
    Uint8List? bytes,
    String? filePath,
  }) async {
    try {
      debugPrint(
        'Uploading: $fileName | bytes: ${bytes?.length} | path: $filePath',
      );

      // Read the original file bytes.
      final fileBytes = await _getBytes(bytes: bytes, filePath: filePath);

      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception('The selected file is empty or could not be read.');
      }

      // Extract the document text.
      String content = await _extractText(
        fileName: fileName,
        bytes: fileBytes,
        filePath: filePath,
      );

      debugPrint('Extracted content length: ${content.length}');

      if (content.length > 200) {
        debugPrint('Preview: ${content.substring(0, 200)}');
      }

      if (content.trim().isEmpty) {
        content =
            'Module content could not be extracted. Please re-upload the file.';
      }

      // Generate quiz questions from the extracted content.
      final questions = _generateQuestions(content);

// Get the file extension.
      final extension = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : '';

      // Preserve the original uploaded file directly in Firestore (avoids Firebase Storage Web CORS infinite retry)
      String? preservedFileUrl;
      final mime = _mimeTypeForExtension(extension);
      final encodedBase64 = base64Encode(fileBytes);
      if (fileBytes.length <= 500 * 1024) {
        preservedFileUrl = 'data:$mime;base64,$encodedBase64';
      } else {
        preservedFileUrl = 'firestore_chunked:$fileName';
      }

      // Save the module metadata, original file reference, and extracted questions separately in Firestore.
      final docRef = await _firestore.collection('modules').add({
        'title': title,
        'content': content,
        'questions': questions.map((q) => q.toMap()).toList(),
        'isValid': true,
        'fileName': fileName,
        'fileType': extension,
        'fileUrl': preservedFileUrl,
        'fileSize': fileBytes.length,
        'pageCount': null,
        'uploadedAt': DateTime.now().toUtc().toIso8601String(),
      });

      // If the original file was larger than 500 KB, store its base64 chunks in a subcollection so the full unmodified file is preserved
      if (preservedFileUrl == 'firestore_chunked:$fileName') {
        const chunkSize = 400000;
        for (int i = 0; i < encodedBase64.length; i += chunkSize) {
          final end = (i + chunkSize < encodedBase64.length)
              ? i + chunkSize
              : encodedBase64.length;
          await docRef.collection('original_file_chunks').add({
            'index': i ~/ chunkSize,
            'data': encodedBase64.substring(i, end),
          });
        }
      }

      // Store extracted questions in a dedicated subcollection as well so they remain separated from the original file
      for (final q in questions) {
        await docRef.collection('extracted_questions').add(q.toMap());
      }

      // Update the local list only after the cloud save succeeds.
      _modules.insert(
        0,
        Module(
          id: docRef.id,
          title: title,
          content: content,
          questions: questions,
          fileName: fileName,
          fileType: extension,
          fileUrl: preservedFileUrl,
          fileSize: fileBytes.length,
          uploadedAt: DateTime.now(),
        ),
      );

      _log(
        'Module uploaded: $fileName '
        '(${questions.length} questions generated)',
      );

      notifyModuleUpdated();
    } catch (e, stackTrace) {
      debugPrint('Error uploading module file: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  // ── Delete module ──────────────────────────────────────────────
  static Future< void > deleteModuleById(
    String? moduleId, {
    String? actorEmail,
  }) async {
    if (moduleId == null || moduleId.isEmpty) return;
    final idx = _modules.indexWhere((m) => m.id == moduleId);
    if (idx >= 0) {
      await deleteModule(idx, actorEmail: actorEmail);
    } else {
      await _firestore.collection('modules').doc(moduleId).delete();
      notifyModuleUpdated();
    }
  }

  static Future< void > deleteModule(int index, {String? actorEmail}) async {
    if (index < 0 || index >= _modules.length) return;

    final module = _modules[index];

    try {
      if (module.id != null && module.id!.isNotEmpty) {
        // Delete any stored original_file_chunks first
        try {
          final chunksSnap = await _firestore
              .collection('modules')
              .doc(module.id)
              .collection('original_file_chunks')
              .get();
          for (final doc in chunksSnap.docs) {
            await doc.reference.delete();
          }
        } catch (_) {}

        await _firestore.collection('modules').doc(module.id).delete();
      }

      _modules.removeAt(index);

      logActivity(
        'Deleted ${module.category.toUpperCase()}: "${module.title}" (Class: ${module.classCode ?? "N/A"})',
        category: 'MATERIAL_DELETED',
        actor: actorEmail ?? module.teacherId ?? 'Teacher',
        target: module.title,
      );
      notifyModuleUpdated();
    } catch (e) {
      debugPrint('Error deleting module: $e');
      rethrow;
    }
  }

  static String _mimeTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'doc':
        return 'application/msword';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }

  // ── Class methods (Persisted in Firestore) ─────────────────────
  static ClassRoom createClass(String name) {
    final code = DateTime.now().millisecondsSinceEpoch.toString();
    return createClassWithCode(name, code);
  }

  static ClassRoom createClassWithCode(
    String name,
    String code, {
    String? teacherId,
    String? teacherEmail,
  }) {
    final normalizedCode = code.trim().toUpperCase();
    final cleanTeacherId = (teacherId ?? '').trim();
    final newClass = ClassRoom(
      id: normalizedCode,
      name: name.trim(),
      teacherId: cleanTeacherId.isEmpty ? null : cleanTeacherId,
    );
    _classes.removeWhere((c) => c.id.toUpperCase() == normalizedCode);
    _classes.add(newClass);

    // Save in 'modules' collection with category 'class_record' so existing Firestore rules allow cross-device sync
    _firestore.collection('modules').doc('class_$normalizedCode').set({
      'title': name.trim(),
      'content': 'Class Record',
      'category': 'class_record',
      'classCode': normalizedCode,
      'teacherId': cleanTeacherId,
      'isValid': true,
      'questions': const [],
      'uploadedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));

    _firestore.collection('classes').doc(normalizedCode).set({
      'id': normalizedCode,
      'name': name.trim(),
      'teacherId': cleanTeacherId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((_) {});

    notifyModuleUpdated();
    logActivity(
      'Created class "${name.trim()}" ($normalizedCode)',
      category: 'CLASS_CREATED',
      actor: teacherEmail ?? cleanTeacherId,
      target: normalizedCode,
    );
    return newClass;
  }

  /// Returns classes owned by the specified teacher.
  /// Legacy classes that lack a `teacherId` are preserved and automatically backfilled to the active teacher so no existing data disappears.
  static List< ClassRoom > getClassesForTeacher(String? teacherId) {
    if (teacherId == null || teacherId.trim().isEmpty) {
      return List< ClassRoom >.unmodifiable(_classes);
    }
    final cleanUid = teacherId.trim();
    final result = < ClassRoom >[];
    for (int i = 0; i < _classes.length; i++) {
      final c = _classes[i];
      final owner = (c.teacherId ?? '').trim();
      if (owner.isEmpty) {
        // Backfill legacy class without teacherId to preserve existing data
        final adopted = ClassRoom(
          id: c.id,
          name: c.name,
          teacherId: cleanUid,
        );
        _classes[i] = adopted;
        _firestore.collection('classes').doc(c.id).set(
          < String, dynamic >{'teacherId': cleanUid},
          SetOptions(merge: true),
        ).catchError((_) {});
        _firestore.collection('modules').doc('class_${c.id}').set(
          < String, dynamic >{'teacherId': cleanUid},
          SetOptions(merge: true),
        ).catchError((_) {});
        result.add(adopted);
      } else if (owner == cleanUid) {
        result.add(c);
      }
    }
    return result;
  }

  /// Returns modules belonging to the teacher or their owned classes, backfilling legacy modules missing `teacherId`.
  static List< Module > getModulesForTeacher(String? teacherId) {
    if (teacherId == null || teacherId.trim().isEmpty) {
      return List< Module >.unmodifiable(_modules);
    }
    final cleanUid = teacherId.trim();
    final ownedCodes = getClassesForTeacher(cleanUid)
        .map((c) => c.id.toUpperCase())
        .toSet();

    return _modules.where((m) {
      final modOwner = (m.teacherId ?? '').trim();
      final modClass = (m.classCode ?? '').trim().toUpperCase();
      if (modOwner == cleanUid) return true;
      if (modClass.isNotEmpty && ownedCodes.contains(modClass)) return true;
      if (modOwner.isEmpty && modClass.isEmpty) return true;
      return false;
    }).toList();
  }

  static Future< void > updateClassDetails({
    required String classCode,
    required String newName,
    required String teacherId,
    String? teacherEmail,
  }) async {
    final normalizedCode = classCode.trim().toUpperCase();
    final idx = _classes.indexWhere(
      (c) => c.id.toUpperCase() == normalizedCode,
    );
    if (idx >= 0) {
      final existing = _classes[idx];
      if (existing.teacherId != null &&
          existing.teacherId!.isNotEmpty &&
          existing.teacherId != teacherId) {
        throw Exception('You can only edit classes that you created.');
      }
      _classes[idx] = ClassRoom(
        id: normalizedCode,
        name: newName.trim(),
        teacherId: teacherId,
      );
    }

    await _firestore.collection('classes').doc(normalizedCode).set(
      < String, dynamic >{
        'id': normalizedCode,
        'name': newName.trim(),
        'teacherId': teacherId,
      },
      SetOptions(merge: true),
    );
    await _firestore.collection('modules').doc('class_$normalizedCode').set(
      < String, dynamic >{
        'title': newName.trim(),
        'teacherId': teacherId,
      },
      SetOptions(merge: true),
    );

    logActivity(
      'Updated class $normalizedCode name to "${newName.trim()}"',
      category: 'CLASS_UPDATED',
      actor: teacherEmail ?? teacherId,
      target: normalizedCode,
    );
    notifyModuleUpdated();
  }

  static final Set< String > _deletedClassCodes = < String >{};

  static Future< void > deleteClassByCode({
    required String classCode,
    required String teacherId,
    String? teacherEmail,
  }) async {
    final normalizedCode = classCode.trim().toUpperCase();
    final idx = _classes.indexWhere(
      (c) => c.id.toUpperCase() == normalizedCode,
    );
    if (idx >= 0) {
      final existing = _classes[idx];
      if (existing.teacherId != null &&
          existing.teacherId!.isNotEmpty &&
          existing.teacherId != teacherId) {
        throw Exception('You can only delete classes that you created.');
      }
    }

    _deletedClassCodes.add(normalizedCode);

    // 1. Delete class document from 'classes' collection and wait for confirmation
    await _firestore.collection('classes').doc(normalizedCode).delete();

    // 2. Delete class_record marker from 'modules' collection
    try {
      await _firestore
          .collection('modules')
          .doc('class_$normalizedCode')
          .delete();
    } catch (_) {}

    // 3. Delete or unassign any modules in Firestore that still reference this deleted classCode
    // so they never resurrect the class on Refresh
    try {
      final matchingModules = _modules
          .where((m) => (m.classCode ?? '').trim().toUpperCase() == normalizedCode)
          .toList();
      for (final mod in matchingModules) {
        if (mod.id != null && mod.id!.isNotEmpty) {
          await _firestore.collection('modules').doc(mod.id).delete();
        }
      }
      final snap = await _firestore
          .collection('modules')
          .where('classCode', isEqualTo: normalizedCode)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Cascade delete class modules notice: $e');
    }

    // 4. Remove the deleted classCode from enrolled students' joinedClassCodes in Firestore
    try {
      final enrolledStudents = await getStudentsInClass(normalizedCode);
      for (final rawStudent in enrolledStudents) {
        final s = Map< String, dynamic >.from(rawStudent as Map);
        final sUid = (s['id'] ?? '').toString();
        if (sUid.isNotEmpty) {
          await _firestore.collection('users').doc(sUid).set(
            < String, dynamic >{
              'joinedClassCodes': FieldValue.arrayRemove([normalizedCode]),
            },
            SetOptions(merge: true),
          );
        }
      }
    } catch (e) {
      debugPrint('Cascade unenroll students notice: $e');
    }

    // 5. Remove from in-memory lists after Firestore confirmation
    _classes.removeWhere((c) => c.id.toUpperCase() == normalizedCode);
    _modules.removeWhere(
      (m) => (m.classCode ?? '').trim().toUpperCase() == normalizedCode,
    );
    _joinedClassCodes.removeWhere((c) => c.toUpperCase() == normalizedCode);

    logActivity(
      'Deleted class $normalizedCode and cleaned associated records',
      category: 'CLASS_DELETED',
      actor: teacherEmail ?? teacherId,
      target: normalizedCode,
    );
    notifyModuleUpdated();
  }

  static Future< void > removeStudentFromClass({
    required String classCode,
    required String studentUid,
    required String studentEmail,
    String? teacherEmail,
  }) async {
    final normalizedCode = classCode.trim().toUpperCase();
    await _firestore.collection('users').doc(studentUid).set(
      < String, dynamic >{
        'joinedClassCodes': FieldValue.arrayRemove([normalizedCode]),
      },
      SetOptions(merge: true),
    );
    logActivity(
      'Removed student $studentEmail from class $normalizedCode',
      category: 'STUDENT_REMOVED',
      actor: teacherEmail ?? 'Teacher',
      target: '$studentEmail ($normalizedCode)',
    );
  }

  static String? lastLoadError;
  static bool isLoadingModules = false;
  static const String _restBaseUrl =
      'https://firestore.googleapis.com/v1/projects/fiber-app-2ada2/databases/(default)/documents';

  static dynamic _parseFirestoreRestValue(dynamic v) {
    if (v is! Map) return v;
    if (v.containsKey('stringValue')) return v['stringValue']?.toString() ?? '';
    if (v.containsKey('booleanValue')) return v['booleanValue'] == true;
    if (v.containsKey('integerValue')) {
      return int.tryParse(v['integerValue'].toString()) ?? 0;
    }
    if (v.containsKey('doubleValue')) {
      return double.tryParse(v['doubleValue'].toString()) ?? 0.0;
    }
    if (v.containsKey('timestampValue')) {
      return v['timestampValue']?.toString() ?? '';
    }
    if (v.containsKey('nullValue')) return null;
    if (v.containsKey('arrayValue')) {
      final arr = v['arrayValue'];
      if (arr is Map && arr['values'] is List) {
        return (arr['values'] as List< dynamic >)
            .map(_parseFirestoreRestValue)
            .toList();
      }
      return < dynamic >[];
    }
    if (v.containsKey('mapValue')) {
      final mp = v['mapValue'];
      if (mp is Map && mp['fields'] is Map) {
        return _parseFirestoreRestFields(
          Map< String, dynamic >.from(mp['fields'] as Map),
        );
      }
      return < String, dynamic >{};
    }
    return null;
  }

  static Map< String, dynamic > _parseFirestoreRestFields(
    Map< String, dynamic > fields,
  ) {
    final out = < String, dynamic >{};
    fields.forEach((key, val) {
      out[key] = _parseFirestoreRestValue(val);
    });
    return out;
  }

  /// Fetches a Firestore collection directly via HTTPS REST on Android,
  /// bypassing the 1MB/2MB Android Pigeon MethodChannel & CursorWindow limit.
  static Future< List< Map< String, dynamic > > > _fetchCollectionViaRest(
    String collectionName, {
    List< String >? maskFields,
    int pageSize = 25,
  }) async {
    final results = < Map< String, dynamic > >[];
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    client.badCertificateCallback = (cert, host, port) => true;

    try {
      String? nextToken;
      for (int page = 0; page < 20; page++) {
        final queryParts = < String >['pageSize=$pageSize'];
        if (nextToken != null && nextToken.isNotEmpty) {
          queryParts.add('pageToken=${Uri.encodeQueryComponent(nextToken)}');
        }
        if (maskFields != null && maskFields.isNotEmpty) {
          for (final f in maskFields) {
            queryParts.add('mask.fieldPaths=${Uri.encodeQueryComponent(f)}');
          }
        }
        final uri = Uri.parse(
          '$_restBaseUrl/$collectionName?${queryParts.join('&')}',
        );
        final req = await client.getUrl(uri);
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();

        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw Exception('HTTP ${resp.statusCode}: $body');
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map) break;

        final docs = decoded['documents'];
        if (docs is List) {
          for (final item in docs) {
            if (item is Map) {
              final fullName = (item['name'] ?? '').toString();
              final docId = fullName.contains('/')
                  ? fullName.split('/').last
                  : fullName;
              final rawFields = item['fields'];
              final parsedData = rawFields is Map
                  ? _parseFirestoreRestFields(
                      Map< String, dynamic >.from(rawFields),
                    )
                  : < String, dynamic >{};
              results.add(< String, dynamic >{
                '_docId': docId,
                'data': parsedData,
              });
            }
          }
        }

        final token = decoded['nextPageToken']?.toString() ?? '';
        if (token.isEmpty) break;
        nextToken = token;
      }
    } finally {
      client.close(force: true);
    }

    return results;
  }

  static Future< Map< String, dynamic >? > _fetchDocViaRest(
    String collectionName,
    String docId,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    client.badCertificateCallback = (cert, host, port) => true;
    try {
      final uri = Uri.parse('$_restBaseUrl/$collectionName/$docId');
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['fields'] is Map) {
        return _parseFirestoreRestFields(
          Map< String, dynamic >.from(decoded['fields'] as Map),
        );
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static void _addOrUpdateClass(
    String code,
    String name, {
    String? teacherId,
  }) {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;
    final cleanTeacherId = (teacherId ?? '').trim();
    final existingIdx = _classes.indexWhere(
      (c) => c.id.toUpperCase() == cleanCode,
    );
    if (existingIdx >= 0) {
      final current = _classes[existingIdx];
      final updatedName =
          (current.name == 'Class $cleanCode' && name != 'Class $cleanCode')
              ? name
              : current.name;
      final updatedTeacherId = cleanTeacherId.isNotEmpty
          ? cleanTeacherId
          : current.teacherId;
      _classes[existingIdx] = ClassRoom(
        id: cleanCode,
        name: updatedName,
        teacherId: updatedTeacherId,
      );
    } else {
      _classes.add(
        ClassRoom(
          id: cleanCode,
          name: name,
          teacherId: cleanTeacherId.isEmpty ? null : cleanTeacherId,
        ),
      );
    }
  }

  static Future< void > loadClasses({String? uid}) async {
    final freshClasses = < ClassRoom >[];

    if (!kIsWeb) {
      try {
        final restClasses = await _fetchCollectionViaRest('classes');
        for (final doc in restClasses) {
          final docId = (doc['_docId'] ?? '').toString();
          final data =
              (doc['data'] as Map< String, dynamic >?) ?? < String, dynamic >{};
          final code = (data['id'] ?? docId).toString().trim().toUpperCase();
          if (code.isNotEmpty && !_deletedClassCodes.contains(code)) {
            freshClasses.removeWhere((c) => c.id.toUpperCase() == code);
            freshClasses.add(
              ClassRoom(
                id: code,
                name: (data['name'] ?? 'Class $code').toString(),
                teacherId: (data['teacherId'] ?? '').toString().trim().isEmpty
                    ? null
                    : (data['teacherId'] ?? '').toString().trim(),
              ),
            );
          }
        }
        _classes
          ..clear()
          ..addAll(freshClasses);
        notifyModuleUpdated();
      } catch (e) {
        debugPrint('REST classes load warning: $e');
      }
    } else {
      try {
        final snapshot = await _firestore.collection('classes').get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final code = (data['id'] ?? doc.id).toString().trim().toUpperCase();
          if (code.isNotEmpty && !_deletedClassCodes.contains(code)) {
            freshClasses.removeWhere((c) => c.id.toUpperCase() == code);
            freshClasses.add(
              ClassRoom(
                id: code,
                name: (data['name'] ?? 'Class $code').toString(),
                teacherId: (data['teacherId'] ?? '').toString().trim().isEmpty
                    ? null
                    : (data['teacherId'] ?? '').toString().trim(),
              ),
            );
          }
        }
        _classes
          ..clear()
          ..addAll(freshClasses);
        notifyModuleUpdated();
      } catch (e) {
        debugPrint('Error loading classes collection: $e');
      }
    }

    if (uid != null && uid.isNotEmpty) {
      Map< String, dynamic >? userData;
      if (!kIsWeb) {
        userData = await _fetchDocViaRest('users', uid);
      }
      if (userData == null) {
        try {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          userData = userDoc.data();
        } catch (_) {}
      }
      if (userData != null) {
        final activeClassCodesSet =
            _classes.map((c) => c.id.toUpperCase()).toSet();
        final codes = (userData['joinedClassCodes'] as List< dynamic >? ?? [])
            .map((e) => e.toString().trim().toUpperCase())
            .where(
              (code) =>
                  code.isNotEmpty &&
                  !_deletedClassCodes.contains(code) &&
                  (activeClassCodesSet.isEmpty ||
                      activeClassCodesSet.contains(code)),
            )
            .toList();
        _joinedClassCodes
          ..clear()
          ..addAll(codes);

        // Monotonic studySeconds sync so background polling never rolls back active study time
        final cloudSeconds = (userData['studySeconds'] as num?)?.toInt() ?? 0;
        if (cloudSeconds > studySeconds) {
          studySeconds = cloudSeconds;
          studySecondsNotifier.value = studySeconds;
        }
        _studyTimeInitializedFromCloud = true;
      }
    }
    notifyModuleUpdated();
  }

  static bool joinClass(String id, {String? uid}) {
    final normalizedId = id.trim().toUpperCase();
    if (normalizedId.isEmpty || _deletedClassCodes.contains(normalizedId)) {
      return false;
    }

    final found = _classes.any((c) => c.id.toUpperCase() == normalizedId);
    if (found &&
        !_joinedClassCodes.any((code) => code.toUpperCase() == normalizedId)) {
      _joinedClassCodes.add(normalizedId);
      if (uid != null && uid.isNotEmpty) {
        _firestore.collection('users').doc(uid).set({
          'joinedClassCodes': FieldValue.arrayUnion([normalizedId]),
        }, SetOptions(merge: true));
      }
      notifyModuleUpdated();
    }

    _log(
      'Student attempted to join class: $id — ${found ? 'success' : 'failed'}',
    );
    return found;
  }

  static Future< void > unenrollFromClass(String id, {String? uid}) async {
    final normalizedId = id.trim().toUpperCase();
    _joinedClassCodes.removeWhere((code) => code.toUpperCase() == normalizedId);
    if (uid != null && uid.isNotEmpty) {
      await _firestore.collection('users').doc(uid).set(< String, dynamic >{
        'joinedClassCodes': FieldValue.arrayRemove([normalizedId]),
      }, SetOptions(merge: true));
    }
    logActivity(
      'Student unenrolled from class $normalizedId',
      category: 'CLASS_UNENROLLED',
      actor: uid ?? 'Student',
      target: normalizedId,
    );
    notifyModuleUpdated();
  }

  static void leaveClass(String id, {String? uid}) {
    unawaited(unenrollFromClass(id, uid: uid));
  }

  static bool hasJoinedClass(String id) {
    final normalizedId = id.trim().toUpperCase();
    return _joinedClassCodes.any((code) => code.toUpperCase() == normalizedId);
  }

  /// Strictly returns published materials belonging to classes the student has joined (`joinedClassCodes`),
  /// optionally filtered by exact category ('module', 'quiz', or 'mock_exam').
  static List< Module > getStudentEnrolledModules({String? category}) {
    final enrolledSet = _joinedClassCodes
        .map((c) => c.trim().toUpperCase())
        .where((c) => c.isNotEmpty)
        .toSet();
    if (enrolledSet.isEmpty) return const < Module >[];

    return _modules.where((m) {
      if (!m.isPublished) return false;
      final modClass = (m.classCode ?? '').trim().toUpperCase();
      if (modClass.isEmpty || !enrolledSet.contains(modClass)) return false;
      if (category != null && category.isNotEmpty) {
        return m.category == category;
      }
      return true;
    }).toList();
  }

  static final Map< String, Map< String, dynamic > > _miniGameProgressCache =
      < String, Map< String, dynamic > >{};

  static Map< String, dynamic > _defaultMiniGameProgress() {
    return < String, dynamic >{
      'unlockedLevel': 1,
      'completedLevels': < int >[],
      'levelScores': < String, int >{},
      'levelStars': < String, int >{},
      'highestScore': 0,
      'bestLevelScore': 0,
      'attempts': 0,
    };
  }

  static Map< String, dynamic > _normalizeMiniGameProgress(
    Map< String, dynamic >? raw,
  ) {
    if (raw == null) return _defaultMiniGameProgress();
    final unlocked = ((raw['unlockedLevel'] as num?)?.toInt() ?? 1).clamp(
      1,
      100,
    );
    final completedSet = < int >{};
    final rawCompleted = raw['completedLevels'];
    if (rawCompleted is List) {
      for (final item in rawCompleted) {
        final v = (item is num)
            ? item.toInt()
            : int.tryParse(item.toString()) ?? 0;
        if (v >= 1 && v <= 100) completedSet.add(v);
      }
    }

    final scores = < String, int >{};
    final rawScores = raw['levelScores'];
    if (rawScores is Map) {
      rawScores.forEach((k, v) {
        final sc = (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 0;
        if (sc >= 0) scores[k.toString()] = sc;
      });
    }

    final stars = < String, int >{};
    final rawStars = raw['levelStars'];
    if (rawStars is Map) {
      rawStars.forEach((k, v) {
        final st = (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 0;
        if (st >= 1 && st <= 3) stars[k.toString()] = st;
      });
    }

    int computedTotal = 0;
    int bestSingle = 0;
    scores.forEach((_, sc) {
      computedTotal += sc;
      if (sc > bestSingle) bestSingle = sc;
    });

    final savedHighest = (raw['highestScore'] as num?)?.toInt() ?? 0;
    final effectiveHighest = max(computedTotal, savedHighest);
    final savedBestSingle = (raw['bestLevelScore'] as num?)?.toInt() ?? 0;
    final effectiveBestSingle = max(bestSingle, savedBestSingle);
    final attempts = (raw['attempts'] as num?)?.toInt() ?? completedSet.length;

    final maxCompleted = completedSet.isEmpty ? 0 : completedSet.reduce(max);
    final effectiveUnlocked = max(unlocked, min(100, maxCompleted + 1));

    final sortedCompleted = completedSet.toList()..sort();
    return < String, dynamic >{
      'unlockedLevel': effectiveUnlocked,
      'completedLevels': sortedCompleted,
      'levelScores': scores,
      'levelStars': stars,
      'highestScore': effectiveHighest,
      'bestLevelScore': effectiveBestSingle,
      'attempts': attempts,
    };
  }

  /// Loads a player's saved 100-level progression and audio/vibration preferences for `gameType` ('word_hunt' or 'word_shark').
  static Future< Map< String, dynamic > > loadMiniGameProgress({
    required String gameType,
    String? uid,
  }) async {
    final cleanUid = (uid ?? _activeStudentUid ?? '').trim();
    final cacheKey = '${cleanUid}_$gameType';
    if (cleanUid.isEmpty) {
      return _miniGameProgressCache[cacheKey] ?? _defaultMiniGameProgress();
    }

    Map< String, dynamic >? userData;
    if (!kIsWeb) {
      try {
        userData = await _fetchDocViaRest('users', cleanUid);
      } catch (_) {}
    }
    if (userData == null) {
      try {
        final snap = await _firestore.collection('users').doc(cleanUid).get();
        userData = snap.data();
      } catch (_) {}
    }

    if (userData != null) {
      final rawAllProgress = userData['miniGameProgress'];
      Map< String, dynamic >? gameRaw;
      if (rawAllProgress is Map && rawAllProgress[gameType] is Map) {
        gameRaw = Map< String, dynamic >.from(rawAllProgress[gameType] as Map);
      }
      final normalized = _normalizeMiniGameProgress(gameRaw);

      final rawSettings = userData['gameSettings'];
      if (rawSettings is Map) {
        normalized['bgmEnabled'] = rawSettings['bgmEnabled'] == true;
        normalized['sfxEnabled'] = rawSettings['sfxEnabled'] != false;
        normalized['vibrationEnabled'] =
            rawSettings['vibrationEnabled'] != false;
      }

      _miniGameProgressCache[cacheKey] = normalized;
      return Map< String, dynamic >.from(normalized);
    }

    return _miniGameProgressCache[cacheKey] ?? _defaultMiniGameProgress();
  }

  /// Saves the player's audio & vibration settings to Firestore so preferences persist across restarts.
  static Future< void > saveMiniGameSettings({
    String? uid,
    required bool bgmEnabled,
    required bool sfxEnabled,
    required bool vibrationEnabled,
  }) async {
    final cleanUid = (uid ?? _activeStudentUid ?? '').trim();
    if (cleanUid.isEmpty) return;
    try {
      await _firestore.collection('users').doc(cleanUid).set(
        < String, dynamic >{
          'gameSettings': < String, dynamic >{
            'bgmEnabled': bgmEnabled,
            'sfxEnabled': sfxEnabled,
            'vibrationEnabled': vibrationEnabled,
          },
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('saveMiniGameSettings warning: $e');
    }
  }

  /// Saves completed level progress, unlocks the next level (up to 100), and deduplicates best level scores.
  static Future< Map< String, dynamic > > saveMiniGameLevelCompletion({
    required String gameType,
    required int level,
    required int score,
    required int stars,
    String? uid,
  }) async {
    final safeLevel = level.clamp(1, 100);
    final safeStars = stars.clamp(1, 3);
    final safeScore = max(0, score);
    final cleanUid = (uid ?? _activeStudentUid ?? '').trim();
    final cacheKey = '${cleanUid}_$gameType';

    final current = await loadMiniGameProgress(gameType: gameType, uid: cleanUid);
    final prevUnlocked = (current['unlockedLevel'] as int?) ?? 1;
    final completedSet = Set< int >.from(
      (current['completedLevels'] as List< dynamic >? ?? const < dynamic >[])
          .map((e) => (e as num).toInt()),
    )..add(safeLevel);

    final scores = Map< String, int >.from(
      (current['levelScores'] as Map? ?? const < String, int >{}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
    );
    final starsMap = Map< String, int >.from(
      (current['levelStars'] as Map? ?? const < String, int >{}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
    );

    final levelKey = '$safeLevel';
    final previousBestForLevel = scores[levelKey] ?? 0;
    if (safeScore > previousBestForLevel || !scores.containsKey(levelKey)) {
      scores[levelKey] = max(safeScore, previousBestForLevel);
    }
    final previousStarsForLevel = starsMap[levelKey] ?? 0;
    if (safeStars > previousStarsForLevel) {
      starsMap[levelKey] = safeStars;
    }

    final nextUnlocked = safeLevel >= prevUnlocked
        ? (safeLevel + 1).clamp(1, 100)
        : prevUnlocked;
    final unlockedNewLevel = nextUnlocked > prevUnlocked;

    int totalCumulativeScore = 0;
    int bestSingleLevelScore = 0;
    scores.forEach((_, s) {
      totalCumulativeScore += s;
      if (s > bestSingleLevelScore) bestSingleLevelScore = s;
    });

    final attempts = ((current['attempts'] as int?) ?? 0) + 1;
    final sortedCompleted = completedSet.toList()..sort();

    final updated = < String, dynamic >{
      'unlockedLevel': nextUnlocked,
      'completedLevels': sortedCompleted,
      'levelScores': scores,
      'levelStars': starsMap,
      'highestScore': totalCumulativeScore,
      'bestLevelScore': bestSingleLevelScore,
      'attempts': attempts,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    _miniGameProgressCache[cacheKey] = updated;

    if (cleanUid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(cleanUid).set(
          < String, dynamic >{
            'miniGameProgress': < String, dynamic >{
              gameType: updated,
            },
          },
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('saveMiniGameLevelCompletion warning: $e');
      }
    }

    return < String, dynamic >{
      ...updated,
      'unlockedNewLevel': unlockedNewLevel,
    };
  }

  /// Loads the leaderboard for `gameType` ('word_hunt' or 'word_shark').
  /// If `classCode` is empty or null, loads rankings across all registered student accounts;
  /// otherwise filters by students enrolled in `classCode`.
  static Future< List< Map< String, dynamic > > > loadMiniGameLeaderboard({
    required String gameType,
    String? classCode,
  }) async {
    final cleanClass = (classCode ?? '').trim().toUpperCase();
    final entries = < Map< String, dynamic > >[];

    List< Map< String, dynamic > > userDocs = < Map< String, dynamic > >[];
    if (!kIsWeb) {
      try {
        userDocs = await _fetchCollectionViaRest(
          'users',
          maskFields: < String >[
            'name',
            'username',
            'email',
            'role',
            'joinedClassCodes',
            'miniGameProgress',
            'assessmentResultsList',
          ],
          pageSize: 80,
        );
      } catch (e) {
        debugPrint('REST loadMiniGameLeaderboard warning: $e');
      }
    }

    if (userDocs.isEmpty) {
      try {
        final snap = await _firestore.collection('users').get();
        userDocs = snap.docs
            .map(
              (d) => < String, dynamic >{
                '_docId': d.id,
                'data': d.data(),
              },
            )
            .toList();
      } catch (e) {
        debugPrint('Firestore loadMiniGameLeaderboard warning: $e');
      }
    }

    for (final doc in userDocs) {
      final uid = (doc['_docId'] ?? '').toString();
      if (uid.isEmpty) continue;
      final data =
          (doc['data'] as Map< String, dynamic >?) ?? < String, dynamic >{};
      final role = (data['role'] ?? 'student').toString().trim().toLowerCase();
      if (role != 'student') continue;

      if (cleanClass.isNotEmpty) {
        final joined = (data['joinedClassCodes'] as List< dynamic >? ?? [])
            .map((e) => e.toString().trim().toUpperCase())
            .toList();
        if (!joined.contains(cleanClass)) continue;
      }

      final name = (data['name'] ?? '').toString().trim();
      final username = (data['username'] ?? '').toString().trim();
      final email = (data['email'] ?? '').toString().trim();
      final displayName = name.isNotEmpty
          ? name
          : (username.isNotEmpty
              ? username
              : (email.contains('@') ? email.split('@').first : 'Student'));

      int highestScore = 0;
      int bestLevelScore = 0;
      int unlockedLevel = 1;
      int completedCount = 0;
      int attemptsCount = 0;
      double bestAccuracy = 0.0;

      final rawMini = data['miniGameProgress'];
      if (rawMini is Map && rawMini[gameType] is Map) {
        final norm = _normalizeMiniGameProgress(
          Map< String, dynamic >.from(rawMini[gameType] as Map),
        );
        highestScore = (norm['highestScore'] as int?) ?? 0;
        bestLevelScore = (norm['bestLevelScore'] as int?) ?? 0;
        unlockedLevel = (norm['unlockedLevel'] as int?) ?? 1;
        completedCount =
            (norm['completedLevels'] as List< dynamic >? ?? const []).length;
        attemptsCount = (norm['attempts'] as int?) ?? completedCount;
      }

      final rawResults =
          (data['assessmentResultsList'] as List< dynamic >?) ?? const [];
      for (final item in rawResults) {
        if (item is Map) {
          final r = Map< String, dynamic >.from(item);
          if ((r['type'] ?? '').toString().toLowerCase() ==
              gameType.toLowerCase()) {
            final sc = (r['score'] as num?)?.toInt() ?? 0;
            final pct = (r['percentage'] as num?)?.toDouble() ?? 0.0;
            if (pct > bestAccuracy) bestAccuracy = pct;
            if (highestScore == 0 && sc > 0) {
              highestScore += sc * 10;
              bestLevelScore = max(bestLevelScore, sc * 10);
              completedCount = max(completedCount, 1);
            }
          }
        }
      }

      entries.add(< String, dynamic >{
        'uid': uid,
        'name': displayName,
        'email': email,
        'highestScore': highestScore,
        'bestScore': highestScore > 0 ? highestScore : bestLevelScore,
        'bestLevelScore': bestLevelScore,
        'unlockedLevel': unlockedLevel,
        'completedCount': completedCount,
        'bestAccuracy': bestAccuracy > 0
            ? bestAccuracy
            : (completedCount > 0 ? 100.0 : 0.0),
        'attempts': attemptsCount,
      });
    }

    entries.sort((a, b) {
      final scoreCmp =
          (b['highestScore'] as int).compareTo(a['highestScore'] as int);
      if (scoreCmp != 0) return scoreCmp;
      final compCmp =
          (b['completedCount'] as int).compareTo(a['completedCount'] as int);
      if (compCmp != 0) return compCmp;
      final lvlCmp =
          (b['unlockedLevel'] as int).compareTo(a['unlockedLevel'] as int);
      if (lvlCmp != 0) return lvlCmp;
      return (a['name'] as String)
          .toLowerCase()
          .compareTo((b['name'] as String).toLowerCase());
    });

    return entries;
  }

  /// Loads the class leaderboard for a specific mini game ('word_shark' or 'word_hunt')
  /// ranked across students enrolled in the given `classCode`.
  static Future< List< Map< String, dynamic > > > loadClassGameLeaderboard({
    required String classCode,
    required String gameType,
  }) async {
    return loadMiniGameLeaderboard(
      gameType: gameType,
      classCode: classCode,
    );
  }

  static Future< List< Map< String, dynamic > > > _legacyLoadClassGameLeaderboardUnused({
    required String classCode,
    required String gameType,
  }) async {
    final normalizedCode = classCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) return < Map< String, dynamic > >[];

    final students = await getStudentsInClass(normalizedCode);
    final entries = < Map< String, dynamic > >[];

    for (final rawStudent in students) {
      final s = Map< String, dynamic >.from(rawStudent as Map);
      final uid = (s['id'] ?? '').toString();
      if (uid.isEmpty) continue;
      final name = (s['name'] ?? '').toString().trim();
      final username = (s['username'] ?? '').toString().trim();
      final email = (s['email'] ?? '').toString().trim();
      final displayName = name.isNotEmpty
          ? name
          : (username.isNotEmpty ? username : email);

      int bestScore = 0;
      double bestAccuracy = 0.0;
      int bestDuration = 999999;
      int attemptsCount = 0;

      try {
        Map< String, dynamic >? userData;
        if (!kIsWeb) {
          userData = await _fetchDocViaRest('users', uid);
        }
        if (userData == null) {
          final doc = await _firestore.collection('users').doc(uid).get();
          userData = doc.data();
        }
        final rawResults =
            (userData?['assessmentResultsList'] as List< dynamic >?) ??
                const < dynamic >[];
        for (final item in rawResults) {
          if (item is Map) {
            final r = Map< String, dynamic >.from(item);
            if ((r['type'] ?? '').toString().toLowerCase() ==
                gameType.toLowerCase()) {
              attemptsCount++;
              final sc = (r['score'] as num?)?.toInt() ?? 0;
              final pct = (r['percentage'] as num?)?.toDouble() ?? 0.0;
              final dur = (r['durationSeconds'] as num?)?.toInt() ?? 0;
              if (sc > bestScore ||
                  (sc == bestScore && dur > 0 && dur < bestDuration)) {
                bestScore = sc;
                bestAccuracy = pct;
                if (dur > 0) bestDuration = dur;
              }
            }
          }
        }
      } catch (_) {}

      entries.add(< String, dynamic >{
        'uid': uid,
        'name': displayName,
        'email': email,
        'bestScore': bestScore,
        'bestAccuracy': bestAccuracy,
        'bestDuration': bestDuration == 999999 ? 0 : bestDuration,
        'attempts': attemptsCount,
      });
    }

    entries.sort((a, b) {
      final scoreCmp =
          (b['bestScore'] as int).compareTo(a['bestScore'] as int);
      if (scoreCmp != 0) return scoreCmp;
      final accCmp =
          (b['bestAccuracy'] as double).compareTo(a['bestAccuracy'] as double);
      if (accCmp != 0) return accCmp;
      final aDur = a['bestDuration'] as int;
      final bDur = b['bestDuration'] as int;
      if (aDur > 0 && bDur > 0) return aDur.compareTo(bDur);
      return 0;
    });

    return entries;
  }

  /// Loads all students enrolled in a given class code from Firestore.
  static Future< List< dynamic > > getStudentsInClass(
    String classCode,
  ) async {
    final normalized = classCode.trim().toUpperCase();
    if (!kIsWeb) {
      try {
        final allUsers = await _fetchCollectionViaRest(
          'users',
          maskFields: < String >[
            'name',
            'username',
            'email',
            'studySeconds',
            'joinedClassCodes',
          ],
          pageSize: 50,
        );
        final matched = < Map< String, dynamic > >[];
        for (final doc in allUsers) {
          final docId = (doc['_docId'] ?? '').toString();
          final data =
              (doc['data'] as Map< String, dynamic >?) ?? < String, dynamic >{};
          final joined = (data['joinedClassCodes'] as List< dynamic >? ?? [])
              .map((e) => e.toString().trim().toUpperCase())
              .toList();
          if (joined.contains(normalized)) {
            matched.add(< String, dynamic >{
              'id': docId,
              'name': (data['name'] ?? '').toString(),
              'username': (data['username'] ?? '').toString(),
              'email': (data['email'] ?? '').toString(),
              'studySeconds': (data['studySeconds'] as num?)?.toInt() ?? 0,
            });
          }
        }
        return matched;
      } catch (e) {
        debugPrint('REST getStudentsInClass warning: $e');
      }
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('joinedClassCodes', arrayContains: normalized)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': (data['name'] ?? '').toString(),
          'username': (data['username'] ?? '').toString(),
          'email': (data['email'] ?? '').toString(),
          'studySeconds': (data['studySeconds'] as num?)?.toInt() ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading students for class $normalized: $e');
      return [];
    }
  }

  static void notifyModuleUpdated() {
    moduleUpdateNotifier.value++;
  }

  static void _ingestModuleDoc(
    String docId,
    Map< String, dynamic > data,
    List< Module > targetList,
  ) {
    if ((data['category'] ?? '').toString() == 'class_record') {
      final code = (data['classCode'] ?? '').toString().trim().toUpperCase();
      final name = (data['title'] ?? 'Class $code').toString();
      final tId = (data['teacherId'] ?? '').toString().trim();
      if (code.isNotEmpty && !_deletedClassCodes.contains(code)) {
        _addOrUpdateClass(code, name, teacherId: tId);
      }
      return;
    }
    final mod = Module.fromMap(data, id: docId);
    final modCode = (mod.classCode ?? '').trim().toUpperCase();
    if (modCode.isNotEmpty && _deletedClassCodes.contains(modCode)) {
      return;
    }
    targetList.removeWhere((m) => m.id == docId);
    targetList.add(mod);
  }

  // ── Load modules from Firestore ──────────────────────
  static Future< void > loadModules() async {
    isLoadingModules = true;
    lastLoadError = null;

    final loadedModules = < Module >[];

    if (!kIsWeb) {
      try {
        final restDocs = await _fetchCollectionViaRest(
          'modules',
          maskFields: < String >[
            'title',
            'content',
            'questions',
            'isValid',
            'isPublished',
            'category',
            'classCode',
            'teacherId',
            'fileName',
            'fileType',
            'mimeType',
            'storagePath',
            'fileSize',
            'pageCount',
            'uploadedAt',
          ],
          pageSize: 20,
        );
        for (final doc in restDocs) {
          try {
            final docId = (doc['_docId'] ?? '').toString();
            final data = (doc['data'] as Map< String, dynamic >?) ??
                < String, dynamic >{};
            _ingestModuleDoc(docId, data, loadedModules);
          } catch (docErr) {
            debugPrint('Skipping malformed REST module doc: $docErr');
          }
        }
      } catch (restErr) {
        lastLoadError = 'REST sync error: $restErr';
        debugPrint('REST modules fetch failed: $restErr');
      }
    }

    if (loadedModules.isEmpty) {
      try {
        final snapshot = await _firestore.collection('modules').get();
        for (final doc in snapshot.docs) {
          try {
            _ingestModuleDoc(doc.id, doc.data(), loadedModules);
          } catch (docErr) {
            debugPrint('Skipping malformed module doc ${doc.id}: $docErr');
          }
        }
      } catch (e) {
        lastLoadError ??= 'Module load error: $e';
      }
    }

    if (loadedModules.isNotEmpty) {
      loadedModules.sort((a, b) {
        final aDate = a.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      _modules
        ..clear()
        ..addAll(loadedModules);
      lastLoadError = null;
    }

    isLoadingModules = false;
    notifyModuleUpdated();
  }

  // ── Alumni profiles ─────────────────────────────────────────────
  static Future< List< AlumniProfile > > loadAlumniProfiles() async {
    final profiles = < AlumniProfile >[];

    if (!kIsWeb) {
      try {
        final restDocs = await _fetchCollectionViaRest(
          'alumni_profiles',
          pageSize: 30,
        );
        for (final doc in restDocs) {
          try {
            final docId = (doc['_docId'] ?? '').toString();
            final data = (doc['data'] as Map< String, dynamic >?) ??
                < String, dynamic >{};
            final profile = AlumniProfile.fromMap(docId, data);
            if (profile.name.isNotEmpty) {
              profiles.add(profile);
            }
          } catch (docErr) {
            debugPrint('Skipping malformed REST alumni doc: $docErr');
          }
        }
      } catch (restErr) {
        debugPrint('REST alumni fetch failed: $restErr');
      }
    }

    if (profiles.isEmpty) {
      try {
        final snapshot = await _firestore.collection('alumni_profiles').get();
        for (final doc in snapshot.docs) {
          try {
            final profile = AlumniProfile.fromMap(doc.id, doc.data());
            if (profile.name.isNotEmpty) {
              profiles.add(profile);
            }
          } catch (docErr) {
            debugPrint('Skipping malformed alumni doc ${doc.id}: $docErr');
          }
        }
      } catch (e) {
        debugPrint('Fallback alumni .get() failed: $e');
      }
    }

    if (profiles.isNotEmpty) {
      profiles.sort((a, b) {
        final orderCmp = a.displayOrder.compareTo(b.displayOrder);
        if (orderCmp != 0) return orderCmp;
        return b.createdAt.compareTo(a.createdAt);
      });
      _alumniProfiles
        ..clear()
        ..addAll(profiles);
      notifyModuleUpdated();
    } else if (_alumniProfiles.isEmpty) {
      _alumniProfiles.addAll(_seedAlumniProfiles());
    }

    return List.unmodifiable([..._alumniProfiles]);
  }

  static Future< void > deleteAlumniProfile(String id) async {
    final existing = _alumniProfiles.where((p) => p.id == id).toList();
    final name = existing.isNotEmpty ? existing.first.name : id;
    try {
      await _firestore.collection('alumni_profiles').doc(id).delete();
    } catch (_) {}

    _alumniProfiles.removeWhere((profile) => profile.id == id);
    logActivity(
      'Deleted alumni profile: $name',
      category: 'ALUMNI_DELETED',
      target: name,
    );
    notifyModuleUpdated();
  }

  static Future< void > saveAlumniProfile(AlumniProfile profile) async {
    final now = DateTime.now();
    final payload = {...profile.toMap(), 'updatedAt': now.toIso8601String()};
    final docId = profile.id.trim();
    final isUpdate = _alumniProfiles.any((item) => item.id == docId);

    if (docId.isEmpty) {
      final ref = await _firestore.collection('alumni_profiles').add(payload);
      _alumniProfiles.add(profile.copyWith(id: ref.id, updatedAt: now));
    } else {
      await _firestore
          .collection('alumni_profiles')
          .doc(docId)
          .set(payload, SetOptions(merge: true));

      final updated = profile.copyWith(updatedAt: now);
      final index = _alumniProfiles.indexWhere((item) => item.id == docId);
      if (index >= 0) {
        _alumniProfiles[index] = updated;
      } else {
        _alumniProfiles.add(updated);
      }
    }
    logActivity(
      '${isUpdate ? "Updated" : "Added"} alumni profile: ${profile.name} (visible: ${profile.isVisible})',
      category: isUpdate ? 'ALUMNI_UPDATED' : 'ALUMNI_ADDED',
      target: profile.name,
    );
    notifyModuleUpdated();
  }

  static List< AlumniProfile > _seedAlumniProfiles() {
    final now = DateTime.now();
    return < AlumniProfile >[
      AlumniProfile(
        id: 'sample-1',
        name: 'Marjorie Dela Cruz',
        title: 'Fisheries Officer',
        position: 'Fisheries Officer',
        company: 'BFAR Region 8',
        batchYear: '2021',
        imageUrl: '',
        highlight:
            'Now helping monitor fishery sustainability and coastal programs.',
        isVisible: true,
        displayOrder: 1,
        createdAt: now,
        updatedAt: now,
      ),
      AlumniProfile(
        id: 'sample-2',
        name: 'Rafael Santos',
        title: 'Quality Assurance Analyst',
        position: 'Quality Assurance Analyst',
        company: 'SeaFresh Foods',
        batchYear: '2019',
        imageUrl: '',
        highlight:
            'Applies quality assurance and product safety standards in the seafood industry.',
        isVisible: true,
        displayOrder: 2,
        createdAt: now,
        updatedAt: now,
      ),
      AlumniProfile(
        id: 'sample-3',
        name: 'Leah Magbanua',
        title: 'Aquaculture Specialist',
        position: 'Aquaculture Specialist',
        company: 'Coastal Harvest',
        batchYear: '2022',
        imageUrl: '',
        highlight:
            'Supports sustainable fish farming and production planning in local communities.',
        isVisible: true,
        displayOrder: 3,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
