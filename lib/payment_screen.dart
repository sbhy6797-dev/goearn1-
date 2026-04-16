import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'withdraw_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int totalCoins = 0;

  final String uid = FirebaseAuth.instance.currentUser!.uid;
  DocumentReference get userDoc =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  final List<Map<String, dynamic>> payments = [
    {"type": "paypal", "amount": 6, "coins": 90000, "image": "assets/images/paypal.png", "currency": "\$"},
    {"type": "paypal", "amount": 4, "coins": 70000, "image": "assets/images/paypal.png", "currency": "\$"},
    {"type": "paypal", "amount": 2, "coins": 50, "image": "assets/images/paypal.png", "currency": "\$"},
    {"type": "fawry", "amount": 200, "coins": 90000, "image": "assets/images/fawry.png", "currency": "ج"},
    {"type": "fawry", "amount": 150, "coins": 70000, "image": "assets/images/fawry.png", "currency": "ج"},
    {"type": "fawry", "amount": 100, "coins": 50000, "image": "assets/images/fawry.png", "currency": "ج"},
    {"type": "vodafone", "amount": 200, "coins": 90000, "image": "assets/images/vodafone.png", "currency": "ج"},
    {"type": "vodafone", "amount": 150, "coins": 70000, "image": "assets/images/vodafone.png", "currency": "ج"},
    {"type": "vodafone", "amount": 100, "coins": 50, "image": "assets/images/vodafone.png", "currency": "ج"},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserCoins();
    _loadBannerAd();
  }

  Future<void> _loadUserCoins() async {
    final snapshot = await userDoc.get();
    if (snapshot.exists) {
      setState(() {
        totalCoins = snapshot['totalCoins'] ?? 0;
      });
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerLoaded = true),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    )..load();
  }

  void handleWithdraw(Map<String, dynamic> item) async {
    if (totalCoins < item["coins"]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your balance is insufficient. Earn more coins'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => WithdrawScreen(
          type: item["type"],
          amount: item["amount"],
          coins: item["coins"],
          minWithdraw: 100,
        ),
      ),
    );

    if (result != null) {
      await _loadUserCoins();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff2EF1F7),
      body: Column(
        children: [
          const SizedBox(height: 40),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              itemBuilder: (context, index) {
                final item = payments[index];
                return GestureDetector(
                  onTap: () => handleWithdraw(item),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(item["image"], width: 45),
                        const SizedBox(height: 8),
                        Text("${item["amount"]} ${item["currency"]}",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("${item["coins"]}",
                            style: const TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isBannerLoaded)
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                width: _bannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) =>  DashboardScreen(totalCoins: totalCoins)),
              ),
              child: Image.asset('assets/images/image_7.png', width: 40),
            ),
            Image.asset('assets/images/image_8.png', width: 40),
            GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(totalCoins: totalCoins),
                ),
              ),
              child: Image.asset('assets/images/image_9.png', width: 40),
            ),
          ],
        ),
      ),
    );
  }
}
