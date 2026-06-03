import 'package:flutter/material.dart';

import 'src/features/home/home_shell.dart';
import 'src/theme/app_theme.dart';

class FoodAtPeaceApp extends StatelessWidget {
  const FoodAtPeaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food at Peace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomeShell(),
    );
  }
}
