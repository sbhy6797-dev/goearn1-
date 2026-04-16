import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'home_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    /// Proper screen tracking (Google compliant)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseAnalytics.instance.logScreenView(
        screenName: 'login_page',
        screenClass: 'LoginPage',
      );
    });
  }

  Future<void> _signInAnonymously() async {
    if (_loading || !mounted) return;

    setState(() => _loading = true);

    try {
      /// 🔐 Firebase Auth with timeout protection
      final userCredential = await FirebaseAuth.instance
          .signInAnonymously()
          .timeout(const Duration(seconds: 10));

      final user = userCredential.user;

      if (user == null) {
        throw Exception("Authentication failed: user is null");
      }

      /// 📊 Analytics (safe event, no spam)
      FirebaseAnalytics.instance.logEvent(
        name: 'login_success',
        parameters: {
          'method': 'anonymous',
        },
      );

      /// 🧠 Crashlytics user binding
      await FirebaseCrashlytics.instance
          .setUserIdentifier(user.uid);

      if (!mounted) return;

      /// 🚀 Safe navigation
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );

    } on FirebaseAuthException catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Anonymous Login Failed',
        fatal: false,
      );

      if (!mounted) return;

      _showError(e.message ?? "Login failed");
    } catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Unexpected Login Error',
        fatal: false,
      );

      if (!mounted) return;

      _showError("Something went wrong. Please try again.");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          /// 🌈 Background gradient
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

          /// 🖼 Bottom decoration
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

          /// 🎯 Main content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    "assets/images/image_1.png",
                    width: width * 0.6,
                    height: height * 0.30,
                    fit: BoxFit.contain,
                  ),

                  SizedBox(height: height * 0.03),

                  /// 🚀 Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signInAnonymously,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        "Get Started",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}