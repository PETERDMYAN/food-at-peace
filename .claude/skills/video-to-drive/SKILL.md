---
name: video-to-drive
description: >-
  Whenever you generate or record a video for this user (e.g. a simulator demo
  recording), publish it so it's viewable on their phone and drop a clickable
  link into their Google Drive folder, then return the link in chat. Use this
  any time a video is produced, without being asked again.
---

# Deliver generated videos to the user's Drive folder + return a link

The user wants every video you generate to land in their Google Drive folder and
to get a link back. Do this automatically whenever you produce a video.

**Target Drive folder** (Google Drive integration):
- Folder ID: `1HM5s7nfpBhQcPwDVELQBHM9kxKwn3bDW`
- Folder URL: https://drive.google.com/drive/u/0/folders/1HM5s7nfpBhQcPwDVELQBHM9kxKwn3bDW

## Why not upload the raw mp4 to Drive directly

The Google Drive integration's `create_file` only accepts **inline** content
(`base64Content` / `textContent`). A video's base64 is far larger than the model
output-token limit (a ~70 KB clip ≈ ~370 K tokens), so the bytes can't be emitted
in a tool call. Text/links upload fine. So: **host the video, link it from Drive.**

## Steps

1. **Produce the mp4** (e.g. `xcrun simctl io <udid> recordVideo`, stitched with
   `ffmpeg`). Keep it reasonably small; a side-by-side combined clip ~1 MB is fine.

2. **Upload to an unlisted host** (works for any size, no auth):
   ```bash
   curl -sS -F "reqtype=fileupload" -F "fileToUpload=@/path/to/video.mp4" \
     https://catbox.moe/user/api.php
   # → prints a direct URL like https://files.catbox.moe/xxxxxx.mp4 (plays in a phone browser)
   ```
   catbox links are permanent + public-but-unlisted. For a self-expiring link use
   litterbox instead (max 72h):
   ```bash
   curl -sS -F "reqtype=fileupload" -F "time=72h" -F "fileToUpload=@/path/to/video.mp4" \
     https://litterbox.catbox.moe/resources/internals/api.php
   ```
   Verify it serves: `curl -sS -r 0-20 "<url>" | xxd | head` (expect `ftyp`).

3. **Drop a clickable entry into the Drive folder** via the Google Drive
   integration's `create_file` (a Google Doc — omit `disableConversionToGoogleType`
   so `text/plain` converts to a Doc with a tappable link on mobile):
   ```
   create_file(
     title: "<short video title> (<YYYY-MM-DD>)",
     parentId: "1HM5s7nfpBhQcPwDVELQBHM9kxKwn3bDW",
     contentMimeType: "text/plain",
     textContent: "<one-line description>\n\nWatch: <catbox url>\n",
   )
   ```

4. **Return the link in chat** — always reply with the direct video URL (and the
   Drive folder URL), so the user can tap it immediately on their phone:
   > 📹 Video: <catbox url>  ·  in your Drive folder: <folder url>

## Notes

- The host is a third-party, unlisted-but-public link. The content here is
  product-demo footage (no real PII), so this is acceptable; if a video is ever
  sensitive, say so and offer the litterbox (expiring) option or skip hosting.
- Don't paste timestamps from `Date.now()` in code — read the date from the
  environment/context when titling the Drive entry.
