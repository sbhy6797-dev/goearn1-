import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'notifications_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SettingsScreen extends StatefulWidget {

  final int totalCoins;

  const SettingsScreen({super.key, required this.totalCoins});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int totalCoins = 0;
  late String referralCode;

  final TextEditingController _friendCodeController = TextEditingController();

  bool _usedReferral = false;

  @override
  void initState() {
    super.initState();

    referralCode =
        FirebaseAuth.instance.currentUser!.uid.substring(0, 8).toUpperCase();

    _loadCoins();
    _saveReferralCode();
    _checkIfUsedReferral();

  }


  Future<void> _loadCoins() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    if (doc.exists && doc.data() != null) {
      final data = doc.data() as Map<String, dynamic>;

      setState(() {
        totalCoins = data['totalCoins'] ?? 0;
      });
    } else {
      setState(() {
        totalCoins = 0;
      });
    }
  }


  Future<void> _saveReferralCode() async {

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({

        'referralCode': referralCode,

      }, SetOptions(merge: true));

    }
  }

  Future<void> _checkIfUsedReferral() async {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      if (!mounted) return;
      setState(() {
        _usedReferral = doc.data()?['usedReferral'] == true;
      });

    }
  }

  Future<void> _useFriendCode() async {
    final code = _friendCodeController.text.trim().toUpperCase();

    if (code.isEmpty) return;

    try {
      final callable =
      FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('applyReferralCode');

      final result = await callable.call({
        "code": code,
      });

      debugPrint("SUCCESS: ${result.data}");

      if (!mounted) return;

      await _loadCoins();

      setState(() {
        _usedReferral = true;
      });

      _friendCodeController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 You got 50 coins')),
      );

    } on FirebaseFunctionsException catch (e) {

      debugPrint("ERROR CODE: ${e.code}");
      debugPrint("ERROR MESSAGE: ${e.message}");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Unknown error"),
        ),
      );

    } catch (e) {

      debugPrint("ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }
  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      // تحديد طريقة تسجيل الدخول
      final providerData = user.providerData.first.providerId;

      AuthCredential credential;

      if (providerData == 'google.com') {
        final googleSignIn = GoogleSignIn();

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) return;

        final googleAuth = await googleUser.authentication;

        credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
      } else {
        throw Exception("Unsupported sign-in method: $providerData");
      }

      // إعادة التحقق (مهم جدًا قبل الحذف)
      await user.reauthenticateWithCredential(credential);

      // حذف بيانات Firestore أولاً
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // ثم حذف الحساب
      await user.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully')),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }


  Future<void> shareReferral() async {
    Share.share(
      'Join the app and stay active. Use my code $referralCode to receive bonus rewards inside the app.',
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: const Text(
            """
Effective date: Mar 16, 2026
Welcome to GoEarn1. Your privacy is important to us. This Privacy Policy explains how we collect, use, and protect your information when you use our mobile application.

By using the application, you agree to the collection and use of information in accordance with this policy.

1. Information We Collect
1.1 Account Information

When you sign in using Google or email, we may collect:

Email address
User ID
Account authentication information

This information is used to create and manage your account securely.

1.2 Activity & Usage Data

The app collects step and activity data using your device sensors:

Daily step count
Activity progress
Walking goals

This information is used to:

Track user progress
Provide rewards
Improve user experience

We do not collect precise location data.

1.3 Device Information

We may collect limited device information such as:

Device model
Operating system
App version
Crash reports

This helps improve app performance and stability.

1.4 Advertising Data

We use Google AdMob to display ads. AdMob may collect:

Advertising ID
Device information
Ad interaction data

This helps display relevant ads and improve ad performance.

For more information:
https://policies.google.com/privacy

1.5 Notifications Data

We may collect:

Firebase Cloud Messaging Token

This is used to:

Send notifications
Inform users about rewards
App updates

Users can disable notifications at any time from device settings.

2. How We Use Information

We use collected information to:

Provide and maintain the app
Track activity and rewards
Improve app performance
Prevent fraud and abuse
Display advertisements
Send notifications

We do not sell personal data to third parties.

3. Third-Party Services

The app may use trusted third-party services:

Google AdMob (Ads)
Firebase Authentication
Firebase Firestore
Firebase Analytics
Firebase Crashlytics
Google Play Services

These services operate under their own privacy policies.

4. Rewards & Virtual Currency
Coins earned in the app are virtual rewards
Coins do not represent real money
Rewards are promotional and subject to review
Withdrawal requests may be approved, delayed, or rejected

The app does not guarantee earnings or income.

5. Referral Program
Users can invite friends
Users may receive promotional coins
Abuse of referral system may result in account suspension
6. Data Security

We take appropriate measures to protect your information:

Secure Firebase infrastructure
Encrypted connections
Limited data access

However, no system is completely secure.

7. User Rights

You have the right to:

Access your data
Delete your account
Stop using the app
Disable notifications

Users can delete their account directly from inside the app 
or request deletion via email at: sbhy6797@gmail.com

8. Children's Privacy

This application is not intended for children under 13.

We do not knowingly collect personal data from children.

If we discover such data, it will be deleted immediately.

9. Data Retention

We retain user data only for as long as necessary to provide our services.

- Account data is stored until the user deletes their account
- Some data may be retained for a limited period for legal, security, and fraud prevention purposes
- After account deletion, user data is permanently deleted within 30 days

10. Data Deletion

Users have the right to delete their data at any time.

You can request deletion by:

- Using the "Delete Account" option inside the app
- Or contacting us via email at: sbhy6797@gmail.com

All user data will be permanently deleted within 30 days of the request.

11. Ads Policy

The app displays ads provided by Google AdMob.

We:

Do not force users to click ads
Do not reward users for clicking ads
Do not display misleading ads

Ads follow Google AdMob policies.

12. Changes to Privacy Policy

We may update this Privacy Policy from time to time.

Changes will be posted inside the app.

Continued use means acceptance of updates.

13. Contact Us

If you have any questions, contact us:

Email:
sbhy6797@gmail.com

14. Consent

By using GoEarn1, you agree to:

Data collection
Data usage
Privacy policy terms
          """,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openPrivacyPolicyLink() async {
    final url = Uri.parse("https://goearn1-app.blogspot.com/p/privacy-policy.html");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ✅ Terms & Conditions Dialog
  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            """
Terms & Conditions

Effective date: Mar 16, 2026

Welcome to GoEarn1. By downloading or using this application, you agree to comply with and be bound by the following Terms and Conditions.

If you do not agree with these terms, please do not use the application.

1. Use of the Application

GoEarn1 is a fitness and rewards application designed to encourage physical activity. Users can earn virtual rewards by walking, completing tasks, and participating in promotional features within the app.

You agree to:

Use the app only for lawful purposes
Not attempt to manipulate or exploit the system
Not create multiple accounts for unfair advantage

Violation of these rules may result in account suspension or termination.

2. User Accounts

To use certain features, you may be required to create an account using:

Google Sign-in
Email authentication

You are responsible for:

Maintaining account security
Protecting login credentials
All activity under your account

We are not responsible for unauthorized account access.

3. Virtual Currency (Coins)

The application uses virtual coins as a reward system.

Important:

Coins are virtual rewards
Coins do not represent real-world currency
Coins have no guaranteed monetary value
Coins may be modified, reset, or removed at any time

Coins are used for:

Unlocking rewards
Promotional redemption
In-app benefits
4. Rewards & Withdrawals

Users may request rewards using earned coins.

Important conditions:

All reward requests are subject to review
Processing time may vary (typically 3–7 business days)
We reserve the right to approve or reject requests
Incorrect payment details may result in rejection

Withdrawal requests may be denied in cases including:

Fraudulent activity
Multiple accounts
Suspicious behavior
Violation of terms

Rewards are promotional and not guaranteed.

The app does not guarantee earnings or income.

5. Referral Program

GoEarn1 may include a referral system allowing users to invite friends.

Rules:

Users may receive promotional coins
Self-referrals are not allowed
Abuse of referral system may result in account suspension

We reserve the right to remove referral rewards if abuse is detected.

6. Advertisements

The app displays advertisements from third-party providers such as:

Google AdMob

We:

Do not require users to click ads
Do not reward users for clicking ads
Do not control ad content

Users interact with ads at their own discretion.

7. Fair Usage Policy

To maintain fairness:

Users must use the app naturally
Automated systems are prohibited
Emulator usage may be restricted
Artificial step generation is prohibited

Violation may result in:

Reward removal
Account suspension
Account termination
8. Account Suspension or Termination

We reserve the right to suspend or terminate accounts for:

Fraud
Abuse
Multiple accounts
Policy violations

Suspended accounts may lose:

Coins
Rewards
Withdraw eligibility
9. Limitation of Liability

GoEarn1 is provided "as is" without warranties.

We are not responsible for:

Loss of rewards
Technical issues
Third-party service interruptions

Use of the app is at your own risk.

10. Third-Party Services

The app uses third-party services including:

Google AdMob
Firebase Authentication
Firebase Firestore
Firebase Analytics
Google Play Services

These services operate under their own policies.

11. Updates to the Terms

We may update these Terms & Conditions at any time.

Changes will be posted inside the app.

Continued use of the app means acceptance of updated terms.

12. User Data & Privacy

Your privacy is important.

Please review our Privacy Policy for details about:

Data collection
Data usage
Data protection

Using the app means you agree to our Privacy Policy.

13. Minimum Requirements

To use rewards:

Minimum coin threshold may apply
Processing time may vary
One account per user allowed
14. Age Requirement

Users must be:

13 years or older

Children under 13 should not use the app.

15. Contact Information

If you have any questions:

Email:
sbhy6797@gmail.com

16. Acceptance

By using GoEarn1, you confirm that you:

Read these Terms
Understand these Terms
Agree to these Terms
            """,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ✅ Terms Link
  void _openTermsLink() async {
    final url = Uri.parse('https://goearn1-app.blogspot.com/p/terms-conditions.html');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {

    _friendCodeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(

      backgroundColor: const Color(0xFF37F4FA),

      body: SafeArea(

        child: Column(

          children: [

            Expanded(

              child: SingleChildScrollView(

                child: Column(

                  children: [

                    const SizedBox(height: 20),


                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          Row(
                            children: [
                              Image.asset('assets/images/image_9.png', width: 45),
                              const SizedBox(width: 10),
                              const Text(
                                'Settings',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Stack(
                            children: [

                              IconButton(
                                icon: const Icon(
                                  Icons.notifications,
                                  color: Colors.amber,
                                  size: 45,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const NotificationsScreen(),
                                    ),
                                  );
                                },
                              ),

                              // 🔴 Badge
                              Positioned(
                                right: 6,
                                top: 6,
                                child: StreamBuilder(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(FirebaseAuth.instance.currentUser!.uid)
                                      .collection('notifications')
                                      .where('read', isEqualTo: false)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) return const SizedBox();

                                    int count = snapshot.data!.docs.length;

                                    if (count == 0) return const SizedBox();

                                    return Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        count > 9 ? "9+" : "$count",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          )

                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    Image.asset('assets/images/image 12.png', width: 70),

                    const SizedBox(height: 25),

                    _infoBox(
                      icon: 'assets/images/image 13.png',
                      text: user?.email ?? 'No Email',
                      isEmail: true,
                    ),

                    const SizedBox(height: 15),

                    _infoBox(
                      icon: 'assets/images/image_5.png',
                      text: '$totalCoins Coins',
                    ),

                    const SizedBox(height: 15),

                    const Text(
                      'Stay active and earn reward coins ',
                      style: TextStyle(fontSize: 12),
                    ),

                    const SizedBox(height: 10),

                    _infoBox(
                      icon: 'assets/images/image 14.png',
                      text: referralCode,
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        TextButton(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: referralCode));
                          },
                          child: const Text('copy',
                              style: TextStyle(color: Colors.red)),
                        ),

                        const SizedBox(width: 20),

                        TextButton(
                          onPressed: shareReferral,
                          child: const Text('share',
                              style: TextStyle(color: Colors.blue)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(

                        controller: _friendCodeController,
                        enabled: !_usedReferral,

                        decoration: InputDecoration(

                          hintText: _usedReferral
                              ? 'Referral already used'
                              : 'Enter friend code',

                          suffixIcon: IconButton(
                            icon: const Icon(Icons.card_giftcard,
                                color: Colors.green),
                            onPressed:
                            _usedReferral ? null : _useFriendCode,
                          ),

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),

                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _showPrivacyPolicy,
                      child: const Text('Privacy Policy'),
                    ),

                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: _openPrivacyPolicyLink,
                      child: const Text('Full Privacy Policy'),
                    ),

                    const SizedBox(height: 10),

                    // ✅ Terms Buttons
                    ElevatedButton(
                      onPressed: _showTermsAndConditions,
                      child: const Text('Terms & Conditions'),
                    ),

                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: _openTermsLink,
                      child: const Text('Full Terms & Conditions'),
                    ),

                    const SizedBox(height: 40),


                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Account'),
                            content: const Text(
                              'Are you sure you want to delete your account? This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteAccount();
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Delete Account'),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _infoBox({
    required String icon,
    required String text,
    bool isEmail = false,
  }) {

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      height: 50,

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),

      child: Row(
        children: [

          Image.asset(icon, width: 24),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow:
              isEmail ? TextOverflow.ellipsis : TextOverflow.visible,
              style: const TextStyle(fontSize: 14),
            ),
          ),

        ],
      ),
    );
  }
}