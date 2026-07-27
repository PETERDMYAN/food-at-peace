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

  /// No description provided for @aboutYouTitle.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get aboutYouTitle;

  /// No description provided for @aboutYouBody.
  ///
  /// In en, this message translates to:
  /// **'Sex, age, height and weight power your calorie and protein targets. Anything Apple Health shared is pre-filled — fill in the rest.'**
  String get aboutYouBody;

  /// No description provided for @todoCompleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get todoCompleteProfile;

  /// No description provided for @todoCompleteProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Sex, age, height & weight set your targets'**
  String get todoCompleteProfileBody;

  /// No description provided for @autoFromGoal.
  ///
  /// In en, this message translates to:
  /// **'Auto from your goal: {value} kcal'**
  String autoFromGoal(String value);

  /// No description provided for @autoProteinRule.
  ///
  /// In en, this message translates to:
  /// **'Auto: 1.6 g × {weight} kg = {value} g'**
  String autoProteinRule(String weight, String value);

  /// No description provided for @autoSatFatRule.
  ///
  /// In en, this message translates to:
  /// **'Auto: 10% of your calorie budget = {value} g'**
  String autoSatFatRule(String value);

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

  /// No description provided for @onboardingSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in with Apple'**
  String get onboardingSignedIn;

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
  /// **'Profile'**
  String get navSettings;

  /// No description provided for @navCircle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get navCircle;

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

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Take daily'**
  String get repeatDaily;

  /// No description provided for @repeatDailyHint.
  ///
  /// In en, this message translates to:
  /// **'For a supplement or daily staple — counts every day, no need to re-log'**
  String get repeatDailyHint;

  /// No description provided for @dailyBadge.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get dailyBadge;

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

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes your account and all synced data from our servers, and signs you out. The data on this device is kept. This can\'t be undone.'**
  String get deleteAccountBody;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleted;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the account. Please try again.'**
  String get deleteAccountFailed;

  /// No description provided for @deleteAccountSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Your session had expired, so nothing was deleted. Sign in again, then retry deleting your account.'**
  String get deleteAccountSignInAgain;

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

  /// No description provided for @dataSources.
  ///
  /// In en, this message translates to:
  /// **'Data sources'**
  String get dataSources;

  /// No description provided for @dataSourcesHeader.
  ///
  /// In en, this message translates to:
  /// **'Active-energy source'**
  String get dataSourcesHeader;

  /// No description provided for @dataSourcesBody.
  ///
  /// In en, this message translates to:
  /// **'When more than one device writes active energy to Apple Health (e.g. Garmin and Apple Watch), Food at Peace uses your preferred source — otherwise it combines them. Garmin syncs in through Apple Health.'**
  String get dataSourcesBody;

  /// No description provided for @sourceAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic (combine all)'**
  String get sourceAutomatic;

  /// No description provided for @dataSourcesConnectFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect Apple Health first to choose a source.'**
  String get dataSourcesConnectFirst;

  /// No description provided for @dataSourcesNone.
  ///
  /// In en, this message translates to:
  /// **'No active-energy sources found in Apple Health yet.'**
  String get dataSourcesNone;

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

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @remindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Friendly nudges to log your meals — breakfast, lunch, dinner and a late-night check-in.'**
  String get remindersSubtitle;

  /// No description provided for @remindersEnable.
  ///
  /// In en, this message translates to:
  /// **'Daily meal reminders'**
  String get remindersEnable;

  /// No description provided for @remindersDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for this app. Turn them on in Settings to get reminders.'**
  String get remindersDenied;

  /// No description provided for @remindersActive.
  ///
  /// In en, this message translates to:
  /// **'{count} on'**
  String remindersActive(int count);

  /// No description provided for @remindersOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get remindersOff;

  /// No description provided for @remindersNone.
  ///
  /// In en, this message translates to:
  /// **'No reminders yet. Add one below.'**
  String get remindersNone;

  /// No description provided for @addReminder.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get addReminder;

  /// No description provided for @onboardingRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay on track'**
  String get onboardingRemindersTitle;

  /// No description provided for @onboardingRemindersBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send light, friendly nudges to log your meals — breakfast, lunch and dinner (plus an optional late-night check-in). Change or turn them off anytime in Settings.'**
  String get onboardingRemindersBody;

  /// No description provided for @enableReminders.
  ///
  /// In en, this message translates to:
  /// **'Enable reminders'**
  String get enableReminders;

  /// No description provided for @onboardingRemindersEnabled.
  ///
  /// In en, this message translates to:
  /// **'Reminders on — we\'ll help you keep the habit.'**
  String get onboardingRemindersEnabled;

  /// No description provided for @reminderBreakfastTitle.
  ///
  /// In en, this message translates to:
  /// **'Breakfast o\'clock 🍳'**
  String get reminderBreakfastTitle;

  /// No description provided for @reminderBreakfastBody.
  ///
  /// In en, this message translates to:
  /// **'Fuel up — then log it before the day runs away with you.'**
  String get reminderBreakfastBody;

  /// No description provided for @reminderLunchTitle.
  ///
  /// In en, this message translates to:
  /// **'Lunch break! 🥪'**
  String get reminderLunchTitle;

  /// No description provided for @reminderLunchBody.
  ///
  /// In en, this message translates to:
  /// **'Whatever\'s on your plate, give it a quick log. Two taps, done.'**
  String get reminderLunchBody;

  /// No description provided for @reminderDinnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Dinner\'s served 🍝'**
  String get reminderDinnerTitle;

  /// No description provided for @reminderDinnerBody.
  ///
  /// In en, this message translates to:
  /// **'Don\'t let those calories sneak by unlogged — quick, before dessert!'**
  String get reminderDinnerBody;

  /// No description provided for @reminderSnackTitle.
  ///
  /// In en, this message translates to:
  /// **'Late-night nibbles? 🌙'**
  String get reminderSnackTitle;

  /// No description provided for @reminderSnackBody.
  ///
  /// In en, this message translates to:
  /// **'Snacks count too — no judgment. Pop it in and call it a day.'**
  String get reminderSnackBody;

  /// No description provided for @beans.
  ///
  /// In en, this message translates to:
  /// **'Beans'**
  String get beans;

  /// No description provided for @beansBalance.
  ///
  /// In en, this message translates to:
  /// **'Beans balance'**
  String get beansBalance;

  /// No description provided for @beansPerScan.
  ///
  /// In en, this message translates to:
  /// **'1 Bean per photo scan'**
  String get beansPerScan;

  /// No description provided for @beansHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get beansHistory;

  /// No description provided for @beansEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get beansEmpty;

  /// No description provided for @topUp.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get topUp;

  /// No description provided for @beansGrant.
  ///
  /// In en, this message translates to:
  /// **'Welcome bonus'**
  String get beansGrant;

  /// No description provided for @beansSpend.
  ///
  /// In en, this message translates to:
  /// **'Photo scan'**
  String get beansSpend;

  /// No description provided for @beansPurchase.
  ///
  /// In en, this message translates to:
  /// **'Top-up'**
  String get beansPurchase;

  /// No description provided for @beansRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get beansRefund;

  /// No description provided for @beansCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Beans'**
  String beansCount(int count);

  /// No description provided for @priceSgd.
  ///
  /// In en, this message translates to:
  /// **'SGD {value}'**
  String priceSgd(String value);

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re out of Beans'**
  String get paywallTitle;

  /// No description provided for @paywallBody.
  ///
  /// In en, this message translates to:
  /// **'Each photo scan uses 1 Bean. Top up to keep scanning your meals.'**
  String get paywallBody;

  /// No description provided for @beansStubNote.
  ///
  /// In en, this message translates to:
  /// **'Demo build — purchases credit instantly; real billing is coming.'**
  String get beansStubNote;

  /// No description provided for @beansBought.
  ///
  /// In en, this message translates to:
  /// **'Added {count} Beans'**
  String beansBought(int count);

  /// No description provided for @scansLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} scans left'**
  String scansLeft(int count);

  /// No description provided for @iapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Purchases aren\'t available right now.'**
  String get iapUnavailable;

  /// No description provided for @iapPending.
  ///
  /// In en, this message translates to:
  /// **'Your purchase is processing…'**
  String get iapPending;

  /// No description provided for @iapFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed. Please try again.'**
  String get iapFailed;

  /// No description provided for @iapProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing your payment…'**
  String get iapProcessingTitle;

  /// No description provided for @iapProcessingBody.
  ///
  /// In en, this message translates to:
  /// **'This takes a few seconds. Please keep this screen open — your Beans will appear here.'**
  String get iapProcessingBody;

  /// No description provided for @iapSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your Beans are ready to use.'**
  String get iapSuccessBody;

  /// No description provided for @iapNewBalance.
  ///
  /// In en, this message translates to:
  /// **'New balance: {count}'**
  String iapNewBalance(int count);

  /// No description provided for @beansChoosePack.
  ///
  /// In en, this message translates to:
  /// **'Top up Beans'**
  String get beansChoosePack;

  /// No description provided for @beansSecretUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Secret pack unlocked 🫘'**
  String get beansSecretUnlocked;

  /// No description provided for @beansCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get beansCustom;

  /// No description provided for @beansCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom top-up'**
  String get beansCustomTitle;

  /// No description provided for @beansCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of Beans'**
  String get beansCustomLabel;

  /// No description provided for @beansBestValue.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get beansBestValue;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @dashboardSample.
  ///
  /// In en, this message translates to:
  /// **'Sample data — wire analytics + App Store Connect to see real numbers.'**
  String get dashboardSample;

  /// No description provided for @mDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get mDownloads;

  /// No description provided for @mActiveToday.
  ///
  /// In en, this message translates to:
  /// **'Active today'**
  String get mActiveToday;

  /// No description provided for @mOpens.
  ///
  /// In en, this message translates to:
  /// **'Total opens'**
  String get mOpens;

  /// No description provided for @mOpens7d.
  ///
  /// In en, this message translates to:
  /// **'Opens · last 7 days'**
  String get mOpens7d;

  /// No description provided for @mPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos scanned'**
  String get mPhotos;

  /// No description provided for @mBeansSold.
  ///
  /// In en, this message translates to:
  /// **'Beans sold'**
  String get mBeansSold;

  /// No description provided for @mRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get mRevenue;

  /// No description provided for @mRefunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get mRefunds;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} {version} ({build})'**
  String versionLabel(String name, String version, String build);

  /// No description provided for @accountIdTitle.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get accountIdTitle;

  /// No description provided for @accountIdHint.
  ///
  /// In en, this message translates to:
  /// **'Your account\'s ID in the sync database.'**
  String get accountIdHint;

  /// No description provided for @accountIdSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your account ID.'**
  String get accountIdSignedOut;

  /// No description provided for @accountIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Account ID copied'**
  String get accountIdCopied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @yourCircle.
  ///
  /// In en, this message translates to:
  /// **'Your circle'**
  String get yourCircle;

  /// No description provided for @evaDailyLesson.
  ///
  /// In en, this message translates to:
  /// **'Daily lesson'**
  String get evaDailyLesson;

  /// No description provided for @addFriend.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addFriend;

  /// No description provided for @circleRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get circleRequests;

  /// No description provided for @circleRequestsN.
  ///
  /// In en, this message translates to:
  /// **'Requests ({count})'**
  String circleRequestsN(int count);

  /// No description provided for @pendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingLabel;

  /// No description provided for @invitePeople.
  ///
  /// In en, this message translates to:
  /// **'Add a friend'**
  String get invitePeople;

  /// No description provided for @inviteShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share invite link'**
  String get inviteShareLink;

  /// No description provided for @inviteLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied'**
  String get inviteLinkCopied;

  /// No description provided for @inviteHandleHelp.
  ///
  /// In en, this message translates to:
  /// **'A friend\'s @username is shown at the top of their own Add-friend screen — ask them for it.'**
  String get inviteHandleHelp;

  /// No description provided for @inviteSend.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get inviteSend;

  /// No description provided for @inviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invite sent to {handle}'**
  String inviteSent(String handle);

  /// No description provided for @yourHandle.
  ///
  /// In en, this message translates to:
  /// **'Your handle'**
  String get yourHandle;

  /// No description provided for @setHandle.
  ///
  /// In en, this message translates to:
  /// **'Set your handle'**
  String get setHandle;

  /// No description provided for @handleHint.
  ///
  /// In en, this message translates to:
  /// **'letters, numbers or _'**
  String get handleHint;

  /// No description provided for @handleCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied {handle}'**
  String handleCopied(String handle);

  /// No description provided for @handleSaved.
  ///
  /// In en, this message translates to:
  /// **'You\'re {handle} — share it so friends can add you'**
  String handleSaved(String handle);

  /// No description provided for @handleTaken.
  ///
  /// In en, this message translates to:
  /// **'That handle is taken — try another'**
  String get handleTaken;

  /// No description provided for @handleInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 2–20 letters, numbers or _'**
  String get handleInvalid;

  /// No description provided for @handleError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your handle — try again'**
  String get handleError;

  /// No description provided for @signInToReact.
  ///
  /// In en, this message translates to:
  /// **'Sign in (Settings) to react to posts'**
  String get signInToReact;

  /// No description provided for @handleFindHint.
  ///
  /// In en, this message translates to:
  /// **'Friends find & add you — and recharge Beans — with this'**
  String get handleFindHint;

  /// No description provided for @handleAssigning.
  ///
  /// In en, this message translates to:
  /// **'Assigning your handle…'**
  String get handleAssigning;

  /// No description provided for @handleSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to claim a handle others can find'**
  String get handleSignInHint;

  /// No description provided for @shareToCircle.
  ///
  /// In en, this message translates to:
  /// **'Share to circle'**
  String get shareToCircle;

  /// No description provided for @shareToCircleHint.
  ///
  /// In en, this message translates to:
  /// **'Friends in your circle see it for 30 days'**
  String get shareToCircleHint;

  /// No description provided for @feedTitle.
  ///
  /// In en, this message translates to:
  /// **'Circle feed'**
  String get feedTitle;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @feedYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get feedYou;

  /// No description provided for @foodStory.
  ///
  /// In en, this message translates to:
  /// **'Food story'**
  String get foodStory;

  /// No description provided for @foodStoryArchive.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get foodStoryArchive;

  /// No description provided for @shareFirstMeal.
  ///
  /// In en, this message translates to:
  /// **'Scan a meal to start your food story.'**
  String get shareFirstMeal;

  /// No description provided for @deleteStory.
  ///
  /// In en, this message translates to:
  /// **'Delete from story'**
  String get deleteStory;

  /// No description provided for @deleteStoryBody.
  ///
  /// In en, this message translates to:
  /// **'Remove this meal from your food story? Your food log keeps it.'**
  String get deleteStoryBody;

  /// No description provided for @storyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Removed from your food story'**
  String get storyDeleted;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profilePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @feedSomeone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get feedSomeone;

  /// No description provided for @feedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No posts yet. Scan a meal and share it to your circle.'**
  String get feedEmpty;

  /// No description provided for @feedReceived.
  ///
  /// In en, this message translates to:
  /// **'{count} reactions'**
  String feedReceived(int count);

  /// No description provided for @feedPostMenu.
  ///
  /// In en, this message translates to:
  /// **'Post options'**
  String get feedPostMenu;

  /// No description provided for @feedReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get feedReport;

  /// No description provided for @feedUnfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get feedUnfollow;

  /// No description provided for @feedReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this post'**
  String get feedReportTitle;

  /// No description provided for @feedReportSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or scam'**
  String get feedReportSpam;

  /// No description provided for @feedReportNudity.
  ///
  /// In en, this message translates to:
  /// **'Nudity or sexual content'**
  String get feedReportNudity;

  /// No description provided for @feedReportHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or bullying'**
  String get feedReportHarassment;

  /// No description provided for @feedReportViolence.
  ///
  /// In en, this message translates to:
  /// **'Violence or harmful content'**
  String get feedReportViolence;

  /// No description provided for @feedReportOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get feedReportOther;

  /// No description provided for @feedReportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for reporting. We review reports and remove violating content within 24 hours. You can also unfollow this person to stop seeing their posts.'**
  String get feedReportThanks;

  /// No description provided for @feedUnfollowTitle.
  ///
  /// In en, this message translates to:
  /// **'Unfollow {name}?'**
  String feedUnfollowTitle(String name);

  /// No description provided for @feedUnfollowBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll stop seeing each other\'s posts, and they\'ll be removed from your circle.'**
  String get feedUnfollowBody;

  /// No description provided for @feedUnfollowed.
  ///
  /// In en, this message translates to:
  /// **'Unfollowed {name}.'**
  String feedUnfollowed(String name);

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @feedComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get feedComment;

  /// No description provided for @commentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get commentsEmpty;

  /// No description provided for @commentHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get commentHint;

  /// No description provided for @commentReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}…'**
  String commentReplyHint(String name);

  /// No description provided for @commentSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commentSend;

  /// No description provided for @signInToComment.
  ///
  /// In en, this message translates to:
  /// **'Sign in (Settings) to comment'**
  String get signInToComment;

  /// No description provided for @commentError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t post your comment. Please try again.'**
  String get commentError;

  /// No description provided for @commentPrivacyViewer.
  ///
  /// In en, this message translates to:
  /// **'Private — only you and {name} can see this.'**
  String commentPrivacyViewer(String name);

  /// No description provided for @commentPrivacyOwner.
  ///
  /// In en, this message translates to:
  /// **'Private — each person sees only their own comments.'**
  String get commentPrivacyOwner;

  /// No description provided for @commentDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get commentDelete;

  /// No description provided for @commentDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this comment for everyone? This can\'t be undone.'**
  String get commentDeleteConfirm;

  /// No description provided for @commentResend.
  ///
  /// In en, this message translates to:
  /// **'Failed to send — tap to retry'**
  String get commentResend;

  /// No description provided for @commentAudiencePublic.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get commentAudiencePublic;

  /// No description provided for @commentAudiencePrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get commentAudiencePrivate;

  /// No description provided for @commentAudienceOnly.
  ///
  /// In en, this message translates to:
  /// **'Only {name}'**
  String commentAudienceOnly(String name);

  /// No description provided for @commentAudienceYouAnd.
  ///
  /// In en, this message translates to:
  /// **'Only you & {name}'**
  String commentAudienceYouAnd(String name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @viewAllComments.
  ///
  /// In en, this message translates to:
  /// **'View all {count} comments'**
  String viewAllComments(int count);

  /// No description provided for @commentPublicHint.
  ///
  /// In en, this message translates to:
  /// **'Comment (everyone sees)…'**
  String get commentPublicHint;

  /// No description provided for @commentOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'Comment, or @name for a private reply…'**
  String get commentOwnerHint;

  /// No description provided for @commentsPublic.
  ///
  /// In en, this message translates to:
  /// **'Everyone can see'**
  String get commentsPublic;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String timeDaysAgo(int count);

  /// No description provided for @sectionSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested to follow'**
  String get sectionSuggested;

  /// No description provided for @sectionOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official account'**
  String get sectionOfficial;

  /// No description provided for @sectionOfficials.
  ///
  /// In en, this message translates to:
  /// **'Officials'**
  String get sectionOfficials;

  /// No description provided for @sectionFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get sectionFriends;

  /// No description provided for @sectionInvited.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get sectionInvited;

  /// No description provided for @badgeCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get badgeCoach;

  /// No description provided for @showInviteQr.
  ///
  /// In en, this message translates to:
  /// **'Show QR'**
  String get showInviteQr;

  /// No description provided for @hideInviteQr.
  ///
  /// In en, this message translates to:
  /// **'Hide QR'**
  String get hideInviteQr;

  /// No description provided for @officialBadge.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get officialBadge;

  /// No description provided for @evaRole.
  ///
  /// In en, this message translates to:
  /// **'AI coach'**
  String get evaRole;

  /// No description provided for @roroName.
  ///
  /// In en, this message translates to:
  /// **'Roro'**
  String get roroName;

  /// No description provided for @roroRole.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get roroRole;

  /// No description provided for @followAction.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get followAction;

  /// No description provided for @followingLabel.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingLabel;

  /// No description provided for @evaUnfollowedMsg.
  ///
  /// In en, this message translates to:
  /// **'Unfollowed Eva — find her under Suggested anytime.'**
  String get evaUnfollowedMsg;

  /// No description provided for @roroFollowedMsg.
  ///
  /// In en, this message translates to:
  /// **'Following Roro 🎉'**
  String get roroFollowedMsg;

  /// No description provided for @followFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t follow. Please try again.'**
  String get followFailed;

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// No description provided for @streakLabel.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streakLabel;

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String streakDays(int count);

  /// No description provided for @friendAdherence.
  ///
  /// In en, this message translates to:
  /// **'On-target · last 7 days'**
  String get friendAdherence;

  /// No description provided for @notifyCtaTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get notifyCtaTitle;

  /// No description provided for @notifyCtaBody.
  ///
  /// In en, this message translates to:
  /// **'Know the moment a friend reacts to your meal or shares one — plus gentle nudges to log.'**
  String get notifyCtaBody;

  /// No description provided for @notifyCtaAction.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get notifyCtaAction;

  /// No description provided for @notifyOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get notifyOpenSettings;

  /// No description provided for @notifyDeniedHint.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off. Tap Open Settings, then turn on Notifications.'**
  String get notifyDeniedHint;

  /// No description provided for @removeFriend.
  ///
  /// In en, this message translates to:
  /// **'Remove from circle'**
  String get removeFriend;

  /// No description provided for @removeFriendQ.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from your circle?'**
  String removeFriendQ(String name);

  /// No description provided for @noRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests.'**
  String get noRequests;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @friendAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name} joined your circle 🎉'**
  String friendAccepted(String name);

  /// No description provided for @manageCircle.
  ///
  /// In en, this message translates to:
  /// **'Manage circle'**
  String get manageCircle;

  /// No description provided for @shareInvite.
  ///
  /// In en, this message translates to:
  /// **'Share invite'**
  String get shareInvite;

  /// No description provided for @scanToConnect.
  ///
  /// In en, this message translates to:
  /// **'Scan to add me to your circle'**
  String get scanToConnect;

  /// No description provided for @inviteLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Your invite link'**
  String get inviteLinkLabel;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @shareInviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Add me on Food at Peace 🍵 {link}'**
  String shareInviteMessage(String link);

  /// No description provided for @connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to your circle'**
  String get connectTitle;

  /// No description provided for @connectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Connect with {handle}? You\'ll each see the other\'s daily food trends.'**
  String connectPrompt(String handle);

  /// No description provided for @connectCta.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectCta;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @connectedToast.
  ///
  /// In en, this message translates to:
  /// **'You\'re now connected with {name} 🎉'**
  String connectedToast(String name);

  /// No description provided for @connectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect — please try again.'**
  String get connectFailed;

  /// No description provided for @sectionConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get sectionConnected;

  /// No description provided for @sectionRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get sectionRequests;

  /// No description provided for @cancelInvite.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelInvite;

  /// No description provided for @circleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your circle is empty. Share your invite link to add friends.'**
  String get circleEmpty;

  /// No description provided for @circleActivity.
  ///
  /// In en, this message translates to:
  /// **'Circle activity'**
  String get circleActivity;

  /// No description provided for @circleActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified when a friend shares a meal'**
  String get circleActivitySubtitle;

  /// No description provided for @commentNotify.
  ///
  /// In en, this message translates to:
  /// **'Comments & mentions'**
  String get commentNotify;

  /// No description provided for @commentNotifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified when a friend comments on, replies to, or @-mentions you'**
  String get commentNotifySubtitle;

  /// No description provided for @circleSharedMeal.
  ///
  /// In en, this message translates to:
  /// **'{name} shared a meal 🍵'**
  String circleSharedMeal(String name);

  /// No description provided for @aFriend.
  ///
  /// In en, this message translates to:
  /// **'A friend'**
  String get aFriend;

  /// No description provided for @circleRequestNotif.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to join your circle 👋'**
  String circleRequestNotif(String name);

  /// No description provided for @circleAcceptedNotif.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted — you\'re connected 🎉'**
  String circleAcceptedNotif(String name);

  /// No description provided for @circleReactionNotif.
  ///
  /// In en, this message translates to:
  /// **'{name} reacted {emoji} to your meal'**
  String circleReactionNotif(String name, String emoji);

  /// No description provided for @addByHandle.
  ///
  /// In en, this message translates to:
  /// **'Add by @handle'**
  String get addByHandle;

  /// No description provided for @addByHandleSent.
  ///
  /// In en, this message translates to:
  /// **'Friend request sent to {handle}'**
  String addByHandleSent(String handle);
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
