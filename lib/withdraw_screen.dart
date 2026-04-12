import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WithdrawScreen extends StatefulWidget {
  final String type;
  final int amount;
  final int coins;
  final int minWithdraw;

  const WithdrawScreen({
    super.key,
    required this.type,
    required this.amount,
    required this.coins,
    required this.minWithdraw,
  });

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _controller = TextEditingController();
  bool isProcessing = false;

  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  final User user = FirebaseAuth.instance.currentUser!;
  late final String uid;
  late final String? email;
  late final DocumentReference userDoc;

  @override
  void initState() {
    super.initState();
    uid = user.uid;
    email = user.email;
    userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

    _loadBanner();
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _bannerLoaded = true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  Future<void> sendNotification(String message) async {
    final tokenDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final token = tokenDoc.data()?['fcmToken'];
    if (token == null) return;

    final notifRef =
    FirebaseFirestore.instance.collection('notifications').doc();

    await notifRef.set({
      'uid': uid,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> handleWithdraw() async {
    if (isProcessing) return;

    final input = _controller.text.trim();

    // ✅ Validation
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.type == 'paypal'
                ? 'دخل ايميل PayPal'
                : 'دخل رقم الموبايل',
          ),
        ),
      );
      return;
    }

    if (widget.type == 'paypal') {
      if (!input.contains('@') || !input.contains('.')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PayPal email غير صحيح')),
        );
        return;
      }
    } else {
      if (input.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رقم الموبايل غير صحيح')),
        );
        return;
      }
    }

    // 🔥 جلب التوكن (إضافة فقط بدون لمس باقي الكود)
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final fcmToken = userSnap.data()?['fcmToken'];

    setState(() => isProcessing = true);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);

        int currentCoins = 0;
        if (snapshot.exists && snapshot.data() != null) {
          currentCoins = snapshot.get('totalCoins') ?? 0;
        }

        if (currentCoins < widget.coins) {
          throw Exception('رصيدك غير كافي');
        }

        // ✅ خصم الرصيد
        transaction.set(
          userDoc,
          {
            'totalCoins': currentCoins - widget.coins,
            'email': email,
            'uid': uid,
          },
          SetOptions(merge: true),
        );

        // ✅ إنشاء طلب سحب
        final withdrawRef = FirebaseFirestore.instance
            .collection('withdraw_requests')
            .doc();

        transaction.set(withdrawRef, {
          'uid': uid,
          'email': email,
          'type': widget.type,
          'amount': widget.amount,
          'coins': widget.coins,
          'account': input,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'fcmToken': fcmToken, // 🔥 إضافة بدون حذف أي شيء
        });
      });

      final message = widget.type == 'paypal'
          ? 'طلب سحب PayPal: $input'
          : 'طلب سحب ${widget.type}: $input';

      await sendNotification(message);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'تم إرسال طلب السحب Processing may take 3–7 business days.⏳'),
          backgroundColor: Colors.green,
        ),
      );

      // 🔥 إضافة إشعار داخل المستخدم بدون حذف أي شيء
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': 'Withdrawal Request Sent',
        'body': 'Your request is under review',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'withdraw',
        'status': 'pending',
      });

      Navigator.pop(context, widget.coins);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    setState(() => isProcessing = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff2EF1F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          children: [
            Image.asset('assets/images/${widget.type}.png', width: 90),
            const SizedBox(height: 20),
            const Text('You are withdrawing'),
            const SizedBox(height: 10),
            Text(
              '${widget.amount} ${widget.type == 'paypal' ? '\$' : 'ج'}',
              style:
              const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _controller,
              keyboardType: widget.type == 'paypal'
                  ? TextInputType.emailAddress
                  : TextInputType.phone,
              decoration: InputDecoration(
                hintText: widget.type == 'paypal'
                    ? 'PayPal Email'
                    : 'Phone Number',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isProcessing ? null : handleWithdraw,
                child: isProcessing
                    ? const CircularProgressIndicator()
                    : const Text('Withdraw'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(height: 15),
            if (_bannerLoaded)
              SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                width: _bannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }
}