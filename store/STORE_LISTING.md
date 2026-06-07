# App Store Connect listing — Food at Peace

Copy/paste these into App Store Connect. Fields with **[ACTION]** need a decision or asset from you.

---

## App information

- **Name** (max 30): `Food at Peace`
- **Subtitle** (max 30): `Calorie & protein tracker`
- **Bundle ID**: `com.foodatpeace.foodAtPeace`
- **Primary category**: Health & Fitness
- **Secondary category** (optional): Food & Drink
- **Primary language**: English (U.S.)  ·  also localized to Chinese (Simplified)

## URLs

- **Privacy Policy URL**: host `store/privacy-policy.html` and paste the URL
  (GitHub Pages: `https://PETERDMYAN.github.io/food-at-peace/store/privacy-policy.html`)
- **Support URL** (required): `store/support.html`
  (GitHub Pages: `https://PETERDMYAN.github.io/food-at-peace/store/support.html`)
- **Marketing URL** (optional): leave blank or your site
- **Support contact email**: peter.yandongming@gmail.com

## Promotional text (max 170, editable anytime without review)

```
Log meals in seconds, snap a photo to estimate nutrition, and see exactly how many calories you have left today — with your Apple Health activity factored in.
```

## Description (max 4000)

```
Food at Peace is a calm, no-nonsense calorie and macro tracker. Log what you eat, see how much you can still eat today, and keep protein and saturated fat on target — without ads, accounts, or noise.

TODAY AT A GLANCE
• A clean ring shows the calories you have left for the day.
• Protein and saturated-fat quota cards show consumed vs. target, and how much is left or over.

LOG IN SECONDS
• Add meals manually: calories, protein, saturated fat, meal, and serving.
• Or snap a photo of your plate and let AI estimate the calories, protein, and saturated fat for you — review the estimate, then log it.

YOUR ACTIVITY, COUNTED
• Connect Apple Health to fold in the calories you actually burned — basal plus active energy — so "calories left" reflects your real day.
• Workout and energy data from Garmin and other devices flows in automatically through Apple Health.

TARGETS THAT MAKE SENSE
• Calorie target from the Mifflin–St Jeor formula and your activity, adjusted for your goal (lose, maintain, or gain).
• Protein target based on your bodyweight.
• Saturated-fat cap based on US Dietary Guidelines.

ALSO INSIDE
• Weight log to track progress over time.
• History grouped by day with daily totals.
• English and Chinese (Simplified).

PRIVACY FIRST
• Your profile and food log stay on your device.
• No accounts, no ads, no third-party tracking.
• Health data is read on-device to do the math and is never sold or shared.

Photo analysis is powered by Anthropic's Claude. You can use the built-in option or add your own Anthropic API key in Settings.
```

## Keywords (max 100 chars, comma-separated, no spaces after commas)

```
calorie counter,macro,protein,nutrition,food diary,diet,health,weight,saturated fat,tdee,bmr,log
```

## What's New (version 1.0.0)

```
First release. Track calories and macros, snap a photo to estimate a meal, and factor in your Apple Health activity. Thanks for trying Food at Peace!
```

---

## App Review notes (paste into "Notes" of the submission)

```
Food at Peace has no login or account — all core features are available immediately.

PHOTO NUTRITION ANALYSIS (Anthropic Claude):
This build ships with a working API key, so you can test the feature directly. On the Add screen, tap the photo/camera option, choose or take a photo of a meal, and the app returns an estimate to confirm before logging. Users may optionally enter their own Anthropic API key in Settings instead. (Camera requires a physical device; choosing an existing photo works in Simulator.)

APPLE HEALTH (HealthKit):
The app reads active/basal energy burned, body weight, and workouts to calculate how many calories the user can still eat, and (with permission) writes the calories/protein/saturated fat the user logs back to Health. Please allow the Health permission prompts on first run. Note: a fresh Simulator has no Health data, so "calories out" may be 0 there — manual logging still demonstrates all targets. Best tested on a physical iPhone.

No demo account is required.
```

- **Sign-in required?** No
- **Demo account**: not applicable
- **Contact info**: Dongming (Peter) YAN · peter.yandongming@gmail.com · phone **[ACTION: add a number]**

---

## Age rating questionnaire — suggested answers

Answer **None / No** to all content categories (violence, sexual content, profanity,
gambling, etc.). Food at Peace has no objectionable content → expect a 4+ rating.
Note: it is NOT a medical/treatment app — it's general wellness, so you can answer
"No" to the medical/treatment questions.

## App Privacy (data collection questionnaire) — suggested answers

Match these to the privacy manifest and policy:

- **Health & Fitness**: Collected? **No** — health data is read/written on-device via
  HealthKit and never leaves the device or reaches us. (Apple treats on-device
  HealthKit use that isn't transmitted off device as "not collected".)
- **Photos**: Data Used? Declare **Photos** → **App Functionality**, **Not linked**
  to identity, **Not used for tracking**. (A meal photo is sent to Anthropic to
  produce the estimate.)
- **Contact Info / Identifiers / Usage Data / Location / etc.**: **Not collected**.
- **Tracking**: **No** (matches NSPrivacyTracking=false).

---

## Screenshots — **[ACTION]** required before submission

Required: **6.7" iPhone** (1290 × 2796) — at least 1, up to 10. A 6.7" set alone
satisfies all modern iPhone sizes. (6.5" 1242×2688 is optional/legacy.)
Suggested shots: Today dashboard · Add (manual) · Photo-analysis result ·
History · Settings/targets. Capture them on a physical device or Simulator
(see PUBLISHING.md for the exact commands).
