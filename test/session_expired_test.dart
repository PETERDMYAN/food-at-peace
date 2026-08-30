import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/data/auth_client.dart';
import 'package:food_at_peace/src/data/session_store.dart';
import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/widgets/session_expired_banner.dart';

/// In-memory Keychain stand-in.
class _MemStore extends SessionStore {
  _MemStore([this.session]);

  Session? session;
  int deletes = 0;

  @override
  Future<Session?> read() async => session;
  @override
  Future<void> write(Session s) async => session = s;
  @override
  Future<void> delete() async {
    session = null;
    deletes++;
  }
}

Session _session({
  required Duration age,
  Duration ttl = const Duration(days: 60),
  bool knownAge = true,
}) {
  final issued = DateTime.now().subtract(age);
  return Session(
    token: 'old-token',
    userId: 'apple:u1',
    email: 'eva@icloud.com',
    expiresAt: issued.add(ttl),
    issuedAt: knownAge ? issued : null,
  );
}

http.Response _renewed() => http.Response(
  jsonEncode({
    'sessionToken': 'new-token',
    'userId': 'apple:u1',
    'email': 'eva@icloud.com',
    'expiresInSeconds': 365 * 24 * 3600,
  }),
  200,
);

/// Let AuthNotifier._load (store read → refresh round-trip → store write) run.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

Future<ProviderContainer> _boot({
  required _MemStore store,
  required MockClient client,
  Map<String, Object> prefsSeed = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsSeed);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      sessionStoreProvider.overrideWithValue(store),
      authClientProvider.overrideWithValue(
        AuthClient(baseUrl: 'https://x.test', httpClient: client),
      ),
    ],
  );
  addTearDown(c.dispose);
  c.read(authProvider); // builds the notifier → loads + maybe renews
  await _settle();
  return c;
}

void main() {
  group('AuthNotifier session renewal', () {
    test('an expired stored session is dropped AND the user is told', () async {
      final store = _MemStore(
        _session(age: const Duration(days: 61)), // 60-day token, a day past
      );
      var calls = 0;
      final c = await _boot(
        store: store,
        client: MockClient((_) async {
          calls++;
          return _renewed();
        }),
      );

      expect(c.read(authProvider), isNull);
      expect(store.session, isNull);
      expect(store.deletes, 1);
      expect(calls, 0, reason: 'an expired token is never sent for renewal');
      expect(c.read(sessionExpiredNoticeProvider), isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'session_expired_notice',
        ),
        isTrue,
        reason: 'the notice survives a relaunch until acted on',
      );
    });

    test('a token older than a week is renewed on launch', () async {
      final store = _MemStore(_session(age: const Duration(days: 10)));
      late http.Request captured;
      final c = await _boot(
        store: store,
        client: MockClient((req) async {
          captured = req;
          return _renewed();
        }),
      );

      expect(captured.url.toString(), 'https://x.test/auth/refresh');
      expect(captured.method, 'POST');
      expect(captured.headers['authorization'], 'Bearer old-token');
      expect(c.read(authProvider)?.token, 'new-token');
      expect(store.session?.token, 'new-token');
      expect(store.session?.issuedAt, isNotNull);
      expect(
        store.session!.expiresAt.isAfter(
          DateTime.now().add(const Duration(days: 364)),
        ),
        isTrue,
      );
      expect(c.read(sessionExpiredNoticeProvider), isFalse);
    });

    test('a recent token is left alone', () async {
      final store = _MemStore(_session(age: const Duration(days: 2)));
      var calls = 0;
      final c = await _boot(
        store: store,
        client: MockClient((_) async {
          calls++;
          return _renewed();
        }),
      );

      expect(calls, 0);
      expect(c.read(authProvider)?.token, 'old-token');
    });

    test('a session saved by a pre-renewal build (no issuedAt) is renewed',
        () async {
      final store = _MemStore(
        _session(age: const Duration(days: 1), knownAge: false),
      );
      var calls = 0;
      final c = await _boot(
        store: store,
        client: MockClient((_) async {
          calls++;
          return _renewed();
        }),
      );

      expect(calls, 1);
      expect(c.read(authProvider)?.token, 'new-token');
    });

    test('a 401 on renewal signs out and raises the notice', () async {
      final store = _MemStore(_session(age: const Duration(days: 10)));
      final c = await _boot(
        store: store,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'Session expired. Please sign in again.'},
            }),
            401,
          ),
        ),
      );

      expect(c.read(authProvider), isNull);
      expect(store.session, isNull);
      expect(c.read(sessionExpiredNoticeProvider), isTrue);
    });

    test('a non-auth failure keeps the session and stays quiet', () async {
      // An older server without the route (404) or a network blip must never
      // sign the user out — the current token is still perfectly valid.
      for (final client in [
        MockClient((_) async => http.Response('not found', 404)),
        MockClient((_) async => throw Exception('offline')),
      ]) {
        final store = _MemStore(_session(age: const Duration(days: 10)));
        final c = await _boot(store: store, client: client);

        expect(c.read(authProvider)?.token, 'old-token');
        expect(store.session?.token, 'old-token');
        expect(c.read(sessionExpiredNoticeProvider), isFalse);
      }
    });

    test('resume re-checks, but at most once an hour after a failure', () async {
      var calls = 0;
      final store = _MemStore(_session(age: const Duration(days: 10)));
      final c = await _boot(
        store: store,
        client: MockClient((_) async {
          calls++;
          return http.Response('not found', 404);
        }),
      );
      expect(calls, 1);

      await c.read(authProvider.notifier).refreshIfDue(); // e.g. app resumed
      expect(calls, 1, reason: 'backs off instead of retrying every resume');
    });

    test('the notice persists across launches until cleared', () async {
      SharedPreferences.setMockInitialValues({'session_expired_notice': true});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);

      expect(c.read(sessionExpiredNoticeProvider), isTrue);
      await c.read(sessionExpiredNoticeProvider.notifier).clear();
      expect(c.read(sessionExpiredNoticeProvider), isFalse);
      expect(prefs.getBool('session_expired_notice'), isNull);
    });
  });

  group('SessionExpiredBanner', () {
    Widget host(SharedPreferences prefs) => ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SessionExpiredBanner()),
      ),
    );

    testWidgets('shows when the notice is set; Later dismisses it', (t) async {
      SharedPreferences.setMockInitialValues({'session_expired_notice': true});
      final prefs = await SharedPreferences.getInstance();
      await t.pumpWidget(host(prefs));
      await t.pumpAndSettle();

      expect(find.text('Your sign-in expired'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);

      await t.tap(find.text('Later'));
      await t.pumpAndSettle();

      expect(find.text('Your sign-in expired'), findsNothing);
      expect(prefs.getBool('session_expired_notice'), isNull);
    });

    testWidgets('renders nothing without a notice', (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await t.pumpWidget(host(prefs));
      await t.pumpAndSettle();

      expect(find.text('Your sign-in expired'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });
}
