import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:firebase_analytics/firebase_analytics.dart';

import 'login_screen.dart';
import 'main_screen.dart';

final GoogleSignIn googleSignIn = GoogleSignIn();

final FirebaseAnalytics analytics =
    FirebaseAnalytics.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics
  FlutterError.onError =
      FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError =
      (error, stack) {
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
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream:
      FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child:
                  CircularProgressIndicator(),
                ),
              );
            }

            if (!snap.hasData ||
                !snap.data!.exists) {
              return const LoginPage();
            }

            final data =
            snap.data!.data()
            as Map<String, dynamic>;

            final totalCoins =
                data['totalCoins'] ?? 0;

            return MainScreen(
              totalCoins: totalCoins,
            );
          },
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  bool _isLoading = false;

  // =========================
  // DEFAULT USER DATA
  // =========================

  Map<String, dynamic> defaultUserData(
      User user,
      ) {
    return {
      'uid': user.uid,

      'email': user.email ?? '',

      'displayName':
      user.displayName ?? '',

      'photoURL': user.photoURL ?? '',

      // Coins
      'coins': 0,
      'totalCoins': 0,

      // Steps
      'todaySteps': 0,
      'totalSteps': 0,

      // Ads
      'adsWatchedToday': 0,
      'lastAdWatchTime': null,

      // Boost
      'boostMultiplier': 1,
      'boostEndTime': null,

      // Referral
      'referralCode': user.uid
          .substring(0, 8)
          .toUpperCase(),

      'usedReferral': false,

      // Account
      'isActive': true,
      'isBanned': false,

      // Daily Reset
      'lastDailyReset':
      FieldValue.serverTimestamp(),

      // Stats
      'loginCount': 0,

      // Time
      'createdAt':
      FieldValue.serverTimestamp(),

      'lastLogin':
      FieldValue.serverTimestamp(),

      'lastUpdate':
      FieldValue.serverTimestamp(),

      // Notifications
      'fcmToken': '',
    };
  }

  // =========================
  // FIX OLD USERS DATA
  // =========================

  Future<void> fixUserData(
      DocumentReference userRef,
      Map<String, dynamic> data,
      User user,
      ) async {
    final defaults =
    defaultUserData(user);

    Map<String, dynamic> updates = {};

    defaults.forEach((key, value) {
      // Missing field
      if (!data.containsKey(key)) {
        updates[key] = value;
        return;
      }

      // Wrong type protection
      final currentValue = data[key];

      if (currentValue != null &&
          value != null &&
          currentValue.runtimeType !=
              value.runtimeType) {
        updates[key] = value;
      }
    });

    // Always update timestamps
    updates['lastUpdate'] =
        FieldValue.serverTimestamp();

    if (updates.isNotEmpty) {
      await userRef.set(
        updates,
        SetOptions(merge: true),
      );
    }
  }

  // =========================
  // DAILY RESET
  // =========================

  Future<void> checkDailyReset(
      DocumentReference userRef,
      Map<String, dynamic> data,
      ) async {
    final lastReset =
    data['lastDailyReset'];

    if (lastReset == null) return;

    final lastDate =
    (lastReset as Timestamp).toDate();

    final now = DateTime.now();

    final isNewDay =
        lastDate.year != now.year ||
            lastDate.month != now.month ||
            lastDate.day != now.day;

    if (isNewDay) {
      await userRef.set({
        'todaySteps': 0,

        'adsWatchedToday': 0,

        'lastDailyReset':
        FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // =========================
  // GOOGLE SIGN IN
  // =========================

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Analytics
      await analytics.logEvent(
        name: 'login_attempt',
        parameters: {
          'method': 'google',
        },
      );

      // Google Sign In
      final googleUser =
      await googleSignIn
          .signIn()
          .timeout(
        const Duration(seconds: 15),
      );

      // User cancelled
      if (googleUser == null) {
        await analytics.logEvent(
          name: 'login_cancelled',
        );

        return;
      }

      final googleAuth =
      await googleUser.authentication;

      // Tokens check
      if (googleAuth.accessToken == null ||
          googleAuth.idToken == null) {
        throw Exception(
          'Google tokens are missing',
        );
      }

      // Firebase credential
      final credential =
      GoogleAuthProvider.credential(
        accessToken:
        googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase Login
      final userCredential =
      await FirebaseAuth.instance
          .signInWithCredential(
        credential,
      );

      final user =
          userCredential.user;

      if (user == null) {
        throw Exception(
          'Firebase user is null',
        );
      }

      // Crashlytics User
      await FirebaseCrashlytics.instance
          .setUserIdentifier(user.uid);

      final userRef =
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final doc =
      await userRef
          .get()
          .timeout(
        const Duration(seconds: 15),
      );

      // =========================
      // NEW USER
      // =========================

      if (!doc.exists) {
        await userRef.set(
          defaultUserData(user),
        );
      }

      // =========================
      // OLD USER
      // =========================

      else {
        final data =
        doc.data()
        as Map<String, dynamic>;

        // Fix missing data
        await fixUserData(
          userRef,
          data,
          user,
        );

        // Daily reset
        await checkDailyReset(
          userRef,
          data,
        );
      }

      // =========================
      // UPDATE LOGIN INFO
      // =========================

      await userRef.set({
        'email': user.email ?? '',

        'displayName':
        user.displayName ?? '',

        'photoURL':
        user.photoURL ?? '',

        'lastLogin':
        FieldValue.serverTimestamp(),

        'lastUpdate':
        FieldValue.serverTimestamp(),

        'loginCount':
        FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Analytics
      await analytics.logEvent(
        name: 'login_success',
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(
            totalCoins: 0,
          ),
        ),
      );

    } catch (e, stack) {
      debugPrint(e.toString());

      debugPrint(stack.toString());

      await FirebaseCrashlytics.instance
          .recordError(
        e,
        stack,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Login failed',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
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

          // Bottom Image
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              "assets/images/image_2.png",
              height: 180,
              fit: BoxFit.cover,
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Center(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Image.asset(
                      "assets/images/image_1.png",
                      height: 180,
                    ),

                    const SizedBox(
                      height: 40,
                    ),

                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _signInWithGoogle,

                      style:
                      ElevatedButton.styleFrom(
                        backgroundColor:
                        Colors.white,

                        minimumSize:
                        const Size(
                          double.infinity,
                          55,
                        ),

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),

                      child: _isLoading
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child:
                        CircularProgressIndicator(),
                      )
                          : Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                        children: [
                          Image.asset(
                            "assets/images/image_3.png",
                            height: 24,
                          ),

                          const SizedBox(
                            width: 12,
                          ),

                          const Text(
                            "Continue with Google",
                            style:
                            TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}