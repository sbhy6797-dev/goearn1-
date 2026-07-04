import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_update/in_app_update.dart';

// ================= GLOBAL =================

final navigatorKey = GlobalKey<NavigatorState>();
late FirebaseAnalytics analytics;
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();


bool isValidStepJump(int stepJump, DateTime now, DateTime? lastTime) {
  if (stepJump < 0) return false;

  if (stepJump > 150) return false;


  if (lastTime != null) {
    final seconds = now.difference(lastTime).inSeconds;
    if (seconds < 1 && stepJump > 20) return false;
  }

  return true;
}

int stepsToday = 0;
int? _startSteps;

bool userAcceptedTracking = false;
bool _permissionRequestRunning = false;


Future<void> loadTrackingSetting() async {
  final prefs = await SharedPreferences.getInstance();
  userAcceptedTracking = prefs.getBool('tracking') ?? false;
}

Future<void> saveTrackingSetting(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('tracking', value);
}

// ================= CRASHLYTICS =================

void setupCrashlytics() {
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: true,
    );
    return true;
  };
}

// ================= UMP (SAFE VERSION) =================

Future<bool> initConsentFormSafe() async {
  try {
    await Future.delayed(const Duration(milliseconds: 500));

    final params = ConsentRequestParameters();
    final completer = Completer<bool>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
          () async {
        try {
          final available =
          await ConsentInformation.instance.isConsentFormAvailable();

          if (!available) {
            completer.complete(
              await ConsentInformation.instance.canRequestAds(),
            );
            return;
          }

          ConsentForm.loadAndShowConsentFormIfRequired(
                (formError) async {
              if (formError != null) {
                debugPrint("UMP form error: ${formError.message}");
                completer.complete(false);
                return;
              }

              final canRequest =
              await ConsentInformation.instance.canRequestAds();

              completer.complete(canRequest);
            },
          );
        } catch (e) {
          debugPrint("UMP inner error: $e");
          completer.complete(false);
        }
      },
          (error) {
        debugPrint("UMP update error: ${error.message}");
        completer.complete(false);
      },
    );

    return completer.future;
  } catch (e) {
    debugPrint("UMP crash safe: $e");
    return false;
  }
}

// ================= BACKGROUND FCM =================

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    final notification = message.notification;
    if (notification == null) return;

    debugPrint("BG message: ${notification.title}");
  } catch (e) {
    debugPrint("BG handler error: $e");
  }
}

// ================= MAIN =================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  setupCrashlytics();



  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  runApp(const MyApp());
}

// ================= PERMISSIONS =================


Future<void> requestPermissions(BuildContext context) async {

  if (_permissionRequestRunning) return;

  _permissionRequestRunning = true;

  try {

    final allowActivity = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Step Tracking Permission"),
        content: const Text(
          "We use activity recognition permission to count your steps and track your daily movement.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("No Thanks"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Allow"),
          ),
        ],
      ),
    );

    if (allowActivity != true) return;

    await Permission.activityRecognition.request();

  } catch (e) {
    debugPrint("Permission error: $e");
  } finally {
    _permissionRequestRunning = false;
  }
}

Future<bool> askTrackingPermission() async {
  final context = navigatorKey.currentContext;
  if (context == null) return false;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Data Usage"),
      content: const Text(
        "We collect your step count, device information, and app usage data to improve app performance and user experience. This data may be shared with third-party services such as Google Analytics and Firebase. No personally identifiable information is sold or shared.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("no"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text("yes"),
        ),
      ],
    ),
  );

  userAcceptedTracking = result ?? false;

  await saveTrackingSetting(userAcceptedTracking);

  await FirebaseAnalytics.instance
      .setAnalyticsCollectionEnabled(userAcceptedTracking);

  return userAcceptedTracking;
}

// ================= APP =================

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}



class _MyAppState extends State<MyApp> {

