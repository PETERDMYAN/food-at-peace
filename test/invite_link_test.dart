import 'package:flutter_test/flutter_test.dart';

import 'package:food_at_peace/src/data/invite_link.dart';

void main() {
  group('inviteLinkFor', () {
    test('builds the canonical universal link, normalizing the handle', () {
      expect(inviteLinkFor('alex'), 'https://foodatpeace.app/i/alex');
      expect(inviteLinkFor('@Alex'), 'https://foodatpeace.app/i/alex');
      expect(inviteLinkFor('  MIA_99 '), 'https://foodatpeace.app/i/mia_99');
    });

    test('scheme link mirrors the universal link', () {
      expect(inviteSchemeLinkFor('@Alex'), 'foodatpeace://i/alex');
    });
  });

  group('handleFromInvite', () {
    test('parses the universal link', () {
      expect(
        handleFromInvite(Uri.parse('https://foodatpeace.app/i/alex')),
        'alex',
      );
    });

    test('parses the custom scheme (host form and /// form)', () {
      expect(handleFromInvite(Uri.parse('foodatpeace://i/mia_99')), 'mia_99');
      expect(handleFromInvite(Uri.parse('foodatpeace:///i/mia_99')), 'mia_99');
    });

    test('round-trips what inviteLinkFor produces', () {
      for (final h in ['alex', 'mia_99', 'a1b2c3']) {
        expect(handleFromInvite(Uri.parse(inviteLinkFor(h))), h);
        expect(handleFromInvite(Uri.parse(inviteSchemeLinkFor(h))), h);
      }
    });

    test('rejects a foreign domain', () {
      expect(handleFromInvite(Uri.parse('https://evil.test/i/alex')), isNull);
    });

    test('rejects non-invite paths', () {
      expect(handleFromInvite(Uri.parse('https://foodatpeace.app/x/alex')), isNull);
      expect(handleFromInvite(Uri.parse('https://foodatpeace.app/')), isNull);
    });

    test('rejects an invalid handle (too short / illegal chars)', () {
      expect(handleFromInvite(Uri.parse('https://foodatpeace.app/i/a')), isNull);
      expect(handleFromInvite(Uri.parse('https://foodatpeace.app/i/bad-dash')), isNull);
      expect(
        handleFromInvite(Uri.parse('https://foodatpeace.app/i/waaaaytoolong_over20chars')),
        isNull,
      );
    });
  });
}
