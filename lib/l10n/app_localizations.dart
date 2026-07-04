import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @stepTrackingPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Step Tracking Permission'**
  String get stepTrackingPermissionTitle;

  /// No description provided for @stepTrackingPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'We use activity recognition permission to count your steps and track your daily movement.'**
  String get stepTrackingPermissionBody;

  /// No description provided for @noThanks.
  ///
  /// In en, this message translates to:
  /// **'No Thanks'**
  String get noThanks;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @enableNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enableNotificationsTitle;

  /// No description provided for @enableNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'We may send occasional reminders to help you stay active.'**
  String get enableNotificationsBody;

  /// No description provided for @dataUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Usage'**
  String get dataUsageTitle;

  /// No description provided for @dataUsageBody.
  ///
  /// In en, this message translates to:
  /// **'We collect your step count, device information, and app usage data to improve app performance and user experience. This data may be shared with third-party services such as Google Analytics and Firebase. No personally identifiable information is sold or shared.'**
  String get dataUsageBody;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @stayActive.
  ///
  /// In en, this message translates to:
  /// **'Stay Active'**
  String get stayActive;

  /// No description provided for @takeWalk.
  ///
  /// In en, this message translates to:
  /// **'Take a short walk today'**
  String get takeWalk;

  /// No description provided for @greatJob.
  ///
  /// In en, this message translates to:
  /// **'Great Job'**
  String get greatJob;

  /// No description provided for @doingGreat.
  ///
  /// In en, this message translates to:
  /// **'You\'re doing great today!'**
  String get doingGreat;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @stayHealthy.
  ///
  /// In en, this message translates to:
  /// **'Stay active and healthy'**
  String get stayHealthy;

  /// No description provided for @noUserLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'No user logged in'**
  String get noUserLoggedIn;

  /// No description provided for @stepCounterNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Step counter not supported on this device'**
  String get stepCounterNotSupported;

  /// No description provided for @permissionNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Permission not granted'**
  String get permissionNotGranted;

  /// No description provided for @stepError.
  ///
  /// In en, this message translates to:
  /// **'Step error'**
  String get stepError;

  /// No description provided for @pedometerInitError.
  ///
  /// In en, this message translates to:
  /// **'Pedometer initialization error'**
  String get pedometerInitError;

  /// No description provided for @loadStepsError.
  ///
  /// In en, this message translates to:
  /// **'Error loading steps'**
  String get loadStepsError;

  /// No description provided for @fcmError.
  ///
  /// In en, this message translates to:
  /// **'FCM error'**
  String get fcmError;

  /// No description provided for @firestoreError.
  ///
  /// In en, this message translates to:
  /// **'Firestore error'**
  String get firestoreError;

  /// No description provided for @surveyTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete surveys and earn rewards ✨'**
  String get surveyTitle;

  /// No description provided for @surveySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose any network to start earning rewards'**
  String get surveySubtitle;

  /// No description provided for @howToEarn.
  ///
  /// In en, this message translates to:
  /// **'How to earn'**
  String get howToEarn;

  /// No description provided for @followSteps.
  ///
  /// In en, this message translates to:
  /// **'Follow these steps:'**
  String get followSteps;

  /// No description provided for @step1.
  ///
  /// In en, this message translates to:
  /// **'1️⃣ Open the offer'**
  String get step1;

  /// No description provided for @step2.
  ///
  /// In en, this message translates to:
  /// **'2️⃣ Complete all required steps'**
  String get step2;

  /// No description provided for @step3.
  ///
  /// In en, this message translates to:
  /// **'3️⃣ Download app or register if needed'**
  String get step3;

  /// No description provided for @step4.
  ///
  /// In en, this message translates to:
  /// **'4️⃣ Rewards will be added automatically'**
  String get step4;

  /// No description provided for @warningNoRewardClick.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Clicking alone does not give rewards'**
  String get warningNoRewardClick;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @startNow.
  ///
  /// In en, this message translates to:
  /// **'Start Now'**
  String get startNow;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
