import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_at_peace/src/data/food_photo_analyzer.dart';
import 'package:food_at_peace/src/providers/providers.dart';

/// Returns a fixed key without touching secure storage, so the selector can be
/// tested deterministically.
class _FakeApiKeyNotifier extends ApiKeyNotifier {
  _FakeApiKeyNotifier(this._value);
  final String? _value;

  @override
  String? build() => _value;
}

void main() {
  group('foodPhotoAnalyzerProvider', () {
    test('uses a DirectAnalyzer when the user has their own key', () {
      final container = ProviderContainer(
        overrides: [
          apiKeyProvider.overrideWith(() => _FakeApiKeyNotifier('sk-ant-user')),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(foodPhotoAnalyzerProvider), isA<DirectAnalyzer>());
    });

    test('is null with no key and no proxy URL baked in', () {
      // proxyBaseUrl is a compile-time const, empty in the test build, so the
      // proxy branch isn't reachable here — ProxyAnalyzer is covered directly in
      // proxy_analyzer_test.dart.
      final container = ProviderContainer(
        overrides: [
          apiKeyProvider.overrideWith(() => _FakeApiKeyNotifier(null)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(foodPhotoAnalyzerProvider), isNull);
    });
  });
}
