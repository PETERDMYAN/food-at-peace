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
Log meals in seconds, snap a photo to estimate nutrition, and see exactly how many calories you have left today — with your real Apple Health burn factored in.
```

## Description (max 4000)

```
Food at Peace is a calm, no-nonsense calorie and macro tracker. Log what you eat, see how much you can still eat today, and keep protein and saturated fat on target — without ads, noise, or guesswork.

TODAY AT A GLANCE
• A greeting with your local weather, then a clean ring with the calories you have left.
• Your budget is transparent: resting burn + active burn + your calorie gap, spelled out on the card.
• Protein and saturated-fat cards show consumed vs. target and what's left.

LOG IN SECONDS
• Add meals manually: calories, protein, saturated fat, meal, and serving.
• Or snap a photo of your plate and let AI estimate the calories, protein, and saturated fat — review the estimate, then log it.
• Photo scans run on Beans, a simple in-app credit: each scan uses one Bean and you start with 100 free. Top up whenever you like — manual logging is always free.

YOUR ACTIVITY, COUNTED
• Connect Apple Health and your budget uses the calories you actually burned — resting plus active energy.
• Your age, height, and weight stay in sync with Apple Health (and your smart scale), with a Sync-now button when you want it fresh.
• Garmin and other devices flow in automatically through Apple Health.

TRENDS THAT TELL YOU SOMETHING
• Daily charts for calories, protein, and saturated fat vs. your target.
• 1, 7, or 30-day windows, paging into the past, and tap any day to inspect it.
• Each chart leads with how many days you were on target.

TARGETS THAT MAKE SENSE — AND SHOW THEIR WORK
• Calorie budget from the Mifflin–St Jeor equation plus your measured activity and goal (lose, maintain, or gain).
• Protein target from your bodyweight; saturated-fat cap per the US Dietary Guidelines.
• Every formula is cited in-app: see "Sources & methodology" with links to the original references.

SHARE WITH YOUR CIRCLE
• Build a small, private Circle of friends — invite by a link or QR code, and a single tap connects you both.
• Share a scanned meal to your Circle and cheer each other on with quick emoji reactions.
• Posts are ephemeral — every shared meal disappears after 3 days, and only mutually-connected friends ever see them.

SYNC, IF YOU WANT IT
• Optional Sign in with Apple keeps your log and profile in sync across devices.
• Skip it entirely — everything works offline and on-device.

ALSO INSIDE
• English and Chinese (Simplified).
• A focused dark design that stays out of your way.

PRIVACY FIRST
• Your data stays on your device unless you choose to sync.
• No ads and no third-party tracking.
• Health data is read on-device to do the math and is never sold or shared.

Photo analysis is powered by Anthropic's Claude. Estimates are general wellness guidance, not medical advice.
```

## Keywords (max 100 chars, comma-separated, no spaces after commas)

```
calorie counter,macro,protein,nutrition,food diary,diet,health,weight,saturated fat,tdee,bmr,log
```

## What's New (version 1.0.1)

```
• Your Beans balance now syncs with your account, so it follows you across devices.
• Smoother top-up: clearer purchase feedback and protection against accidental double taps.
• Circle push notifications — get notified when a friend asks to connect, accepts your invite, shares a meal, or reacts to one of yours.
• Polish and performance improvements throughout.
```

(1.0.0 was: First release. Track calories and macros, snap a photo to estimate a meal, factor in your real Apple Health burn, and see your trends — with every formula cited under Sources & methodology.)

---

## App Review notes (paste into "Notes" of the submission)

```
RESOLUTION OF GUIDELINE 1.4.1 (previous submission b46a8aa4-30dd-4a47-90e8-e6a8c7fe54c5):
The app now includes citations for all health calculations, easy to find from both places the reviewer flagged:
• Today tab → "How your budget is calculated" (link directly under the calorie/macro cards) opens the Sources & methodology screen.
• Settings tab → "Sources & methodology" card opens the same screen.
The screen explains each calculation and cites primary sources with tappable links: Mifflin–St Jeor resting-energy equation (Am J Clin Nutr, 1990; PubMed), the US Dietary Guidelines for Americans 2020–2025 (calorie budget and the 10% saturated-fat cap), and the International Society of Sports Nutrition position stand on protein (2017). A prominent disclaimer states these are general estimates for healthy adults and not medical advice. Settings also shows the budget formula inline ("Your daily calorie budget = BMR + active burn + calorie gap target").

