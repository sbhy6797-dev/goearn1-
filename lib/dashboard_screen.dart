import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'payment_screen.dart';
import 'settings_screen.dart';
import 'lucky_spin_screen.dart';
import 'main.dart';
// ================= Dashboard Screen =================
class DashboardScreen extends StatefulWidget {
  final int totalCoins;
  const DashboardScreen({super.key, required this.totalCoins});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with RouteAware {

  int getRemainingSeconds() {
    if (boostEndTime == null) return 0;

    final remaining = boostEndTime!.difference(DateTime.now()).inSeconds;

    return remaining > 0 ? remaining : 0;
  }

  Timer? _uiTimer;
  int steps = 0;
  int coins = 0;
  int totalCoins = 0;
  int lastSensorSteps = 0;


  List<int> speedLevels = [3, 5, 7];

  int initialSteps = 0;
  bool isFirstUpdate = true;

  late StreamSubscription<StepCount> _stepSubscription;
  late Stream<StepCount> _stepCountStream;

  final int maxSteps = 70000;
  final int stepPerCoin = 100;

  late final DocumentReference userDoc;
  late final String uid;
  Timer? _debounce;

  // ===== Speed Boost =====
  double boostMultiplier = 1.0;

  DateTime? boostEndTime;
  int remainingSeconds = 0;

  String lastSpinText = "";
  int speedLevel = 0;


  // ===== Ad Tracking =====
  int adsWatchedCount = 0;


  DateTime? lastAdTime;


// ===== Interstitial Ad =====
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  @override
  void initState() {
    super.initState();
    _loadLocalData();

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    totalCoins = widget.totalCoins;
    final user = FirebaseAuth.instance.currentUser!;
    uid = user.uid;
    userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

    initApp();


    Future.delayed(Duration(milliseconds: 800), () {
      _restoreTimerFromFirebase();
    });


    _loadInterstitial();
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
    _restoreTimerFromFirebase();
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
    var status = await Permission.activityRecognition.status;
    if (!status.isGranted) {
      status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        openAppSettings();
        return;
      }
    }

    await loadData();
    initPedometer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCongratulationScreen();
    });
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          setState(() {});
        },
        onAdFailedToLoad: (error) {
          _isInterstitialReady = false;

          Future.delayed(const Duration(seconds: 3), () {
            _loadInterstitial();
          });
        },
      ),
    );
  }

  void _showInterstitial() async {
    if (_isInterstitialReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(

        onAdDismissedFullScreenContent: (ad) async {
          ad.dispose();
          _loadInterstitial();

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          DocumentSnapshot snapshot = await userDoc.get();
          int adsToday = 0;

          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            adsToday = data['adsWatchedToday'] ?? 0;
          }

          adsToday++;
          adsWatchedCount++;

          await userDoc.set({
            'adsWatchedToday': adsToday,
            'lastAdDate': Timestamp.fromDate(today),
          }, SetOptions(merge: true));
        },

        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitial();
        },
      );

      _interstitialAd!.show();
      _interstitialAd = null;
      _isInterstitialReady = false;
    }
  }


  Future<void> loadData() async {
    try {
      final snapshot = await userDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          steps = data['steps'] ?? 0;
          coins = data['coins'] ?? 0;
          totalCoins = data['totalCoins'] ?? 0;
          initialSteps = data['initialSteps'] ?? 0;
          isFirstUpdate = data['isFirstUpdate'] ?? true;
          adsWatchedCount = data['adsWatchedToday'] ?? 0;
        });

        Timestamp? boostTime = data['boostEndTime'];

        if (boostTime != null) {

          DateTime endTime = boostTime.toDate();

          final remaining = endTime.difference(DateTime.now()).inSeconds;

          if (remaining > 0) {

            setState(() {
              boostEndTime = endTime;
              remainingSeconds = remaining;
            });

            activateSpeed(
              data['boostMultiplier'] ?? 3,
              remaining,
              isRestore: true,
            );

          } else {

            if (remaining <= 0) {
              boostEndTime = null;
              remainingSeconds = 0;
              boostMultiplier = 1.0;
            }

          }
        }
      }
    } catch (e) {
      print('Error loading Firebase data: $e');
    }
  }

  Future<void> _restoreTimerFromFirebase() async {
    try {
      final snapshot = await userDoc.get();
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      Timestamp? boostTime = data['boostEndTime'];

      if (boostTime == null) return;

      DateTime endTime = boostTime.toDate();
      final remaining = endTime.difference(DateTime.now()).inSeconds;

      if (remaining > 0) {
        boostEndTime = endTime;

        activateSpeed(
          (data['boostMultiplier'] ?? 3),
          remaining,
          isRestore: true,
        );


        setState(() {
          remainingSeconds = remaining;
        });

      } else {
        setState(() {
          boostEndTime = null;
          boostMultiplier = 1.0;
          remainingSeconds = 0;
        });
      }
    } catch (e) {
      print("Timer restore error: $e");
    }
  }

  void initPedometer() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepSubscription =
        _stepCountStream.listen(onStepCount, onError: onStepError);
  }

  void onStepCount(StepCount event) {

    if (lastSensorSteps == 0) {
      lastSensorSteps = event.steps;
    }

    int diff = event.steps - lastSensorSteps;

    if (diff < 0) {
      lastSensorSteps = event.steps;
      return;
    }

    if (diff > 0) {
      setState(() {
        steps = (steps + diff).clamp(0, maxSteps);
        coins = ((steps * boostMultiplier) ~/ stepPerCoin) * 10;
      });

      lastSensorSteps = event.steps;

      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 5), () async {
        await _saveLocalData();
        await _updateFirebase();
      });
    }
  }


  void onStepError(Object error) {
    print("Step Error: $error");
  }

  Future<void> convertCoins() async {
    if (coins == 0) return;

    setState(() {
      totalCoins += coins;
      coins = 0;
      steps = 0;
      initialSteps = 0;
      isFirstUpdate = true;
    });
    await _saveLocalData();
    await _updateFirebase();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DocumentSnapshot snapshot = await userDoc.get();
    int adsToday = 0;

    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>;
      Timestamp? lastAdDate = data['lastAdDate'];

      if (lastAdDate != null &&
          lastAdDate.toDate().year == today.year &&
          lastAdDate.toDate().month == today.month &&
          lastAdDate.toDate().day == today.day) {
        adsToday = data['adsWatchedToday'] ?? 0;
      } else {
        adsToday = 0;
      }
    }

    if (adsToday < 20 &&
        _isInterstitialReady &&
        (lastAdTime == null ||
            DateTime.now().difference(lastAdTime!).inSeconds > 20)) {

      lastAdTime = DateTime.now();

      Future.delayed(const Duration(milliseconds: 500), () {
        _showInterstitial();
      });
    }
  }

  Future<void> _updateFirebase() async {
    try {

      await _saveLocalData(); // ✔
      await userDoc.set({
        'steps': steps,
        'coins': coins,
        'totalCoins': totalCoins,
        'initialSteps': initialSteps,
        'isFirstUpdate': isFirstUpdate,
        'adsWatchedToday': adsWatchedCount,


        'boostEndTime': boostEndTime != null
            ? Timestamp.fromDate(boostEndTime!)
            : null,
        'boostMultiplier': boostMultiplier,

      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating Firebase: $e');
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
    final prefs = await SharedPreferences.getInstance();
    lastSensorSteps = prefs.getInt('lastSensorSteps') ?? 0;
    setState(() {
      steps = prefs.getInt('steps') ?? 0;
      coins = prefs.getInt('coins') ?? 0;
      totalCoins = prefs.getInt('totalCoins') ?? totalCoins;
      initialSteps = prefs.getInt('initialSteps') ?? 0;
      isFirstUpdate = prefs.getBool('isFirstUpdate') ?? true;
    });
  }


  void activateSpeed(int speed, int secondsToAdd, {bool isRestore = false}) async {
    if (!isRestore) {
      if (boostEndTime != null && boostEndTime!.isAfter(DateTime.now())) {
        boostEndTime = boostEndTime!.add(Duration(seconds: secondsToAdd));
      } else {
        boostEndTime = DateTime.now().add(Duration(seconds: secondsToAdd));
      }

      await userDoc.set({
        'boostEndTime': Timestamp.fromDate(boostEndTime!),
        'boostMultiplier': speed,
      }, SetOptions(merge: true));
    }

    setState(() {
      boostMultiplier = speed.toDouble();
    });
  }


  @override
  void dispose() {
    _uiTimer?.cancel();
    routeObserver.unsubscribe(this);
    _stepSubscription.cancel();
    _debounce?.cancel();

    super.dispose();
  }

  void showLuckySpin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LuckySpinScreen(
          onRewardCollected: (reward) {

            int currentIndex =
            speedLevels.indexOf(boostMultiplier.toInt());

            if (currentIndex == -1) {
              currentIndex = 0;
            } else {
              currentIndex =
                  (currentIndex + 1) % speedLevels.length;
            }

            int newSpeed = speedLevels[currentIndex];

            setState(() {
              boostMultiplier = newSpeed.toDouble();
              lastSpinText = "🚀 Speed Boost x$newSpeed Activated";
            });

            activateSpeed(newSpeed, 60);
          },
        ),
      ),
    );
  }

  void showAdSpeedBoost() {

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CongratulationScreen(

          reward: 0,

          speed: 3,

          duration: const Duration(minutes: 2),

          onClaim: (reward) {},

          onSpeedBoost: (speed, duration) {

            adsWatchedCount++;
            _updateFirebase();

            activateSpeed(3, duration.inSeconds);

          },

        ),
      ),
    );

  }

  void _showCongratulationScreen() {

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CongratulationScreen(

          reward: 0,

          speed: 3,

          duration: const Duration(minutes: 2),

          onClaim: (reward) {},

          onSpeedBoost: (speed, duration) {

            adsWatchedCount++;
            _updateFirebase();

            activateSpeed(3, duration.inSeconds);

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
            if (boostEndTime != null && remainingSeconds > 1)
              Column(
                children: [
                  Text(
                    "🚀 Boost x${boostMultiplier.toInt()} Active",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    "Time remaining: ${getRemainingSeconds()} s | Ads watched: $adsWatchedCount",
                  ),
                ],
              ),
            const SizedBox(height: 20),
            _stepConvertRow(),
            const SizedBox(height: 20),
            _convertButtonWithBanner(),
            const Spacer(),
            _bottomNav(),
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
                  ((steps * boostMultiplier) / maxSteps).clamp(0.0, 1.0)),
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
    Positioned(bottom: 18, child: Text('30000')),
    Positioned(bottom: 55, left: 40, child: Text('35000')),
    Positioned(left: 15, child: Text('40000')),
    Positioned(top: 55, left: 40, child: Text('50000')),
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
              color: coins == 0 ? Colors.grey : const Color(0xffF1B938),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                'Convert to Coins',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomNav() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Image.asset('assets/images/image_7.png', width: 40),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentScreen()),
              );
            },
            child: Image.asset('assets/images/image_8.png', width: 40),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        SettingsScreen(totalCoins: totalCoins)),
              );
            },
            child: Image.asset('assets/images/image_9.png', width: 40),
          ),
        ],
      ),
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

  final int reward;
  final int speed;
  final Duration duration;

  final Function(int) onClaim;
  final Function(int, Duration) onSpeedBoost;

  const CongratulationScreen({
    super.key,
    required this.reward,
    required this.speed,
    required this.duration,
    required this.onClaim,
    required this.onSpeedBoost,
  });

  @override
  State<CongratulationScreen> createState() => _CongratulationScreenState();
}

class _CongratulationScreenState extends State<CongratulationScreen> {
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  bool _adWatched = false;
  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
    _loadBannerAd();
  }

  void _loadRewardedAd() {
    if (_isAdLoading) return;
    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
          setState(() {});
        },
        onAdFailedToLoad: (_) {
          _isAdLoading = false;
        },
      ),
    );
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print(error);
        },
      ),
    );

    _bannerAd!.load();
  }

  void _showAd() {
    if (_rewardedAd == null) return;

    _rewardedAd!.show(
      onUserEarnedReward: (_, __) {
        setState(() {
          _adWatched = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffB8ECFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🎉 Congratulations!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Watch ad to get temporary speed boost 🚀',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 40),
            if (!_adWatched)
              ElevatedButton(
                onPressed: _rewardedAd == null ? null : _showAd,
                child: const Text('Watch Ad to activate speed boost'),
              ),
            if (_adWatched)
              ElevatedButton(
                onPressed: () {
                  widget.onSpeedBoost(widget.speed, widget.duration);
                  Navigator.pop(context);
                },
                child: const Text('Activate speed boost 🚀'),
              ),
            const SizedBox(height: 150),
            if (_isBannerReady)
              Container(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }
}