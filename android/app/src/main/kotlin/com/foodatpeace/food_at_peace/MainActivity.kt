package com.foodatpeace.food_at_peace

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (a FragmentActivity → androidx ComponentActivity) so
// plugins that register against ComponentActivity's ActivityResult APIs
// (image_picker photo picker, sign_in_with_apple, in_app_purchase, …) attach
// instead of throwing ClassCastException during GeneratedPluginRegistrant.
class MainActivity : FlutterFragmentActivity()
