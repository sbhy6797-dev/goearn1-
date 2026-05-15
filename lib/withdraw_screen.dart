import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

Future<double> getBtcPrice() async {
  try {
    final res = await http.get(
      Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd',
      ),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load price");
    }

    final data = jsonDecode(res.body);

    return (data['bitcoin']['usd'] as num).toDouble();
  } catch (e) {
    return 0;
  }
}

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

  final TextEditingController walletController = TextEditingController();

  double btcPrice = 0;

  Timer? _timer;

  Future<void> loadPrice() async {
    btcPrice = await getBtcPrice();

    if (mounted) {
      setState(() {});
    }
  }

  bool isProcessing = false;

  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  // ✅ FIX: safe nullable user instead of crash
  final User? user = FirebaseAuth.instance.currentUser;

  late final String uid;
  late final String? email;
  late final DocumentReference userDoc;

  @override
  void initState() {
    super.initState();

    if (user != null) {
      uid = user!.uid;
      email = user!.email;
      userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

      _loadBannerAd();
      loadPrice();

      _timer = Timer.periodic(const Duration(seconds: 60), (_) {
        loadPrice();
      });
    }
  }

  void _loadBannerAd() {
    _bannerAd?.dispose();

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5925712456846655/9667012771',
      size: AdSize.banner,
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
            if (mounted) _loadBannerAd();
          });
        },
      ),
    );

    _bannerAd!.load();
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

    final double usd = widget.amount.toDouble();


    if (widget.type == 'bitcoin' && btcPrice <= 0) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("BTC price not loaded"),
        ),
      );

      return;
    }


    double btcAmount = 0;

    if (widget.type == 'bitcoin' && btcPrice > 0) {
      btcAmount = usd / btcPrice;
    }

    // ✅ Validation
    if (widget.type == 'paypal' && input.isEmpty) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter PayPal email'),
        ),
      );

      return;
    }

    if (widget.type == 'vodafone' && input.isEmpty) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter Vodafone number'),
        ),
      );

      return;
    }

    if (widget.type == 'bitcoin') {

      final wallet = walletController.text.trim();

      if (wallet.isEmpty || wallet.length < 20) {

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter Bitcoin wallet'),
          ),
        );

        return;
      }
    }

    if (widget.type == 'paypal') {
      if (!input.contains('@') || !input.contains('.')) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid PayPal email'),
          ),
        );

        return;
      }
    }

    else if (widget.type == 'vodafone') {
      if (input.length < 8) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid phone number'),
          ),
        );

        return;
      }
    }

    else if (widget.type == 'bitcoin') {

      final wallet = walletController.text.trim();

      if (wallet.isEmpty || wallet.length < 20) {

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter Bitcoin wallet'),
          ),
        );

        return;
      }
    }

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final fcmToken = userSnap.data()?['fcmToken'];

    setState(() => isProcessing = true);

    try {

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      final userSnap = await userRef.get();
      int currentCoins = userSnap.data()?['totalCoins'] ?? 0;

      if (currentCoins < widget.coins) {
        throw Exception('Insufficient balance');
      }


      await userRef.update({
        'totalCoins': currentCoins - widget.coins,
      });


      await FirebaseFirestore.instance
          .collection('withdraw_requests')
          .add({
        'uid': uid,
        'type': widget.type,
        'wallet': walletController.text.trim(),
        'email': email,
        'amount': widget.amount,
        'coins': widget.coins,
        'btc_amount': btcAmount,
        'btc_price': btcPrice,
        'status': 'pending',
        'processed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'fcmToken': fcmToken,
      });

      final message = widget.type == 'paypal'
          ? 'طلب سحب PayPal: $input'
          : widget.type == 'vodafone'
          ? 'طلب سحب Vodafone: $input'
          : 'طلب سحب Bitcoin: ${walletController.text.trim()}';

      await sendNotification(message);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
          content: Text(
            'Withdrawal Request Sent\n'
                'Your withdrawal request is being processed.\n'
                'Processing may take 3–7 business days.\n'
                'Please wait for confirmation.',
            softWrap: true,
          ),
        ),
      );

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
      });
      if (!mounted) return;
      Navigator.pop(context, widget.coins);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    if (mounted) {
      setState(() => isProcessing = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    walletController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xff2EF1F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          children: [

            Image.asset(
              widget.type == 'bitcoin'
                  ? 'assets/images/faucetpay.png'
                  : 'assets/images/${widget.type}.png',
              width: 90,
            ),

            const SizedBox(height: 20),

            const Text('You are withdrawing'),

            const SizedBox(height: 10),

            Text(
              '${widget.amount} ${widget.type == 'paypal' ? '\$' : 'ج'}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),


            if (widget.type == 'paypal' ||
                widget.type == 'vodafone')
              TextField(
                controller: _controller,
                keyboardType: widget.type == 'vodafone'
                    ? TextInputType.phone
                    : TextInputType.text,
                decoration: InputDecoration(
                  hintText: widget.type == 'paypal'
                      ? 'PayPal Email'
                      : widget.type == 'vodafone'
                      ? 'Vodafone Number'
                      : 'FaucetPay Wallet Address',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

            const SizedBox(height: 15),

            // 🟡 Bitcoin Wallet (فقط لو Bitcoin)
            if (widget.type == 'bitcoin')
              TextField(
                controller: walletController,
                decoration: InputDecoration(
                  hintText: 'Bitcoin Wallet Address',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

            if (widget.type == 'bitcoin')
              const SizedBox(height: 15),

            // 💰 BTC PRICE (فقط Bitcoin)
            if (widget.type == 'bitcoin') ...[
              Text(
                btcPrice == 0
                    ? "Loading BTC price..."
                    : "BTC Price: \$${btcPrice.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 5),

              Text(
                btcPrice == 0
                    ? "Calculating..."
                    : "You will receive: ${(widget.amount / btcPrice).toStringAsFixed(8)} BTC",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],

            const SizedBox(height: 25),

            // 🔘 Withdraw Button
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

            // 🔘 Cancel Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),

            const SizedBox(height: 15),

            if (_isBannerReady)
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