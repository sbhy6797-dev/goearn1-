// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get stepTrackingPermissionTitle => 'Step Tracking Permission';

  @override
  String get stepTrackingPermissionBody => 'We use activity recognition permission to count your steps and track your daily movement.';

  @override
  String get noThanks => 'No Thanks';

  @override
  String get allow => 'Allow';

  @override
  String get enableNotificationsTitle => 'Enable Notifications';

  @override
  String get enableNotificationsBody => 'We may send occasional reminders to help you stay active.';

  @override
  String get dataUsageTitle => 'Data Usage';

  @override
  String get dataUsageBody => 'We collect your step count, device information, and app usage data to improve app performance and user experience. This data may be shared with third-party services such as Google Analytics and Firebase. No personally identifiable information is sold or shared.';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get stayActive => 'Stay Active';

  @override
  String get takeWalk => 'Take a short walk today';

  @override
  String get greatJob => 'Great Job';

  @override
  String get doingGreat => 'You\'re doing great today!';

  @override
  String get reminder => 'Reminder';

  @override
  String get stayHealthy => 'Stay active and healthy';

  @override
  String get noUserLoggedIn => 'No user logged in';

  @override
  String get stepCounterNotSupported => 'Step counter not supported on this device';

  @override
  String get permissionNotGranted => 'Permission not granted';

  @override
  String get stepError => 'Step error';

  @override
  String get pedometerInitError => 'Pedometer initialization error';

  @override
  String get loadStepsError => 'Error loading steps';

  @override
  String get fcmError => 'FCM error';

  @override
  String get firestoreError => 'Firestore error';

  @override
  String get surveyTitle => 'Complete surveys and earn rewards ✨';

  @override
  String get surveySubtitle => 'Choose any network to start earning rewards';

  @override
  String get howToEarn => 'How to earn';

  @override
  String get followSteps => 'Follow these steps:';

  @override
  String get step1 => '1️⃣ Open the offer';

  @override
  String get step2 => '2️⃣ Complete all required steps';

  @override
  String get step3 => '3️⃣ Download app or register if needed';

  @override
  String get step4 => '4️⃣ Rewards will be added automatically';

  @override
  String get warningNoRewardClick => '⚠️ Clicking alone does not give rewards';

  @override
  String get cancel => 'Cancel';

  @override
  String get startNow => 'Start Now';
}
