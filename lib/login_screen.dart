  import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // تسجيل عرض الشاشة
    analytics.logScreenView(screenName: 'LoginPage');
  }

  /// 🔐 تسجيل دخول Anonymous مؤقت
  Future<void> _signInAnonymously() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      if (!mounted) return;

      // الانتقال للـ HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      // عرض رسالة خطأ للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login failed, try again"),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // الخلفية المتدرجة
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF37F4FA),
                    Color(0xFF45F3C4),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // الصورة السفلية
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              "assets/images/image_2.png",
              width: width,
              height: height * 0.25,
              fit: BoxFit.cover,
            ),
          ),

          // المحتوى
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  "assets/images/image_1.png",
                  width: width * 0.6,
                  height: height * 0.35,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: height * 0.03),

                SizedBox(
                  width: width * 0.6,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                      // تسجيل Event في Firebase Analytics
                      analytics.logEvent(
                        name: 'app_started',
                        parameters: {
                          'screen': 'login',
                          'method': 'start_button',
                        },
                      );

                      // تسجيل دخول Anonymous
                      await _signInAnonymously();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                        : const Text(
                      "Get Started",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}