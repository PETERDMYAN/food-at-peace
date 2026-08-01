# Food at Peace

A calorie & macro tracker for iOS (and later Android). Log what you eat — by hand
or by **snapping a photo** — see how much you can still eat today, and keep an eye
on your protein and saturated-fat quotas. Connects to **Apple Health / Garmin**
for real calories burned, and speaks **English and 中文**. Built with Flutter.

> **Status:** **1.1.1 (build 77) is approved & live on the App Store** (Eva Official ✓ badge + push
> deep-linking; CN name **食之安**), and **1.1.2 (build 78) — Circle photos now last 30 days — is submitted
> to App Review** (2026-07-27). Prior live: 1.1.0 (75) `f99cb1b`, v1.0.2 (62) `54166a7`, v1.0.1 `1c6ca03`.
> Web Beans recharge at `foodatpeace.app/recharge` is also fully live (Stripe live keys, webhook verified,
> Sign in with Apple on the web, shareable `/recharge/<handle>` links). Tags `v1.1.0`/`v1.1.1` created with
> the 1.1.2 ship (were pending confirmation).
> **Web recharge tiers (2026-08-01):** the 300/S$5.99 pack is delisted from the page (still honored
> server-side for cached copies) and a web-only **8,000 beans / S$120.99** "Best value" pack was added —
> live on prod + v2 + the published page. In-app IAP lineup (25…800) unchanged.
> **Circle photo retention 3 → 30 days (1.1.2, build 78):** shared Circle photos/posts (and their reactions +
> comments — one `TTL_SECONDS` in `posts.py`, plus the `CirclePhotosBucket` S3 lifecycle) now live **30 days**
> instead of 3. Live on **v2 AND prod** (changeset preview; a fresh post's expiry verified at exactly +30 d;
> all 30 live prod rows backfilled +27 d so nothing posted under the 3-day regime vanishes early — S3 objects
> extend automatically, age-based). Client (build 78): the share-to-circle hint reads **"Friends in your
> circle see it for 30 days" / "圈子好友可见 30 天"**. Additive — no request/response shape change; presigned
> URL TTLs (6 h) untouched; Eva's 3-day *story lesson* window is a separate client design and unchanged.
> Sim-verified (share-hint before/after captured; QA suite 8/8 after refreshing its stale `1.0`-only version
> matcher).
> **Eva broadcast capability (1.1.1, build 76 — live on prod):** an owner-only **`POST /circle/official-post`**
> (admin-token gated) + **`backend/scripts/official_post.py --handle eva`** publishes a **photo + text post as a
> chosen official account** (**Eva** or Roro — they're DISTINCT accounts). The server now **surfaces the Eva
> account in the feed** (`feed` + `official_feed` carry Eva alongside Roro — **Roro's path is untouched**;
> Eva is only added, deduped), so an existing installed app shows Eva's posts with **no update**. The client
> **Official ✓ badge** now covers Eva too (`kEvaHandle` / `isOfficialHandle`) — that part ships in build 76.
> Backend additive + backward-compatible (1.0.2/1.1.0 contract intact, `AppleClientId` preserved); the Eva
> account was created on prod (`handle#eva`). The 1.1.0 launch announcement is posted as Eva on the live feed.
> **Push deep-linking (1.1.1, build 77):** tapping a push now navigates **directly** to the target — a friend's
> **new meal**/reaction → the Circle tab on that post; a **comment / reply / @mention** → that post's **comment
> thread**, opened automatically. APNs carries route keys (`apns.py`/`posts.py`); native iOS forwards taps over
> a method channel (`AppDelegate.swift`, incl. cold-start) → `NotificationRouter` → `pendingDeepLinkProvider` →
> HomeShell + `CircleFeedBody`. Additive (old clients ignore the keys). Tap-routing is device-verified.
> **Next (1.1.0, dev on `main`):** the **Circle name-drift** fix — renaming yourself now propagates to what
> friends see (`list_circle` serves each friend's *live* me-card name; a nickname-only edit re-registers it).
> The backend (read-live) is now **live on v2 + prod** (2026-06-24, backward-compatible — same response
> shape); only the app change (nickname-only re-register) rides the 1.0.3 cutover.
> **Circle comments + more (this session — shipping as 1.1.0, TestFlight builds 63–75):** Circle feed posts can
> now be **commented on**, as **private per-commenter threads** with the post owner as the hub — the **owner**
> sees every commenter's thread and replies into each; a **commenter** sees only their *own* thread (their
> comments + the owner's replies), never another commenter's. A new comment pushes the owner; an owner reply
> pushes that commenter. The **post owner can delete any comment** (a commenter, their own). Also in build 63:
> the **stories-strip ring bug** is fixed — a friend with no shared posts no longer shows a false "unseen
> stories" ring (`friendHasStory` gates the ring; new users render a plain avatar). **Build 64** adds an
> **inline comment preview** on each feed card — the most recent few comments *visible to that viewer* + a
> **"View all N comments"** link — plus a **Beans-ledger fix**: an early admin grant wrote a numeric `ts` the
> app's parser (`ts as String`) choked on, crashing the whole `/beans` fetch; the response now normalizes any
> numeric `ts` / off-model type, so balances sync again (e.g. `foodie` → 288). **Build 65** lets the **post
> owner post a PUBLIC comment** everyone sees (stored under a `__public__` thread sentinel), distinct from a
> private reply — a non-owner can never broadcast — and adds **relative timestamps** ("5 minutes ago" / "3
> hours ago" / "2 days ago") to feed posts + the food story. Backend is **additive +
> live on v2 AND prod** (new `/circle/comment`, `/circle/comments`, `/circle/comment/delete` routes; comment
> rows reuse `PostsTable`'s 3-day TTL; a per-viewer `commentCount` on the feed — old clients ignore it; the
> 1.0.2 contract was verified intact via changeset preview, `AppleClientId` preserved). Privacy invariant
> locked by the **`circle-comments-privacy`** skill; backend + widget tests green (`test_posts.py` encodes
> "A sees 1, B sees 2, owner sees 3").
> **Builds 66–70 — comments UX polish (all client-only; backend unchanged):** the comment sheet is now ~3/5
> of the screen with a close ✕; there's a **single composer** (owner types `@handle` for a private reply, plain
> text = public) with a **local `@`-mention picker** (no server round-trip); the **whole comment area on a card
> is tappable** to open the sheet; comment fetches were de-spinnered (cached + `skipLoadingOnReload`) so reopen
> is instant. **Build 70** is the last polish pass: comments are **posted optimistically** — your message shows
> at once with a sending spinner, then a **retry icon if the send fails** (tap to resend), replaced by the real
> row on success; the sheet shows **one time-ranked list** of every comment the viewer may see, each carrying a
> small **audience tag** ("Everyone" / "Only PY" / "Private") rather than split sections; and **delete removes a
> comment for everyone** (server hard-delete). Analyze + 182 Flutter + 169 backend tests green.
> **Build 71 — clearer private tag:** a commenter's private comment now reads **"Only you & 〈owner〉"**
> (e.g. *仅你和 Eva 可见*) instead of a bare **"Private"**, so the audience is self-explanatory (it names the post
> owner — the only other person who can see it). Client-only string/label change.
> **Build 72 — owner can @-mention a friend to start a private thread + push on @-mention:** previously the
> **owner** could only privately reply to someone who had *already* commented — so on a brand-new post there was
> no way to begin a private comment. Now the owner's `@`-mention picker also lists **connected circle friends**
> (not just existing commenters), and `@`-mentioning one **opens a fresh private thread** visible to only that
> friend + the owner; that friend gets a **push** ("〈owner〉 mentioned you in a comment 💬"; a follow-up into the
> now-existing thread reads as "replied to your comment"). Backend change is **additive + backward-compatible**
> (the owner-reply path now *also* accepts a connected friend with no prior comment — old clients that only reply
> into existing threads are unaffected; no 1.0.2 endpoint touched). analyze + 183 Flutter + 170 backend green.
> **Build 73 — onboarding "Signed in ✓" confirmation (sign-in *looked* broken):** Sign in with Apple actually
> *worked* on first onboarding (server verified the token, session stored), but the welcome page never reflected
> it — it kept showing the Apple button with no confirmation (and on a reinstall Apple returns a null name, so
> even the name field didn't change), so it read as "it still asks me to connect." The page now swaps the Apple
> button for a **"Signed in with Apple ✓"** state once a session exists (`_NamePage` watches `authProvider`).
> Client-only; no auth-flow or backend change. analyze + 183 Flutter tests green.
> **Build 74 — Comments & mentions notification toggle (Reminders screen):** a new switch next to *Circle
> activity* — **"Comments & mentions / Get notified when a friend comments on, replies to, or @-mentions you"**
> (中文: *评论与@提及*). Unlike the master Circle toggle (which gates device registration), this is a **per-user
> server-enforced preference**: the client syncs it to a new **`POST /circle/notify-prefs`** (`{comments}`),
> stored on a `notifyprefs` row, and **posts.py checks it before sending** each comment / reply / @-mention push
> (`_comment_notify_ok`). **Additive + backward-compatible** — absent pref → ON, so existing users are
> unaffected; no 1.0.2 endpoint touched. analyze + 183 Flutter + 173 backend tests green.
> **Build 75 — onboarding auto-advances after sign-in + Reminders count fix (both client-only):** (1) once Sign
> in with Apple succeeds, the welcome page now **auto-advances** to the next step after a brief beat (so the
> "Signed in ✓" registers) instead of waiting for a manual *Continue*. (2) The Settings **提醒 / Reminders**
> summary ("N on") used to count **only meal reminders**, ignoring the two Circle notification switches — so 4
> meals + Circle + Comments all on showed "4". It now counts **every enabled switch** on that screen (meals when
> the master is on + Circle activity + Comments & mentions). analyze + 183 Flutter tests green.
> **Owner admin-grant (new, live on prod):** an authenticated owner-only **`POST /beans/grant`** endpoint
> (admin-token gated, SSM `/food-at-peace/admin-token`) credits a user's Beans ledger by @handle. **Google
> Sign-In is designed** (new-user + bind-existing, both directions, web included) — see
> [`GOOGLE_SIGNIN.md`](GOOGLE_SIGNIN.md); blocked only on a Google Cloud OAuth client (yours to create).
> **Web recharge (new, this session):** a standalone Stripe top-up page at **`foodatpeace.app/recharge`**
> credits the same server Beans ledger via a signature-verified, idempotent webhook — a no-Apple-cut
> path that also covers Android/web users with no StoreKit. Now **deployed to prod** (`6m19l2b025`)
> via an additive changeset — every shared handler byte-identical except a backward-compatible
> `auth.py` audience tweak, so the **1.0.0 contract was verified intact** — and the page points at
> prod. It identifies the account with **Sign in with Apple on the web** (reuses `/auth/apple`). It's
> a *standalone* page (no in-app link, so the App Store app is untouched). **Now LIVE on Stripe**
> (2026-06-23): live keys are in SSM and `/recharge/checkout` creates real (`cs_live_`) sessions; the
> 25-bean pack is **S$0.50** (Stripe's SGD minimum), and the page shows the app's **gradient bean icon**
> + a **← Back** control (served `no-cache`). **Fully verified end-to-end (2026-06-23):** a real live-card
> purchase credited beans via the signature-verified webhook, and **Sign in with Apple (web)** works (the
> Services ID `com.foodatpeace.web` is registered + configured; the backend already trusts that audience).
> Both the @handle deposit-address path and Apple sign-in now work. A shareable
> **`/recharge?h=<handle>`** deep-link opens the page pre-targeted at that account.
> **Build 62** makes the **Circle tab scroll as one page** (Instagram-style): the stories strip is now
> the scrolling header of the feed, so it scrolls **away** as you go down — instead of a fixed strip over
> a separately-scrolling feed, which wasted permanent vertical space. The whole tab is one `ListView`
> (`CircleFeedBody` takes an optional scrolling `header`); pull-to-refresh still works. **Build 61** adds a blue **"Official" badge** to the first-party accounts (**@roro** and **Eva**) so
> users can tell them apart from peers — a verified-check on their strip avatars and an "Official" tag by
> their name in the feed. Shown to everyone **except the creator** (@roro) themselves, and never on your
> own posts. **Build 60** makes the Circle feed **auto-refresh after you log a photo meal** — sharing a scanned
> meal now invalidates the feed once the post lands (via the root provider container, captured before the
> add screen pops), so your new post appears on its own instead of needing a manual pull-to-refresh.
> **Build 59** gives every new account a **random 8-character @handle** by default (lowercase letters +
> digits, always a mix) instead of one derived from the nickname — unique, low-collision, and still
> editable in the profile dialog. Existing accounts keep their handle. **Build 58** fixes **deleting a recurring ("Take daily") entry** — swipe-deleting it on a day used to
> soft-delete the single shared entry, wiping it from **every** day. It now removes just **that day's
> occurrence** (a per-entry `skippedDates`), keeping the daily series on other days; to stop the series
> entirely, toggle "Take daily" off. Additive + backward-compatible (older clients ignore the field).
> **Build 57** is a Circle/profile polish pass from the live review: (a) **@handle moved into the profile
> dialog** — shown read-only under your nickname (no separate edit button), edited via the profile pen;
> (b) the official **@roro is now properly unfollowable** (consistent **Unfollow** on both Eva and Roro
> in Manage — no more "Unfollow" vs "Following" mismatch — backed by a local `roroHidden` flag that hides
> him from the strip + feed); (c) **friend/Roro story rings now grey out once viewed** (were always
> "unseen"); (d) **logged in as @roro you no longer see two Roros** (the official avatar is suppressed
> for yourself); (e) tapping a reaction while **signed out now prompts sign-in** instead of doing nothing.
> **Recharge Beans by @handle is LIVE** (deployed to prod, page published): on `foodatpeace.app/recharge`
> you can enter a **@handle** to top up that account (resolved server-side, id never exposed); charging
> stays inert until Stripe keys are set.
>
> **Recharge Beans by @handle (LIVE on prod):** the web recharge page (`foodatpeace.app/recharge`) lets
> anyone enter a **@handle** to top up that account — a "public deposit address" for Beans (your own
> top-up from any browser, or gifting). The server resolves the handle → account **server-side** (the
> account id is never exposed); Apple sign-in stays as the alternative. Additive backend (`GET
> /recharge/handle` + optional `handle` on `/recharge/checkout`, 16 tests) deployed isolated to the prod
> RechargeFunction + a new `GET /recharge/handle` route; the page is published (S3 + CloudFront). Charging
> stays inert until Stripe keys are set. **Build 56** fixes the **Story archive's "black/blank" pages**: a
> meal with no available image (a manual entry, or a photo whose image isn't on this device) used to
> render as a near-black blank screen with only a caption. It now shows a clean, intentional card — an
> "image unavailable" / meal icon above the dish + nutrition — so it reads as designed, not broken. (The
> render paths were verified correct: meals with a local photo or a synced thumbnail show full-bleed as
> before.) **Build 55** adds **@handle management in Settings** and fixes a
> **follow-state inconsistency**. (1) Your **@handle** now appears in the Settings profile — auto-assigned
> on sign-in, with edit + copy; it's the unique id others find/add you by (and recharge Beans into). (2)
> The Circle no longer says **"Suggested: follow Roro"** while his story + feed are on screen: `followsRoro`
> is now feed-aware (if his official posts show, you effectively follow him), so Manage lists him under
> **Officials → Following** instead of Suggested. (3) The Circle tab's strip/feed **divider** got proper
> margin so it no longer crowds the first post. (Client-only.) **Build 54** fixes **Roro's story** for signed-out users: tapping
> the creator's story now opens his **real shared meals** (with his profile photo on the avatar), instead
> of a **fabricated trend** (mock streak / adherence / kcal) and an initials avatar. Root cause: following
> @roro while signed out created a *placeholder* friend (synthetic id + `Friend.sample` mock trend, no
> photo) disconnected from his real account, so the strip avatar fell back to initials and tapping fell
> back to the trend sheet. Now the strip sources the official account from the **feed** (real id + photo +
> posts), and a friend's story matches their posts by **@handle as well as id** — so Roro's avatar shows
> his face and his story shows his meals. (Client-only; no backend change.) **Build 53** shows **friends' real profile photos as their
> avatars** across the Circle — a friend's photo now appears on their story ring in the strip, on
> their **feed posts**, and in trends / requests / manage, instead of coloured initials (graceful
> fall-back to initials when no photo is set). It works **signed-out** too: the official **@roro**
> account already has a photo, so brand-new users see Roro's face on his posts and in the strip.
> Backend (additive, deployed **isolated to the prod circle + posts functions only**): `/circle/list`
> and `/circle/feed` now return each person's presigned profile-photo URL from the durable
> photo store (a new optional field → the shipped app simply ignores it). **Build 52** lets **signed-out users see the creator's feed**:
> the Circle feed now shows the official **@roro** account's real meal photos **without logging in** (via
> the app token), so a brand-new user sees real content before any account. (Root cause: the feed was
> session-gated, so logged-out users got an empty feed no matter what.) Backend: `/circle/feed` accepts
> the app token → returns the official account's public posts (additive, deployed to the prod posts
> function only). **Build 51** polishes the Circle: the **"Add" bubble moved to the
> end** of the strip (after your friends, not wedged in the middle), and the **feed is now one
> reverse-chronological stream** (newest first) — meal posts and Eva's daily lessons interleaved by time,
> instead of Eva's 3 cards pinned to the top. **Build 50** makes **new accounts see real photos**: every
> account now **auto-follows the creator's official @roro account** on first sign-in (one-time, still
> removable), so a brand-new user's Circle feed isn't empty — they immediately see Roro's shared meals.
> (Root cause: a fresh account had **no connection to Roro**, so the privacy-gated feed `[me] +
> connected` returned nothing; Roro himself has live photo posts.) The feed also now shows **Eva's
> lesson as one card per day for the last 3 days** (was today only), matching her 3-day story. **Build 49** fixes **your own story**: tapping **You** now shows
> **what your friends see** — the meals you've *shared* to the circle (your photo posts) — instead of a
> duplicate of your whole food log. Your full food log stays one tap away under the **Archive** (history)
> icon. **Build 48** makes the social loop work: **tapping a friend
> opens their story** (their recent shared meals, swipeable — was only a trend before), and
> **following someone now refreshes your feed immediately** so their posts show up without a manual
> pull-to-refresh. **Build 47** turns **daily meal reminders AND circle activity on
> by default**, and adds a clear **"turn on iOS notifications" prompt (with the why)** wherever they're
> wanted but iOS hasn't granted permission — the onboarding reminders step, the Reminders settings
> screen, and the Circle tab. The toggles are now intent (they stay on even if you deny iOS, so the CTA
> can keep prompting). **Build 46** makes Circle feed photos **load fast and reliably**
> — shared meals now upload a downscaled ~1024px copy instead of the 3–4 MB original, feed cards are
> **disk-cached** (keyed by post id, since the S3 URL rotates), and the 10 existing posts were
> backfilled in S3 (28 MB → 1 MB). Also **Eva's story now spans the last 3 days** (one lesson per day,
> older days dated), matching the 3-day feed window. **Build 45** makes your **@handle survive a reinstall**: after
> delete-app → Sign in with Apple, the app now **recovers the exact handle the account already owns**
> from the server (it used to re-derive one from your name and could change it, breaking friends'
> links). The handle still **defaults to your nickname** and stays **unique app-wide** — that part was
> already true; build 45 just stops it drifting on reinstall (client-only, no backend change).
> **Build 44 (on TestFlight)** adds **Eva's daily lesson as the
> first card in the scrollable Circle feed** (above every food story), shows your **nickname (display
> name) distinct from your @handle** in Manage circle (the name is what friends see; the handle is the
> unique id they add you by), and stops the creator (`@roro`) from being **"Suggested to follow"
> themselves**. **Build 42** trims the Circle tab: **removes the redundant
> "Circle" title bar** (the nav tab already labels it), shows the **invite QR by default** in Manage
> circle again (the build-41 collapse was reverted per feedback), and swaps the redundant feed icon
> for an **"Archive" (history) icon** that opens your own food story. (The Circle feed already shows
> everyone's posts + your own — it only looks "mine-only" before you have connected friends.)
> **Build 41** restructures **Manage circle** (header now reads
> "Officials · N" with distinct Coach/Creator badges; the friend list is split into Requests / Friends
> / Invited; the always-on QR is collapsed behind a "Show QR" button) and gives **Circle its own
> bottom-nav tab** (Today / Trends / Circle / Profile), moving the strip + photo feed off the Trends
> screen. **Build 40** aligns the Manage-circle handle avatar with the
> rows below it (was larger + offset). **Build 39** makes the food story show **S3-backed meal photos
> even when no thumbnail synced** (so durable photos reappear after a reinstall, not just a caption);
> older meals logged before durable backup remain unrecoverable. **Build 38** hardens profile restore — the client now never
> pushes an *unconfigured* profile, so a fresh install can't overwrite the real server profile before
> it's pulled back (reinstall-safe, not just update-safe). **Build 37** makes the **notification call-to-action** actually
> get OS permission: the "Turn on notifications" card prompts on first tap, then becomes **"Open
> Settings"** (one tap into the app's iOS Settings) — the in-app toggles stay default-on but are
> independent of the OS permission. **Build 36** fixes **profile restore on reinstall** (the
> profile stayed blank even on prod: launch-time HealthKit refresh stamped the fresh local profile
> newer than the server, so last-write-wins discarded the real one — now a *configured* server
> profile always wins over an *unconfigured* local one) and adds a **tappable avatar on the Manage
> Circle handle card** (opens your story). **Build 35** rebuilds the app against the **production
> backend** (`6m19l2b025`): a returning user who reinstalled saw blank data because this session's
> builds 33/34 were accidentally pointed at the empty **v2/dev** stack — their real data (profile +
> 24 meals + weight) was safe on prod the whole time. Reinstalling build 35 restores everything;
> the main app must always build with `dart_defines.prod.json` (CLAUDE.md guardrail added).
> **Build 34** is a Circle polish pass: story avatars now show
> a **grey "seen" ring** once viewed, **Roro sits left of the ＋** with the official accounts,
> **"Unfollow"** is the one consistent word everywhere (was a mix of "Unfollow" / "Remove from
> circle"), and a strong **"Turn on notifications"** card appears when circle alerts are on but iOS
> permission hasn't been granted (so the default-on toggle actually means something). **Build 33**
> fixes the **IAP purchase feedback**: after
> Apple's payment sheet closed there was only a tiny spinner while the receipt validated, so a paid
> top-up felt like *"nothing happened"* — the Beans paywall now shows a clear full-screen
> **"Processing your payment…"** state and then a **success view** (✓ "Added N Beans" + new balance)
> once the Beans actually land. **Build 31** adds **official Circle accounts** — **Eva**
> (the AI coach) is now a followable member with her daily lesson,
> default-followed and unfollowable (she moves to **Suggested** to re-follow); **Roro** (the
> creator's real account) is **recommended** to follow, opt-in only (never auto-followed, so no
> data-sharing without consent). Both carry an **Official** badge — first-party, not fabricated
> peers. Build 31 also makes the **profile photo durable** (S3, survives reinstall). **Build 29**
> carries the **meal-photo durability
> fix**: the synced photo copy now adaptively shrinks so its base64 always stays under
> DynamoDB's 400 KB row limit — a detailed 1080px photo could previously exceed it and silently
> fail to sync (then vanish after a reinstall); the prod sync endpoint was also hardened so one
> oversized row can't fail the whole push. **Build 30** adds the **proper fix — a durable per-user
> S3 photo store**: the full-resolution original is uploaded to S3 (presigned URLs, no size limit)
> and restored to the Food story on any device, with the synced thumbnail as the instant/offline
> preview. **Android:** the Flutter app now **builds + runs on Android** (emulator-verified) —
> JDK17/SDK toolchain, minSdk 26 + core-library desugaring, AndroidManifest with internet/camera/
> location/notifications + **Health Connect** perms + **foodatpeace.app deep links**,
> `MainActivity` on `FlutterFragmentActivity` (so all plugins register), and a platform-aware
> health service. **Remaining for a Play release (need Google accounts):** Sign in with Apple on
> Android (Apple Services ID), FCM push, Google Play Billing, and the Play Console listing.
> **In review: `1.0.2 (build 62)`** (submitted 2026-06-21, prod backend) — build 62 (the full Circle
> social layer + recharge-by-handle + random handles + Official badges + whole-page scroll + the
> recurring-delete fix, all QA-verified) was swapped into the pending 1.0.2 (the earlier build 28 was
> pulled from the queue) and resubmitted via the ASC API. Its "What's New" already describes the Circle
> features.
> **Submitting next: `1.0.2 (28)`** (prod backend) — the full v3 feature wave (Circle stories:
> photo-hero food story, Calm Eva scenes, story tray + swipe, 7-day archive + delete; profile
> photo; synced meal photos; "Take daily" recurring foods; Data Sources energy priority;
> Circle activity on by default) **plus a fix so a new user no longer sees seeded sample
> friends**. Build (28)
> adds a **⋯ menu on every Circle post — Report (Apple Guideline 1.2 reason picker; the post
> hides for you immediately) and Unfollow (removes the friend both ways)** — closing the last
> UGC-safety gap before submission. Build (26)
> turned **Circle activity notifications on by default** (permission requested when a friend
> first does something; an explicit off sticks). Build (25)
> adds **Data sources** in Settings — choose which device's active energy takes priority when
> several (Garmin, Apple Watch, iPhone) write to Apple Health. Build (24)
> has **"Take daily" foods** — tap an item in 今日饮食 to mark a supplement/staple as daily,
> counted every day with a Daily badge, no re-logging (the post-save prompt from build 23 was
> removed per feedback). It also **fixes Food-story delete** so it no longer removes the
> food-log entry. Build (22)
> makes the stories a **tray** — swiping past the end of your food story rolls into **Eva's**
> story instead of closing — and bumps the **synced photo to 1080px** so it looks crisp on
> every device. Build (21) added **left/right swipe** navigation (tap still works). Build (20)
> **fixes meal photos not showing in the food story** — they were device-local only, so synced
> or older entries fell back to the nutrient card; a small thumbnail now rides on the entry and
> **syncs across devices / survives a reinstall** (no backend change). Build (19) was a **story
> polish** batch: the **Food story** is **photo-hero** (the meal photo fills the
> frame, calories/macros become a caption), **Eva's lesson is a Calm-style scene** (a
> per-lesson gradient + warm glow across all 100 lessons), the food story spans the **last 7
> days** with a **per-story delete**, and you can set a **profile photo** (in Settings) that
> shows in your circle **You** avatar + story header. Build (18) added the full-screen
> **Food story** + per-entry meal photos; (17) the first Circle-stories cut + the **Haiku**
> photo-analysis model (~3–4× cheaper, server-wide), a real **25-Bean** IAP (`beans_25`), a
> **rate-the-app prompt** (5th open), and **`purchase` analytics**. All of this — plus the
> **Circle of Food** social layer (friends by `@handle`, invite universal link + QR, a Manage
> circle screen, privacy-gated friend trends, the 30-day photo **stories** feed with emoji
> reactions), a **real owner-analytics** backend, daily reminders, and the **Beans** wallet —
> **shipped in 1.0.2 (build 62), approved & live 2026-06-23** (tag `v1.0.2`). The repo is now a
> single `main` (the old `v2`/`v3` branches are retired) plus release branches like `1.0.2`.
> Dev runs against the **isolated `food-at-peace-vision-proxy-v2` stack**; the live app points
> at the **migrated prod stack** (`6m19l2b025`) — see `CLAUDE.md` /
> [`backend/README.md`](backend/README.md).
> The **invite links are live**: `foodatpeace.app` is registered + hosted on AWS
> (Route53 + CloudFront/HTTPS) serving the AASA + a smart `/i/<handle>` page (app
> installed → opens the app · not installed → App Store · WeChat → tap ••• (top-right)
> → **用默认浏览器打开** hand-off) — see [`store/INVITE_LINKS.md`](store/INVITE_LINKS.md).
> **Beans are real now**: a StoreKit paywall (consumable packs) backed by a **server
> ledger that follows the account**; the buy shows a spinner + can't be double-fired,
> and a purchase is **validated server-side against Apple's receipt** (`/iap/validate`)
> before crediting (the hidden 1-Bean dev pack is debug-only). Circle notifications
> arrive as **real Apple banners** — foreground, and **background via APNs push**
> (build 14) for friend requests, accepts, shared meals, and reactions.
> Earlier: v1.0.0 cleared the Guideline 1.4.1 rejection with the in-app Sources &
> methodology screen + in-app account deletion (see `PUBLISHING.md`).

## What it does today
- **Onboarding** — on first launch: continue with **Sign in with Apple** (pulls your
  name) or type it, pick a goal, connect Apple Health, then "About you"
  (sex / age / height / weight — prefilled from Apple Health, never guessed).
  Anything you skip shows up as a "Finish setting up" checklist on Today.
- **Today dashboard** — a large time-of-day greeting ("Good evening, …" with an emoji)
  and your local **weather** (animated background reflecting rain/sun/cloud/snow +
  a temperature/condition chip; falls back to an approximate IP location if you
  decline GPS). A calorie ring (budget = burn + your calorie *gap*),
  protein and saturated-fat cards, and a card of today's workouts.
- **Add food** — manual entry, or **scan a meal photo** and let Claude estimate the
  calories / protein / saturated fat for you to confirm — **in your app language**
  (EN/中文). You can also share the scan to your **Circle** (below).
- **Circle of Food** — a social layer on **Trends**: claim a `@handle`, **share an
  invite link or QR** (one tap connects you both as mutual friends) or invite by
  handle and accept requests, **manage your circle** (connected / requests / invited),
  tap a connected friend for their
  **privacy-gated trend** (today vs target, streak, 7-day adherence) or remove them,
  and share a scanned meal to a **30-day photo feed** where friends react with emojis
  (👍❤️😋🔥👏) and you receive the reactions. The story keeps the full-resolution
  photo; the AI estimate uses a downscaled copy.
- **Trends** — daily charts for calories / protein / saturated fat vs. target, each
  led by a prominent "on target X/Y days" stat. Switch between **1 / 7 / 30-day**
  windows, page to earlier windows with prev/next, and tap or drag a chart to read
  any day's value against the target.
- **Settings** — profile (editable **nickname** + sex / age / height / weight, synced
  from Apple Health with a **Sync now** button + last-synced time — edits write height
  + weight back to Health), editable goal & targets (each shows how it's calculated;
  **Use automatic** appears once the profile is reliable), account & sync (incl.
  in-app account deletion), Apple Health
  connection, language, and feedback.
- **Apple Health / Garmin** — reads active + resting energy, weight, height, and date
  of birth (→ age), plus workouts; writes logged food, weight, and height edits back.
  Garmin data flows in via Apple Health.
- **Accounts + cloud sync** — Sign in with Apple; food / weight / profile follow you
  across devices (last-write-wins, tombstone deletes).
- **Bilingual** — English / 中文, following the iOS system language with a manual
  override in Settings.
- **Theme** — a dark, GXS-style violet palette with a gradient calorie hero.
- **Feedback** — an in-app form that submits to a Google Form.

## How the targets work
- **Calorie budget = BMR + active + gap.** A full day's resting energy
  (Mifflin-St Jeor BMR) + the active energy you've burned (measured via Apple
  Health, or 0 when there's no reading yet / it isn't connected) + your calorie
  **gap** (the goal default — lose −500, maintain 0, gain +400 — or a custom
  value). Calories left = budget − eaten; the full-day resting part keeps it
  stable while it grows as you move. Settings shows this as the **Calorie gap
  target** and lets you edit the calorie gap, protein target, and saturated-fat
  cap directly.
- **Protein:** 1.6 g per kg of bodyweight.
- **Saturated fat:** capped at 10% of the calorie target (US Dietary Guidelines).

These are general estimates for healthy adults, **not medical advice**. In-app, a
**Sources & methodology** screen (linked from both Today and Settings, per App Store
Guideline 1.4.1) cites the references with tappable links — Mifflin-St Jeor (BMR),
the Dietary Guidelines for Americans (calorie balance + saturated fat), and the ISSN
protein position stand — alongside a medical disclaimer.

## Photo analysis (Claude)
Photos are analyzed via Anthropic's Messages API, forcing a `log_food` tool for
structured output (name / calories / protein / saturated fat / portion / confidence).
The Claude key lives **server-side** in an AWS Lambda proxy (see
[`backend/`](backend/README.md)) — the app ships no key and calls the proxy
(`ProxyAnalyzer`), sending only the photo + a build-time app token
(`--dart-define=PROXY_BASE_URL` / `PROXY_APP_TOKEN`). A direct path
(`ClaudeVisionClient` via `DirectAnalyzer`) remains in the code for a user-supplied key
in the iOS Keychain, but isn't surfaced in the UI.

The proxy is defined with AWS SAM (Python); deploy + secret setup are in
[`backend/README.md`](backend/README.md).

## Localization
Uses Flutter `gen-l10n`. Strings live in `lib/l10n/app_en.arb` and `app_zh.arb`; run
`flutter gen-l10n` (or any build) to regenerate `AppLocalizations`. The app follows
the system locale by default and persists a manual choice.

## Status & remaining work

**Done (in `main`):**
- [x] Manual food logging + goal-**gap** targets engine
- [x] Claude photo analysis (server-side key via the AWS proxy)
- [x] Apple Health / Garmin — active + resting energy, weight, height, date of birth
  (→ age) and workouts in; logged food, weight, and height edits written back
- [x] Targets polish — calorie **gap** (±) with edit-all (calorie / protein / sat-fat);
  age / height / weight auto-filled from Apple Health and editable; manual weight log dropped
- [x] First-run onboarding (Sign in with Apple or manual name → goal → connect Health)
  plus a "Finish setting up" checklist on Today
- [x] Today greeting (time-of-day + name) and a location-based animated **weather**
  header — GPS via geolocator, falling back to an approximate IP lookup when
  location is denied; conditions from Open-Meteo (no key)
- [x] Trends — interactive charts (tap / drag to inspect), 1 / 7 / 30-day windows with
  prev/next paging, "on target X/Y" highlight
- [x] Dark GXS-violet redesign — gradient calorie hero, modern type, floating cards
- [x] English / 中文 localization (follows the system language, with a manual toggle)
- [x] In-app feedback → Google Form
- [x] Deploy to iPhone (paid Apple Developer membership active)
- [x] AWS Lambda vision proxy holds the Claude key server-side (SAM + Python, in
  `backend/`); the app ships no key
- [x] Accounts + sync — Sign in with Apple (`/auth/apple`) + DynamoDB delta sync
  (`/sync`) + in-app account deletion (`/account/delete`, App Store 5.1.1(v)),
  deployed to `ap-southeast-1`; app-side bidirectional sync of food /
  weight / profile (last-write-wins, tombstones; on sign-in / resume / edit / manual)
- [x] **Resubmitted 1.0.0 (3) to App Review** (June 12, 2026 — **Waiting for Review**):
  replied to the 1.4.1 rejection, refreshed description/promo + App Privacy answers
  (Name / Health / User ID → linked to identity), and replaced the screenshots with
  a 5-shot 6.9″ set (`store/app-store-screens/` — Today, Trends, Add, Sources &
  methodology, Settings); auto-releases on approval

- [x] **Daily meal reminders** — opt-in local notifications (breakfast 8:00 /
  lunch 12:00 / dinner 19:00 on, snack 22:00 off by default), each editable /
  toggleable / deletable + "Add reminder"; funny localized per-meal copy;
  enabled from onboarding or **Settings → Reminders**
  (`flutter_local_notifications` + `timezone`)

- [~] **Beans (in-app credit) — real StoreKit IAP wired** — 100 free Beans on
  first launch; 1 Bean per photo scan (Add screen shows "N scans left");
  iridescent pastel "jelly-bean" wallet in **Profile → Beans** with balance,
  transaction history, and a paywall of **consumable** packs **100 / 200 / 300 /
  500 / 800** (SGD 1.99 / 3.99 / 5.99 / 9.48 / 13.98). The paywall buys through
  **`in_app_purchase` / StoreKit** (`IapService` → `BeansNotifier.recordPurchase`),
  showing Apple's localized price; the five `beans_100…beans_800` products are
  **live in App Store Connect** (EN/中文, prices, review shots, available). The
  "Custom" tile and the unlimited subscription are **gone** (Apple has no arbitrary
  pricing; the sub was cut). **Screen-recordable walkthroughs** of the purchase live in
  [`beans_purchase_demo.dart`](integration_test/beans_purchase_demo.dart) (buy 200) and
  [`beans_100_demo.dart`](integration_test/beans_100_demo.dart) (recharge 100 → balance
  200); a faked store stands in for Apple's payment sheet on the sim, and the ledger row
  reads "Top-up · <price>" (no raw product id). These join the full **8-step Eva+Peter
  walkthrough** (onboarding, photo→log, the two-user Circle flow) recorded across two
  simulators. The balance is **synced to the account's
  server ledger** (`/beans` on v2) — pushed on every change, pulled on sign-in, with
  per-device signup grants collapsed (`BeansClient` + `mergeBeansLedgers`) — so it
  follows you across devices and survives a reinstall; account deletion clears it too.
  Remaining: `/iap/validate` receipt validation — see `TODO.md` §2.

- [x] **Owner metrics dashboard — moved to the web, LIVE at `foodatpeace.app/dashboard`**
  ([`store/website/dashboard/`](store/website/dashboard/index.html); prod `/metrics` dual-auth
  deployed 2026-06-17)
  → downloads / active / opens (7-day bars) / photos scanned / Beans sold / revenue /
  refunds / **AI prompt-cache hit rate + token usage** (recorded per `/analyze` call by
  `app.py` from the Anthropic `usage` block). The app still emits `open`/`scan`/`purchase` events; the **standalone web
  page** reads **live** aggregates from `GET /metrics` using a **dedicated read-only
  metrics token** (entered in-browser, never in source — kept out of the app so the
  shared `/analyze` token never ships in a web page). **All cards are now wired** —
  revenue + beans-sold are recorded server-side in [`iap.py`](backend/src/iap.py) per
  validated Apple transaction (idempotent, can't be client-faked), and `downloads` is
  folded in daily from the **App Store Connect Sales report** by a scheduled
  [`downloads.py`](backend/src/downloads.py) Lambda (needs the ASC `.p8` in SSM
  `/food-at-peace/asc-private-key`). `?demo=1` shows the layout with sample numbers.
  CORS is **locked to `https://foodatpeace.app`** (browser-only; the native app is
  unaffected), and a CloudFront viewer-request function
  ([`store/website/_cloudfront-rewrite.js`](store/website/_cloudfront-rewrite.js))
  resolves directory URLs so `…/dashboard/` works as well as `…/dashboard`. The old
  in-app 5×-tap screen was **removed**; tapping the version **10×** still reveals +
  copies this account's **user id** (sync-DB key).

**TODO (pricing — StoreKit, mind Apple's rules):**
- [x] **Beans packs** — each tier (100/200/300/500/800) is a fixed **consumable
  IAP** product (`beans_100…beans_800`) live in App Store Connect; the "Custom"
  tile was dropped (Apple has no arbitrary pricing) and the paywall buys via
  StoreKit (`in_app_purchase`). Beans are consumed in-app → Apple IAP only, no
  external payment.
- [ ] **Harden Beans IAP** — wire the **server-side ledger** (`/beans`, built on
  v2) into the client (pull on sign-in / push on append) so a balance follows the
  account, add **Restore Purchases**, and **receipt validation** (`/iap/validate`).
- [x] **Unlimited subscription — cut.** Replaced by Beans packs only (the
  auto-renewable plan and its local `subscribed` flag were removed).

**TODO (dashboard):**
- [x] **(v2)** Emit `open`/`scan`/`purchase` events + a `GET /metrics` aggregation
  endpoint. **(v3)** Dashboard moved out of the app to a standalone web page
  ([`store/website/dashboard/`](store/website/dashboard/index.html)) reading
  `GET /metrics` with a dedicated read-only token. Still TODO: `refund` events and
  **downloads** from the **App Store Connect API**.

- [x] **Circle of Food — real backend + UX (v2)** — story-style friend avatars on the
  **Trends** graph; claim a `@handle`, **share an invite universal link + QR** that
  connects both sides in one tap (`POST /circle/connect`), invite by handle,
  accept/decline **Requests**, a **Manage circle** screen (connected / requests /
  invited), tap a connected friend for their **privacy-gated** trend (today vs
  target, streak, 7-day adherence) or remove them. Plus a **30-day photo feed**: share
  a scanned meal (toggle, default on), friends react with emojis and you receive the
  reactions. Backed by `circle.py` + `posts.py` (CircleTable, PostsTable, S3 photos)
  on the v2 stack; trends/feed are gated to mutually-connected friends. The in-app
  link handler (`app_links`) + `foodatpeace://` scheme ship in build 4; the
  **universal link** needs the AASA hosted on `foodatpeace.app`
  ([`store/INVITE_LINKS.md`](store/INVITE_LINKS.md)).

**TODO (next up):**
- [ ] **Google Sign-In** — `/auth/google` mirroring `/auth/apple`
- [ ] **Recurring food** — log a repeating food entry once and have it recur
- [ ] Later: home-screen widget, barcode scan, Android

## Tech stack
- **Flutter / Dart**, iOS first (iPhone), then Android and web.
- **Riverpod** for state; **shared_preferences** for local data (behind repositories)
  and **flutter_secure_storage** for tokens/keys; **http**, **image_picker** +
  **image** (full-res story photo + downscaled analysis copy), the **health**
  package, **geolocator** (weather), **sign_in_with_apple** + **crypto** (accounts),
  **flutter_local_notifications** + **timezone** (reminders), **intl** +
  **flutter_localizations**.

## Getting started
```bash
flutter pub get
flutter gen-l10n          # generate the localization classes

# Browser (UI + manual logging; no HealthKit / camera):
flutter run -d chrome

# iOS device (uses the AWS proxy for photo analysis):
cp dart_defines.example.json dart_defines.json   # then add PROXY_BASE_URL + PROXY_APP_TOKEN
flutter run -d ios --dart-define-from-file=dart_defines.json
```
`dart_defines.json` is git-ignored. Deploy the proxy first ([`backend/`](backend/README.md)),
or skip it and paste your own Anthropic key in the app's **Settings** to analyze photos
via the direct path.

### Tests & checks
```bash
flutter analyze
flutter test
```

## iOS notes
- **HealthKit needs a paid Apple Developer Program account.** A free Personal Team
  cannot sign the `com.apple.developer.healthkit` entitlement, so the health
  features only build on a paid team. Apps signed with a free team also expire after
  7 days (a paid team lasts a year).
- Built with **Xcode 26.5+** (matching recent macOS).

## Project layout
```
lib/
  main.dart                 app entry (loads storage, sets up Riverpod)
  app.dart                  MaterialApp + theme + localization
  l10n/                     app_en.arb / app_zh.arb + generated AppLocalizations
  src/
    models/                 FoodEntry, UserProfile, DailySummary, EnergyOut,
                            WorkoutSummary, WeightEntry, MealType, FoodAnalysis,
                            Weather, Session, SyncRecord
    nutrition/              NutritionMath (BMR, TDEE, targets)
    data/                   Food/Profile/Weight repositories, ApiKeyStore,
                            ClaudeVisionClient + FoodPhotoAnalyzer (proxy/direct),
                            HealthService (+io/stub), WeatherService, FeedbackService,
                            AuthClient + SessionStore, SyncClient + sync engine,
                            MetricsService + AnalyticsService, CircleClient, PostsClient
    providers/              Riverpod providers
    features/               onboarding / today / add / trends / circle / settings /
                            feedback / dashboard / wallet (Beans)
    theme/ util/            theme, formatting, localized enum labels
test/                       unit + widget tests
ios/                        Runner + Runner.entitlements (HealthKit)
backend/                    AWS SAM vision proxy (Lambda, Python) — holds the Claude key
```
