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

  @override
  void initState() {
    super.initState();

    _loadRewardedAd();
    _loadBannerAd();

    _centerConfetti =
        ConfettiController(duration: const Duration(seconds: 5));
  }

  // ================= AD NAME =================
  String _getAdName(int speed) {
    switch (speed) {
      case 3:
        return "Ad 1";
      case 5:
        return "Ad 2";
      case 7:
        return "Ad 3";
      default:
        return "Ad";
    }
  }

  // ================= LOAD REWARDED AD =================
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
          _rewardedAd = null;
          Future.delayed(const Duration(seconds: 5), _loadRewardedAd);
        },
      ),
    );
  }

  // ================= SHOW AD =================
  void _showAd() {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback =
        FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            _onAdCompleted();
            ad.dispose();
            _rewardedAd = null;
            _loadRewardedAd();
          },
          onAdFailedToShowFullScreenContent: (ad, _) {
            ad.dispose();
            _rewardedAd = null;
            _loadRewardedAd();
          },
        );

    _rewardedAd!.show(onUserEarnedReward: (_, __) {});
  }

  // ================= AD COMPLETED =================
  void _onAdCompleted() {
    setState(() => _adWatched = true);
    _centerConfetti.play();
  }

  // ================= ASK USER =================
  void _askToWatchAd() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Watch Ad?"),
        content: Text(
          "Watch ${_getAdName(widget.speed)} to activate x${widget.speed} boost?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showAd();
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  // ================= BANNER =================
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerReady = true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
    _centerConfetti.dispose();
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

              const Text(
                '🎉 Congratulations!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              Text(
                'You won x${widget.speed} Speed Boost 🚀',
                style: const TextStyle(fontSize: 22),
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _adWatched ? null : _askToWatchAd,
                child: Text(
                  _adWatched
                      ? "Already Activated"
                      : "Watch Ad to Activate",
                ),
              ),

              const SizedBox(height: 15),

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
                  child: const Text("Activate 🚀"),
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
            numberOfParticles: 40,
          ),
        ],
      ),
    );
  }
}
