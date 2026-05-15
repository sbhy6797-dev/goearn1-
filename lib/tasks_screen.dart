import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'surveys_page.dart';
import 'package:firebase_auth/firebase_auth.dart';


void main() {
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
      'https://offers.cpx-research.com/index.php?app_id=32761&ext_user_id=USER_ID',
  ),

  SurveyNetwork(
    'BitLabs',
    'Offerwall',
    'assets/images/bitlabs.png',
    'https://web.bitlabs.ai/?uid=USER_ID&token=a7de60e1-8532-4d71-bc39-35ab560adfc6',
  ),

  SurveyNetwork(
    'TheoremReach',
    'Surveys',
    'assets/images/theoremreach.png',
    'https://theoremreach.com/respondent_entry/direct?placementId=71b42ce0-8e8d-46b3-8732-e03d0918baa9',
  ),

  SurveyNetwork(
    'Pollfish',
    'Mobile Surveys',
    'assets/images/pollfish.png',
    'https://www.pollfish.com',
  ),

  SurveyNetwork(
    'TapResearch',
    'Rewarded Surveys',
    'assets/images/tapresearch.png',
    'https://www.tapresearch.com',
  ),

  SurveyNetwork(
    'AdGem',
    'Offerwall',
    'assets/images/adgem.png',
    'https://wall.adgem.com/USER_ID',
  ),

  SurveyNetwork(
    'KiwiWall',
    'Offers & Surveys',
    'assets/images/kiwiwall.png',
    'https://kiwiwall.io',
  ),

  SurveyNetwork(
    'AdMantum',
    'Reward Network',
    'assets/images/admantum.png',

      'https://www.admantum.com/offers?appid=51125&uid=USER_ID',
  ),
];

/* ================= HOME ================= */

class SurveyHomePage extends StatelessWidget {
  const SurveyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF031128),
              Color(0xFF020817),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: networks.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (context, index) {
                      return SurveyCard(network: networks[index]);
                    },
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

            url =
            'https://offers.cpx-research.com/index.php'
                '?app_id=32761'
                '&ext_user_id=${user.uid}';
          }

          // ================= BitLabs =================
          else if (network.name == 'BitLabs') {

            url =
            'https://web.bitlabs.ai/'
                '?uid=${user.uid}'
                '&token=a7de60e1-8532-4d71-bc39-35ab560adfc6';
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
// ================= AdMantum =================
          else if (network.name == 'AdMantum') {

            url =
            'https://www.admantum.com/offers'
                '?appid=51125'
                '&uid=${user.uid}';
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
              const Color(0xFF0A1428).withOpacity(0.98),
            ],
          ),

          border: Border.all(
            color: Colors.white.withOpacity(0.06),
            width: 1.2,
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.blue.withOpacity(0.06),
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
                      color: Colors.white.withOpacity(0.08),
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