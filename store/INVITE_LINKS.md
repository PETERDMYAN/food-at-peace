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

### The website to host — [`store/website/`](website/)

A ready-to-host static site that makes the link **smart** (this is what fixes the
"link doesn't work / detect install / prompt download" report):

```
store/website/
  .well-known/apple-app-site-association   # AASA (universal links)
  i/index.html                             # the /i/<handle> landing page
  404.html                                 # same page — GitHub Pages serves this
                                           #   for /i/<handle> (no per-handle file)
  index.html                               # plain homepage → App Store
```

The landing page (`404.html` / `i/index.html`) detects the visitor and routes:
- **iOS, app installed** → opens the app (Universal Link, or the `foodatpeace://`
  scheme + Safari Smart App Banner "OPEN").
- **iOS, not installed** → the App Store (`id6777715561`) to download.
- **WeChat in-app browser** → a "tap ••• → Open in Safari" hand-off, because WeChat
  **blocks** Universal Links *and* App Store redirects (see `TODO.md` §6 for the
  native WeChat-program follow-up).
- **Android / desktop** → App Store / homepage (the app is iPhone-only).

Host it at the **domain root** so paths resolve as `foodatpeace.app/.well-known/...`
and `foodatpeace.app/i/<handle>`:

1. **Register `foodatpeace.app`** (e.g. Cloudflare/Porkbun/Namecheap, ~US$14/yr).
   `.app` is HTTPS-only (HSTS preloaded) — any modern host gives a free cert.
2. **Publish `store/website/` at the domain root.** Simplest with the existing
   GitHub Pages: point a **custom domain** (`foodatpeace.app`) at the Pages site
   and put these four files at the served root (Pages serves `404.html` for
   `/i/<handle>`, and auto-provisions HTTPS). Cloudflare Pages / Netlify work too
   (set a `/i/* → /i/index.html 200` rewrite). The AWS API stack can also serve it.
3. **Verify:** `curl -i https://foodatpeace.app/.well-known/apple-app-site-association`
   returns the JSON over HTTPS with no redirect, and
   `https://foodatpeace.app/i/<yourhandle>` shows the landing page.

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
