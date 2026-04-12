import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dashboard_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email'],
);

final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError =
      FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: 'Unhandled async error',
      fatal: false,
    );
    return true;
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {

      await analytics.logEvent(
        name: 'login_attempt',
        parameters: {'method': 'google'},
      );

      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();

      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {

        await analytics.logEvent(
          name: 'login_cancelled',
          parameters: {'method': 'google'},
        );

        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) return;


      await analytics.logEvent(
        name: 'login_success',
        parameters: {
          'method': 'google',
        },
      );


      await FirebaseCrashlytics.instance
          .setUserIdentifier(user.uid);

      final userRef =
      FirebaseFirestore.instance.collection('users').doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          transaction.set(userRef, {
            'email': user.email ?? '',
            'displayName': user.displayName ?? '',
            'photoURL': user.photoURL ?? '',
            'totalCoins': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(userRef, {
            'lastLogin': FieldValue.serverTimestamp(),
            'loginCount': FieldValue.increment(1),
          });
        }
      });

      final userDoc = await userRef.get();
      final totalCoins = userDoc.data()?['totalCoins'] ?? 0;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(totalCoins: totalCoins),
        ),
      );

    } catch (e, stack) {

      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Google Sign-In failed',
        fatal: false,
      );

      await analytics.logEvent(
        name: 'login_failed',
        parameters: {'method': 'google'},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login failed. Please try again later"),
          backgroundColor: Colors.red,
        ),
      );

    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF37F4FA), Color(0xFF45F3C4)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              "assets/images/image_2.png",
              fit: BoxFit.cover,
              height: 180,
            ),
          ),

          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  const SizedBox(height: 40),

                  Image.asset("assets/images/image_1.png", height: 180),

                  const SizedBox(height: 40),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset("assets/images/image_3.png", height: 24),
                        const SizedBox(width: 10),
                        const Text(
                          "Continue with Google",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ],
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