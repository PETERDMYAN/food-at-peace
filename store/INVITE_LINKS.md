# Circle invite links (universal links)

Circle invites are **universal links** of the form:

```
https://foodatpeace.app/i/<handle>
```

The app shares this as a tappable link (WeChat / WhatsApp / SMS / anywhere) and
as a QR code. When the recipient has the app installed, iOS opens it straight to
a **"Add @handle to your circle?"** sheet; one tap connects both sides as mutual
friends (`POST /circle/connect`). Without the app, the link falls back to the
website.

A custom-scheme form — `foodatpeace://i/<handle>` — is **also** handled by the
app (registered in `ios/Runner/Info.plist`). It needs no domain or entitlement,
so the connect flow is testable on a device right now, before the steps below
are done. WeChat/WhatsApp won't open a custom scheme, though — the universal
link is what makes sharing work, so finish the two steps below for production.

## What's already in the app

- **Associated Domains entitlement** — `applinks:foodatpeace.app`
  (`ios/Runner/Runner.entitlements`).
- **In-app handler** — `app_links` listens for both the universal link and the
  custom scheme and shows the Connect sheet (`lib/app.dart` →
  `lib/src/features/circle/connect_sheet.dart`).
- **Single source of truth** for the URL/parse logic:
  `lib/src/data/invite_link.dart` (change `kInviteDomain` there if the domain
  differs).

## Step 1 — You must own `foodatpeace.app` and host the AASA file  **(you)**

Apple fetches an **Apple App Site Association** file to learn which app owns the
domain. Host the file in this repo at:

```
https://foodatpeace.app/.well-known/apple-app-site-association
```

Requirements (Apple is strict):
- Served over **HTTPS** with a valid certificate.
- `Content-Type: application/json`.
- **No `.json` extension** on the path.
- No redirects.

The ready-to-host file is committed at
[`store/apple-app-site-association`](apple-app-site-association):

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["GJB4AB92L4.com.foodatpeace.foodAtPeace"],
        "components": [{ "/": "/i/*", "comment": "Circle invite links" }]
      }
    ]
  }
}
```

(`GJB4AB92L4` is the Team ID; `com.foodatpeace.foodAtPeace` the bundle ID.)

If you don't own a domain yet: any static host works (the same GitHub Pages site
that serves the privacy policy can serve `/.well-known/apple-app-site-association`
from the repo root — but a **project** Pages site lives under a path, and AASA
must be at the domain root, so you'd need a custom domain or a `<user>.github.io`
root repo). A custom domain on the existing Pages site is the simplest path.

## Step 2 — Enable the Associated Domains capability on the App ID

The next signed build needs the App ID to carry the **Associated Domains**
capability. The headless export already passes `-allowProvisioningUpdates` with
the App Store Connect API key, which auto-adds the capability and regenerates the
profile — so a normal `flutter build ipa` + export (see `PUBLISHING.md` Path D)
should just work. If it ever fails to provision, enable **Associated Domains**
manually for `com.foodatpeace.foodAtPeace` at
developer.apple.com → Identifiers, then rebuild.

## Verifying

- **Custom scheme (works today):** with the app installed on a device,
  `foodatpeace://i/<yourhandle>` opens the Connect sheet. Easiest test:
  put it behind a tappable link or run
  `xcrun simctl openurl booted "foodatpeace://i/test"` on the simulator.
- **Universal link (after Steps 1–2):** Apple validates the AASA at
  install/update; tapping `https://foodatpeace.app/i/<handle>` in Messages/Notes
  opens the app. Check `https://foodatpeace.app/.well-known/apple-app-site-association`
  returns the JSON with `Content-Type: application/json`.
