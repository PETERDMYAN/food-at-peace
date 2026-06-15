import 'package:flutter/material.dart';

/// App-wide messenger key so non-widget code (e.g. the circle-activity check)
/// can show an in-app SnackBar reliably over whatever screen is showing —
/// including right after launch, where `ScaffoldMessenger.of(context)` can race
/// the first frame.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
