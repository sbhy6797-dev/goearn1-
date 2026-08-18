import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:confetti/confetti.dart';


class CongratulationScreen extends StatefulWidget {
  final int reward;
  final Function(int) onClaim;

  const CongratulationScreen({
    super.key,
    required this.reward,
    required this.onClaim,

  });

  @override
  State<CongratulationScreen> createState() => _CongratulationScreenState();
}

class _CongratulationScreenState extends State<CongratulationScreen>
    with SingleTickerProviderStateMixin {
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  bool _adWatched = false;
  bool _rewardEarned = false;

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

  late ConfettiController _centerConfetti;
  late ConfettiController _leftConfetti;
  late ConfettiController _rightConfetti;

  late AnimationController _cardController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;


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
    // يوجد إعلان جاهز
    if (_rewardedAd != null) {
      return;
    }

    // يوجد طلب تحميل حالي
    if (_isAdLoading) {
      return;
    }

    // منع إرسال Requests متقاربة جدًا
    if (!_canRequestRewardedLoad()) {
      return;
    }

    // تسجيل وقت آخر محاولة تحميل
    _lastRewardedLoadAttempt = DateTime.now();

    _isAdLoading = true;

    debugPrint('REWARDED: Requesting ad...');

    RewardedAd.load(
      adUnitId: 'ca-app-pub-5925712456846655/9841768010',
      request: const AdRequest(),

      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _isAdLoading = false;

          // التخلص من أي إعلان قديم بالخطأ
          _rewardedAd?.dispose();

          _rewardedAd = ad;

          debugPrint('REWARDED: Ad loaded successfully');

          if (mounted) {
            setState(() {});
          }
        },

        onAdFailedToLoad: (error) {
          _isAdLoading = false;
          _rewardedAd = null;

          debugPrint(
            'REWARDED: Failed to load '
                '${error.code} - ${error.message}',
          );

          // Retry بعد 45 ثانية فقط
          Future.delayed(const Duration(seconds: 45), () {
            if (!mounted) return;

            if (_rewardedAd == null && !_isAdLoading) {
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

          _isBannerReady = false;

          debugPrint(
            'BANNER: Failed to load '
                '${error.code} - ${error.message}',
          );

          Future.delayed(const Duration(seconds: 45), () {
            if (!mounted) return;

            if (!_isBannerReady && _bannerAd == null) {
              _loadBannerAd();
            }
          });
        },
      ),
    )..load();
  }

  // =================  =================
  void _showAd() {
    final ad = _rewardedAd;

    // لا يوجد إعلان جاهز
    if (ad == null) {
      debugPrint('REWARDED: No ad ready');

      if (!_isAdLoading) {
        _loadRewardedAd();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ad is preparing. Please try again shortly.',
            ),
          ),
        );
      }

      return;
    }

    // إزالة الإعلان قبل عرضه
    _rewardedAd = null;

    if (mounted) {
      setState(() {});
    }

    ad.fullScreenContentCallback =
        FullScreenContentCallback(

          onAdShowedFullScreenContent: (ad) {
            debugPrint('REWARDED: Ad showed');
          },

          onAdDismissedFullScreenContent: (ad) {
            debugPrint('REWARDED: Ad dismissed');

            ad.dispose();

            // تجهيز إعلان واحد للمشاهدة القادمة
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
        if (_rewardEarned) return;

        _rewardEarned = true;

        debugPrint(
          'REWARDED: User earned '
              '${reward.amount} ${reward.type}',
        );

        if (!mounted) return;

        setState(() {
          _adWatched = true;
        });

        _centerConfetti.play();
        _leftConfetti.play();
        _rightConfetti.play();
      },
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
                '🎉 Congratulations ',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              Text(
                'You won ${widget.reward} Coins',
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
                          color: Colors.orange.withValues(alpha: 0.6),
                          blurRadius: 30,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Coins Reward",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          "${widget.reward}",
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          "Watch the ad to claim your reward",
                          style: TextStyle(
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
                  child: const Text(
                    'Watch Ad to Claim Coins',
                  ),
                ),

              if (_adWatched)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () {
                    widget.onClaim(widget.reward);

                    Navigator.pop(context);
                  },
                  child: const Text('Claim Coins'),
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