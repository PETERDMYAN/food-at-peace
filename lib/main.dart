import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'src/data/meal_photos.dart';
import 'src/providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final mealPhotos = await MealPhotos.create();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mealPhotosProvider.overrideWithValue(mealPhotos),
      ],
      child: const FoodAtPeaceApp(),
    ),
  );
}
