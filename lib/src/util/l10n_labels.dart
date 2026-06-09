import 'package:food_at_peace/l10n/app_localizations.dart';

import '../models/meal_type.dart';
import '../models/user_profile.dart';

/// Localized display labels for the domain enums (which stay pure Dart, so they
/// can't reference [AppLocalizations] directly).
extension SexL10n on Sex {
  String labelOf(AppLocalizations t) => switch (this) {
    Sex.male => t.sexMale,
    Sex.female => t.sexFemale,
  };
}

extension ActivityLevelL10n on ActivityLevel {
  String labelOf(AppLocalizations t) => switch (this) {
    ActivityLevel.sedentary => t.activitySedentary,
    ActivityLevel.light => t.activityLight,
    ActivityLevel.moderate => t.activityModerate,
    ActivityLevel.active => t.activityActive,
    ActivityLevel.veryActive => t.activityVeryActive,
  };

  String hintOf(AppLocalizations t) => switch (this) {
    ActivityLevel.sedentary => t.activitySedentaryHint,
    ActivityLevel.light => t.activityLightHint,
    ActivityLevel.moderate => t.activityModerateHint,
    ActivityLevel.active => t.activityActiveHint,
    ActivityLevel.veryActive => t.activityVeryActiveHint,
  };
}

extension GoalL10n on Goal {
  String labelOf(AppLocalizations t) => switch (this) {
    Goal.lose => t.goalLose,
    Goal.maintain => t.goalMaintain,
    Goal.gain => t.goalGain,
  };
}

extension MealTypeL10n on MealType {
  String labelOf(AppLocalizations t) => switch (this) {
    MealType.breakfast => t.mealBreakfast,
    MealType.lunch => t.mealLunch,
    MealType.dinner => t.mealDinner,
    MealType.snack => t.mealSnack,
  };
}
