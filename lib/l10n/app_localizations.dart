import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Food at Peace'**
  String get appTitle;

  /// No description provided for @greetMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String greetMorning(String name);

  /// No description provided for @greetAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String greetAfternoon(String name);

  /// No description provided for @greetEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String greetEvening(String name);

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @weatherClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get weatherClear;

  /// No description provided for @weatherPartlyCloudy.
  ///
  /// In en, this message translates to:
  /// **'Partly cloudy'**
  String get weatherPartlyCloudy;

  /// No description provided for @weatherCloudy.
  ///
  /// In en, this message translates to:
  /// **'Cloudy'**
  String get weatherCloudy;

  /// No description provided for @weatherFog.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get weatherFog;

  /// No description provided for @weatherDrizzle.
  ///
  /// In en, this message translates to:
  /// **'Drizzle'**
  String get weatherDrizzle;

  /// No description provided for @weatherRain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get weatherRain;

  /// No description provided for @weatherSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get weatherSnow;

  /// No description provided for @weatherThunder.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get weatherThunder;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @sourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources & methodology'**
  String get sourcesTitle;

  /// No description provided for @sourcesIntro.
  ///
  /// In en, this message translates to:
  /// **'How your targets are estimated, with references you can check.'**
  String get sourcesIntro;

  /// No description provided for @sourcesDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'These are general estimates for healthy adults — not medical advice. Talk to a doctor or registered dietitian before making significant changes, especially if you\'re pregnant, under 18, or managing a health condition.'**
  String get sourcesDisclaimer;

  /// No description provided for @viewSource.
  ///
  /// In en, this message translates to:
  /// **'View source'**
  String get viewSource;

  /// No description provided for @howCalculated.
  ///
  /// In en, this message translates to:
  /// **'How your budget is calculated'**
  String get howCalculated;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to\nFood at Peace'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Track calories and macros with a calm, simple daily view.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingNameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get onboardingNameTitle;

  /// No description provided for @onboardingNameBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple to bring your name in, or just type it. We\'ll greet you by name each day.'**
  String get onboardingNameBody;

  /// No description provided for @onboardingNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get onboardingNameLabel;

  /// No description provided for @onboardingNameManual.
  ///
  /// In en, this message translates to:
  /// **'Or enter it manually'**
  String get onboardingNameManual;

  /// No description provided for @onboardingGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s your goal?'**
  String get onboardingGoalTitle;

  /// No description provided for @onboardingGoalBody.
  ///
  /// In en, this message translates to:
  /// **'This sets your daily calorie gap. You can change it anytime.'**
  String get onboardingGoalBody;

  /// No description provided for @onboardingHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Apple Health'**
  String get onboardingHealthTitle;

  /// No description provided for @onboardingHealthBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll read your age, height, weight and calories burned from Apple Health (including Garmin) to keep your targets accurate — refreshed daily.'**
  String get onboardingHealthBody;

  /// No description provided for @onboardingHealthConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected — your stats will stay in sync.'**
  String get onboardingHealthConnected;

  /// No description provided for @perDayKcal.
  ///
  /// In en, this message translates to:
  /// **'{value} kcal/day'**
  String perDayKcal(String value);

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @finishSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up'**
  String get finishSetup;

  /// No description provided for @todoAddName.
  ///
  /// In en, this message translates to:
  /// **'Add your name'**
  String get todoAddName;

  /// No description provided for @todoAddNameBody.
  ///
  /// In en, this message translates to:
  /// **'So the app can greet you each day'**
  String get todoAddNameBody;

  /// No description provided for @todoConnectHealthBody.
  ///
  /// In en, this message translates to:
  /// **'Sync your age, height, weight & calories'**
  String get todoConnectHealthBody;

  /// No description provided for @syncedFromHealth.
  ///
  /// In en, this message translates to:
  /// **'Synced from Apple Health'**
  String get syncedFromHealth;

  /// No description provided for @heightTitle.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get heightTitle;

  /// No description provided for @calorieBudgetExplainer.
  ///
  /// In en, this message translates to:
  /// **'Your daily calorie budget = BMR + active burn + calorie gap target.'**
  String get calorieBudgetExplainer;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navTrends.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get navTrends;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @addFood.
  ///
  /// In en, this message translates to:
  /// **'Add food'**
  String get addFood;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @caloriesLeftToday.
  ///
  /// In en, this message translates to:
  /// **'Calories left today'**
  String get caloriesLeftToday;

  /// No description provided for @overBudget.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get overBudget;

  /// No description provided for @budgetEaten.
  ///
  /// In en, this message translates to:
  /// **'Budget {budget} · Eaten {eaten}'**
  String budgetEaten(String budget, String eaten);

  /// No description provided for @burnViaHealth.
  ///
  /// In en, this message translates to:
  /// **'Burn {burn} kcal · {active} active via Health'**
  String burnViaHealth(String burn, String active);

  /// No description provided for @estBurn.
  ///
  /// In en, this message translates to:
  /// **'Est. burn ~{burn} kcal/day'**
  String estBurn(String burn);

  /// No description provided for @goalLine.
  ///
  /// In en, this message translates to:
  /// **'Goal: {goal}'**
  String goalLine(String goal);

  /// No description provided for @goalLineAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Goal: {goal} ({adjustment} kcal/day)'**
  String goalLineAdjusted(String goal, String adjustment);

  /// No description provided for @budgetBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Resting {resting} · Active {active} · Gap {adjustment}'**
  String budgetBreakdown(String resting, String active, String adjustment);

  /// No description provided for @budgetBreakdownEst.
  ///
  /// In en, this message translates to:
  /// **'Est. burn {burn} · Gap {adjustment}'**
  String budgetBreakdownEst(String burn, String adjustment);

  /// No description provided for @protein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get protein;

  /// No description provided for @saturatedFat.
  ///
  /// In en, this message translates to:
  /// **'Saturated fat'**
  String get saturatedFat;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @chartActual.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get chartActual;

  /// No description provided for @chartTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get chartTarget;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String daysCount(int count);

  /// No description provided for @onTargetDays.
  ///
  /// In en, this message translates to:
  /// **'On target {met}/{total} days'**
  String onTargetDays(int met, int total);

  /// No description provided for @onTargetShort.
  ///
  /// In en, this message translates to:
  /// **'{met}/{total} days'**
  String onTargetShort(int met, int total);

  /// No description provided for @editTargets.
  ///
  /// In en, this message translates to:
  /// **'Edit targets'**
  String get editTargets;

  /// No description provided for @useAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Use automatic'**
  String get useAutomatic;

  /// No description provided for @targetReached.
  ///
  /// In en, this message translates to:
  /// **'Target reached'**
  String get targetReached;

  /// No description provided for @toGo.
  ///
  /// In en, this message translates to:
  /// **'{amount} to go'**
  String toGo(String amount);

  /// No description provided for @overBy.
  ///
  /// In en, this message translates to:
  /// **'Over by {amount}'**
  String overBy(String amount);

  /// No description provided for @amountLeft.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String amountLeft(String amount);

  /// No description provided for @todaysFood.
  ///
  /// In en, this message translates to:
  /// **'Today\'s food'**
  String get todaysFood;

  /// No description provided for @nothingLogged.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet.\nTap \"Add food\" to start.'**
  String get nothingLogged;

  /// No description provided for @connectHealthGarmin.
  ///
  /// In en, this message translates to:
  /// **'Connect Apple Health & Garmin'**
  String get connectHealthGarmin;

  /// No description provided for @appleHealthConnected.
  ///
  /// In en, this message translates to:
  /// **'Apple Health connected'**
  String get appleHealthConnected;

  /// No description provided for @healthNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Health access was not granted'**
  String get healthNotGranted;

  /// No description provided for @profilePrompt.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile in Settings for accurate targets.'**
  String get profilePrompt;

  /// No description provided for @workouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workouts;

  /// No description provided for @noTrendsYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet.\nLog some food to see your trends.'**
  String get noTrendsYet;

  /// No description provided for @kcalValue.
  ///
  /// In en, this message translates to:
  /// **'{value} kcal'**
  String kcalValue(String value);

  /// No description provided for @gramsValue.
  ///
  /// In en, this message translates to:
  /// **'{value} g'**
  String gramsValue(String value);

  /// No description provided for @scanPhoto.
  ///
  /// In en, this message translates to:
  /// **'Scan a photo with Claude'**
  String get scanPhoto;

  /// No description provided for @foodName.
  ///
  /// In en, this message translates to:
  /// **'Food name'**
  String get foodName;

  /// No description provided for @foodNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Grilled chicken salad'**
  String get foodNameHint;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get enterName;

  /// No description provided for @meal.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get meal;

  /// No description provided for @caloriesKcal.
  ///
  /// In en, this message translates to:
  /// **'Calories (kcal)'**
  String get caloriesKcal;

  /// No description provided for @proteinG.
  ///
  /// In en, this message translates to:
  /// **'Protein (g)'**
  String get proteinG;

  /// No description provided for @saturatedFatG.
  ///
  /// In en, this message translates to:
  /// **'Saturated fat (g)'**
  String get saturatedFatG;

  /// No description provided for @servingOptional.
  ///
  /// In en, this message translates to:
  /// **'Serving (optional)'**
  String get servingOptional;

  /// No description provided for @servingHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1 bowl, 200 g'**
  String get servingHint;

  /// No description provided for @saveEntry.
  ///
  /// In en, this message translates to:
  /// **'Save entry'**
  String get saveEntry;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get enterValidNumber;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @chooseFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose from library'**
  String get chooseFromLibrary;

  /// No description provided for @cameraError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera or photo library.'**
  String get cameraError;

  /// No description provided for @analysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed. Please try again.'**
  String get analysisFailed;

  /// No description provided for @addApiKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your API key'**
  String get addApiKeyTitle;

  /// No description provided for @addApiKeyBody.
  ///
  /// In en, this message translates to:
  /// **'Photo analysis isn\'t set up in this build. Add your own Anthropic API key in Settings to scan photos.'**
  String get addApiKeyBody;

  /// No description provided for @estimatedByClaude.
  ///
  /// In en, this message translates to:
  /// **'Estimated by Claude — review & edit below.'**
  String get estimatedByClaude;

  /// No description provided for @confidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'confidence: {value}'**
  String confidenceLabel(String value);

  /// No description provided for @analyzingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Analyzing photo…'**
  String get analyzingPhoto;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @sex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sex;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCm;

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKg;

  /// No description provided for @activityLevel.
  ///
  /// In en, this message translates to:
  /// **'Activity level'**
  String get activityLevel;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @yourTargets.
  ///
  /// In en, this message translates to:
  /// **'Your targets'**
  String get yourTargets;

  /// No description provided for @restingBurn.
  ///
  /// In en, this message translates to:
  /// **'Resting burn (BMR)'**
  String get restingBurn;

  /// No description provided for @estDailyBurn.
  ///
  /// In en, this message translates to:
  /// **'Est. daily burn'**
  String get estDailyBurn;

  /// No description provided for @dailyCalorieTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily calorie target'**
  String get dailyCalorieTarget;

  /// No description provided for @calorieGapTarget.
  ///
  /// In en, this message translates to:
  /// **'Calorie gap target'**
  String get calorieGapTarget;

  /// No description provided for @estBurnDailyTarget.
  ///
  /// In en, this message translates to:
  /// **'Est. burn {burn} · Daily target {target}'**
  String estBurnDailyTarget(String burn, String target);

  /// No description provided for @proteinTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Protein target'**
  String get proteinTargetLabel;

  /// No description provided for @satFatCap.
  ///
  /// In en, this message translates to:
  /// **'Saturated-fat cap'**
  String get satFatCap;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get saveProfile;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @foodPhotoAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Food photo analysis (Claude)'**
  String get foodPhotoAnalysis;

  /// No description provided for @apiKeySavedDevice.
  ///
  /// In en, this message translates to:
  /// **'Using your own Anthropic key on this device. Remove it to go back to the built-in analysis.'**
  String get apiKeySavedDevice;

  /// No description provided for @apiKeyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Photo analysis works out of the box. Advanced: add your own Anthropic API key to use your own account instead — get one at console.anthropic.com.'**
  String get apiKeyPrompt;

  /// No description provided for @replaceApiKey.
  ///
  /// In en, this message translates to:
  /// **'Replace API key'**
  String get replaceApiKey;

  /// No description provided for @apiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key (sk-ant-…)'**
  String get apiKeyLabel;

  /// No description provided for @saveKey.
  ///
  /// In en, this message translates to:
  /// **'Save key'**
  String get saveKey;

  /// No description provided for @apiKeySavedToast.
  ///
  /// In en, this message translates to:
  /// **'API key saved'**
  String get apiKeySavedToast;

  /// No description provided for @apiKeyRemoved.
  ///
  /// In en, this message translates to:
  /// **'API key removed'**
  String get apiKeyRemoved;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your data across devices. Optional — the app works without it.'**
  String get signInPrompt;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {value}'**
  String signedInAs(String value);

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get signInFailed;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced {time}'**
  String lastSynced(String time);

  /// No description provided for @healthGarminTitle.
  ///
  /// In en, this message translates to:
  /// **'Apple Health & Garmin'**
  String get healthGarminTitle;

  /// No description provided for @healthNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this platform.'**
  String get healthNotAvailable;

  /// No description provided for @healthConnectedBody.
  ///
  /// In en, this message translates to:
  /// **'Connected. Your budget uses real calories burned (active + resting), your weight auto-syncs from your scale, and logged food is written back to Apple Health. Garmin data flows in via Apple Health.'**
  String get healthConnectedBody;

  /// No description provided for @healthConnectBody.
  ///
  /// In en, this message translates to:
  /// **'Connect Apple Health to use your real calories burned (incl. Garmin), auto-sync your weight, see your workouts, and write logged food back.'**
  String get healthConnectBody;

  /// No description provided for @connectAppleHealth.
  ///
  /// In en, this message translates to:
  /// **'Connect Apple Health'**
  String get connectAppleHealth;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @activitySedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get activitySedentary;

  /// No description provided for @activityLight.
  ///
  /// In en, this message translates to:
  /// **'Lightly active'**
  String get activityLight;

  /// No description provided for @activityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderately active'**
  String get activityModerate;

  /// No description provided for @activityActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activityActive;

  /// No description provided for @activityVeryActive.
  ///
  /// In en, this message translates to:
  /// **'Very active'**
  String get activityVeryActive;

  /// No description provided for @activitySedentaryHint.
  ///
  /// In en, this message translates to:
  /// **'Little or no exercise'**
  String get activitySedentaryHint;

  /// No description provided for @activityLightHint.
  ///
  /// In en, this message translates to:
  /// **'Exercise 1-3 days/week'**
  String get activityLightHint;

  /// No description provided for @activityModerateHint.
  ///
  /// In en, this message translates to:
  /// **'Exercise 3-5 days/week'**
  String get activityModerateHint;

  /// No description provided for @activityActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Exercise 6-7 days/week'**
  String get activityActiveHint;

  /// No description provided for @activityVeryActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Hard exercise or physical job'**
  String get activityVeryActiveHint;

  /// No description provided for @goalLose.
  ///
  /// In en, this message translates to:
  /// **'Lose weight'**
  String get goalLose;

  /// No description provided for @goalMaintain.
  ///
  /// In en, this message translates to:
  /// **'Maintain'**
  String get goalMaintain;

  /// No description provided for @goalGain.
  ///
  /// In en, this message translates to:
  /// **'Gain muscle'**
  String get goalGain;

  /// No description provided for @mealBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealLunch;

  /// No description provided for @mealDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealDinner;

  /// No description provided for @mealSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealSnack;

  /// No description provided for @addWeight.
  ///
  /// In en, this message translates to:
  /// **'Add weight'**
  String get addWeight;

  /// No description provided for @logWeight.
  ///
  /// In en, this message translates to:
  /// **'Log weight'**
  String get logWeight;

  /// No description provided for @weightSaved.
  ///
  /// In en, this message translates to:
  /// **'Weight saved'**
  String get weightSaved;

  /// No description provided for @latestWeight.
  ///
  /// In en, this message translates to:
  /// **'Latest weight'**
  String get latestWeight;

  /// No description provided for @enterWeight.
  ///
  /// In en, this message translates to:
  /// **'Enter your weight'**
  String get enterWeight;

  /// No description provided for @weightTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightTitle;

  /// No description provided for @weightKgValue.
  ///
  /// In en, this message translates to:
  /// **'{value} kg'**
  String weightKgValue(String value);

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @feedbackPrompt.
  ///
  /// In en, this message translates to:
  /// **'Found a bug or have an idea? We\'d love to hear it.'**
  String get feedbackPrompt;

  /// No description provided for @feedbackHint.
  ///
  /// In en, this message translates to:
  /// **'Your feedback…'**
  String get feedbackHint;

  /// No description provided for @yourEmailOptional.
  ///
  /// In en, this message translates to:
  /// **'Your email (optional)'**
  String get yourEmailOptional;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @feedbackThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your feedback!'**
  String get feedbackThanks;

  /// No description provided for @feedbackError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send feedback. Please try again.'**
  String get feedbackError;

  /// No description provided for @feedbackEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter some feedback'**
  String get feedbackEmpty;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
