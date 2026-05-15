import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'firebase_options.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// ================= GLOBAL =================

final navigatorKey = GlobalKey<NavigatorState>();
late FirebaseAnalytics analytics;
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

bool _fcmListenerAdded = false;

bool isValidStepJump(int stepJump, DateTime now, DateTime? lastTime) {
  if (stepJump < 0) return false;

  if (stepJump > 150) return false;


  if (lastTime != null) {
    final seconds = now.difference(lastTime).inSeconds;
    if (seconds < 1 && stepJump > 20) return false;
  }

  return true;
}

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

int stepsToday = 0;
int? _startSteps;
int notificationCountToday = 0;
DateTime? notificationDay;

int notificationCountWeek = 0;
DateTime? notificationWeekStart;

bool userAcceptedTracking = false;

Future<void> loadTrackingSetting() async {
  final prefs = await SharedPreferences.getInstance();
  userAcceptedTracking = prefs.getBool('tracking') ?? false;
}

Future<void> saveTrackingSetting(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('tracking', value);
}

bool notificationsEnabled = false;

Future<void> loadNotificationSetting() async {
  final prefs = await SharedPreferences.getInstance();
  notificationsEnabled = prefs.getBool('notifications') ?? false;
}

Future<void> saveNotificationSetting(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('notifications', value);
}

DateTime? _lastNotificationTime;

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

Future<bool> initConsentForm() async {
  try {
    final params = ConsentRequestParameters();
    final completer = Completer<bool>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
          () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          ConsentForm.loadAndShowConsentFormIfRequired(
                (formError) async {
              if (formError != null) {
                debugPrint("Consent error: ${formError.message}");
                completer.complete(false);
              } else {
                final canRequestAds = await ConsentInformation.instance.canRequestAds();
                completer.complete(canRequestAds);
              }
            },
          );
        } else {
          final canRequestAds = await ConsentInformation.instance.canRequestAds();
          completer.complete(canRequestAds);
        }
      },
          (error) {
        debugPrint("Consent update error: ${error.message}");
        completer.complete(false);
      },
    );

    return completer.future;
  } catch (e) {
    debugPrint("UMP error: $e");
    return false;
  }
}

// ================= BACKGROUND FCM =================

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  setupCrashlytics();
}

// ================= NOTIFICATIONS =================

Future<void> showLocalNotification(String title, String body) async {
  final now = DateTime.now();

  if (!notificationsEnabled) return;


  if (_lastNotificationTime != null) {
    final diff = now.difference(_lastNotificationTime!).inHours;
    if (diff < 6) return;
  }
  final today = DateTime.now();
  if (notificationDay == null || today.day != notificationDay!.day) {
    notificationCountToday = 0;
    notificationDay = today;
  }


  if (notificationWeekStart == null ||
      now.difference(notificationWeekStart!).inDays >= 7) {
    notificationWeekStart = now;
    notificationCountWeek = 0;
  }

  if (stepsToday < 2000) return;


  if (notificationCountToday >= 2) return;
  if (notificationCountWeek >= 5) return;


  notificationCountToday++;
  notificationCountWeek++;
  _lastNotificationTime = now;

  await flutterLocalNotificationsPlugin.show(
    now.millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'smart_channel',
        'Smart Notifications',
        channelDescription: 'Global notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
      ),
    ),
  );
}

// ================= SMART NOTIFICATION ENGINE =================

void smartNotificationEngine() async {
  if (!notificationsEnabled) return;

  if (_lastNotificationTime != null &&
      DateTime.now().difference(_lastNotificationTime!).inHours < 24) {
    return;
  }

  if (stepsToday < 2000) return;

  if (stepsToday < 5000) {
    showLocalNotification(
      "🚶 Stay Active",
      "Take a short walk today",
    );
  } else {
    showLocalNotification(
      "🔥 Great Job",
      "You're doing great today!",
    );
  }


}

// ================= SCHEDULE NOTIFICATIONS =================
Future<void> scheduleDailyNotification(int id, int hour, int minute) async {
  if (!notificationsEnabled) return;

  final now = tz.TZDateTime.now(tz.local);

  var scheduled = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );

  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }

  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    "🏃 Reminder",
    "Stay active and healthy",
    scheduled,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'smart_channel',
        'Smart Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),

    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,

    matchDateTimeComponents: DateTimeComponents.time,
  );
}