SIGN-IN (optional):
Sign in with Apple is optional and only enables cross-device sync — every feature works without an account, so no demo account is needed. You can test sign-in with any Apple ID.

ACCOUNT DELETION (Guideline 5.1.1(v)):
Settings → Account → "Delete account" permanently removes the user's account and all synced data from our server (immediate, server-side deletion — not just a deactivation) and signs them out. It's available in-app whenever the user is signed in.

PHOTO NUTRITION ANALYSIS (Anthropic Claude):
Photo analysis works out of the box (the API key lives on our server; the app ships none). On the Add screen, tap the camera/photo option, choose or take a photo of a meal, and the app returns an estimate to confirm before logging. (Camera requires a physical device; choosing an existing photo works in Simulator.)

APPLE HEALTH (HealthKit):
The app reads active/basal energy, weight, height, date of birth (for age), biological sex, and workouts to compute the calorie budget, and (with permission) writes logged food, weight, and height back. Please allow the Health prompts on first run. A fresh Simulator has no Health data, so the onboarding "About you" step will simply be blank for manual entry — best tested on a physical iPhone.

LOCATION (optional):
Used only to show local weather on the Today screen (Open-Meteo). Declining the prompt is fine — the app falls back to an approximate IP-based location or simply hides the weather.
```

- **Sign-in required?** No (optional; only for sync)
- **Demo account**: not applicable
- **Contact info**: Dongming (Peter) YAN · peter.yandongming@gmail.com · phone **[ACTION: add a number]**

---

## Age rating questionnaire — suggested answers

Answer **None / No** to all content categories (violence, sexual content, profanity,
gambling, etc.). Food at Peace has no objectionable content → expect a 4+ rating.
Note: it is NOT a medical/treatment app — it's general wellness (and now carries an
in-app disclaimer + citations), so answer "No" to the medical/treatment questions.

## App Privacy (data collection questionnaire) — suggested answers

Match these to the privacy manifest (`ios/Runner/PrivacyInfo.xcprivacy`) and policy:

- **Health & Fitness**: **Collected** → App Functionality, **Linked** to identity,
  **Not used for tracking**. (Only when the user opts into Sign in with Apple sync:
  the food log, weight history, and profile — which can include Health-derived
  weight/height/age/sex — are stored on our server keyed to their account.)
- **Contact Info → Name / Email Address**: **Collected** → App Functionality,
  **Linked**, **Not tracking** (shared via Sign in with Apple at the user's choice).
- **Identifiers → User ID**: **Collected** → App Functionality, **Linked**,
  **Not tracking** (the Sign in with Apple user identifier).
- **Location → Coarse Location**: **Collected** → App Functionality,
  **Not linked**, **Not tracking** (sent to the weather API only; never stored).
- **Photos**: **Collected** → App Functionality, **Not linked**, **Not tracking**
  (a meal photo is sent through our proxy to Anthropic to produce the estimate).
- **Tracking**: **No** (matches NSPrivacyTracking=false).

---

## Screenshots — **[ACTION]** required before submission

Required: **6.7" iPhone** (1290 × 2796) — at least 1, up to 10. A 6.7" set alone
satisfies all modern iPhone sizes. (6.5" 1242×2688 is optional/legacy.)
Suggested shots: Today dashboard (greeting + weather + ring) · Add (manual) ·
Photo-analysis result · Trends (with the on-target badges) · Settings (targets +
Sources & methodology). Capture them on a physical device or Simulator
(see PUBLISHING.md for the exact commands).
