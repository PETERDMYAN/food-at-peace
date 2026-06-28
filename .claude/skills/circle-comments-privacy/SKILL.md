---
name: circle-comments-privacy
description: >-
  Read and apply BEFORE changing anything about Circle feed COMMENTS — the
  comment endpoints (/circle/comment, /circle/comments) or feed commentCount in
  backend/src/posts.py, the comment models (CircleComment / CircleCommentThread /
  CircleComments), PostsClient.comment/comments, postCommentsProvider, or the
  comment UI (_CommentsSheet) in circle_feed_screen.dart. Comments are PRIVATE
  per-commenter threads with the post owner as the hub; this invariant must hold.
---

# Circle comments — private per-commenter threads (owner is the hub)

Comments on a Circle post are **not** a public thread. Each non-owner commenter
has a **private 1:1 thread with the post owner**. Verify this every time you
touch comments.

## The invariant

- **The post OWNER is the hub.** They see **every** comment on their post: every
  commenter's messages **and** their own replies, grouped one thread per
  commenter.
- **A COMMENTER sees only their own thread** — their comment(s) **plus the
  owner's replies to them**. They must **never** see another commenter's
  comments, nor even that another commenter exists.
- **A connected friend who hasn't commented** sees an **empty** thread (and may
  start one) — never anyone else's.
- **The owner replies INTO a commenter's existing thread** (`threadUser` = that
  commenter). The owner cannot start a thread to someone who hasn't commented.
- **Counts are per-viewer**: the feed's `commentCount` is the total the *viewer*
  can see — all threads for the owner, just their own thread for a commenter, 0
  signed out.

### Public comments (the one exception)

- **The post OWNER — and only the owner — can post a PUBLIC comment** that
  *everyone who can see the post* sees. It's stored under the thread sentinel
  `__public__` (`posts._PUBLIC`; real ids contain ":", so no clash) and returned
  in a separate `public` array, distinct from the private `threads`.
- **A non-owner CANNOT broadcast.** If a non-owner sends `public: true`, it's
  ignored and their comment goes to their own private thread.
- **Owner "reply" stays private; owner "comment" is public.** In the UI the owner
  has a public composer (`commentPublicHint`) plus a private reply box per thread.
- **Visibility including public:** owner → public + every private thread;
  commenter → public + their own thread; signed-out → public only. The feed's
  `recentComments` follows the same per-viewer rule (so public comments preview to
  everyone, private ones only to the right viewer).

## The canonical example (must always pass)

On one post: viewer **A** comments once; viewer **B** comments once; the **owner**
replies to **B** once. Then:

| Who   | Sees | Why |
|-------|------|-----|
| Owner | **3** | A(1) + B(1) + own reply(1), across 2 threads |
| A     | **1** | only A's own comment |
| B     | **2** | B's comment + the owner's reply |

A never sees B's comment; B never sees A's.

## How it's enforced (source of truth = server)

- **Storage** (`PostsTable`): `pk="post#<postId>"`,
  `sk="comment#<threadUser>#<createdMs>#<commentId>"`. `threadUser` is always the
  **non-owner** participant, so `begins_with "comment#<uid>#"` returns exactly one
  thread and `begins_with "comment#"` returns all (owner view).
- **Ownership is authoritative, never client-claimed.** `_find_post(authorId,
  postId)` confirms the post really exists under that author before any read/write
  — so a client can't spoof `postAuthorId` to read another commenter's thread.
- **Read gating** (`list_comments`): owner → all threads; otherwise the caller
  must be a connected friend (`_connected_ids`) and gets `comment#<caller>#` only.
- **Write gating** (`create_comment`): non-owner must be connected; their
  `threadUser` is forced to themselves. Owner must pass a `threadUser` that has an
  existing thread.
- **Push**: a new comment notifies the owner; an owner reply notifies that
  commenter (best-effort `_push`).
- **Delete** (`/circle/comment/delete`): the **post owner** may delete ANY comment
  on their post; a **commenter** may delete only their **own**. Enforced
  server-side (`uid == owner or uid == comment.authorId`), so the UI offering the
  control is a convenience, not the gate. `threadUser` scopes the lookup.
- **Client mirrors, never widens.** `_CommentsSheet` trusts the server's
  `isOwner` + `threads`; it must not assemble or request threads the server
  didn't return.

## Checklist before you ship a comments change

- [ ] A commenter still cannot retrieve or even count another commenter's thread.
- [ ] Only the OWNER can broadcast (`public:true`); a non-owner's `public` is ignored
      → their comment stays in their own private thread.
- [ ] Spoofing `postAuthorId` still 404s (ownership comes from `_find_post`).
- [ ] `backend/tests/test_posts.py` comment tests still pass (they encode the
      example above). Add a test for any new path.
- [ ] `commentCount` stays per-viewer; never leak a global count to a commenter.
- [ ] Endpoints stay backward-compatible (apply `production-safety`); these routes
      ship in the client, so additive-only.