// ================= MAIN =================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );

  setupCrashlytics();

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  final prefs = await SharedPreferences.getInstance();
  userAcceptedTracking = prefs.getBool('tracking') ?? false;

  await FirebaseAnalytics.instance
      .setAnalyticsCollectionEnabled(userAcceptedTracking);

  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(true);

  bool adsAllowed = false;

  try {
    adsAllowed = await initConsentForm();
  } catch (e) {
    adsAllowed = false;
  }

  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
      maxAdContentRating: MaxAdContentRating.g,
    ),
  );

  if (adsAllowed) {
    await MobileAds.instance.initialize();
  }

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.local);

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
    const AndroidNotificationChannel(
      'smart_channel',
      'Smart Notifications',
      description: 'Global smart notifications',
      importance: Importance.high,
    ),
  );

  await loadNotificationSetting();

  runApp(
    MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const MyApp(),
    ),
  );
}


// ================= PERMISSIONS =================
Future<void> requestPermissions(BuildContext context) async {
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

  if (!context.mounted) return;

  final allowNotification = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Enable Notifications"),
      content: const Text(
        "We may send occasional reminders to help you stay active.",
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

  if (allowNotification == true) {
    final status = await Permission.notification.request();
    notificationsEnabled = status.isGranted;
    await saveNotificationSetting(notificationsEnabled);
  }

  if (notificationsEnabled) {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
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


        await Future.wait([
          _saveNotification(uid, title, body),
          showLocalNotification(title, body),
        ]);


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

  Future<void> _loadSteps(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (data != null) {
        final steps = data['steps'];
        if (steps is int) {
          stepsToday = steps;
        } else if (steps is num) {
          stepsToday = steps.toInt();
        }

        final start = data['initialSteps'];
        if (start is int) {
          _startSteps = start;
        } else if (start is num) {
          _startSteps = start.toInt();
        }
      }

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
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (!mounted) return;
        if (user == null) return;

        try {
          await _initFCM();
          await _loadSteps(user);
          await _start(user);
        } catch (e) {
          debugPrint("Auth flow error: $e");
        }
      });
    });
  }


  Future<void> _initFCM() async {
    if (_fcmInitialized) return;
    _fcmInitialized = true;

    try {
      if (notificationsEnabled) {
        await FirebaseMessaging.instance.requestPermission();
      }

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

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
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


  void _handleStep(StepCount event) async {
    _startSteps ??= event.steps;
    final now = DateTime.now();

    final rawSteps = event.steps;

    // reset detection (safe)
    if (event.steps < _lastRawSteps) {
      final diffReset = _lastRawSteps - event.steps;

      if (diffReset > 1000) {
        _startSteps = event.steps;
      }

      _lastRawSteps = event.steps;
      return;
    }

    final stepJump = rawSteps - _lastRawSteps;

    if (!isValidStepJump(stepJump, now, _lastStepTime)) return;

    if (stepJump > 250) return;

    _lastRawSteps = rawSteps;
    _lastStepTime = now;

    final diff = (event.steps - _startSteps!).clamp(0, 200000);
    final steps = diff;

    if (!mounted) return;
    setState(() {
      stepsToday = steps;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_lastSave == null ||
        now.difference(_lastSave!) > const Duration(minutes: 5) ||
        (stepsToday - _lastSavedSteps).abs() > 300) {

      _lastSave = now;
      _lastSavedSteps = stepsToday;

      unawaited(
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'steps': stepsToday,
          'initialSteps': _startSteps ?? 0,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      );
    }
  }



  Future<void> _start(User user) async {
    if (_started) return;
    _started = true;

    await loadTrackingSetting();
    await loadNotificationSetting();

    initFCMListener();

    if (userAcceptedTracking) {
      await Future.delayed(const Duration(seconds: 2));
      _listenSteps();
    }

    if (notificationsEnabled) {
      Future.delayed(const Duration(minutes: 5), () {
        if (mounted) smartNotificationEngine();
      });

      scheduleDailyNotification(1, 10, 0);
      scheduleDailyNotification(2, 18, 0);
    }

    Future.delayed(const Duration(seconds: 1), () async {
      try {
        if (!mounted) return;
        await startPermissionFlow();
      } catch (e, stack) {
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          fatal: false,
        );
      }
    });
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    _authSub.cancel();
    _stepSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const LoginPage();
  }
}