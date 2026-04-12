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

// ================= GLOBAL =================

final navigatorKey = GlobalKey<NavigatorState>();
late FirebaseAnalytics analytics;
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

bool _fcmListenerAdded = false;

bool isValidStepJump(int stepJump, DateTime now, DateTime? lastTime) {
  if (stepJump < 0) return false;

  // منع القفزات الكبيرة
  if (stepJump > 50) return false;

  // منع السرعة غير الطبيعية
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
    if (diff < 6) return; // كل 6 ساعات بدل 3
  }

  final today = DateTime.now();
  if (notificationDay == null || today.day != notificationDay!.day) {
    notificationCountToday = 0;
    notificationDay = today;
  }

  if (!notificationsEnabled) return;
  if (stepsToday < 2000) return;
  if (notificationCountToday >= 2) return;


  notificationCountToday++;
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

  // إعادة التشغيل بعد يوم
  Future.delayed(const Duration(days: 1), smartNotificationEngine);
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
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await loadTrackingSetting();

  analytics = FirebaseAnalytics.instance;

  await analytics.setAnalyticsCollectionEnabled(userAcceptedTracking);

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  setupCrashlytics();

  bool adsAllowed = false;

  try {
    adsAllowed = await initConsentForm();
  } catch (e) {
    adsAllowed = false;
  }

// fallback أمان
  if (!adsAllowed) {
    debugPrint("Ads disabled due to no consent");
  }

  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      tagForChildDirectedTreatment:
      TagForChildDirectedTreatment.unspecified,
      tagForUnderAgeOfConsent:
      TagForUnderAgeOfConsent.unspecified,
      maxAdContentRating: MaxAdContentRating.pg,
    ),
  );

  await MobileAds.instance.initialize();

  if (adsAllowed) {
    debugPrint("Ads allowed by consent");
  } else {
    debugPrint("Ads will not be shown until consent is granted");
  }

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.local);

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit),
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

  runApp(const MyApp());
}

// ================= PERMISSIONS =================

Future<void> requestPermissions(BuildContext context) async {
  final allowActivity = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Step Tracking Permission"),
      content: const Text(
        "We track your steps to show your activity, progress, and achievements.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("No Thanks"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Allow"),
        ),
      ],
    ),
  );

  if (allowActivity == true) {

    final activityStatus = await Permission.activityRecognition.request();

    if (!activityStatus.isGranted) {
      debugPrint("User denied activity tracking - steps disabled");
      return;
    }
  }

  if (!context.mounted) return;

  final allowNotification = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Enable Notifications"),
      content: const Text(
        "We may send occasional reminders to help you stay active. You can disable them anytime.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("No Thanks"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
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
    await FirebaseMessaging.instance.requestPermission();
  }
}

Future<bool> askTrackingPermission(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Data Usage"),
      content: const Text(
        "We collect anonymous usage data such as steps and app interactions to improve app experience. No personal or sensitive data is collected or shared.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("no"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
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


  void initFCMListener() {
    if (_fcmListenerAdded) return;
    _fcmListenerAdded = true;

    FirebaseMessaging.onMessage.listen((message) async {
      if (message.notification == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;

      // 1 - حفظ الإشعار في Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': message.notification!.title ?? '',
        'body': message.notification!.body ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 2 - عرض إشعار محلي
      showLocalNotification(
        message.notification!.title ?? "Notification",
        message.notification!.body ?? "",
      );
    });
  }

  bool _fcmInitialized = false;
  Future<void> startPermissionFlow(BuildContext context) async {
    if (!context.mounted) return;

    final tracking = await askTrackingPermission(context);

    if (!context.mounted) return;

    if (tracking) {
      await requestPermissions(context);
    }
  }

  StreamSubscription<StepCount>? _stepSub;
  bool _started = false;
  int _lastRawSteps = 0;
  DateTime? _lastStepTime;

  DateTime? _lastSave;
  int _lastSavedSteps = 0;

  Future<void> _loadSteps() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();

    stepsToday = data?['steps'] ?? 0;
    _startSteps = data?['initialSteps'];

    debugPrint("LOADED stepsToday = $stepsToday");
    debugPrint("LOADED startSteps = $_startSteps");
  }

  @override
  void initState() {
    super.initState();

    _initFCM();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _start();
      }
    });
  }

  void _initFCM() async {
    if (_fcmInitialized) return;
    _fcmInitialized = true;

    try {
      await FirebaseMessaging.instance.requestPermission();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;

      final token = await FirebaseMessaging.instance.getToken();

      debugPrint("FCM TOKEN: $token");

      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 🔥 Token refresh (safe)
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

      // 🔥 Foreground messages
      FirebaseMessaging.onMessage.listen((message) {
        if (!notificationsEnabled) return;
        if (message.notification == null) return;

        showLocalNotification(
          message.notification!.title ?? "Notification",
          message.notification!.body ?? "",
        );
      });

      // 🔥 When user taps notification
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        FirebaseAnalytics.instance.logEvent(
          name: "notification_click",
        );
      });

    } catch (e) {
      debugPrint("FCM ERROR: $e");
    }
  }


  void _listenSteps() async {
    final status = await Permission.activityRecognition.status;
    if (!status.isGranted) return;

    _stepSub = Pedometer.stepCountStream.listen((event) async {
      _startSteps ??= event.steps;

      final start = _startSteps ?? event.steps;
      final diff = event.steps - start;

      if (diff < 0) return;

      final now = DateTime.now();

      final rawSteps = event.steps;

      // 🔥 هنا بالضبط
      if (event.steps < _lastRawSteps) {
        _startSteps = event.steps;
        _lastRawSteps = event.steps;
        return;
      }

      if (_lastRawSteps == 0) {
        _lastRawSteps = rawSteps;
        return;
      }

      final stepJump = rawSteps - _lastRawSteps;

// 🔥 حماية أولية
      if (!isValidStepJump(stepJump, now, _lastStepTime)) return;

// 🔥 منع التلاعب (أقوى وأدق)
      if (stepJump > 250) {
        debugPrint("Suspicious step jump ignored");
        return;
      }

// 🔥 منع التكرار السريع جدًا
      if (_lastStepTime != null &&
          now.difference(_lastStepTime!).inSeconds < 2 &&
          stepJump > 200) {
        return;
      }

      const maxDailySteps = 20000;

      final safeDiff = diff.clamp(0, maxDailySteps);

      _lastRawSteps = rawSteps;
      _lastStepTime = now;

      setState(() {
        stepsToday = safeDiff;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final saveInterval = Duration(seconds: 30);

      if (_lastSave == null ||
          now.difference(_lastSave!) > saveInterval ||
          (stepsToday - _lastSavedSteps).abs() > 300) {
        _lastSave = now;
        _lastSavedSteps = stepsToday;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'steps': stepsToday.clamp(0, 20000),
          'initialSteps': _startSteps ?? 0,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;

    await loadTrackingSetting();
    await loadNotificationSetting();

    _initFCM();

    initFCMListener();

    if (!mounted) return;

    await startPermissionFlow(context);

    await _loadSteps();

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
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      title: "Go Earn",
      home: const LoginPage(),
    );
  }
}
