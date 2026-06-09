// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Food at Peace';

  @override
  String greetMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String greetAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String greetEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String get navToday => 'Today';

  @override
  String get navTrends => 'Trends';

  @override
  String get navSettings => 'Settings';

  @override
  String get addFood => 'Add food';

  @override
  String get save => 'Save';

  @override
  String get ok => 'OK';

  @override
  String get remove => 'Remove';

  @override
  String get cancel => 'Cancel';

  @override
  String get caloriesLeftToday => 'Calories left today';

  @override
  String get overBudget => 'Over budget';

  @override
  String budgetEaten(String budget, String eaten) {
    return 'Budget $budget · Eaten $eaten';
  }

  @override
  String burnViaHealth(String burn, String active) {
    return 'Burn $burn kcal · $active active via Health';
  }

  @override
  String estBurn(String burn) {
    return 'Est. burn ~$burn kcal/day';
  }

  @override
  String goalLine(String goal) {
    return 'Goal: $goal';
  }

  @override
  String goalLineAdjusted(String goal, String adjustment) {
    return 'Goal: $goal ($adjustment kcal/day)';
  }

  @override
  String budgetBreakdown(String resting, String active, String adjustment) {
    return 'Resting $resting · Active $active · Goal $adjustment';
  }

  @override
  String budgetBreakdownEst(String burn, String adjustment) {
    return 'Est. burn $burn · Goal $adjustment';
  }

  @override
  String get protein => 'Protein';

  @override
  String get saturatedFat => 'Saturated fat';

  @override
  String get calories => 'Calories';

  @override
  String get chartActual => 'Actual';

  @override
  String get chartTarget => 'Target';

  @override
  String get targetReached => 'Target reached';

  @override
  String toGo(String amount) {
    return '$amount to go';
  }

  @override
  String overBy(String amount) {
    return 'Over by $amount';
  }

  @override
  String amountLeft(String amount) {
    return '$amount left';
  }

  @override
  String get todaysFood => 'Today\'s food';

  @override
  String get nothingLogged => 'Nothing logged yet.\nTap \"Add food\" to start.';

  @override
  String get connectHealthGarmin => 'Connect Apple Health & Garmin';

  @override
  String get appleHealthConnected => 'Apple Health connected';

  @override
  String get healthNotGranted => 'Health access was not granted';

  @override
  String get profilePrompt =>
      'Set up your profile in Settings for accurate targets.';

  @override
  String get workouts => 'Workouts';

  @override
  String get noTrendsYet => 'No data yet.\nLog some food to see your trends.';

  @override
  String kcalValue(String value) {
    return '$value kcal';
  }

  @override
  String gramsValue(String value) {
    return '$value g';
  }

  @override
  String get scanPhoto => 'Scan a photo with Claude';

  @override
  String get foodName => 'Food name';

  @override
  String get foodNameHint => 'e.g. Grilled chicken salad';

  @override
  String get enterName => 'Enter a name';

  @override
  String get meal => 'Meal';

  @override
  String get caloriesKcal => 'Calories (kcal)';

  @override
  String get proteinG => 'Protein (g)';

  @override
  String get saturatedFatG => 'Saturated fat (g)';

  @override
  String get servingOptional => 'Serving (optional)';

  @override
  String get servingHint => 'e.g. 1 bowl, 200 g';

  @override
  String get saveEntry => 'Save entry';

  @override
  String get required => 'Required';

  @override
  String get enterValidNumber => 'Enter a valid number';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get chooseFromLibrary => 'Choose from library';

  @override
  String get cameraError => 'Could not open the camera or photo library.';

  @override
  String get analysisFailed => 'Analysis failed. Please try again.';

  @override
  String get addApiKeyTitle => 'Add your API key';

  @override
  String get addApiKeyBody =>
      'Photo analysis isn\'t set up in this build. Add your own Anthropic API key in Settings to scan photos.';

  @override
  String get estimatedByClaude => 'Estimated by Claude — review & edit below.';

  @override
  String confidenceLabel(String value) {
    return 'confidence: $value';
  }

  @override
  String get analyzingPhoto => 'Analyzing photo…';

  @override
  String get profile => 'Profile';

  @override
  String get sex => 'Sex';

  @override
  String get age => 'Age';

  @override
  String get heightCm => 'Height (cm)';

  @override
  String get weightKg => 'Weight (kg)';

  @override
  String get activityLevel => 'Activity level';

  @override
  String get goal => 'Goal';

  @override
  String get yourTargets => 'Your targets';

  @override
  String get restingBurn => 'Resting burn (BMR)';

  @override
  String get estDailyBurn => 'Est. daily burn';

  @override
  String get dailyCalorieTarget => 'Daily calorie target';

  @override
  String estBurnDailyTarget(String burn, String target) {
    return 'Est. burn $burn · Daily target $target';
  }

  @override
  String get proteinTargetLabel => 'Protein target';

  @override
  String get satFatCap => 'Saturated-fat cap';

  @override
  String get saveProfile => 'Save profile';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get foodPhotoAnalysis => 'Food photo analysis (Claude)';

  @override
  String get apiKeySavedDevice =>
      'Using your own Anthropic key on this device. Remove it to go back to the built-in analysis.';

  @override
  String get apiKeyPrompt =>
      'Photo analysis works out of the box. Advanced: add your own Anthropic API key to use your own account instead — get one at console.anthropic.com.';

  @override
  String get replaceApiKey => 'Replace API key';

  @override
  String get apiKeyLabel => 'API key (sk-ant-…)';

  @override
  String get saveKey => 'Save key';

  @override
  String get apiKeySavedToast => 'API key saved';

  @override
  String get apiKeyRemoved => 'API key removed';

  @override
  String get account => 'Account';

  @override
  String get signInPrompt =>
      'Sign in to sync your data across devices. Optional — the app works without it.';

  @override
  String signedInAs(String value) {
    return 'Signed in as $value';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get signInFailed => 'Sign-in failed. Please try again.';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncing => 'Syncing…';

  @override
  String lastSynced(String time) {
    return 'Last synced $time';
  }

  @override
  String get healthGarminTitle => 'Apple Health & Garmin';

  @override
  String get healthNotAvailable => 'Not available on this platform.';

  @override
  String get healthConnectedBody =>
      'Connected. Your budget uses real calories burned (active + resting), your weight auto-syncs from your scale, and logged food is written back to Apple Health. Garmin data flows in via Apple Health.';

  @override
  String get healthConnectBody =>
      'Connect Apple Health to use your real calories burned (incl. Garmin), auto-sync your weight, see your workouts, and write logged food back.';

  @override
  String get connectAppleHealth => 'Connect Apple Health';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get sexMale => 'Male';

  @override
  String get sexFemale => 'Female';

  @override
  String get activitySedentary => 'Sedentary';

  @override
  String get activityLight => 'Lightly active';

  @override
  String get activityModerate => 'Moderately active';

  @override
  String get activityActive => 'Active';

  @override
  String get activityVeryActive => 'Very active';

  @override
  String get activitySedentaryHint => 'Little or no exercise';

  @override
  String get activityLightHint => 'Exercise 1-3 days/week';

  @override
  String get activityModerateHint => 'Exercise 3-5 days/week';

  @override
  String get activityActiveHint => 'Exercise 6-7 days/week';

  @override
  String get activityVeryActiveHint => 'Hard exercise or physical job';

  @override
  String get goalLose => 'Lose weight';

  @override
  String get goalMaintain => 'Maintain';

  @override
  String get goalGain => 'Gain muscle';

  @override
  String get mealBreakfast => 'Breakfast';

  @override
  String get mealLunch => 'Lunch';

  @override
  String get mealDinner => 'Dinner';

  @override
  String get mealSnack => 'Snack';

  @override
  String get addWeight => 'Add weight';

  @override
  String get logWeight => 'Log weight';

  @override
  String get weightSaved => 'Weight saved';

  @override
  String get latestWeight => 'Latest weight';

  @override
  String get enterWeight => 'Enter your weight';

  @override
  String get weightTitle => 'Weight';

  @override
  String weightKgValue(String value) {
    return '$value kg';
  }

  @override
  String get feedback => 'Feedback';

  @override
  String get feedbackPrompt =>
      'Found a bug or have an idea? We\'d love to hear it.';

  @override
  String get feedbackHint => 'Your feedback…';

  @override
  String get yourEmailOptional => 'Your email (optional)';

  @override
  String get submit => 'Submit';

  @override
  String get feedbackThanks => 'Thanks for your feedback!';

  @override
  String get feedbackError => 'Couldn\'t send feedback. Please try again.';

  @override
  String get feedbackEmpty => 'Please enter some feedback';
}
