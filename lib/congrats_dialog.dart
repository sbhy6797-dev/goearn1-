import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:confetti/confetti.dart';


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

class _CongratulationScreenState extends State<CongratulationScreen>
    with SingleTickerProviderStateMixin {
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  bool _adWatched = false;

  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  late ConfettiController _centerConfetti;
  late ConfettiController _leftConfetti;
  late ConfettiController _rightConfetti;

  late AnimationController _cardController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;



  String getAdName(int speed) {
    if (speed == 3) return "Ad 1";
    if (speed == 5) return "Ad 2";
    if (speed == 7) return "Ad 3";
    return "Ad";
  }
  Color getSpeedColor(int speed) {
    if (speed == 3) return Colors.blue;
    if (speed == 5) return Colors.green;
    if (speed == 7) return Colors.amber;
    return Colors.orange;
  }

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
    _loadBannerAd();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeIn),
    );


    _cardController.forward();
    _centerConfetti =
        ConfettiController(duration: const Duration(seconds: 5));
    _leftConfetti =
        ConfettiController(duration: const Duration(seconds: 5));
    _rightConfetti =
        ConfettiController(duration: const Duration(seconds: 5));
  }

  // ==============  =================
  void _loadRewardedAd() {
    if (_isAdLoading) return;

    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: 'ca-app-pub-5925712456846655/9841768010',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
          if (!mounted) return;
          setState(() {});
        },
        onAdFailedToLoad: (error) {
          _isAdLoading = false;
          _rewardedAd = null;
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _loadRewardedAd();
            }
          });
        },
      ),
    );
  }

  // ================= Banner =================
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-5925712456846655/9667012771',
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() {
            _isBannerReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();

          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _loadBannerAd();
            }
          });
        },
      ),
    )..load();
  }

  // =================  =================
  void _showAd() {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        setState(() {
          _adWatched = true;
        });


        _centerConfetti.play();
        _leftConfetti.play();
        _rightConfetti.play();

        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {},
    );
  }


  List<Widget> _buildBalloons() {
    return List.generate(12, (index) {
      return Positioned(
        bottom: 0,
        left: 10.0 + (index * 25),
        child: TweenAnimationBuilder(
          tween: Tween(begin: 0.0, end: -600.0),
          duration: Duration(seconds: 3 + index % 3),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, value),
              child: Text(
                ['🎈', '🎉', '✨', '🎊'][index % 4],
                style: const TextStyle(fontSize: 35),
              ),
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
    _cardController.dispose();
    _centerConfetti.dispose();
    _leftConfetti.dispose();
    _rightConfetti.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffB8ECFF),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),

              const Text(
                '🎉 Congratulations!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              Text(
                'You won x${widget.speed} Speed Boost 🚀',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: getSpeedColor(widget.speed).withValues(alpha: 0.6),
                          blurRadius: 30,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "🚀 Speed Boost",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: getSpeedColor(widget.speed),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          "x${widget.speed}",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: getSpeedColor(widget.speed),
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "${getAdName(widget.speed)} Reward",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              if (!_adWatched)
                ElevatedButton(
                  onPressed: _rewardedAd == null ? null : _showAd,
                  child: Text(
                    'Watch ${getAdName(widget.speed)} to activate x${widget.speed}',
                  ),
                ),

              if (_adWatched)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () {
                    widget.onSpeedBoost(
                      widget.speed,
                      widget.duration,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Activate 🚀'),
                ),

              const SizedBox(height: 80),

              if (_isBannerReady)
                SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),


          ConfettiWidget(
            confettiController: _centerConfetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            emissionFrequency: 0.2,
            numberOfParticles: 50,
            maxBlastForce: 30,
            minBlastForce: 15,
            gravity: 0.2,
          ),

          Align(
            alignment: Alignment.centerLeft,
            child: ConfettiWidget(
              confettiController: _leftConfetti,
              blastDirection: 0,
              emissionFrequency: 0.1,
              numberOfParticles: 30,
            ),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: ConfettiWidget(
              confettiController: _rightConfetti,
              blastDirection: 3.14,
              emissionFrequency: 0.1,
              numberOfParticles: 30,
            ),
          ),


          ..._buildBalloons(),
        ],
      ),
    );
  }
}
