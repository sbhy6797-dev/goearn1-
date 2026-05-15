import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TheoremReachBridge {
  static const platform = MethodChannel('theoremreach');

  // تشغيل + إرسال userId
  static Future<void> initTheoremReach() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await platform.invokeMethod('initTR', {
      "userId": user.uid,
    });
  }

  // فتح Reward Center
  static Future<void> openRewardCenter() async {
    await platform.invokeMethod('openRewardCenter');
  }
}