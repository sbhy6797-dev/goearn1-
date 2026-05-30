import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'surveys_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();

  runApp(const SurveyApp());
}

class SurveyApp extends StatelessWidget {
  const SurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Cairo',
      ),
      home: const SurveyHomePage(),
    );
  }
}

/* ================= DATA ================= */

class SurveyNetwork {
  final String name;
  final String subtitle;
  final String iconPath;
  final String url;

  const SurveyNetwork(
      this.name,
      this.subtitle,
      this.iconPath,
      this.url,
      );
}

final List<SurveyNetwork> networks = const [

  SurveyNetwork(
    'CPX Research',
    'Paid Surveys',
    'assets/images/cpx.png',
    'https://offers.cpx-research.com/index.php?app_id=32761',
  ),

  SurveyNetwork(
    'cpagrip',
    'Earn by Visits',
    'assets/images/cpagrip.png',
    'https://www.cpagrip.com/show.php?u=2528152&id=OFFER_ID&tracking_id=USER_ID',
  ),

  SurveyNetwork(
    'TheoremReach',
    'Surveys',
    'assets/images/theoremreach.png',
    'https://theoremreach.com/respondent_entry/direct?placementId=71b42ce0-8e8d-46b3-8732-e03d0918baa9',
  ),

  SurveyNetwork(
    'MyLead',
    'Offers & Surveys',
    'assets/images/mylead.png',
    'https://reward-me.eu/4cbc0d18-57af-11f1-b2be-129a1c289511',
  ),



  SurveyNetwork(
    'AdMantum',
    'Reward Network',
    'assets/images/admantum.png',

    'https://www.admantum.com/offers?appid=51183&uid=USER_ID',
  ),

  SurveyNetwork(
    'Pollmatic',
    'Offers & Surveys',
    'assets/images/pollmatic.png',
    'https://pollmatic.io/offerwall/5nn2tuj7dys60tdmce803natkrnlzz/USER_ID',
  ),

];


void showCpagripDialog(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF0B1730),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),

        title: const Row(
          children: [
            Icon(Icons.task_alt, color: Colors.green),
            SizedBox(width: 8),
            Text(
              "كيفية الربح",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),

        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [

            Text(
              "اتبع الخطوات التالية:",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 14),

            Text(
              "1️⃣ افتح العرض",
              style: TextStyle(color: Colors.white70),
            ),

            SizedBox(height: 8),

            Text(
              "2️⃣ أكمل جميع الخطوات المطلوبة",
              style: TextStyle(color: Colors.white70),
            ),

            SizedBox(height: 8),

            Text(
              "3️⃣ حمّل التطبيق أو سجّل إذا طُلب منك",
              style: TextStyle(color: Colors.white70),
            ),

            SizedBox(height: 8),

            Text(
              "4️⃣ بعد إكمال العرض ستُضاف العملات تلقائيًا",
              style: TextStyle(color: Colors.greenAccent),
            ),

            SizedBox(height: 16),

            Text(
              "⚠️ الضغط فقط لا يمنح مكافأة",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        actions: [

          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              "إلغاء",
              style: TextStyle(color: Colors.white70),
            ),
          ),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(context);

              final uri = Uri.parse(url);

              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text("ابدأ الآن"),
          ),
        ],
      );
    },
  );
}

/* ================= HOME ================= */

class SurveyHomePage extends StatefulWidget {
  const SurveyHomePage({super.key});

  @override
  State<SurveyHomePage> createState() => _SurveyHomePageState();
}

class _SurveyHomePageState extends State<SurveyHomePage> {

  BannerAd? _topBannerAd;
  BannerAd? _bottomBannerAd;

  @override
  void initState() {
    super.initState();
    _loadTopBannerAd();
    _loadBottomBannerAd();
  }

  void _loadTopBannerAd() {
    _topBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5925712456846655/9667012771',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _topBannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    _topBannerAd!.load();
  }

  void _loadBottomBannerAd() {
    _bottomBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5925712456846655/9667012771',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _bottomBannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    _bottomBannerAd!.load();
  }

  @override
  void dispose() {
    _topBannerAd?.dispose();
    _bottomBannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {



    return Scaffold(
      backgroundColor: const Color(0xFF0B319A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF071B3C),
              Color(0xFF85A0E4),
              Color(0xFF12A4BD),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 18),

              /* ================= TITLE ================= */

              const Text(
                'اكمل الاستطلاعات واربح المكافآت ✨',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'اختر أي شبكة لبدء تحقيق المكافآت',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 24),

              /* ================= GRID ================= */

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),

                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),

