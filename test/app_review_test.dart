import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/data/app_review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records calls so we can assert the prompter's behaviour without the OS sheet.
class _FakeReview implements AppReviewService {
  _FakeReview({this.available = true});
  bool available;
  int requested = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requested++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppReviewPrompter> build(_FakeReview svc) async =>
      AppReviewPrompter(await SharedPreferences.getInstance(), svc);

  test('asks exactly once, on the 5th open', () async {
    final svc = _FakeReview();
    final p = await build(svc);
    for (var i = 0; i < 4; i++) {
      await p.registerOpenAndMaybeAsk();
    }
    expect(svc.requested, 0, reason: 'opens 1–4 should not ask');
    await p.registerOpenAndMaybeAsk(); // 5th open
    expect(svc.requested, 1);
    await p.registerOpenAndMaybeAsk();
    await p.registerOpenAndMaybeAsk();
    expect(svc.requested, 1, reason: 'never ask twice');
  });

  test('skips when the OS prompt is unavailable, then asks once available', () async {
    final svc = _FakeReview(available: false);
    final p = await build(svc);
    for (var i = 0; i < 6; i++) {
      await p.registerOpenAndMaybeAsk();
    }
    expect(svc.requested, 0);
    svc.available = true; // next launch the OS allows it
    await p.registerOpenAndMaybeAsk();
    expect(svc.requested, 1);
  });
}
