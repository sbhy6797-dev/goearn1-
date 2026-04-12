import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

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


    analytics.logEvent(
      name: 'screen_view',
      parameters: {
        'screen_name': 'login_page',
      },
    );
  }

  Future<void> _signInAnonymously() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {

      final userCredential =
      await FirebaseAuth.instance.signInAnonymously();

      final user = userCredential.user;


      await analytics.logEvent(
        name: 'login_success',
        parameters: {
          'method': 'anonymous',
        },
      );


      if (user != null) {
        await FirebaseCrashlytics.instance
            .setUserIdentifier(user.uid);
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Login failed"),
          backgroundColor: Colors.red,
        ),
      );

    } catch (e, stack) {


      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Unexpected Login Error',
        fatal: false,
      );
    }

    finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [


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

                      await analytics.logEvent(
                        name: 'login_attempt',
                        parameters: {
                          'method': 'anonymous',
                        },
                      );

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