  Future<void> checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {


        if (info.immediateUpdateAllowed == true) {
          await InAppUpdate.performImmediateUpdate();
        } else {
          debugPrint("Immediate update not allowed");
        }
      }

    } catch (e) {

      debugPrint("Update check failed: $e");
    }
  }


  void showUpdateDialog() {
    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("تحديث مطلوب"),
        content: const Text("لازم تحدث التطبيق عشان تقدر تكمل."),
        actions: [
          TextButton(
            onPressed: () {
              launchUrl(
                Uri.parse(
                    "https://play.google.com/store/apps/details?id=com.goearn.goearn1"
                ),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text("تحديث"),
          ),
        ],
      ),
    );
  }




  Timer? _stepTimer;
  Timer? _permissionTimer;


  Timer? _firestoreTimer;
  StreamSubscription<String>? _tokenSub;

  bool _fcmListenerAdded = false;

  Future<void> initializeServices() async {

    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
    );

    final prefs = await SharedPreferences.getInstance();
    userAcceptedTracking = prefs.getBool('tracking') ?? false;

    await FirebaseAnalytics.instance
        .setAnalyticsCollectionEnabled(userAcceptedTracking);

    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(true);

    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
        maxAdContentRating: MaxAdContentRating.g,
      ),
    );
  }


  bool isStepAvailable = true;

  Future<bool> hasSeenPermissionDialogs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('seen_permission_dialogs') ?? false;
  }

  Future<void> setSeenPermissionDialogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_permission_dialogs', true);
  }


  bool _fcmInitialized = false;
  bool _fcmTokenSaved = false;


  late StreamSubscription<User?> _authSub;
  StreamSubscription<RemoteMessage>? _fcmSub;


  void initFCMListener() {
    if (_fcmListenerAdded) return;
    _fcmListenerAdded = true;

    _fcmSub = FirebaseMessaging.onMessage.listen((message) async {

      try {
        final notification = message.notification;
        if (notification == null) return;

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          debugPrint("No user logged in");
          return;
        }

        final uid = currentUser.uid;
        final title = notification.title ?? "Notification";
        final body = notification.body ?? "";
        await _saveNotification(uid, title, body);
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();

        if (snapshot.docs.length > 40) {
          Future.microtask(() async {
            for (var doc in snapshot.docs.skip(30)) {
              await doc.reference.delete();
            }
          });
        }

      } catch (e, stack) {
        debugPrint("FCM error: $e");

        await FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          fatal: false,
        );
      }
    });
  }

  Future<void> _saveNotification(String uid, String title, String body) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e, stack) {
      debugPrint("Firestore error: $e");

      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        fatal: false,
      );
    }
  }

  Future<void> startPermissionFlow() async {
    final seen = await hasSeenPermissionDialogs();
    if (seen) return;

    final tracking = await askTrackingPermission();

    if (tracking) {
      await requestPermissions(navigatorKey.currentContext!);
    }

    await setSeenPermissionDialogs();
  }


  StreamSubscription<StepCount>? _stepSub;
  bool _started = false;
  int _lastRawSteps = 0;
  DateTime? _lastStepTime;

  DateTime? _lastSave;
  int _lastSavedSteps = 0;

  void _listenSteps() async {

    if (!isStepAvailable) {
      debugPrint("Step counter not supported on this device");
      return;
    }

    final status = await Permission.activityRecognition.status;

    if (!status.isGranted) {
      debugPrint("Permission not granted");
      return;
    }

    try {
      // ✅ مهم: تأخير تشغيل sensor لتخفيف الضغط
      await Future.delayed(const Duration(seconds: 1));

      _stepSub = Pedometer.stepCountStream.listen(
            (event) {
          _handleStep(event);
        },

        onError: (error) async {
          debugPrint("STEP ERROR: $error");
          isStepAvailable = false;

          await _stepSub?.cancel();

          await FirebaseCrashlytics.instance.recordError(
            error,
            null,
            fatal: false,
          );
        },

        cancelOnError: true,
      );

    } catch (e, stack) {
      debugPrint("Pedometer init error: $e");

      isStepAvailable = false;

      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        fatal: false,
      );
    }
  }


  Future<void> _loadSteps(User? user) async {
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final doc = await docRef.get();

      if (!doc.exists) {
        debugPrint("User doc not found");
        return;
      }

      final data = doc.data();

      if (data == null) return;

      stepsToday = (data['steps'] as num?)?.toInt() ?? 0;
      _startSteps = (data['initialSteps'] as num?)?.toInt() ?? 0;

      debugPrint("LOADED stepsToday = $stepsToday");
      debugPrint("LOADED startSteps = $_startSteps");

    } catch (e, stack) {
      debugPrint("Load steps error: $e");

      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        fatal: false,
      );
    }
  }


  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForUpdate();
    });

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted || user == null) return;

      await _initFCM();
      await _loadSteps(user);

      Future.delayed(const Duration(seconds: 2), () {
        _start(user);
      });
    });
  }


  Future<void> _initFCM() async {
    if (_fcmInitialized) return;
    _fcmInitialized = true;

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;

      final token = await FirebaseMessaging.instance.getToken();

      if (token != null && !_fcmTokenSaved) {
        _fcmTokenSaved = true;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 🟢 safe single listener
      _tokenSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
          'fcmToken': newToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

    } catch (e) {
      debugPrint("FCM ERROR: $e");
    }
  }


  DateTime? _lastUiUpdate;
  Timer? _syncTimer;
  Map<String, dynamic>? _pendingStepData;

  void _handleStep(StepCount event) {
    _startSteps ??= event.steps;
    final now = DateTime.now();

    final rawSteps = event.steps;

    // 🔴 reset detection
    if (rawSteps < _lastRawSteps) {
      final diffReset = _lastRawSteps - rawSteps;

      if (diffReset > 1000) {
        _startSteps = rawSteps;
      }

      _lastRawSteps = rawSteps;
      return;
    }

    final stepJump = rawSteps - _lastRawSteps;

    if (!isValidStepJump(stepJump, now, _lastStepTime)) return;
    if (stepJump > 250) return;

    _lastRawSteps = rawSteps;
    _lastStepTime = now;

    final start = _startSteps ?? rawSteps;
    final diff = (rawSteps - start).clamp(0, 200000);

    // =========================
    // UI UPDATE (throttled)
    // =========================
    if (_lastUiUpdate == null ||
        now.difference(_lastUiUpdate!) > const Duration(seconds: 1)) {
      _lastUiUpdate = now;

      if (mounted) {
        setState(() {
          stepsToday = diff;
        });
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // =========================
    // SAVE THROTTLE
    // =========================
    final shouldSave =
        _lastSave == null ||
            now.difference(_lastSave!) > const Duration(minutes: 5) ||
            (stepsToday - _lastSavedSteps).abs() > 500;

    if (!shouldSave) return;

    _lastSave = now;
    _lastSavedSteps = stepsToday;

    _pendingStepData = {
      'steps': stepsToday,
      'initialSteps': _startSteps ?? rawSteps,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    // =========================
    // SINGLE SYNC TIMER (NO CHAOS)
    // =========================
    if (_syncTimer?.isActive == true) return;

    _syncTimer = Timer(const Duration(seconds: 20), () async {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null || _pendingStepData == null) return;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set(_pendingStepData!, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));

      } catch (e) {
        debugPrint("Step sync error: $e");
      }
    });
  }



  Future<void> _start(User user) async {
    if (_started) return;
    _started = true;

    await loadTrackingSetting();


    initFCMListener();

    if (userAcceptedTracking) {
      _stepTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && userAcceptedTracking) {
          _listenSteps();
        }
      });
    }

    _permissionTimer = Timer(const Duration(seconds: 5), () async {
      try {
        if (!mounted) return;
        await startPermissionFlow();
      } catch (e, stack) {
        FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      }
    });
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    _authSub.cancel();
    _stepSub?.cancel();
    _stepTimer?.cancel();
    _permissionTimer?.cancel();
    _firestoreTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}