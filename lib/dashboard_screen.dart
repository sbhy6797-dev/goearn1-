import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lucky_spin_screen.dart';
import 'main.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// ================= Dashboard Screen =================
class DashboardScreen extends StatefulWidget {
  final int totalCoins;
  const DashboardScreen({super.key, required this.totalCoins});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with RouteAware {

  Future<void> saveDeviceLanguage() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final languageCode =
        ui.PlatformDispatcher.instance.locale.languageCode;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'language': languageCode,
    }, SetOptions(merge: true));
  }



  bool _isListening = false;

  Timer? _uiTimer;
  int steps = 0;
  int coins = 0;
  int totalCoins = 0;
  int lastSensorSteps = 0;

  String getTodayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
  }



  int initialSteps = 0;
  bool isFirstUpdate = true;


  bool isStepSupported = true;


  StreamSubscription<StepCount>? _stepSubscription;
  late Stream<StepCount> _stepCountStream;

  final int maxSteps = 70000;
  final int stepPerCoin = 100;

  late final DocumentReference userDoc;
  late final String uid;
  Timer? _debounce;

  // ===== Ad Tracking =====
  int adsWatchedCount = 0;

  DateTime? lastAdTime;
  bool _isCollectingReward = false;

  bool canShowAd() {
    if (!_isInterstitialReady) return false;
    if (adsWatchedCount >= 20) return false;

    if (lastAdTime == null) return true;

    return DateTime.now().difference(lastAdTime!).inSeconds > 60;
  }

  void tryShowAd() {
    if (!canShowAd()) return;

    lastAdTime = DateTime.now();
    _showInterstitial();
  }

