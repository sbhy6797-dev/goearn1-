import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';

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

// ================= GLOBAL =================

final navigatorKey = GlobalKey<NavigatorState>();
late FirebaseAnalytics analytics;
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

int stepsToday = 0;
int? _startSteps;

bool notificationsEnabled = false;
DateTime? _lastNotificationTime;

// ================= CRASHLYTICS =================

void setupCrashlytics() {
  FlutterError.onError =
      FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
    return true;
  };
}

// ================= UMP (SAFE VERSION) =================

Future<void> initConsentForm() async {
  try {
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
          () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          ConsentForm.loadAndShowConsentFormIfRequired(
                (formError) {
              if (formError != null) {
                debugPrint("Consent form error: ${formError.message}");
              }
            },
          );
        }
      },
          (error) {
        debugPrint("Consent info update error: ${error.message}");
      },
    );

  } catch (e) {
    debugPrint("UMP error: $e");
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

  // anti-spam (global safe)
  if (_lastNotificationTime != null &&
      now.difference(_lastNotificationTime!).inMinutes < 30) {
    return;
  }

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
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
    ),
  );
}

// ================= SMART NOTIFICATION ENGINE =================

void smartNotificationEngine() {
  Timer.periodic(const Duration(hours: 3), (_) {
    if (!notificationsEnabled) return;

    if (stepsToday < 2000) {
      showLocalNotification("🚶 Move!", "You are too inactive today.");
    } else if (stepsToday < 6000) {
      showLocalNotification("🔥 Keep going!", "You're doing great!");
    } else {
      showLocalNotification("🏆 Amazing!", "You crushed your goal!");
    }
  });
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
        importance: Importance.max,
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
  setupCrashlytics();

  analytics = FirebaseAnalytics.instance;

  await initConsentForm();

  if (await ConsentInformation.instance.canRequestAds()) {
    await MobileAds.instance.initialize();
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // timezone fix (GLOBAL SAFE)
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.local);

  // notifications init
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit),
  );

  const channel = AndroidNotificationChannel(
    'smart_channel',
    'Smart Notifications',
    description: 'Global smart notifications',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  runApp(const MyApp());
}

// ================= PERMISSIONS =================

Future<void> requestPermissions() async {
  await Permission.activityRecognition.request();
  final notification = await Permission.notification.request();

  notificationsEnabled = notification.isGranted;

  await FirebaseMessaging.instance.requestPermission();
}

// ================= APP =================

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<StepCount>? _stepSub;
  bool _started = false;

  @override
  void initState() {
    super.initState();

    _listenSteps();
    _initFCM();
  }

  // ================= FCM =================

  void _initFCM() {
    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification == null) return;

      showLocalNotification(
        message.notification!.title ?? "Notification",
        message.notification!.body ?? "",
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      FirebaseAnalytics.instance.logEvent(
        name: "notification_click",
      );
    });
  }

  // ================= STEPS =================

  void _listenSteps() {
    _stepSub = Pedometer.stepCountStream.listen((event) {
      _startSteps ??= event.steps;

      final diff = event.steps - (_startSteps ?? event.steps);

      setState(() {
        stepsToday = diff < 0 ? 0 : diff;
      });
    });
  }

  // ================= START FLOW =================

  Future<void> _start() async {
    if (_started) return;
    _started = true;

    await requestPermissions();

    smartNotificationEngine();

    scheduleDailyNotification(1, 10, 0);
    scheduleDailyNotification(2, 18, 0);
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