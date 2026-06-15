/// Circle invite links — the single source of truth for the shareable URL and
/// for parsing inbound links/QRs back into a handle.
///
/// The canonical link is a **universal link** (`https://<domain>/i/<handle>`):
/// it renders as a tappable link in WeChat / WhatsApp / SMS and encodes cleanly
/// into a QR code. On a device with the app installed it opens the app directly
/// (via the Associated Domains + AASA setup); otherwise it falls back to the
/// website. A custom-scheme form (`foodatpeace://i/<handle>`) is also accepted
/// so the deep-link flow is testable without the AASA hosted yet.
library;

/// Domain that hosts the Apple App Site Association file and serves invite
/// links. Change here (one place) if the production domain differs.
const String kInviteDomain = 'foodatpeace.app';

/// Custom URL scheme registered in Info.plist — a fallback path that needs no
/// domain/entitlement, handy for testing the connect flow on a fresh device.
const String kInviteScheme = 'foodatpeace';

final RegExp _handleRe = RegExp(r'^[a-z0-9_]{2,20}$');

String _normalize(String raw) => raw.trim().replaceAll('@', '').toLowerCase();

/// The shareable universal link for [handle] (with or without a leading `@`).
String inviteLinkFor(String handle) => 'https://$kInviteDomain/i/${_normalize(handle)}';

/// The custom-scheme equivalent (testing/fallback).
String inviteSchemeLinkFor(String handle) => '$kInviteScheme://i/${_normalize(handle)}';

/// Extracts the invited handle from an inbound link/QR, or `null` if [uri] is
/// not a (valid) Circle invite. Accepts both the universal link and the custom
/// scheme, and tolerates the `///` form some openers produce.
String? handleFromInvite(Uri uri) {
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https' && uri.host.toLowerCase() == kInviteDomain) {
    // https://foodatpeace.app/i/<handle>
    if (segs.length >= 2 && segs[0].toLowerCase() == 'i') return _validate(segs[1]);
  } else if (scheme == kInviteScheme) {
    // foodatpeace://i/<handle>     -> host == 'i', segs == [handle]
    if (uri.host.toLowerCase() == 'i' && segs.isNotEmpty) return _validate(segs[0]);
    // foodatpeace:///i/<handle>    -> host == '',  segs == ['i', handle]
    if (segs.length >= 2 && segs[0].toLowerCase() == 'i') return _validate(segs[1]);
  }
  return null;
}

String? _validate(String raw) {
  final h = _normalize(raw);
  return _handleRe.hasMatch(h) ? h : null;
}
