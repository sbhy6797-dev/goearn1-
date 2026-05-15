import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'congrats_dialog.dart';

class LuckySpinScreen extends StatefulWidget {

  final Function(int) onRewardCollected;

  const LuckySpinScreen({
    super.key,
    required this.onRewardCollected,
  });

  @override
  State<LuckySpinScreen> createState() => _LuckySpinScreenState();
}

class _LuckySpinScreenState extends State<LuckySpinScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;

  double _currentAngle = 0.0;
  int _spinCounter = 0;
  int _selectedIndex = 0;
  final int totalSections = 8;
  final double sectionAngle = 2 * pi / 8;

  bool _isSpinning = false;

  String rewardText = "";

  // ================= Banner =================

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {

    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _controller.addListener(() {

      setState(() {

        _currentAngle = _controller.value * 10 * 2 * pi;

      });

    });

    _controller.addStatusListener((status) {

      if (status == AnimationStatus.completed) {

        _controller.reset();

        _isSpinning = false;

        _calculateReward();

      }

    });

    _loadBannerAd();

  }

  // ================= Banner Ad =================

  void _loadBannerAd() {
    _bannerAd?.dispose();

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5925712456846655/9667012771',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() {
            _isBannerLoaded = true;
          });
        },

        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isBannerLoaded = false;


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

  @override
  void dispose() {

    _controller.dispose();

    _bannerAd?.dispose();

    super.dispose();

  }

  // ================= Spin =================

  void _spinWheel() {

    if (_isSpinning) return;

    _spinCounter++;

    if (_spinCounter % 3 == 1) {
      _selectedIndex = Random().nextInt(3);
    }
    else if (_spinCounter % 3 == 2) {
      _selectedIndex = 3 + Random().nextInt(3);
    }
    else {
      _selectedIndex = 6 + Random().nextInt(2);
    }

    _isSpinning = true;

    double targetAngle =
        _currentAngle +
            (6 * 2 * pi) +
            (_selectedIndex * sectionAngle) +
            (sectionAngle / 2);

    _controller.animateTo(
      targetAngle / (10 * 2 * pi),
      duration: const Duration(seconds: 5),
      curve: Curves.decelerate,
    );

  }

  // ================= Reward =================

  void _calculateReward() {

    int index = _selectedIndex;

    int speed = 3;
    Duration duration = const Duration(minutes: 10);

    if (index <= 2) {

      speed = 3;
      duration = const Duration(minutes: 10);
      rewardText = "🚀 Speed Boost x3";

    }

    else if (index <= 5) {

      speed = 5;
      duration = const Duration(minutes: 15);
      rewardText = "🚀 Speed Boost x5";

    }

    else {

      speed = 7;
      duration = const Duration(minutes: 20);
      rewardText = "🚀 Speed Boost x7";

    }

    setState(() {});

    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (context) => CongratulationScreen(

          reward: 0,

          speed: speed,

          duration: duration,

          onClaim: (_) {},

          onSpeedBoost: (speed, duration) {

            widget.onRewardCollected(speed);

          },

        ),

      ),

    );

  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text('Lucky Spin'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),

      backgroundColor: const Color(0xffB8ECFF),

      body: Center(

        child: SingleChildScrollView(

          child: Column(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              // ===== Wheel =====

              Stack(

                alignment: Alignment.center,

                children: [

                  Transform.rotate(

                    angle: _currentAngle,

                    child: Image.asset(
                      'assets/images/Frame 5(2).png',
                      width: 300,
                    ),

                  ),

                  const Positioned(

                    top: 10,

                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 60,
                      color: Colors.red,
                    ),

                  ),

                ],

              ),

              const SizedBox(height: 30),

              // ===== Spin Button =====

              GestureDetector(

                onTap: _spinWheel,

                child: Container(

                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),

                  decoration: BoxDecoration(

                    color: Colors.orange,

                    borderRadius: BorderRadius.circular(30),

                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0,3),
                      )
                    ],

                  ),

                  child: const Text(

                    'SPIN',

                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),

                  ),

                ),

              ),

              const SizedBox(height: 25),

              if (rewardText.isNotEmpty)

                Text(

                  rewardText,

                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),

                ),

              const SizedBox(height: 25),

              // ===== Banner =====

              if (_isBannerLoaded)

                SizedBox(

                  height: _bannerAd!.size.height.toDouble(),

                  width: _bannerAd!.size.width.toDouble(),

                  child: AdWidget(ad: _bannerAd!),

                ),

              const SizedBox(height: 20),

            ],

          ),

        ),

      ),

    );

  }

}