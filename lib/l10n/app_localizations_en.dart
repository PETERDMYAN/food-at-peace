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
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get weatherClear => 'Clear';

  @override
  String get weatherPartlyCloudy => 'Partly cloudy';

  @override
  String get weatherCloudy => 'Cloudy';

  @override
  String get weatherFog => 'Fog';

  @override
  String get weatherDrizzle => 'Drizzle';

  @override
  String get weatherRain => 'Rain';

  @override
  String get weatherSnow => 'Snow';

  @override
  String get weatherThunder => 'Thunderstorm';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get nickname => 'Nickname';

  @override
  String get aboutYouTitle => 'About you';

  @override
  String get aboutYouBody =>
      'Sex, age, height and weight power your calorie and protein targets. Anything Apple Health shared is pre-filled — fill in the rest.';

  @override
  String get todoCompleteProfile => 'Complete your profile';

  @override
  String get todoCompleteProfileBody =>
      'Sex, age, height & weight set your targets';

  @override
  String autoFromGoal(String value) {
    return 'Auto from your goal: $value kcal';
  }

  @override
  String autoProteinRule(String weight, String value) {
    return 'Auto: 1.6 g × $weight kg = $value g';
  }

  @override
  String autoSatFatRule(String value) {
    return 'Auto: 10% of your calorie budget = $value g';
  }

  @override
  String get sourcesTitle => 'Sources & methodology';

  @override
  String get sourcesIntro =>
      'How your targets are estimated, with references you can check.';

  @override
  String get sourcesDisclaimer =>
      'These are general estimates for healthy adults — not medical advice. Talk to a doctor or registered dietitian before making significant changes, especially if you\'re pregnant, under 18, or managing a health condition.';

  @override
  String get viewSource => 'View source';

  @override
  String get howCalculated => 'How your budget is calculated';

  @override
  String get onboardingWelcomeTitle => 'Welcome to\nFood at Peace';

  @override
  String get onboardingWelcomeBody =>
      'Track calories and macros with a calm, simple daily view.';

  @override
  String get onboardingNameTitle => 'What should we call you?';

  @override
  String get onboardingNameBody =>
      'Sign in with Apple to bring your name in, or just type it. We\'ll greet you by name each day.';

  @override
  String get onboardingNameLabel => 'Your name';

  @override
  String get onboardingNameManual => 'Or enter it manually';

  @override
  String get onboardingGoalTitle => 'What\'s your goal?';

  @override
  String get onboardingGoalBody =>
      'This sets your daily calorie gap. You can change it anytime.';

  @override
  String get onboardingHealthTitle => 'Connect Apple Health';

  @override
  String get onboardingHealthBody =>
      'We\'ll read your age, height, weight and calories burned from Apple Health (including Garmin) to keep your targets accurate — refreshed daily.';

  @override
  String get onboardingHealthConnected =>
      'Connected — your stats will stay in sync.';

  @override
  String perDayKcal(String value) {
    return '$value kcal/day';
  }

  @override
  String get continueLabel => 'Continue';

  @override
  String get getStarted => 'Get started';

  @override
  String get skip => 'Skip';

  @override
  String get back => 'Back';

  @override
  String get finishSetup => 'Finish setting up';

  @override
  String get todoAddName => 'Add your name';

  @override
  String get todoAddNameBody => 'So the app can greet you each day';

  @override
  String get todoConnectHealthBody =>
      'Sync your age, height, weight & calories';

  @override
  String get syncedFromHealth => 'Synced from Apple Health';

  @override
  String get heightTitle => 'Height';

  @override
  String get calorieBudgetExplainer =>
      'Your daily calorie budget = BMR + active burn + calorie gap target.';

  @override
  String get navToday => 'Today';

  @override
  String get navTrends => 'Trends';

  @override
  String get navSettings => 'Profile';

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
    return 'Resting $resting · Active $active · Gap $adjustment';
  }

  @override
  String budgetBreakdownEst(String burn, String adjustment) {
    return 'Est. burn $burn · Gap $adjustment';
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
  String daysCount(int count) {
    return '${count}d';
  }

  @override
  String onTargetDays(int met, int total) {
    return 'On target $met/$total days';
  }

  @override
  String onTargetShort(int met, int total) {
    return '$met/$total days';
  }

  @override
  String get editTargets => 'Edit targets';

  @override
  String get useAutomatic => 'Use automatic';

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
  String get calorieGapTarget => 'Calorie gap target';

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
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountBody =>
      'This permanently removes your account and all synced data from our servers, and signs you out. The data on this device is kept. This can\'t be undone.';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get deleteAccountFailed =>
      'Couldn\'t delete the account. Please try again.';

  @override
  String get deleteAccountSignInAgain =>
      'Your session had expired, so nothing was deleted. Sign in again, then retry deleting your account.';

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

  @override
  String get reminders => 'Reminders';

  @override
  String get remindersSubtitle =>
      'Friendly nudges to log your meals — breakfast, lunch, dinner and a late-night check-in.';

  @override
  String get remindersEnable => 'Daily meal reminders';

  @override
  String get remindersDenied =>
      'Notifications are off for this app. Turn them on in Settings to get reminders.';

  @override
  String remindersActive(int count) {
    return '$count on';
  }

  @override
  String get remindersOff => 'Off';

  @override
  String get remindersNone => 'No reminders yet. Add one below.';

  @override
  String get addReminder => 'Add reminder';

  @override
  String get onboardingRemindersTitle => 'Stay on track';

  @override
  String get onboardingRemindersBody =>
      'We\'ll send light, friendly nudges to log your meals — breakfast, lunch and dinner (plus an optional late-night check-in). Change or turn them off anytime in Settings.';

  @override
  String get enableReminders => 'Enable reminders';

  @override
  String get onboardingRemindersEnabled =>
      'Reminders on — we\'ll help you keep the habit.';

  @override
  String get reminderBreakfastTitle => 'Breakfast o\'clock 🍳';

  @override
  String get reminderBreakfastBody =>
      'Fuel up — then log it before the day runs away with you.';

  @override
  String get reminderLunchTitle => 'Lunch break! 🥪';

  @override
  String get reminderLunchBody =>
      'Whatever\'s on your plate, give it a quick log. Two taps, done.';

  @override
  String get reminderDinnerTitle => 'Dinner\'s served 🍝';

  @override
  String get reminderDinnerBody =>
      'Don\'t let those calories sneak by unlogged — quick, before dessert!';

  @override
  String get reminderSnackTitle => 'Late-night nibbles? 🌙';

  @override
  String get reminderSnackBody =>
      'Snacks count too — no judgment. Pop it in and call it a day.';

  @override
  String get beans => 'Beans';

  @override
  String get beansBalance => 'Beans balance';

  @override
  String get beansPerScan => '1 Bean per photo scan';

  @override
  String get beansHistory => 'Transaction history';

  @override
  String get beansEmpty => 'No transactions yet.';

  @override
  String get topUp => 'Top up';

  @override
  String get beansGrant => 'Welcome bonus';

  @override
  String get beansSpend => 'Photo scan';

  @override
  String get beansPurchase => 'Top-up';

  @override
  String get beansRefund => 'Refund';

  @override
  String beansCount(int count) {
    return '$count Beans';
  }

  @override
  String priceSgd(String value) {
    return 'SGD $value';
  }

  @override
  String get paywallTitle => 'You\'re out of Beans';

  @override
  String get paywallBody =>
      'Each photo scan uses 1 Bean. Top up to keep scanning your meals.';

  @override
  String get beansStubNote =>
      'Demo build — purchases credit instantly; real billing is coming.';

  @override
  String beansBought(int count) {
    return 'Added $count Beans';
  }

  @override
  String scansLeft(int count) {
    return '$count scans left';
  }

  @override
  String get iapUnavailable => 'Purchases aren\'t available right now.';

  @override
  String get iapPending => 'Your purchase is processing…';

  @override
  String get iapFailed => 'Purchase failed. Please try again.';

  @override
  String get beansChoosePack => 'Top up Beans';

  @override
  String get beansSecretUnlocked => 'Secret pack unlocked 🫘';

  @override
  String get beansCustom => 'Custom';

  @override
  String get beansCustomTitle => 'Custom top-up';

  @override
  String get beansCustomLabel => 'Number of Beans';

  @override
  String get beansBestValue => 'Best value';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get dashboardSample =>
      'Sample data — wire analytics + App Store Connect to see real numbers.';

  @override
  String get mDownloads => 'Downloads';

  @override
  String get mActiveToday => 'Active today';

  @override
  String get mOpens => 'Total opens';

  @override
  String get mOpens7d => 'Opens · last 7 days';

  @override
  String get mPhotos => 'Photos scanned';

  @override
  String get mBeansSold => 'Beans sold';

  @override
  String get mRevenue => 'Revenue';

  @override
  String get mRefunds => 'Refunds';

  @override
  String versionLabel(String name, String version, String build) {
    return '$name $version ($build)';
  }

  @override
  String get accountIdTitle => 'Account ID';

  @override
  String get accountIdHint => 'Your account\'s ID in the sync database.';

  @override
  String get accountIdSignedOut => 'Sign in to see your account ID.';

  @override
  String get accountIdCopied => 'Account ID copied';

  @override
  String get copy => 'Copy';

  @override
  String get close => 'Close';

  @override
  String get yourCircle => 'Your circle';

  @override
  String get evaDailyLesson => 'Daily lesson';

  @override
  String get addFriend => 'Add';

  @override
  String get circleRequests => 'Requests';

  @override
  String circleRequestsN(int count) {
    return 'Requests ($count)';
  }

  @override
  String get pendingLabel => 'Pending';

  @override
  String get invitePeople => 'Add a friend';

  @override
  String get inviteShareLink => 'Share invite link';

  @override
  String get inviteLinkCopied => 'Invite link copied';

  @override
  String get inviteHandleHelp =>
      'A friend\'s @username is shown at the top of their own Add-friend screen — ask them for it.';

  @override
  String get inviteSend => 'Send invite';

  @override
  String inviteSent(String handle) {
    return 'Invite sent to $handle';
  }

  @override
  String get yourHandle => 'Your handle';

  @override
  String get setHandle => 'Set your handle';

  @override
  String get handleHint => 'letters, numbers or _';

  @override
  String handleCopied(String handle) {
    return 'Copied $handle';
  }

  @override
  String handleSaved(String handle) {
    return 'You\'re $handle — share it so friends can add you';
  }

  @override
  String get handleTaken => 'That handle is taken — try another';

  @override
  String get handleInvalid => 'Use 2–20 letters, numbers or _';

  @override
  String get handleError => 'Couldn\'t save your handle — try again';

  @override
  String get shareToCircle => 'Share to circle';

  @override
  String get shareToCircleHint => 'Friends in your circle see it for 3 days';

  @override
  String get feedTitle => 'Circle feed';

  @override
  String get feedYou => 'You';

  @override
  String get foodStory => 'Food story';

  @override
  String get foodStoryArchive => 'Last 7 days';

  @override
  String get shareFirstMeal => 'Scan a meal to start your food story.';

  @override
  String get deleteStory => 'Delete from story';

  @override
  String get deleteStoryBody =>
      'Remove this meal from your food story? This also deletes the log entry.';

  @override
  String get storyDeleted => 'Removed from your food story';

  @override
  String get profilePhoto => 'Profile photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get feedSomeone => 'Someone';

  @override
  String get feedEmpty =>
      'No posts yet. Scan a meal and share it to your circle.';

  @override
  String feedReceived(int count) {
    return '$count reactions';
  }

  @override
  String get todayLabel => 'Today';

  @override
  String get streakLabel => 'Streak';

  @override
  String streakDays(int count) {
    return '$count days';
  }

  @override
  String get friendAdherence => 'On-target · last 7 days';

  @override
  String get removeFriend => 'Remove from circle';

  @override
  String removeFriendQ(String name) {
    return 'Remove $name from your circle?';
  }

  @override
  String get noRequests => 'No pending requests.';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String friendAccepted(String name) {
    return '$name joined your circle 🎉';
  }

  @override
  String get manageCircle => 'Manage circle';

  @override
  String get shareInvite => 'Share invite';

  @override
  String get scanToConnect => 'Scan to add me to your circle';

  @override
  String get inviteLinkLabel => 'Your invite link';

  @override
  String get copyLink => 'Copy link';

  @override
  String shareInviteMessage(String link) {
    return 'Add me on Food at Peace 🍵 $link';
  }

  @override
  String get connectTitle => 'Add to your circle';

  @override
  String connectPrompt(String handle) {
    return 'Connect with $handle? You\'ll each see the other\'s daily food trends.';
  }

  @override
  String get connectCta => 'Connect';

  @override
  String get connecting => 'Connecting…';

  @override
  String connectedToast(String name) {
    return 'You\'re now connected with $name 🎉';
  }

  @override
  String get connectFailed => 'Couldn\'t connect — please try again.';

  @override
  String get sectionConnected => 'Connected';

  @override
  String get sectionRequests => 'Requests';

  @override
  String get sectionInvited => 'Invited';

  @override
  String get cancelInvite => 'Cancel';

  @override
  String get circleEmpty =>
      'Your circle is empty. Share your invite link to add friends.';

  @override
  String get circleActivity => 'Circle activity';

  @override
  String get circleActivitySubtitle =>
      'Get notified when a friend shares a meal';

  @override
  String circleSharedMeal(String name) {
    return '$name shared a meal 🍵';
  }

  @override
  String get aFriend => 'A friend';

  @override
  String circleRequestNotif(String name) {
    return '$name wants to join your circle 👋';
  }

  @override
  String circleAcceptedNotif(String name) {
    return '$name accepted — you\'re connected 🎉';
  }

  @override
  String circleReactionNotif(String name, String emoji) {
    return '$name reacted $emoji to your meal';
  }

  @override
  String get addByHandle => 'Add by @handle';

  @override
  String addByHandleSent(String handle) {
    return 'Friend request sent to $handle';
  }
}