// ===== Interstitial Ad =====
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  bool _isInterstitialLoading = false;
// ===== Banner Ad =====
  BannerAd? _bannerAd;
  bool _isBannerReady = false;


  Future<void> addRewardedCoins() async {
    const int reward = 100;

    try {
      final result = await FirebaseFirestore.instance.runTransaction(
            (transaction) async {
          final snapshot = await transaction.get(userDoc);

          if (!snapshot.exists) {
            throw Exception('User document does not exist');
          }

          final data = snapshot.data() as Map<String, dynamic>;

          final int firebaseTotal =
              (data['totalCoins'] as num?)?.toInt() ?? 0;

          final int currentAds =
              (data['adsWatchedToday'] as num?)?.toInt() ?? 0;

          final int newTotalCoins =
              firebaseTotal + reward;

          final int newAdsCount =
              currentAds + 1;

          transaction.set(
            userDoc,
            {
              'totalCoins': newTotalCoins,
              'adsWatchedToday': newAdsCount,
              'adsDate': getTodayKey(),
              'lastUpdate': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          return {
            'totalCoins': newTotalCoins,
            'adsWatchedToday': newAdsCount,
          };
        },
      );

      if (!mounted) return;

      setState(() {
        totalCoins = result['totalCoins'] as int;
        adsWatchedCount = result['adsWatchedToday'] as int;
      });

      await _saveLocalData();

    } catch (e) {
      debugPrint('addRewardedCoins error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your reward. Please try again.'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      uid = user.uid;
      userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);

      saveDeviceLanguage();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initConsentFormSafe();
    });

    _loadLocalData();

    initApp();

    _loadInterstitial();

    _loadBannerAd();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {



    setState(() {});
  }
  @override
  void didPushNext() {


  }


  @override
  void didPop() {
    routeObserver.unsubscribe(this);
  }


  Future<void> initApp() async {

    final status = await Permission.activityRecognition.status;

    if (!status.isGranted) {
      return;
    }

    await loadData();

    Future.delayed(const Duration(milliseconds: 500), () {
      initPedometer();
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _showCongratulationScreen();
    });
  }

  void _loadInterstitial() {
    // يوجد إعلان جاهز بالفعل
    if (_interstitialAd != null) return;

    // يوجد طلب تحميل جارٍ بالفعل
    if (_isInterstitialLoading) return;

    _isInterstitialLoading = true;

    debugPrint('INTERSTITIAL: Loading ad...');

    InterstitialAd.load(
      adUnitId: 'ca-app-pub-5925712456846655/5052040996',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(

        onAdLoaded: (ad) {
          _isInterstitialLoading = false;

          _interstitialAd?.dispose();

          _interstitialAd = ad;
          _isInterstitialReady = true;

          debugPrint('INTERSTITIAL: Ad loaded successfully');

          if (mounted) {
            setState(() {});
          }
        },

        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          _isInterstitialReady = false;

          debugPrint(
            'INTERSTITIAL: Failed to load '
                '${error.code} - ${error.message}',
          );

          // لا نطلب كل 3 ثواني.
          // محاولة واحدة بعد 30 ثانية.
          Future.delayed(const Duration(seconds: 30), () {
            if (!mounted) return;

            _loadInterstitial();
          });
        },
      ),
    );
  }



  void _loadBannerAd() {

    _bannerAd?.dispose();

    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-5925712456846655/9667012771',
      request: const AdRequest(),

      listener: BannerAdListener(

        onAdLoaded: (ad) {

          if (!mounted) return;

          setState(() {
            _isBannerReady = true;
          });

        },

        onAdFailedToLoad: (ad, error) {

          ad.dispose();

          if (!mounted) return;

          setState(() {
            _isBannerReady = false;
          });

          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _loadBannerAd();
            }
          });

        },

      ),
    );

    _bannerAd!.load();
  }


  void _showInterstitial() async {
    if (!_isInterstitialReady || _interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback =
        FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _loadInterstitial();
          },

          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            _loadInterstitial();
          },
        );

    lastAdTime = DateTime.now();

    _interstitialAd!.show();
    _interstitialAd = null;
    _isInterstitialReady = false;
  }

  Future<void> loadData() async {
    try {
      final snapshot = await userDoc.get();

      if (!snapshot.exists) {
        debugPrint('User document does not exist');
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;

      final todayKey = getTodayKey();

      final savedDate = data['adsDate']?.toString();

      int adsCount =
          (data['adsWatchedToday'] as num?)?.toInt() ?? 0;

      if (savedDate != todayKey) {
        adsCount = 0;

        await userDoc.set({
          'adsWatchedToday': 0,
          'adsDate': todayKey,
        }, SetOptions(merge: true));
      }

      final int firebaseSteps =
          (data['steps'] as num?)?.toInt() ?? 0;

      final int firebaseCoins =
          (data['coins'] as num?)?.toInt() ?? 0;

      final int firebaseTotalCoins =
          (data['totalCoins'] as num?)?.toInt() ?? 0;

      final int firebaseInitialSteps =
          (data['initialSteps'] as num?)?.toInt() ?? 0;

      final bool firebaseIsFirstUpdate =
          data['isFirstUpdate'] as bool? ?? true;

      if (!mounted) return;

      setState(() {
        steps = firebaseSteps;
        coins = firebaseCoins;

        // ⭐ Firestore هو المصدر الأساسي
        totalCoins = firebaseTotalCoins;

        initialSteps = firebaseInitialSteps;
        isFirstUpdate = firebaseIsFirstUpdate;

        adsWatchedCount = adsCount;
      });

      // نحفظ آخر قيمة صحيحة محليًا فقط كنسخة احتياطية
      await _saveLocalData();

      debugPrint(
        'FIRESTORE LOADED: '
            'steps=$steps '
            'coins=$coins '
            'totalCoins=$totalCoins',
      );

    } catch (e, stack) {
      debugPrint('Error loading Firebase data: $e');

      // لا نستبدل totalCoins بقيمة قديمة إذا فشل Firestore
      try {
        await FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          fatal: false,
        );
      } catch (_) {}
    }
  }


  void initPedometer() {
    if (_isListening) return;

    _isListening = true;

    try {
      _stepCountStream = Pedometer.stepCountStream;

      _stepSubscription = _stepCountStream.listen(
        onStepCount,
        onError: onStepError,
        cancelOnError: false,
      );
    } catch (e) {
      _isListening = false;

      isStepSupported = false;

      debugPrint("Pedometer NOT supported: $e");

      _handleNoStepSupport();
    }
  }


  void onStepCount(StepCount event) {
    if (!mounted || !_isListening) return;

    final int sensorSteps = event.steps;

    // أول قراءة من الحساس
    if (lastSensorSteps == 0) {
      lastSensorSteps = sensorSteps;
      _saveLocalData();
      return;
    }

    // إذا عداد الحساس رجع للخلف،
    // نحافظ على خطوات المستخدم كما هي.
    if (sensorSteps < lastSensorSteps) {
      lastSensorSteps = sensorSteps;
      _saveLocalData();
      return;
    }

    final int diff = sensorSteps - lastSensorSteps;

    if (diff == 0) return;

    final int newSteps =
    (steps + diff).clamp(0, maxSteps);

    final int newCoins =
        (newSteps ~/ stepPerCoin) * 50;

    setState(() {
      steps = newSteps;
      coins = newCoins;
    });

    lastSensorSteps = sensorSteps;

    _debounce?.cancel();

    _debounce = Timer(
      const Duration(seconds: 5),
          () async {
        if (!mounted) return;

        await _saveLocalData();
        await _updateFirebase();
      },
    );
  }


  void onStepError(Object error) {
    debugPrint("Step Error: $error");

    if (error.toString().contains("StepCount not available")) {
      isStepSupported = false;

      _handleNoStepSupport();

      return;
    }

    _stepSubscription?.cancel();
    _stepSubscription = null;
    _isListening = false;

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) initPedometer();
    });
  }

  Future<void> convertCoins() async {
    if (coins <= 0) return;

    final int coinsToAdd = coins;

    try {
      final result = await FirebaseFirestore.instance.runTransaction(
            (transaction) async {
          final snapshot = await transaction.get(userDoc);

          if (!snapshot.exists) {
            throw Exception('User document does not exist');
          }

          final data = snapshot.data() as Map<String, dynamic>;

          final int firebaseTotal =
              (data['totalCoins'] as num?)?.toInt() ?? 0;

          final int newTotalCoins =
              firebaseTotal + coinsToAdd;

          transaction.set(
            userDoc,
            {
              'totalCoins': newTotalCoins,
              'coins': 0,
              'steps': 0,
              'initialSteps': 0,
              'isFirstUpdate': true,
              'lastUpdate': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          return newTotalCoins;
        },
      );

      if (!mounted) return;

      setState(() {
        totalCoins = result;
        coins = 0;
        steps = 0;
        initialSteps = 0;
        isFirstUpdate = true;
      });

      // حفظ آخر قيمة محليًا بعد نجاح Firebase فقط
      await _saveLocalData();

      // إعلان Interstitial
      if (adsWatchedCount < 100 &&
          _isInterstitialReady &&
          (lastAdTime == null ||
              DateTime.now()
                  .difference(lastAdTime!)
                  .inSeconds >
                  20)) {
        lastAdTime = DateTime.now();

        Future.delayed(
          const Duration(milliseconds: 500),
              () {
            if (mounted) {
              _showInterstitial();
            }
          },
        );
      }
    } catch (e, stack) {
      debugPrint('Convert coins error: $e');

      try {
        await FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          fatal: false,
        );
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save your coins. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _updateFirebase() async {
    try {
      final snapshot = await userDoc.get();

      if (!snapshot.exists) {
        debugPrint('User document does not exist');
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;

      final int firestoreTotalCoins =
          (data['totalCoins'] as num?)?.toInt() ?? 0;

      // ⭐ ممنوع ننقص totalCoins
      final int safeTotalCoins =
      totalCoins < firestoreTotalCoins
          ? firestoreTotalCoins
          : totalCoins;

      // لو Firestore عنده قيمة أكبر،
      // نحدث الشاشة بالقيمة الصحيحة
      if (mounted && safeTotalCoins != totalCoins) {
        setState(() {
          totalCoins = safeTotalCoins;
        });
      }

      await userDoc.set({
        'totalCoins': safeTotalCoins,
        'steps': steps,
        'coins': coins,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // نحفظ نفس القيمة الصحيحة محليًا
      await _saveLocalData();

      debugPrint(
        'FIREBASE SAVED: '
            'totalCoins=$safeTotalCoins '
            'steps=$steps '
            'coins=$coins',
      );

    } catch (e) {
      debugPrint('Error updating Firebase: $e');
    }
  }

  Future<void> _saveLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSensorSteps', lastSensorSteps);
    await prefs.setInt('steps', steps);
    await prefs.setInt('coins', coins);
    await prefs.setInt('totalCoins', totalCoins);
    await prefs.setInt('initialSteps', initialSteps);
    await prefs.setBool('isFirstUpdate', isFirstUpdate);
  }

  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      lastSensorSteps =
          prefs.getInt('lastSensorSteps') ?? 0;

      final localSteps =
          prefs.getInt('steps') ?? 0;

      final localCoins =
          prefs.getInt('coins') ?? 0;

      final localInitialSteps =
          prefs.getInt('initialSteps') ?? 0;

      final localIsFirstUpdate =
          prefs.getBool('isFirstUpdate') ?? true;

      if (!mounted) return;

      setState(() {
        steps = localSteps;
        coins = localCoins;

        // ✅ لا نقرأ totalCoins من SharedPreferences هنا.
        // Firestore هو المصدر الأساسي لـ totalCoins.

        initialSteps = localInitialSteps;
        isFirstUpdate = localIsFirstUpdate;
      });

      debugPrint(
        'LOCAL DATA: '
            'steps=$steps '
            'coins=$coins '
            'totalCoins=$totalCoins',
      );

    } catch (e) {
      debugPrint('Error loading local data: $e');
    }
  }


  @override
  void dispose() {
    _bannerAd?.dispose();
    _uiTimer?.cancel();
    _debounce?.cancel();

    try {
      _stepSubscription?.cancel();
    } catch (_) {}

    _stepSubscription = null;
    _isListening = false;

    routeObserver.unsubscribe(this);

    super.dispose();
  }

  void _handleNoStepSupport() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Device not supported"),
        content: const Text(
          "Your device does not support step counting.\n\nYou can still earn coins using ads 🎁",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }



  void showLuckySpin() {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LuckySpinScreen(
          onRewardCollected: (reward) async {
            try {
              final currentUser = FirebaseAuth.instance.currentUser;

              if (currentUser == null) {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please sign in again.'),
                  ),
                );

                return;
              }

              final docRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid);

              // حفظ المكافأة مباشرة في Firestore
              await docRef.set(
                {
                  'totalCoins': FieldValue.increment(reward),
                  'lastUpdate': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              ).timeout(
                const Duration(seconds: 10),
              );

              // قراءة القيمة النهائية من Firestore
              final snapshot = await docRef.get();

              if (!snapshot.exists) return;

              final data =
              snapshot.data() as Map<String, dynamic>;

              final firebaseTotal =
                  (data['totalCoins'] as num?)?.toInt() ?? 0;

              if (!mounted) return;

              setState(() {
                totalCoins = firebaseTotal;
              });

              // حفظ نسخة محلية بعد نجاح Firestore
              await _saveLocalData();

            } on FirebaseException catch (e, stack) {
              debugPrint(
                'LuckySpin Firestore error: '
                    '${e.code} - ${e.message}',
              );

              // لا نسجل أخطاء الاتصال/الصلاحيات كـ Crashlytics fatal
              if (e.code != 'permission-denied' &&
                  e.code != 'unavailable' &&
                  e.code != 'deadline-exceeded') {
                await FirebaseCrashlytics.instance.recordError(
                  e,
                  stack,
                  reason: 'LuckySpin Firestore error: ${e.code}',
                  fatal: false,
                );
              }

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    e.code == 'permission-denied'
                        ? 'Unable to save reward. Please sign in again.'
                        : 'Connection problem. Please try again.',
                  ),
                ),
              );

            } on TimeoutException catch (e) {
              debugPrint('LuckySpin timeout: $e');

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Connection is slow. Please try again.',
                  ),
                ),
              );

            } catch (e, stack) {
              debugPrint('LuckySpin unknown error: $e');

              await FirebaseCrashlytics.instance.recordError(
                e,
                stack,
                reason: 'LuckySpin unknown error',
                fatal: false,
              );

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Could not save your reward. Please try again.',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showCongratulationScreen() {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CongratulationScreen(
          onRewardCollected: () async {
            const int reward = 100;

            // حماية من تنفيذ المكافأة مرتين
            if (_isCollectingReward) return;

            _isCollectingReward = true;

            try {
              bool success = false;
              int? finalTotalCoins;
              int? finalAdsCount;

              // محاولة العملية حتى 3 مرات في حالة وجود انقطاع مؤقت
              for (int attempt = 1; attempt <= 3; attempt++) {
                try {
                  await FirebaseFirestore.instance.runTransaction(
                        (transaction) async {
                      final snapshot = await transaction.get(userDoc);

                      if (!snapshot.exists) {
                        throw Exception(
                          'User document does not exist',
                        );
                      }

                      final data =
                      snapshot.data() as Map<String, dynamic>;

                      final int firebaseTotal =
                          (data['totalCoins'] as num?)?.toInt() ?? 0;

                      final int currentAds =
                          (data['adsWatchedToday'] as num?)?.toInt() ?? 0;

                      final int newTotal =
                          firebaseTotal + reward;

                      final int newAdsCount =
                          currentAds + 1;

                      transaction.set(
                        userDoc,
                        {
                          'totalCoins': newTotal,
                          'adsWatchedToday': newAdsCount,
                          'adsDate': getTodayKey(),
                        },
                        SetOptions(merge: true),
                      );

                      // نحفظ القيم فقط، ولا نعمل setState هنا
                      finalTotalCoins = newTotal;
                      finalAdsCount = newAdsCount;
                    },
                  );

                  success = true;
                  break;
                } on FirebaseException catch (e) {
                  debugPrint(
                    'Reward transaction attempt $attempt failed: '
                        '${e.code} - ${e.message}',
                  );

                  if (e.code == 'unavailable' ||
                      e.code == 'deadline-exceeded' ||
                      e.code == 'aborted') {
                    if (attempt < 3) {
                      await Future.delayed(
                        Duration(seconds: attempt * 2),
                      );
                      continue;
                    }
                  }

                  break;
                } catch (e) {
                  debugPrint(
                    'Reward transaction error: $e',
                  );
                  break;
                }
              }

              if (success &&
                  finalTotalCoins != null &&
                  finalAdsCount != null) {

                if (mounted) {
                  setState(() {
                    totalCoins = finalTotalCoins!;
                    adsWatchedCount = finalAdsCount!;
                  });
                }

                await _saveLocalData();
              } else {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Connection problem. Please try again.',
                    ),
                  ),
                );
              }
            } finally {
              _isCollectingReward = false;
            }
          },
        ),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffB8ECFF),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            const SizedBox(height: 20),
            _circleSteps(),
            const SizedBox(height: 10),

            if (!isStepSupported)
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  "⚠️ Step tracking not supported on this device",
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),

            const SizedBox(height: 20),
            _stepConvertRow(),
            const SizedBox(height: 20),
            _convertButtonWithBanner(),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: showLuckySpin,
            child: _roundedBox(
              child: Image.asset('assets/images/image_4.png', width: 28),
            ),
          ),
          _roundedBox(
            child: Row(
              children: [
                Image.asset('assets/images/image_5.png', width: 22),
                const SizedBox(width: 6),
                Text(
                  totalCoins.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundedBox({required Widget child}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(child: child),
    );
  }

  Widget _circleSteps() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 10),
              ),
            ),
            ..._circleTicks(),
            ..._circleNumbers(),
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey.shade300,
              child: Image.asset('assets/images/image_6.png', width: 40),
            ),
            CustomPaint(
              size: const Size(240, 240),
              painter: CircleProgressPainter(
                  (steps / maxSteps).clamp(0.0, 1.0)
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _circleNumbers() => const [
    Positioned(top: 18, child: Text('0')),
    Positioned(top: 55, right: 40, child: Text('10000')),
    Positioned(right: 15, child: Text('17000')),
    Positioned(bottom: 55, right: 40, child: Text('25000')),
    Positioned(bottom: 18, child: Text('35000')),
    Positioned(bottom: 55, left: 40, child: Text('45000')),
    Positioned(left: 15, child: Text('55000')),
    Positioned(top: 55, left: 40, child: Text('70000')),
  ];

  List<Widget> _circleTicks() {
    Widget tick({double? top, double? bottom, double? left, double? right}) {
      return Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: Container(
          width: 6,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
    }

    return [
      tick(top: 22),
      tick(bottom: 22),
      tick(left: 22),
      tick(right: 22),
      tick(top: 55, left: 55),
      tick(top: 55, right: 55),
      tick(bottom: 55, left: 55),
      tick(bottom: 55, right: 55),
    ];
  }

  Widget _stepConvertRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: _infoBox('Steps', steps.toString(), Colors.grey)),
          const SizedBox(width: 10),
          Expanded(child: _infoBox('Coins', coins.toString(), Colors.orange)),
        ],
      ),
    );
  }

  Widget _infoBox(String label, String value, Color color) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          '$label: $value',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _convertButtonWithBanner() {
    return Column(
      children: [

        GestureDetector(
          onTap: coins == 0 ? null : convertCoins,
          child: Container(
            height: 45,
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: coins == 0
                  ? Colors.grey
                  : const Color(0xffF1B938),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                'Convert to Coins',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 15),

        // ===== Banner Ad تحت زر Convert =====
        if (_isBannerReady)
          SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),

      ],
    );
  }

}

