import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'src/data/meal_photos.dart';
import 'src/data/profile_photo.dart';
import 'src/providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final mealPhotos = await MealPhotos.create();
  final profilePhotoFile = await resolveProfilePhotoFile();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mealPhotosProvider.overrideWithValue(mealPhotos),
        profilePhotoFileProvider.overrideWithValue(profilePhotoFile),
      ],
      child: const FoodAtPeaceApp(),
    ),
  );
}