                    child: Column(
                      children: [

                        /* ===== الصف الأول ===== */

                        Row(
                          children: [

                            Expanded(
                              child: SurveyCard(
                                network: networks[0],
                              ),
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              child: SurveyCard(
                                network: networks[1],
                              ),
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              child: SurveyCard(
                                network: networks[2],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        /* ===== البانر في النص ===== */

                        if (_topBannerAd != null)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                ),
                              ],
                            ),

                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),

                              child: SizedBox(
                                height:
                                _topBannerAd!.size.height.toDouble(),

                                width: double.infinity,

                                child: Center(
                                  child: SizedBox(
                                    height:
                                    _topBannerAd!.size.height.toDouble(),

                                    width:
                                    _topBannerAd!.size.width.toDouble(),

                                    child: AdWidget(
                                      ad: _topBannerAd!,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),

                        /* ===== الصف الثاني ===== */

                        Row(
                          children: [

                            Expanded(
                              child: SurveyCard(
                                network: networks[3],
                              ),
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              child: SurveyCard(
                                network: networks[4],
                              ),
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              child: SurveyCard(
                                network: networks[5],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              if (_topBannerAd != null)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 12,
                    left: 12,
                    right: 12,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: _bottomBannerAd!.size.height.toDouble(),
                        width: double.infinity,
                        child: Center(
                          child: SizedBox(
                            height: _bottomBannerAd!.size.height.toDouble(),
                            width: _bottomBannerAd!.size.width.toDouble(),
                            child: AdWidget(ad: _bottomBannerAd!),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }
}

/* ================= CARD ================= */

class SurveyCard extends StatelessWidget {
  final SurveyNetwork network;

  const SurveyCard({
    super.key,
    required this.network,
  });

  Future<void> _openUrl() async {
    final Uri uri = Uri.parse(network.url);

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),

      onTap: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        String url = network.url;

        // ================= CPX =================
        if (network.name == 'CPX Research') {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          final userId = user.uid;

          final appKey = "PUT_YOUR_APP_KEY_HERE";

          final raw = "$userId-$appKey";
          final secureHash = md5.convert(utf8.encode(raw)).toString();

          url =
          "https://offers.cpx-research.com/index.php"
              "?app_id=32761"
              "&ext_user_id=$userId"
              "&secure_hash=$secureHash";
        }


        // ================= cpagrip =================


        else if (network.name == 'cpagrip') {
          final url = 'https://www.cpagrip.com/show.php'
              '?u=2528152'
              '&id=offer_id'
              '&tracking_id=${user.uid}';

          showCpagripDialog(context, url);
          return;
        }


        // ================= TheoremReach =================
        else if (network.name == 'TheoremReach') {

          url =
          'https://theoremreach.com/respondent_entry/direct'
              '?api_key=2c0bb35a2a332fb33c559e24003e'
              '&user_id=${user.uid}'
              '&external_id=${user.uid}'
              '&partner_user_id=${user.uid}'
              '&transaction_id=${DateTime.now().millisecondsSinceEpoch}'
              '&partner_id=de73338e-f29f-4cfb-9cd6-7926f258fb7d'
              '&currency_name_plural=Coins'
              '&currency_name_singular=Coin'
              '&exchange_rate=100';
        }

        // ================= MyLead =================
        else if (network.name == 'MyLead') {

          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          final userId = user.uid;

          url =
          'https://reward-me.eu/4cbc0d18-57af-11f1-b2be-129a1c289511'
              '?player_id=$userId';

          final uri = Uri.parse(url);

          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );

          return;
        }


// ================= AdMantum =================
        else if (network.name == 'AdMantum') {

          url =
          'https://www.admantum.com/offers'
              '?appid=51183'
              '&uid=${user.uid}'
              '&subid=flutter_app';

          final uri = Uri.parse(url);

          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );

          return;
        }



        // ================= Pollmatic =================
        else if (network.name == 'Pollmatic') {

          url =
          'https://pollmatic.io/offerwall/'
              '5nn2tuj7dys60tdmce803natkrnlzz/'
              '${FirebaseAuth.instance.currentUser!.uid}';
        }



        // ================= فتح الصفحة =================

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurveysPage(
              title: network.name,
              url: url,
            ),
          ),
        );
      },

      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),

          /* ================= CARD COLOR ================= */

          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0B1730),
              const Color(0xFF0A1428).withValues(alpha: 0.98),
            ],
          ),

          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1.2,
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),

        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 14,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              /* ================= ICON ================= */

              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    network.iconPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}