// =================== Circle Progress Painter ===================
class CircleProgressPainter extends CustomPainter {
  final double progress;
  CircleProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 12.0;
    final paintBg = Paint()
      ..color = Colors.blue.shade100
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final paintProgress = Paint()
      ..shader =
      const LinearGradient(colors: [Colors.blue, Colors.orange])
          .createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    canvas.drawCircle(center, radius, paintBg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.1415926 / 2,
      2 * 3.1415926 * progress,
      false,
      paintProgress,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =================== Congratulation Screen ===================
class CongratulationScreen extends StatefulWidget {

  final Function() onRewardCollected;

  const CongratulationScreen({
    super.key,
    required this.onRewardCollected,
  });

  @override
  State<CongratulationScreen> createState() => _CongratulationScreenState();
}

class _CongratulationScreenState extends State<CongratulationScreen> {

  final Random _random = Random();

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  bool _adWatched = false;


  DateTime? _lastRewardedLoadAttempt;

  bool _canRequestRewardedLoad() {
    if (_lastRewardedLoadAttempt == null) return true;

    return DateTime.now()
        .difference(_lastRewardedLoadAttempt!)
        .inSeconds >=
        10;
  }


  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  bool _showCollectAnimation = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      _loadRewardedAd();
      _loadBannerAd();
    });
  }

  void _loadRewardedAd() {
    if (_rewardedAd != null) return;

    if (_isAdLoading) return;

    if (!_canRequestRewardedLoad()) return;

    _lastRewardedLoadAttempt = DateTime.now();
    _isAdLoading = true;

    debugPrint('REWARDED: Loading ad...');

    RewardedAd.load(
      adUnitId: 'ca-app-pub-5925712456846655/9841768010',
      request: const AdRequest(),

      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _isAdLoading = false;

          _rewardedAd?.dispose();
          _rewardedAd = ad;

          debugPrint('REWARDED: Ad loaded successfully');

          if (mounted) {
            setState(() {});
          }
        },

        onAdFailedToLoad: (error) {
          _isAdLoading = false;

          debugPrint(
            'REWARDED: Failed to load '
                '${error.code} - ${error.message}',
          );
        },
      ),
    );
  }

  void _loadBannerAd() {
    _bannerAd?.dispose();

    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-5925712456846655/9667012771',
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;

          setState(() {
            _isBannerReady = true;
          });
        },

        onAdFailedToLoad: (ad, error) {
          ad.dispose();

          if (!mounted) return;

          setState(() {
            _isBannerReady = false;
          });


          Future.delayed(const Duration(seconds: 30), () {
            if (mounted) _loadBannerAd();
          });
        },
      ),
    );

    _bannerAd!.load();
  }

  void _showAd() {
    // لو الإعلان بيتحمّل حاليًا، لا تعمل طلب جديد
    if (_isAdLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The ad is still loading. Please wait.'),
        ),
      );
      return;
    }

    // حفظ الإعلان الحالي في متغير مؤقت
    final ad = _rewardedAd;

    // لا يوجد إعلان جاهز
    if (ad == null) {
      // اعمل Load واحد فقط
      _loadRewardedAd();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad is preparing. Please try again.'),
        ),
      );

      return;
    }

    // الإعلان سيتم استخدامه الآن
    // نزيله حتى لا يتم عرضه مرتين
    _rewardedAd = null;

    if (mounted) {
      setState(() {});
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(

      onAdShowedFullScreenContent: (ad) {
        debugPrint('REWARDED: Ad showed');
      },

      onAdDismissedFullScreenContent: (ad) {
        debugPrint('REWARDED: Ad dismissed');

        ad.dispose();

        // تجهيز إعلان واحد فقط للمرة القادمة
        _loadRewardedAd();
      },

      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint(
          'REWARDED: Failed to show '
              '${error.code} - ${error.message}',
        );

        ad.dispose();

        // تجهيز إعلان واحد جديد
        _loadRewardedAd();
      },
    );

    ad.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint(
          'REWARDED: User earned '
              '${reward.amount} ${reward.type}',
        );

        if (!mounted) return;

        setState(() {
          _adWatched = true;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffB8ECFF),
      body: Stack(
        children: [
          // 🪙 Falling Coins Animation
          ...List.generate(15, (index) {
            return TweenAnimationBuilder<double>(
              tween: Tween(
                begin: -100,
                end: MediaQuery.of(context).size.height + 100,
              ),
              duration: Duration(
                seconds: 10 + _random.nextInt(8),
              ),
              curve: Curves.linear,
              builder: (context, value, child) {
                return Positioned(
                  left: _random.nextDouble() *
                      MediaQuery.of(context).size.width,
                  top: value,
                  child: Opacity(
                    opacity: 0.5,
                    child: Transform.rotate(
                      angle: value / 80,
                      child: Icon(
                        Icons.monetization_on,
                        color: Colors.amber,
                        size: 18 + _random.nextInt(20).toDouble(),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          // 🪙 Collect Animation (تطلع لفوق)
          if (_showCollectAnimation)
            ...List.generate(20, (index) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: -350),
                duration: Duration(
                  milliseconds: 1200 + _random.nextInt(800),
                ),
                builder: (context, value, child) {
                  return Positioned(
                    bottom: 180,
                    left: MediaQuery.of(context).size.width / 2 +
                        (_random.nextDouble() * 200 - 100),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        value,
                      ),
                      child: Transform.rotate(
                        angle: value / 20,
                        child: Icon(
                          Icons.paid,
                          color: Colors.amber,
                          size: 25 + _random.nextInt(15).toDouble(),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🎉 Congratulations 🎉',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Column(
                  children: [
                    Text(
                      'Watch Ad to Claim',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '100 Coins',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                if (!_adWatched)
                  ElevatedButton(
                    onPressed: _isAdLoading
                        ? null
                        : _showAd,
                    child: Text(
                      _isAdLoading
                          ? 'Loading Ad...'
                          : 'Watch Ad to Claim Coins',
                    ),
                  ),

                if (_adWatched)
                  ElevatedButton(
                    onPressed: () async {
                      if (_showCollectAnimation) return;

                      setState(() {
                        _showCollectAnimation = true;
                      });

                      await Future.delayed(
                        const Duration(seconds: 2),
                      );

                      if (!context.mounted) return;

                      widget.onRewardCollected();

                      Navigator.pop(context);

                    },
                    child: const Text('Collect 100 Coins'),
                  ),
                const SizedBox(height: 150),
                if (_isBannerReady)
                  SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
          ),
        ],
      ),

    );
  }
}